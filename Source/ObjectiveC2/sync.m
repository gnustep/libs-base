#include "runtime.h"

/* Ensure Unix98 compatible pthreads for glibc */
#if defined __GLIBC__
	#define __USE_UNIX98 1
#endif

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

@interface Fake
+ (void)dealloc;
@end

static pthread_mutex_t at_sync_init_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned long long lockClassId;

IMP objc_msg_lookup(id, SEL);

static void deallocLockClass(id obj, SEL _cmd);

static inline Class findLockClass(id obj)
{
	struct objc_object object = { obj->isa };
	SEL dealloc = @selector(dealloc);
	// Find the first class where this lookup is correct
	if (objc_msg_lookup((id)&object, dealloc) != (IMP)deallocLockClass)
	{
		do {
			object.isa = class_getSuperclass(object.isa);
		} while (Nil != object.isa && 
				objc_msg_lookup((id)&object, dealloc) != (IMP)deallocLockClass);
	}
	if (Nil == object.isa) { return Nil; }
	// object->isa is now either the lock class, or a class which inherits from
	// the lock class
	Class lastClass;
	do {
		lastClass = object.isa;
		object.isa = class_getSuperclass(object.isa);
	} while (Nil != object.isa &&
		   objc_msg_lookup((id)&object, dealloc) == (IMP)deallocLockClass);
	return lastClass;
}

static inline Class initLockObject(id obj)
{
	char nameBuffer[40];
	snprintf(nameBuffer, 39, "hiddenlockClass%lld", lockClassId++);
	Class lockClass = objc_allocateClassPair(obj->isa, nameBuffer,
			sizeof(pthread_mutex_t));
	const char *types =
		method_getTypeEncoding(class_getInstanceMethod(obj->isa,
					@selector(dealloc)));
	class_addMethod(lockClass, @selector(dealloc), (IMP)deallocLockClass,
			types);
	objc_registerClassPair(lockClass);

	pthread_mutex_t *lock = object_getIndexedIvars(lockClass);
	pthread_mutexattr_t attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(lock, &attr);
	pthread_mutexattr_destroy(&attr);

	obj->isa = lockClass;
	return lockClass;
}

static void deallocLockClass(id obj, SEL _cmd)
{
	Class lockClass = findLockClass(obj);
	Class realClass = class_getSuperclass(lockClass);
	// Free the lock
	pthread_mutex_t *lock = object_getIndexedIvars(lockClass);
	pthread_mutex_destroy(lock);
	// Free the class
	objc_disposeClassPair(lockClass);
	// Reset the class then call the real -dealloc
	obj->isa = realClass;
	[obj dealloc];
}

void objc_sync_enter(id obj)
{
	Class lockClass = findLockClass(obj);
	if (Nil == lockClass)
	{
		pthread_mutex_lock(&at_sync_init_lock);
		// Test again in case two threads call objc_sync_enter at once
		lockClass = findLockClass(obj);
		if (Nil == lockClass)
		{
			lockClass = initLockObject(obj);
		}
		pthread_mutex_unlock(&at_sync_init_lock);
	}
	pthread_mutex_t *lock = object_getIndexedIvars(lockClass);
	pthread_mutex_lock(lock);
}
void objc_sync_exit(id obj)
{
	Class lockClass = findLockClass(obj);
	pthread_mutex_t *lock = object_getIndexedIvars(lockClass);
	pthread_mutex_unlock(lock);
}
