/* Ensure Unix98 compatible pthreads for glibc */
#if defined __linux__ || defined __GNU__ || defined __GLIBC__
#  ifndef _XOPEN_SOURCE
#    define _XOPEN_SOURCE 600
#  endif
#endif

#include "ObjectiveC2/runtime.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

@interface Fake
+ (void) dealloc;
@end

static pthread_mutex_t at_sync_init_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned long long lockClassId;

IMP objc_msg_lookup(id, SEL);

static void deallocLockClass(id obj, SEL _cmd);

static inline Class
findLockClass(id obj)
{
  struct objc_object object = { obj->isa };
  SEL dealloc = @selector(dealloc);
  Class lastClass;

  // Find the first class where this lookup is correct
  if (objc_msg_lookup((id)&object, dealloc) != (IMP)deallocLockClass)
    {
      do {
	object.isa = class_getSuperclass(object.isa);
      } while (Nil != object.isa
	&& objc_msg_lookup((id)&object, dealloc) != (IMP)deallocLockClass);
    }
  if (Nil == object.isa)
    {
      return Nil;
    }
  /* object->isa is now either the lock class, or a class which inherits from
   * the lock class
   */
  do {
    lastClass = object.isa;
    object.isa = class_getSuperclass(object.isa);
  } while (Nil != object.isa
    && objc_msg_lookup((id)&object, dealloc) == (IMP)deallocLockClass);
  return lastClass;
}

static inline Class
initLockObject(id obj)
{
  Class lockClass;
  const char *types;
  pthread_mutex_t *lock;
  pthread_mutexattr_t attr;

  if (class_isMetaClass(obj->isa))
    {
      lockClass = objc_allocateMetaClass(obj, sizeof(pthread_mutex_t));
    }
  else
    {
      char nameBuffer[40];

      snprintf(nameBuffer, 39, "hiddenlockClass%lld", lockClassId++);
      lockClass = objc_allocateClassPair(obj->isa, nameBuffer,
	sizeof(pthread_mutex_t));
    }

  types = method_getTypeEncoding(class_getInstanceMethod(obj->isa,
    @selector(dealloc)));
  class_addMethod(lockClass, @selector(dealloc), (IMP)deallocLockClass, types);

  if (!class_isMetaClass(obj->isa))
    {
      objc_registerClassPair(lockClass);
    }

  lock = object_getIndexedIvars(lockClass);
  pthread_mutexattr_init(&attr);
  pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(lock, &attr);
  pthread_mutexattr_destroy(&attr);

  obj->isa = lockClass;
  return lockClass;
}

static void
deallocLockClass(id obj, SEL _cmd)
{
  Class lockClass = findLockClass(obj);
  Class realClass = class_getSuperclass(lockClass);
  // Free the lock
  pthread_mutex_t *lock = object_getIndexedIvars(lockClass);

  pthread_mutex_destroy(lock);
  // Free the class
#ifndef __MINGW32__
  objc_disposeClassPair(lockClass);
#endif
  // Reset the class then call the real -dealloc
  obj->isa = realClass;
  [obj dealloc];
}

void
objc_sync_enter(id obj)
{
  Class lockClass = findLockClass(obj);
  pthread_mutex_t *lock;

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
  lock = object_getIndexedIvars(lockClass);
  pthread_mutex_lock(lock);
}

void
objc_sync_exit(id obj)
{
  Class lockClass = findLockClass(obj);
  pthread_mutex_t *lock = object_getIndexedIvars(lockClass);
  pthread_mutex_unlock(lock);
}
