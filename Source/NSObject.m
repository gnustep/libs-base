/** Implementation of NSObject for GNUStep
   Copyright (C) 1994-2010 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSObject class reference</title>
   $Date$ $Revision$
   */

/* On some versions of mingw we need to work around bad function declarations
 * by defining them away and doing the declarations ourself later.
 */
#ifndef _WIN64
#define InterlockedIncrement	BadInterlockedIncrement
#define InterlockedDecrement	BadInterlockedDecrement
#endif

#import "common.h"
#include <objc/Protocol.h>
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSDistantObject.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSMapTable.h"
#import "GNUstepBase/GSLocale.h"
#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif

#ifdef	HAVE_SIGNAL_H
#include	<signal.h>
#endif
#ifdef	HAVE_SYS_SIGNAL_H
#include	<sys/signal.h>
#endif
#ifdef __FreeBSD__
#include <fenv.h>
#endif

#import "GSPrivate.h"


#ifndef NeXT_RUNTIME
extern BOOL __objc_responds_to(id, SEL);
#endif

/* When this is `YES', every call to release/autorelease, checks to
   make sure isn't being set up to release itself too many times.
   This does not need mutex protection. */
static BOOL double_release_check_enabled = NO;

/* The Class responsible for handling autorelease's.  This does not
   need mutex protection, since it is simply a pointer that gets read
   and set. */
static id autorelease_class = nil;
static SEL autorelease_sel;
static IMP autorelease_imp;



#if GS_WITH_GC

#include	<gc.h>
#include	<gc_typed.h>

static SEL finalize_sel;
static IMP finalize_imp;
#endif

static Class	NSConstantStringClass;

@class	NSDataMalloc;
@class	NSMutableDataMalloc;

@interface	NSZombie
{
  Class	isa;
}
- (Class) class;
- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;
@end

@interface GSContentAccessingProxy : NSProxy 
{
  NSObject<NSDiscardableContent> *object;
}
- (id) initWithObject: (id)anObject;
@end

/*
 * allocationLock is needed when running multi-threaded for 
 * protecting the map table of zombie information.
 */
static NSLock *allocationLock;

BOOL	NSZombieEnabled = NO;
BOOL	NSDeallocateZombies = NO;

@class	NSZombie;
static Class		zombieClass;
static NSMapTable	*zombieMap;

#if	!GS_WITH_GC
static void GSMakeZombie(NSObject *o)
{
  Class	c = ((id)o)->class_pointer;

  ((id)o)->class_pointer = zombieClass;
  if (NSDeallocateZombies == NO)
    {
      [allocationLock lock];
      NSMapInsert(zombieMap, (void*)o, (void*)c);
      [allocationLock unlock];
    }
}
#endif

static void GSLogZombie(id o, SEL sel)
{
  Class	c = 0;

  if (NSDeallocateZombies == NO)
    {
      [allocationLock lock];
      c = NSMapGet(zombieMap, (void*)o);
      [allocationLock unlock];
    }
  if (c == 0)
    {
      NSLog(@"Deallocated object (%p) sent %@",
	o, NSStringFromSelector(sel));
    }
  else
    {
      NSLog(@"Deallocated %@ (%p) sent %@",
	c, o, NSStringFromSelector(sel));
    }
  if (GSPrivateEnvironmentFlag("CRASH_ON_ZOMBIE", NO) == YES)
    {
      abort();
    }
}


/*
 *	Reference count and memory management
 *	Reference counts for object are stored
 *	with the object.
 *	The zone in which an object has been
 *	allocated is stored with the object.
 */

/* Now, if we are on a platform where we know how to do atomic
 * read, increment, and decrement, then we define the GSATOMICREAD
 * macro and macros or functions to increment/decrement.
 * The presence of the GSATOMICREAD macro is used later to determine
 * whether to attempt atomic operations or to use locking for the
 * retain/release mechanism.
 * The GSAtomicIncrement() and GSAtomicDecrement() functions take a
 * pointer to a 32bit integer as an argument, increment/decrement the
 * value pointed to, and return the result.
 */
#ifdef	GSATOMICREAD
#undef	GSATOMICREAD
#endif

#if	defined(__MINGW__)
#ifndef _WIN64
#undef InterlockedIncrement
#undef InterlockedDecrement
LONG WINAPI InterlockedIncrement(LONG volatile *);
LONG WINAPI InterlockedDecrement(LONG volatile *);
#endif

/* Set up atomic read, increment and decrement for mswindows
 */

typedef int32_t volatile *gsatomic_t;

#define	GSATOMICREAD(X)	(*(X))

#define	GSAtomicIncrement(X)	InterlockedIncrement((LONG volatile*)X)
#define	GSAtomicDecrement(X)	InterlockedDecrement((LONG volatile*)X)


#elif defined(__llvm__) || (defined(USE_ATOMIC_BUILDINS) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 1)))
/* Use the GCC atomic operations with recent GCC versions */

typedef int32_t volatile *gsatomic_t;
#define GSATOMICREAD(X) (*(X))
#define GSAtomicIncrement(X)    __sync_fetch_and_add(X, 1)
#define GSAtomicDecrement(X)    __sync_fetch_and_sub(X, 1)


#elif	defined(__linux__) && (defined(__i386__) || defined(__x86_64__))
/* Set up atomic read, increment and decrement for intel style linux
 */

typedef int32_t volatile *gsatomic_t;

#define	GSATOMICREAD(X)	(*(X))

static __inline__ int
GSAtomicIncrement(gsatomic_t X)
{
 __asm__ __volatile__ (
     "lock addl $1, %0"
     :"=m" (*X));
 return *X;
}

static __inline__ int
GSAtomicDecrement(gsatomic_t X)
{
 __asm__ __volatile__ (
     "lock subl $1, %0"
     :"=m" (*X));
 return *X;
}

#elif defined(__PPC__) || defined(__POWERPC__)

typedef int32_t volatile *gsatomic_t;

#define	GSATOMICREAD(X)	(*(X))

static __inline__ int
GSAtomicIncrement(gsatomic_t X)
{
  int tmp;
  __asm__ __volatile__ (
    "0:"
    "lwarx %0,0,%1 \n"
    "addic %0,%0,1 \n"
    "stwcx. %0,0,%1 \n"
    "bne- 0b \n"
    :"=&r" (tmp)
    :"r" (X)
    :"cc", "memory");
  return *X;
}

static __inline__ int
GSAtomicDecrement(gsatomic_t X)
{
  int tmp;
  __asm__ __volatile__ (
    "0:"
    "lwarx %0,0,%1 \n"
    "addic %0,%0,-1 \n"
    "stwcx. %0,0,%1 \n"
    "bne- 0b \n"
    :"=&r" (tmp)
    :"r" (X)
    :"cc", "memory");
  return *X;
}

#elif defined(__m68k__)

typedef int32_t volatile *gsatomic_t;

#define	GSATOMICREAD(X)	(*(X))

static __inline__ int
GSAtomicIncrement(gsatomic_t X)
{
  __asm__ __volatile__ (
    "addq%.l %#1, %0"
    :"=m" (*X));
    return *X;
}

static __inline__ int
GSAtomicDecrement(gsatomic_t X)
{
  __asm__ __volatile__ (
    "subq%.l %#1, %0"
    :"=m" (*X));
    return *X;
}

#elif defined(__mips__)

typedef int32_t volatile *gsatomic_t;

#define	GSATOMICREAD(X)	(*(X))

static __inline__ int
GSAtomicIncrement(gsatomic_t X)
{
  int tmp;

  __asm__ __volatile__ (
    "   .set  mips2  \n"
    "0: ll    %0, %1 \n"
    "   addiu %0, 1  \n"
    "   sc    %0, %1 \n"
    "   beqz  %0, 0b  \n"
    :"=&r" (tmp), "=m" (*X));
    return *X;
}

static __inline__ int
GSAtomicDecrement(gsatomic_t X)
{
  int tmp;

  __asm__ __volatile__ (
    "   .set  mips2  \n"
    "0: ll    %0, %1 \n"
    "   addiu %0, -1 \n"
    "   sc    %0, %1 \n"
    "   beqz  %0, 0b  \n"
    :"=&r" (tmp), "=m" (*X));
    return *X;
}
#endif

#if	!defined(GSATOMICREAD)

/*
 * Having just one allocationLock for all leads to lock contention
 * if there are lots of threads doing lots of retain/release calls.
 * To alleviate this, instead of a single
 * allocationLock for all objects, we divide the object space into
 * chunks, each with its own lock. The chunk is selected by shifting
 * off the low-order ALIGNBITS of the object's pointer (these bits
 * are presumably always zero) and take
 * the low-order LOCKBITS of the result to index into a table of locks.
 */

#define LOCKBITS 5
#define LOCKCOUNT (1<<LOCKBITS)
#define LOCKMASK (LOCKCOUNT-1)
#define ALIGNBITS 3

static NSLock *allocationLocks[LOCKCOUNT] = { 0 };

static inline NSLock *GSAllocationLockForObject(id p)
{
  NSUInteger i = ((((NSUInteger)(uintptr_t)p) >> ALIGNBITS) & LOCKMASK);
  return allocationLocks[i];
}

#endif


#ifdef ALIGN
#undef ALIGN
#endif
#define	ALIGN __alignof__(double)

/*
 *	Define a structure to hold information that is held locally
 *	(before the start) in each object.
 */
typedef struct obj_layout_unpadded {
    NSUInteger	retained;
    NSZone	*zone;
} unp;
#define	UNP sizeof(unp)

/*
 *	Now do the REAL version - using the other version to determine
 *	what padding (if any) is required to get the alignment of the
 *	structure correct.
 */
struct obj_layout {
    NSUInteger	retained;
    NSZone	*zone;
    char	padding[ALIGN - ((UNP % ALIGN) ? (UNP % ALIGN) : ALIGN)];
};
typedef	struct obj_layout *obj;


/**
 * Examines the extra reference count for the object and, if non-zero
 * decrements it, otherwise leaves it unchanged.<br />
 * Returns a flag to say whether the count was zero
 * (and hence whether the extra reference count was decremented).<br />
 * This function is used by the [NSObject-release] method.
 */
BOOL
NSDecrementExtraRefCountWasZero(id anObject)
{
#if	!GS_WITH_GC
  if (double_release_check_enabled)
    {
      NSUInteger release_count;
      NSUInteger retain_count = [anObject retainCount];
      release_count = [autorelease_class autoreleaseCountForObject: anObject];
      if (release_count >= retain_count)
        [NSException raise: NSGenericException
		    format: @"Release would release object too many times."];
    }
  if (allocationLock != 0)
    {
#if	defined(GSATOMICREAD)
      int	result;

      result = GSAtomicDecrement((gsatomic_t)&(((obj)anObject)[-1].retained));
      if (result < 0)
	{
	  if (result != -1)
	    {
	      [NSException raise: NSInternalInconsistencyException
		format: @"NSDecrementExtraRefCount() decremented too far"];
	    }
	  /* The counter has become negative so it must have been zero.
	   * We reset it and return YES ... in a correctly operating
	   * process we know we can safely reset back to zero without
	   * worrying about atomicity, since there can be no other
	   * thread accessing the object (or its reference count would
	   * have been greater than zero)
	   */
	  (((obj)anObject)[-1].retained) = 0;
	  return YES;
	}
#else	/* GSATOMICREAD */
      NSLock *theLock = GSAllocationLockForObject(anObject);

      [theLock lock];
      if (((obj)anObject)[-1].retained == 0)
	{
	  [theLock unlock];
	  return YES;
	}
      else
	{
	  ((obj)anObject)[-1].retained--;
	  [theLock unlock];
	  return NO;
	}
#endif	/* GSATOMICREAD */
    }
  else
    {
      if (((obj)anObject)[-1].retained == 0)
	{
	  return YES;
	}
      else
	{
	  ((obj)anObject)[-1].retained--;
	  return NO;
	}
    }
#endif /* !GS_WITH_GC */
  return NO;
}

/**
 * Return the extra reference count of anObject (a value in the range
 * from 0 to the maximum unsigned integer value minus one).<br />
 * The retain count for an object is this value plus one.
 */
inline NSUInteger
NSExtraRefCount(id anObject)
{
#if	GS_WITH_GC
  return UINT_MAX - 1;
#else	/* GS_WITH_GC */
  return ((obj)anObject)[-1].retained;
#endif /* GS_WITH_GC */
}

/**
 * Increments the extra reference count for anObject.<br />
 * The GNUstep version raises an exception if the reference count
 * would be incremented to too large a value.<br />
 * This is used by the [NSObject-retain] method.
 */
inline void
NSIncrementExtraRefCount(id anObject)
{
#if	GS_WITH_GC
  return;
#else	/* GS_WITH_GC */
  if (allocationLock != 0)
    {
#if	defined(GSATOMICREAD)
      /* I've seen comments saying that some platforms only support up to
       * 24 bits in atomic locking, so raise an exception if we try to
       * go beyond 0xfffffe.
       */
      if (GSAtomicIncrement((gsatomic_t)&(((obj)anObject)[-1].retained))
        > 0xfffffe)
	{
	  [NSException raise: NSInternalInconsistencyException
	    format: @"NSIncrementExtraRefCount() asked to increment too far"];
	}
#else	/* GSATOMICREAD */
      NSLock *theLock = GSAllocationLockForObject(anObject);

      [theLock lock];
      if (((obj)anObject)[-1].retained == UINT_MAX - 1)
	{
	  [theLock unlock];
	  [NSException raise: NSInternalInconsistencyException
	    format: @"NSIncrementExtraRefCount() asked to increment too far"];
	}
      ((obj)anObject)[-1].retained++;
      [theLock unlock];
#endif	/* GSATOMICREAD */
    }
  else
    {
      if (((obj)anObject)[-1].retained == UINT_MAX - 1)
	{
	  [NSException raise: NSInternalInconsistencyException
	    format: @"NSIncrementExtraRefCount() asked to increment too far"];
	}
      ((obj)anObject)[-1].retained++;
    }
#endif	/* GS_WITH_GC */
}

#ifndef	NDEBUG
#define	AADD(c, o) GSDebugAllocationAdd(c, o)
#define	AREM(c, o) GSDebugAllocationRemove(c, o)
#else
#define	AADD(c, o) 
#define	AREM(c, o) 
#endif

/*
 *	Now do conditional compilation of memory allocation functions
 *	depending on what information (if any) we are storing before
 *	the start of each object.
 */
#if	GS_WITH_GC

inline NSZone *
GSObjCZone(NSObject *object)
{
  GSOnceFLog(@"GSObjCZone() is deprecated ... use -zone instead");
  /* MacOS-X 10.5 seems to return the default malloc zone if GC is enabled.
   */
  return NSDefaultMallocZone();
}

static void
GSFinalize(void* object, void* data)
{
  [(id)object finalize];
  AREM(((id)object)->class_pointer, (id)object);
  ((id)object)->class_pointer = (void*)0xdeadface;
}

static BOOL
GSIsFinalizable(Class c)
{
  if (get_imp(c, finalize_sel) != finalize_imp)
    return YES;
  return NO;
}

inline id
NSAllocateObject(Class aClass, NSUInteger extraBytes, NSZone *zone)
{
  id	new;
  int	size;
  GC_descr	gc_type;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
  gc_type = (GC_descr)aClass->gc_object_type;
  size = class_getInstanceSize(aClass) + extraBytes;
  if (size % sizeof(void*) != 0)
    {
      /* Size must be a multiple of pointer size for the garbage collector
       * to be able to allocate explicitly typed memory.
       */
      size += sizeof(void*) - size % sizeof(void*);
    }

  if (gc_type == 0)
    {
      new = NSZoneCalloc(zone, 1, size);
      NSLog(@"No garbage collection information for '%s'",
	class_getName(aClass));
    }
  else
    {
      new = GC_calloc_explicitly_typed(1, size, gc_type);
    }

  if (new != nil)
    {
      new->class_pointer = aClass;
      if (GSIsFinalizable(aClass))
	{
	  /* We only do allocation counting for objects that can be
	   * finalised - for other objects we have no way of decrementing
	   * the count when the object is collected.
	   */
	  AADD(aClass, new);
	  GC_REGISTER_FINALIZER (new, GSFinalize, NULL, NULL, NULL);
	}
    }
  return new;
}

inline void
NSDeallocateObject(id anObject)
{
}

#else	/* GS_WITH_GC */

inline NSZone *
GSObjCZone(NSObject *object)
{
  GSOnceFLog(@"GSObjCZone() is deprecated ... use -zone instead");
  if (object_getClass(object) == NSConstantStringClass)
    return NSDefaultMallocZone();
  return ((obj)object)[-1].zone;
}

inline id
NSAllocateObject (Class aClass, NSUInteger extraBytes, NSZone *zone)
{
  id	new;
  int	size;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
  size = class_getInstanceSize(aClass) + extraBytes + sizeof(struct obj_layout);
  if (zone == 0)
    {
      zone = NSDefaultMallocZone();
    }
  new = NSZoneMalloc(zone, size);
  if (new != nil)
    {
      memset (new, 0, size);
      ((obj)new)->zone = zone;
      new = (id)&((obj)new)[1];
      new->class_pointer = aClass;
      AADD(aClass, new);
    }
  return new;
}

inline void
NSDeallocateObject(id anObject)
{
  if ((anObject!=nil) && CLS_ISCLASS(((id)anObject)->class_pointer))
    {
      obj	o = &((obj)anObject)[-1];
      NSZone	*z = o->zone;

      AREM(((id)anObject)->class_pointer, (id)anObject);
      if (NSZombieEnabled == YES)
	{
	  GSMakeZombie(anObject);
	  if (NSDeallocateZombies == YES)
	    {
	      NSZoneFree(z, o);
	    }
	}
      else
	{
	  ((id)anObject)->class_pointer = (void*) 0xdeadface;
	  NSZoneFree(z, o);
	}
    }
  return;
}

#endif	/* GS_WITH_GC */


void
GSPrivateSwizzle(id o, Class c)
{
  if ((Class)o->class_pointer != c)
    {
#if	GS_WITH_GC
      /* We only do allocation counting for objects that can be
       * finalised - for other objects we have no way of decrementing
       * the count when the object is collected.
       */
      if (GSIsFinalizable(o->class_pointer))
	{
	  /* Already finalizable, so we just need to do any allocation
	   * accounting.
	   */
          AREM(o->class_pointer, o);
          AADD(c, o);
	}
      else if (GSIsFinalizable(c))
	{
	  /* New class is finalizable, so we must register the instance
	   * for finalisation and do allocation acounting for it.
	   */
	  AADD(c, o);
	  GC_REGISTER_FINALIZER (o, GSFinalize, NULL, NULL, NULL);
	}
#else
      AREM(o->class_pointer, o);
      AADD(c, o);
#endif	/* GS_WITH_GC */
      o->class_pointer = c;
    }
}


BOOL
NSShouldRetainWithZone (NSObject *anObject, NSZone *requestedZone)
{
#if	GS_WITH_GC
  return YES;
#else
  return (!requestedZone || requestedZone == NSDefaultMallocZone()
    || [anObject zone] == requestedZone);
#endif
}



/* FIXME ... the following code is a hack for the gnu runtime only
 */
struct objc_method_description_list {
  int count;
  struct objc_method_description list[1];
};

/* Must have same layout as ivars of Protocol class
 */
struct protocol_class {
  Class	isa;
  char	*protocol_name;
  struct objc_protocol_list *protocol_list;
  struct objc_method_description_list *instance_methods;
  struct objc_method_description_list *class_methods;
};

struct objc_method_description *
GSDescriptionForInstanceMethod(Protocol *self, SEL aSel)
{
  struct protocol_class *pcl = (struct protocol_class*)self;
  int i;
  struct objc_protocol_list	*p_list;
  const char			*name = sel_getName(aSel);
  struct objc_method_description *result;

  if (pcl->instance_methods != 0)
    {
      for (i = 0; i < pcl->instance_methods->count; i++)
	{
	  if (!strcmp ((char*)pcl->instance_methods->list[i].name, name))
	    return &(pcl->instance_methods->list[i]);
	}
    }
  for (p_list = pcl->protocol_list; p_list != 0; p_list = p_list->next)
    {
      for (i = 0; i < p_list->count; i++)
	{
	  result = GSDescriptionForInstanceMethod(p_list->list[i], aSel);
	  if (result)
	    {
	      return result;
	    }
	}
    }

  return NULL;
}

struct objc_method_description *
GSDescriptionForClassMethod(Protocol *self, SEL aSel)
{
  struct protocol_class *pcl = (struct protocol_class*)self;
  int i;
  struct objc_protocol_list	*p_list;
  const char			*name = sel_getName(aSel);
  struct objc_method_description *result;

  if (pcl->class_methods != 0)
    {
      for (i = 0; i < pcl->class_methods->count; i++)
	{
	  if (!strcmp ((char*)pcl->class_methods->list[i].name, name))
	    return &(pcl->class_methods->list[i]);
	}
    }
  for (p_list = pcl->protocol_list; p_list != 0; p_list = p_list->next)
    {
      for (i = 0; i < p_list->count; i++)
	{
	  result = GSDescriptionForClassMethod(p_list->list[i], aSel);
	  if (result)
	    {
	      return result;
	    }
	}
    }

  return NULL;
}

@implementation	Protocol (Fixup)

- (struct objc_method_description *) descriptionForInstanceMethod:(SEL)aSel
{
  return GSDescriptionForInstanceMethod(self, aSel);
}

- (struct objc_method_description *) descriptionForClassMethod:(SEL)aSel;
{
  return GSDescriptionForClassMethod(self, aSel);
}

@end

/**
 * <p>
 *   <code>NSObject</code> is the root class (a root class is
 *   a class with no superclass) of the GNUstep base library
 *   class hierarchy, so all classes normally inherit from
 *   <code>NSObject</code>.  There is an exception though:
 *   <code>NSProxy</code> (which is used for remote messaging)
 *   does not inherit from <code>NSObject</code>.
 * </p>
 * <p>
 *   Unless you are really sure of what you are doing, all
 *   your own classes should inherit (directly or indirectly)
 *   from <code>NSObject</code> (or in special cases from
 *   <code>NSProxy</code>).  <code>NSObject</code> provides
 *   the basic common functionality shared by all GNUstep
 *   classes and objects.
 * </p>
 * <p>
 *   The essential methods which must be implemented by all
 *   classes for their instances to be usable within GNUstep
 *   are declared in a separate protocol, which is the
 *   <code>NSObject</code> protocol.  Both
 *   <code>NSObject</code> and <code>NSProxy</code> conform to
 *   this protocol, which means all objects in a GNUstep
 *   application will conform to this protocol (btw, if you
 *   don't find a method of <code>NSObject</code> you are
 *   looking for in this documentation, make sure you also
 *   look into the documentation for the <code>NSObject</code>
 *   protocol).
 * </p>
 * <p>
 *   Theoretically, in special cases you might need to
 *   implement a new root class.  If you do, you need to make
 *   sure that your root class conforms (at least) to the
 *   <code>NSObject</code> protocol, otherwise it will not
 *   interact correctly with the GNUstep framework.  Said
 *   that, I must note that I have never seen a case in which
 *   a new root class is needed.
 * </p>
 * <p>
 *   <code>NSObject</code> is a root class, which implies that
 *   instance methods of <code>NSObject</code> are treated in
 *   a special way by the Objective-C runtime.  This is an
 *   exception to the normal way messaging works with class
 *   and instance methods: if the Objective-C runtime can't
 *   find a class method for a class object, as a last resort
 *   it looks for an instance method of the root class with
 *   the same name, and executes it if it finds it.  This
 *   means that instance methods of the root class (such as
 *   <code>NSObject</code>) can be performed by class objects
 *   which inherit from that root class !  This can only
 *   happen if the class doesn't have a class method with the
 *   same name, otherwise that method - of course - takes the
 *   precedence.  Because of this exception,
 *   <code>NSObject</code>'s instance methods are written in
 *   such a way that they work both on <code>NSObject</code>'s
 *   instances and on class objects.
 * </p>
 */
@implementation NSObject

+ (void) _becomeMultiThreaded: (NSNotification *)aNotification
{
  if (allocationLock == 0)
    {
#if !defined(GSATOMICREAD)
      NSUInteger	i;

      for (i = 0; i < LOCKCOUNT; i++)
        {
	  allocationLocks[i] = [NSLock new];
	}
#endif
      allocationLock = [NSLock new];
    }
}

#if	GS_WITH_GC
/* Function to log Boehm GC warnings
 * NB. This must not allocate any collectable memory as it may result
 * in a deadlock in the garbage collecting library.
 */
static void
GSGarbageCollectorLog(char *msg, GC_word arg)
{
  char	buf[strlen(msg)+1024];
  sprintf(buf, msg, (unsigned long)arg);
  fprintf(stderr, "Garbage collector: %s", buf);
}
#endif

/**
 * Semi-private function in libobjc2 that initialises the classes used for
 * blocks.
 */
#ifndef __MINGW__
BOOL 
objc_create_block_classes_as_subclasses_of(Class super) __attribute__((weak));
#endif

+ (void)load
{
#ifndef __MINGW__
  /* When NSObject is loaded, register it as the superclass of the block
   * classes */
  if (objc_create_block_classes_as_subclasses_of)
    objc_create_block_classes_as_subclasses_of(self);
#endif
}

+ (void) initialize
{
  if (self == [NSObject class])
    {
#if	GS_WITH_GC
      /* Make sure that the garbage collection library is initialised.
       * This is not necessary on most platforms, but is good practice.
       */
      GC_init();
      GC_set_warn_proc(GSGarbageCollectorLog);
#endif

#ifdef __MINGW__
      {
        // See libgnustep-base-entry.m
        extern void gnustep_base_socket_init(void);	
        gnustep_base_socket_init();	
      }
#else /* __MINGW__ */

#ifdef	SIGPIPE
    /*
     * If SIGPIPE is not handled or ignored, we will abort on any attempt
     * to write to a pipe/socket that has been closed by the other end!
     * We therefore need to ignore the signal if nothing else is already
     * handling it.
     */
#ifdef	HAVE_SIGACTION
      {
	struct sigaction	act;

	if (sigaction(SIGPIPE, 0, &act) == 0)
	  {
	    if (act.sa_handler == SIG_DFL)
	      {
		// Not ignored or handled ... so we ignore it.
		act.sa_handler = SIG_IGN;
		if (sigaction(SIGPIPE, &act, 0) != 0)
		  {
		    fprintf(stderr, "Unable to ignore SIGPIPE\n");
		  }
	      }
	  }
	else
	  {
	    fprintf(stderr, "Unable to retrieve information about SIGPIPE\n");
	  }
      }
#else /* HAVE_SIGACTION */
      {
	void	(*handler)(NSInteger);

	handler = signal(SIGPIPE, SIG_IGN);
	if (handler != SIG_DFL)
	  {
	    signal(SIGPIPE, handler);
	  }
      }
#endif /* HAVE_SIGACTION */
#endif /* SIGPIPE */
#endif /* __MINGW__ */

#if	GS_WITH_GC
      finalize_sel = @selector(finalize);
      finalize_imp = get_imp(self, finalize_sel);
#endif

#if (defined(__FreeBSD__) || defined(__OpenBSD__)) && defined(__i386__)
      // Manipulate the FPU to add the exception mask. (Fixes SIGFPE
      // problems on *BSD)
      // Note this only works on x86
#  if defined(FE_INVALID)
      fedisableexcept(FE_INVALID);
#  else
      {
        volatile short cw;

        __asm__ volatile ("fstcw (%0)" : : "g" (&cw));
        cw |= 1; /* Mask 'invalid' exception */
        __asm__ volatile ("fldcw (%0)" : : "g" (&cw));
      }
#  endif
#endif

#ifdef HAVE_LOCALE_H
      GSSetLocaleC(LC_ALL, "");		// Set up locale from environment.
#endif

      // Create the global lock
      gnustep_global_lock = [NSRecursiveLock new];

      // Behavior debugging
      GSObjCBehaviorDebug(GSPrivateEnvironmentFlag("GNUSTEP_BEHAVIOR_DEBUG",
	GSObjCBehaviorDebug(-1)));

      // Zombie management stuff.
      zombieMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
      zombieClass = [NSZombie class];
      NSZombieEnabled = GSPrivateEnvironmentFlag("NSZombieEnabled", NO);
      NSDeallocateZombies = GSPrivateEnvironmentFlag("NSDeallocateZombies", NO);

      autorelease_class = [NSAutoreleasePool class];
      autorelease_sel = @selector(addObject:);
      autorelease_imp = [autorelease_class methodForSelector: autorelease_sel];
      NSConstantStringClass = [NSString constantStringClass];
      GSPrivateBuildStrings();
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	   selector: @selector(_becomeMultiThreaded:)
	       name: NSWillBecomeMultiThreadedNotification
	     object: nil];
    }
  return;
}

/**
 * Allocates a new instance of the receiver from the default
 * zone, by invoking +allocWithZone: with
 * <code>NSDefaultMallocZone()</code> as the zone argument.<br />
 * Returns the created instance.
 */
+ (id) alloc
{
  return [self allocWithZone: NSDefaultMallocZone()];
}

/**
 * This is the basic method to create a new instance.  It
 * allocates a new instance of the receiver from the specified
 * memory zone.
 * <p>
 *   Memory for an instance of the receiver is allocated; a
 *   pointer to this newly created instance is returned.  All
 *   instance variables are set to 0 except the
 *   <code>isa</code> pointer which is set to point to the
 *   object class.  No initialization of the instance is
 *   performed: it is your responsibility to initialize the
 *   instance by calling an appropriate <code>init</code>
 *   method.  If you are not using the garbage collector, it is
 *   also your responsibility to make sure the returned
 *   instance is destroyed when you finish using it, by calling
 *   the <code>release</code> method to destroy the instance
 *   directly, or by using <code>autorelease</code> and
 *   autorelease pools.
 * </p>
 * <p>
 *  You do not normally need to override this method in
 *  subclasses, unless you are implementing a class which for
 *  some reasons silently allocates instances of another class
 *  (this is typically needed to implement class clusters and
 *  similar design schemes).
 * </p>
 * <p>
 *   If you have turned on debugging of object allocation (by
 *   calling the <code>GSDebugAllocationActive</code>
 *   function), this method will also update the various
 *   debugging counts and monitors of allocated objects, which
 *   you can access using the <code>GSDebugAllocation...</code>
 *   functions.
 * </p>
 */
+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject (self, 0, z);
}

/**
 * Returns the receiver.
 */
+ (id) copyWithZone: (NSZone*)z
{
  return self;
}

/**
 * <p>
 *   This method is a short-hand for alloc followed by init, that is,
 * </p>
 * <p><code>
 *    NSObject *object = [NSObject new];
 * </code></p>
 * is exactly the same as
 * <p><code>
 *    NSObject *object = [[NSObject alloc] init];
 * </code></p>
 * <p>
 *   This is a general convention: all <code>new...</code>
 *   methods are supposed to return a newly allocated and
 *   initialized instance, as would be generated by an
 *   <code>alloc</code> method followed by a corresponding
 *   <code>init...</code> method.  Please note that if you are
 *   not using a garbage collector, this means that instances
 *   generated by the <code>new...</code> methods are not
 *   autoreleased, that is, you are responsible for releasing
 *   (autoreleasing) the instances yourself.  So when you use
 *   <code>new</code> you typically do something like:
 * </p>
 * <p>
 *   <code>
 *      NSMutableArray *array = AUTORELEASE ([NSMutableArray new]);
 *   </code>
 * </p>
 * <p>
 *   You do not normally need to override <code>new</code> in
 *   subclasses, because if you override <code>init</code> (and
 *   optionally <code>allocWithZone:</code> if you really
 *   need), <code>new</code> will automatically use your
 *   subclass methods.
 * </p>
 * <p>
 *   You might need instead to define new <code>new...</code>
 *   methods specific to your subclass to match any
 *   <code>init...</code> specific to your subclass.  For
 *   example, if your subclass defines an instance method
 * </p>
 * <p>
 *   <code>initWithName:</code>
 * </p>
 * <p>
 *   it might be handy for you to have a class method
 * </p>
 * <p>
 *    <code>newWithName:</code>
 * </p>
 * <p>
 *   which combines <code>alloc</code> and
 *   <code>initWithName:</code>.  You would implement it as follows:
 * </p>
 * <p>
 *   <code>
 *     + (id) newWithName: (NSString *)aName
 *     {
 *       return [[self alloc] initWithName: aName];
 *     }
 *   </code>
 * </p>
 */
+ (id) new
{
  return [[self alloc] init];
}

/**
 * Returns the class of which the receiver is an instance.<br />
 * The default implementation returns the private <code>isa</code>
 * instance variable of NSObject, which is used to store a pointer
 * to the objects class.<br />
 * NB.  When NSZombie is enabled (see NSDebug.h) this pointer is
 * changed upon object deallocation.
 */
- (Class) class
{
  return object_get_class(self);
}

/**
 * Returns the name of the class of the receiving object by using
 * the NSStringFromClass() function.<br />
 * This is a MacOS-X addition for apple scripting, which is also
 * generally useful.
 */
- (NSString*) className
{
  return NSStringFromClass([self class]);
}

/**
 * Creates and returns a copy of the receiver by calling -copyWithZone:
 * passing NSDefaultMallocZone()
 */
- (id) copy
{
  return [(id)self copyWithZone: NSDefaultMallocZone()];
}

/**
 * Deallocates the receiver by calling NSDeallocateObject() with self
 * as the argument.<br />
 * <p>
 *   You should normally call the superclass implementation of this method
 *   when you override it in a subclass, or the memory occupied by your
 *   object will not be released.
 * </p>
 * <p>
 *   <code>NSObject</code>'s implementation of this method
 *   destroys the receiver, by returning the memory allocated
 *   to the receiver to the system.  After this method has been
 *   called on an instance, you must not refer the instance in
 *   any way, because it does not exist any longer.  If you do,
 *   it is a bug and your program might even crash with a
 *   segmentation fault.
 * </p>
 * <p>
 *   If you have turned on the debugging facilities for
 *   instance allocation, <code>NSObject</code>'s
 *   implementation of this method will also update the various
 *   counts and monitors of allocated instances (see the
 *   <code>GSDebugAllocation...</code> functions for more
 *   info).
 * </p>
 * <p>
 *   Normally you are supposed to manage the memory taken by
 *   objects by using the high level interface provided by the
 *   <code>retain</code>, <code>release</code> and
 *   <code>autorelease</code> methods (or better by the
 *   corresponding macros <code>RETAIN</code>,
 *   <code>RELEASE</code> and <code>AUTORELEASE</code>), and by
 *   autorelease pools and such; whenever the
 *   release/autorelease mechanism determines that an object is
 *   no longer needed (which happens when its retain count
 *   reaches 0), it will call the <code>dealloc</code> method
 *   to actually deallocate the object.  This means that normally,
 *   you should not need to call <code>dealloc</code> directly as
 *   the gnustep base library automatically calls it for you when
 *   the retain count of an object reaches 0.
 * </p>
 * <p>
 *   Because the <code>dealloc</code> method will be called
 *   when an instance is being destroyed, if instances of your
 *   subclass use objects or resources (as it happens for most
 *   useful classes), you must override <code>dealloc</code> in
 *   subclasses to release all objects and resources which are
 *   used by the instance, otherwise these objects and
 *   resources would be leaked.  In the subclass
 *   implementation, you should first release all your subclass
 *   specific objects and resources, and then invoke super's
 *   implementation (which will do the same, and so on up in
 *   the class hierarchy to <code>NSObject</code>'s
 *   implementation, which finally destroys the object).  Here
 *   is an example of the implementation of
 *   <code>dealloc</code> for a subclass whose instances have a
 *   single instance variable <code>name</code> which needs to
 *   be released when an instance is deallocated:
 * </p>
 * <p>
 *   <code>
 *   - (void) dealloc
 *   {
 *     RELEASE (name);
 *     [super dealloc];
 *   }
 *   </code>
 *  </p>
 *  <p>
 *    <code>dealloc</code> might contain code to release not
 *    only objects, but also other resources, such as open
 *    files, network connections, raw memory allocated in other
 *    ways, etc.
 *  </p>
 * <p>
 *   If you have allocated the memory using a non-standard mechanism, you
 *   will not call the superclass (NSObject) implementation of the method
 *   as you will need to handle the deallocation specially.<br />
 *   In some circumstances, an object may wish to prevent itself from
 *   being deallocated, it can do this simply be refraining from calling
 *   the superclass implementation.
 * </p>
 */
- (void) dealloc
{
  NSDeallocateObject (self);
}

- (void) finalize
{
  return;
}

/**
 *  This method is an anachronism.  Do not use it.
 */
- (id) free
{
  [NSException raise: NSGenericException
	      format: @"Use `dealloc' instead of `free' for %@.", self];
  return nil;
}

/**
 * Initialises the receiver ... the NSObject implementation simply returns self.
 */
- (id) init
{
  return self;
}

/**
 * Creates and returns a mutable copy of the receiver by calling
 * -mutableCopyWithZone: passing NSDefaultMallocZone().
 */
- (id) mutableCopy
{
  return [(id)self mutableCopyWithZone: NSDefaultMallocZone()];
}

/**
 * Returns the super class from which the receiver was derived.
 */
+ (Class) superclass
{
  return class_getSuperclass(self);
}

/**
 * Returns the super class from which the receivers class was derived.
 */
- (Class) superclass
{
  return class_getSuperclass(object_getClass(self));
}

/**
 * Returns a flag to say if instances of the receiver class will
 * respond to the specified selector.  This ignores situations
 * where a subclass implements -forwardInvocation: to respond to
 * selectors not normally handled ... in these cases the subclass
 * may override this method to handle it.
 * <br />If given a null selector, raises NSInvalidArgumentException when
 * in MacOS-X compatibility more, or returns NO otherwise.
 */
+ (BOOL) instancesRespondToSelector: (SEL)aSelector
{
  if (aSelector == 0)
    {
      if (GSPrivateDefaultsFlag(GSMacOSXCompatible))
	{
	  [NSException raise: NSInvalidArgumentException
		    format: @"%@ null selector given",
	    NSStringFromSelector(_cmd)];
	}
      return NO;
    }
  return __objc_responds_to((id)&self, aSelector);
}

/**
 * Returns a flag to say whether the receiving class conforms to aProtocol
 */
+ (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  return class_conformsToProtocol(self, aProtocol);
}

/**
 * Returns a flag to say whether the class of the receiver conforms
 * to aProtocol.
 */
- (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  return class_conformsToProtocol([self class], aProtocol);
}

/**
 * Returns a pointer to the C function implementing the method used
 * to respond to messages with aSelector by instances of the receiving
 * class.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
+ (IMP) instanceMethodForSelector: (SEL)aSelector
{
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];
  /*
   *	Since 'self' is an class, get_imp() will get the instance method.
   */
  return get_imp((Class)self, aSelector);
}

/**
 * Returns a pointer to the C function implementing the method used
 * to respond to messages with aSelector.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (IMP) methodForSelector: (SEL)aSelector
{
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];
  /*
   *	If 'self' is an instance, object_getClass() will get the class,
   *	and get_imp() will get the instance method.
   *	If 'self' is a class, object_getClass() will get the meta-class,
   *	and get_imp() will get the class method.
   */
  return get_imp(object_getClass(self), aSelector);
}

/**
 * Returns a pointer to the C function implementing the method used
 * to respond to messages with aSelector which are sent to instances
 * of the receiving class.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
  struct objc_method	*mth;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  mth = GSGetMethod(self, aSelector, YES, YES);
  if (mth == 0)
    return nil;
  return [NSMethodSignature signatureWithObjCTypes:mth->method_types];
}

/**
 * Returns the method signature describing how the receiver would handle
 * a message with aSelector.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  const char		*types;
  struct objc_method	*mth;
  Class			c;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  c = (GSObjCIsInstance(self) ? object_getClass(self) : (Class)self);
  mth = GSGetMethod(c, aSelector, GSObjCIsInstance(self), YES);

  if (mth == 0)
    {
      return nil; // Method not implemented
    }
  types = mth->method_types;

  /*
   * If there are protocols that this class conforms to,
   * the method may be listed in a protocol with more
   * detailed type information than in the class itself
   * and we must therefore use the information from the
   * protocol.
   * This is because protocols also carry information
   * used by the Distributed Objects system, which the
   * runtime does not maintain in classes.
   */
  if (c->protocols != 0)
    {
      struct objc_protocol_list	*protocols = c->protocols;
      BOOL			found = NO;

      while (found == NO && protocols != 0)
	{
	  NSUInteger	i = 0;

	  while (found == NO && i < protocols->count)
	    {
	      Protocol				*p;
	      struct objc_method_description	*pmth;

	      p = protocols->list[i++];
	      if (c == (Class)self)
		{
		  pmth = [p descriptionForClassMethod: aSelector];
		}
	      else
		{
		  pmth = [p descriptionForInstanceMethod: aSelector];
		}
	      if (pmth != 0)
		{
		  types = pmth->types;
		  found = YES;
		}
	    }
	  protocols = protocols->next;
	}
    }

  if (types == 0)
    {
      return nil;
    }
  return [NSMethodSignature signatureWithObjCTypes: types];
}

/**
 * Returns a string describing the receiver.  The default implementation
 * gives the class and memory location of the receiver.
 */
- (NSString*) description
{
  return [NSString stringWithFormat: @"<%s: %p>",
    class_getName([self class]), self];
}

/**
 * Returns a string describing the receiving class.  The default implementation
 * gives the name of the class by calling NSStringFromClass().
 */
+ (NSString*) description
{
  return NSStringFromClass(self);
}

/**
 * Sets up the ObjC runtime so that the receiver is used wherever code
 * calls for aClassObject to be used.
 */
+ (void) poseAsClass: (Class)aClassObject
{
  class_pose_as(self, aClassObject);
  /*
   *	We may have replaced a class in the cache, or may have replaced one
   *	which had cached methods, so we must rebuild the cache.
   */
}

/**
 * Raises an invalid argument exception providing information about
 * the receivers inability to handle aSelector.
 */
- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  [NSException raise: NSInvalidArgumentException
	      format: @"%s(%s) does not recognize %s",
	       GSClassNameFromObject(self),
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSelector ? sel_getName(aSelector) : "(null)"];
}

- (retval_t) forward: (SEL)aSel : (arglist_t)argFrame
{
  NSInvocation *inv;

  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  inv = AUTORELEASE([[NSInvocation alloc] initWithArgframe: argFrame
						  selector: aSel]);
  [self forwardInvocation: inv];
  return [inv returnFrame: argFrame];
}

/**
 * This method is called automatically to handle a message sent to
 * the receiver for which the receivers class has no method.<br />
 * The default implementation calls -doesNotRecognizeSelector:
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  id target = [self forwardingTargetForSelector: [anInvocation selector]];

  if (nil != target)
    {
      [anInvocation invokeWithTarget: target];
      return;
    }
  [self doesNotRecognizeSelector: [anInvocation selector]];
  return;
}

/**
 * Called after the receiver has been created by decoding some sort
 * of archive.  Returns self.  Subclasses may override this to perform
 * some special initialisation upon being decoded.
 */
- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder
{
  return self;
}

// FIXME - should this be added (as in OS X) now that we have NSKeyedArchiver?
// - (Class) classForKeyedArchiver
// {
//     return [self classForArchiver];
// }

/**
 * Override to substitute class when an instance is being archived by an
 * [NSArchiver].  Default implementation returns -classForCoder.
 */
- (Class) classForArchiver
{
  return [self classForCoder];
}

/**
 * Override to substitute class when an instance is being serialized by an
 * [NSCoder].  Default implementation returns <code>[self class]</code> (no
 * substitution).
 */
- (Class) classForCoder
{
  return [self class];
}

// FIXME - should this be added (as in OS X) now that we have NSKeyedArchiver?
// - (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver *)keyedArchiver
// {
//     return [self replacementObjectForCoder: (NSArchiver *)keyedArchiver];
// }

/**
 * Override to substitute another object for this instance when being archived
 * by given [NSArchiver].  Default implementation returns
 * -replacementObjectForCoder:.
 */
- (id) replacementObjectForArchiver: (NSArchiver*)anArchiver
{
  return [self replacementObjectForCoder: (NSCoder*)anArchiver];
}

/**
 * Override to substitute another object for this instance when being
 * serialized by given [NSCoder].  Default implementation returns
 * <code>self</code>.
 */
- (id) replacementObjectForCoder: (NSCoder*)anEncoder
{
  return self;
}


/* NSObject protocol */

/**
 * Adds the receiver to the current autorelease pool, so that it will be
 * sent a -release message when the pool is destroyed.<br />
 * Returns the receiver.<br />
 * In GNUstep, the [NSObject+enableDoubleReleaseCheck:] method may be used
 * to turn on checking for retain/release errors in this method.
 */
- (id) autorelease
{
#if	GS_WITH_GC == 0
  if (double_release_check_enabled)
    {
      NSUInteger release_count;
      NSUInteger retain_count = [self retainCount];
      release_count = [autorelease_class autoreleaseCountForObject:self];
      if (release_count > retain_count)
        [NSException
	  raise: NSGenericException
	  format: @"Autorelease would release object too many times.\n"
	  @"%d release(s) versus %d retain(s)", release_count, retain_count];
    }

  (*autorelease_imp)(autorelease_class, autorelease_sel, self);
#endif
  return self;
}

/**
 * Dummy method returning the receiver.
 */
+ (id) autorelease
{
  return self;
}

/**
 * Returns the receiver.
 */
+ (Class) class
{
  return self;
}

/**
 * Returns the hash of the receiver.  Subclasses should ensure that their
 * implementations of this method obey the rule that if the -isEqual: method
 * returns YES for two instances of the class, the -hash method returns the
 * same value for both instances.<br />
 * The default implementation returns a value based on the address
 * of the instance.
 */
- (NSUInteger) hash
{
  /*
   * Ideally we would shift left to lose any zero bits produced by the
   * alignment of the object in memory ... but that depends on the
   * processor architecture and the memory allocatiion implementation.
   * In the absence of detailed information, pick a reasonable value
   * assuming the object will be aligned to an eight byte boundary.
   */
  return (NSUInteger)(uintptr_t)self >> 3;
}

/**
 * Tests anObject and the receiver for equality.  The default implementation
 * considers two objects to be equal only if they are the same object
 * (ie occupy the same memory location).<br />
 * If a subclass overrides this method, it should also override the -hash
 * method so that if two objects are equal they both have the same hash.
 */
- (BOOL) isEqual: (id)anObject
{
  return (self == anObject);
}

/**
 * Returns YES if aClass is the NSObject class
 */
+ (BOOL) isKindOfClass: (Class)aClass
{
  if (aClass == [NSObject class])
    return YES;
  return NO;
}

/**
 * Returns YES if the class of the receiver is either the same as aClass
 * or is derived from (a subclass of) aClass.
 */
- (BOOL) isKindOfClass: (Class)aClass
{
  Class class = object_getClass(self);

  return GSObjCIsKindOf(class, aClass);
}

/**
 * Returns YES if aClass is the same as the receiving class.
 */
+ (BOOL) isMemberOfClass: (Class)aClass
{
  return (self == aClass) ? YES : NO;
}

/**
 * Returns YES if the class of the receiver is aClass
 */
- (BOOL) isMemberOfClass: (Class)aClass
{
  return (object_getClass(self) == aClass) ? YES : NO;
}

/**
 * Returns a flag to differentiate between 'true' objects, and objects
 * which are proxies for other objects (ie they forward messages to the
 * other objects).<br />
 * The default implementation returns NO.
 */
- (BOOL) isProxy
{
  return NO;
}

/**
 * Returns YES if the receiver is aClass or a subclass of aClass.
 */
+ (BOOL) isSubclassOfClass: (Class)aClass
{
  return GSObjCIsKindOf(self, aClass);
}

/**
 * Causes the receiver to execute the method implementation corresponding
 * to aSelector and returns the result.<br />
 * The method must be one which takes no arguments and returns an object.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (id) performSelector: (SEL)aSelector
{
  IMP msg;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  msg = get_imp(object_getClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		   format: @"invalid selector passed to %s",
		     sel_getName(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector);
}

/**
 * Causes the receiver to execute the method implementation corresponding
 * to aSelector and returns the result.<br />
 * The method must be one which takes one argument and returns an object.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (id) performSelector: (SEL)aSelector withObject: (id) anObject
{
  IMP msg;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  msg = get_imp(object_getClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		   format: @"invalid selector passed to %s",
		   sel_getName(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, anObject);
}

/**
 * Causes the receiver to execute the method implementation corresponding
 * to aSelector and returns the result.<br />
 * The method must be one which takes two arguments and returns an object.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (id) performSelector: (SEL)aSelector
	    withObject: (id) object1
	    withObject: (id) object2
{
  IMP msg;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  msg = get_imp(object_getClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_getName(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, object1, object2);
}

/**
 * Decrements the retain count for the receiver if greater than zero,
 * otherwise calls the dealloc method instead.<br />
 * The default implementation calls the NSDecrementExtraRefCountWasZero()
 * function to test the extra reference count for the receiver (and
 * decrement it if non-zero) - if the extra reference count is zero then
 * the retain count is one, and the dealloc method is called.<br />
 * In GNUstep, the [NSObject+enableDoubleReleaseCheck:] method may be used
 * to turn on checking for ratain/release errors in this method.
 */
- (oneway void) release
{
#if	GS_WITH_GC == 0
  if (NSDecrementExtraRefCountWasZero(self))
    {
      [self dealloc];
    }
#endif
}

/**
 * The class implementation of the release method is a dummy method
 * having no effect.  It is present so that class objects can be stored
 * in containers (such as NSArray) which will send them retain and
 * release messages.
 */
+ (oneway void) release
{
  return;
}

/**
 * Returns a flag to say if the receiver will
 * respond to the specified selector.  This ignores situations
 * where a subclass implements -forwardInvocation: to respond to
 * selectors not normally handled ... in these cases the subclass
 * may override this method to handle it.
 * <br />If given a null selector, raises NSInvalidArgumentException when
 * in MacOS-X compatibility more, or returns NO otherwise.
 */
- (BOOL) respondsToSelector: (SEL)aSelector
{
  if (aSelector == 0)
    {
      if (GSPrivateDefaultsFlag(GSMacOSXCompatible))
	{
	  [NSException raise: NSInvalidArgumentException
		    format: @"%@ null selector given",
	    NSStringFromSelector(_cmd)];
	}
      return NO;
    }

  return __objc_responds_to(self, aSelector);
}

/**
 * Increments the reference count and returns the receiver.<br />
 * The default implementation does this by calling NSIncrementExtraRefCount()
 */
- (id) retain
{
#if	GS_WITH_GC == 0
  NSIncrementExtraRefCount(self);
#endif
  return self;
}

/**
 * The class implementation of the retain method is a dummy method
 * having no effect.  It is present so that class objects can be stored
 * in containers (such as NSArray) which will send them retain and
 * release messages.
 */
+ (id) retain
{
  return self;
}

/**
 * Returns the reference count for the receiver.  Each instance has an
 * implicit reference count of 1, and has an 'extra reference count'
 * returned by the NSExtraRefCount() function, so the value returned by
 * this method is always greater than zero.<br />
 * By convention, objects which should (or can) never be deallocated
 * return the maximum unsigned integer value.
 */
- (NSUInteger) retainCount
{
#if	GS_WITH_GC
  return UINT_MAX;
#else
  return NSExtraRefCount(self) + 1;
#endif
}

/**
 * The class implementation of the retainCount method always returns
 * the maximum unsigned integer value, as classes can not be deallocated
 * the retain count mechanism is a dummy system for them.
 */
+ (NSUInteger) retainCount
{
  return UINT_MAX;
}

/**
 * Returns the receiver.
 */
- (id) self
{
  return self;
}

/**
 * Returns the memory allocation zone in which the receiver is located.
 */
- (NSZone*) zone
{
#if	GS_WITH_GC
  /* MacOS-X 10.5 seems to return the default malloc zone if GC is enabled.
   */
  return NSDefaultMallocZone();
#else
  return (((obj)self)[-1]).zone;
#endif
}

/**
 * Called to encode the instance variables of the receiver to aCoder.<br />
 * Subclasses should call the superclass method at the start of their
 * own implementation.
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  return;
}

/**
 * Called to intialise instance variables of the receiver from aDecoder.<br />
 * Subclasses should call the superclass method at the start of their
 * own implementation.
 */
- (id) initWithCoder: (NSCoder*)aDecoder
{
  return self;
}

+ (BOOL) resolveClassMethod: (SEL)name
{
  return NO;
}

+ (BOOL) resolveInstanceMethod: (SEL)name
{
  return NO;
}

/**
 * Sets the version number of the receiving class.  Should be nonnegative.
 */
+ (id) setVersion: (NSInteger)aVersion
{
  if (aVersion < 0)
    [NSException raise: NSInvalidArgumentException
	        format: @"%s +setVersion: may not set a negative version",
			GSClassNameFromObject(self)];
  class_set_version(self, aVersion);
  return self;
}

/**
 *  Returns the version number of the receiving class.  This will default to
 *  a number assigned by the Objective C compiler if [NSObject -setVersion] has
 *  not been called.
 */
+ (NSInteger) version
{
  return class_get_version(self);
}

- (id) autoContentAccessingProxy
{
  return AUTORELEASE([[GSContentAccessingProxy alloc] initWithObject: self]);
}

- (id) forwardingTargetForSelector:(SEL)aSelector
{
  return nil;
}
@end


/**
 *  Methods for compatibility with the NEXTSTEP (pre-OpenStep) 'Object' class.
 */
@implementation NSObject (NEXTSTEP)

/* NEXTSTEP Object class compatibility */

/**
 * Logs a message.  <em>Deprecated.</em>  Use NSLog() in new code.
 */
- (id) error: (const char *)aString, ...
{
#if !defined(NeXT_RUNTIME) && !defined(__GNUSTEP_RUNTIME__)
#define FMT "error: %s (%s)\n%s\n"
  char fmt[(strlen((char*)FMT)+strlen((char*)GSClassNameFromObject(self))
            +((aString!=NULL)?strlen((char*)aString):0)+8)];
  va_list ap;

  sprintf(fmt, FMT, GSClassNameFromObject(self),
                    GSObjCIsInstance(self)?"instance":"class",
                    (aString!=NULL)?aString:"");
  va_start(ap, aString);
  /* xxx What should `code' argument be?  Current 0. */
  objc_verror (self, 0, fmt, ap);
  va_end(ap);
#undef FMT
#endif
  return nil;
}

/*
- (const char *) name
{
  return GSClassNameFromObject(self);
}
*/

- (BOOL) isKindOf: (Class)aClassObject
{
  return [self isKindOfClass: aClassObject];
}

- (BOOL) isMemberOf: (Class)aClassObject
{
  return [self isMemberOfClass: aClassObject];
}

+ (BOOL) instancesRespondTo: (SEL)aSel
{
  return [self instancesRespondToSelector: aSel];
}

- (BOOL) respondsTo: (SEL)aSel
{
  return [self respondsToSelector: aSel];
}

+ (BOOL) conformsTo: (Protocol*)aProtocol
{
  return [self conformsToProtocol: aProtocol];
}

- (BOOL) conformsTo: (Protocol*)aProtocol
{
  return [self conformsToProtocol: aProtocol];
}

- (retval_t) performv: (SEL)aSel :(arglist_t)argFrame
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  return objc_msg_sendv(self, aSel, argFrame);
}

+ (IMP) instanceMethodFor: (SEL)aSel
{
  return [self instanceMethodForSelector:aSel];
}

+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
  struct objc_method* mth;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  mth = GSGetMethod(self, aSelector, YES, YES);
  if (mth == 0)
    return nil;
  return [NSMethodSignature signatureWithObjCTypes:mth->method_types];
}

- (IMP) methodFor: (SEL)aSel
{
  return [self methodForSelector: aSel];
}

+ (id) poseAs: (Class)aClassObject
{
  [self poseAsClass: aClassObject];
  return self;
}

- (id) doesNotRecognize: (SEL)aSel
{
  [NSException raise: NSGenericException
	       format: @"%s(%s) does not recognize %s",
	       GSClassNameFromObject(self),
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSel ? sel_getName(aSel) : "(null)"];
  return nil;
}

- (id) perform: (SEL)sel with: (id)anObject
{
  return [self performSelector:sel withObject:anObject];
}

- (id) perform: (SEL)sel with: (id)anObject with: (id)anotherObject
{
  return [self performSelector:sel withObject:anObject
	       withObject:anotherObject];
}

@end



/**
 * Some non-standard extensions mainly needed for backwards compatibility
 * and internal utility reasons.
 */
@implementation NSObject (GNUstep)

/**
 * Enables runtime checking of retain/release/autorelease operations.<br />
 * <p>Whenever either -autorelease or -release is called, the contents of any
 * autorelease pools will be checked to see if there are more outstanding
 * release operations than the objects retain count.  In which case an
 * exception is raised to say that the object is released too many times.
 * </p>
 * <p><strong>Beware</strong>, since this feature entails examining all active
 * autorelease pools every time an object is released or autoreleased, it
 * can cause a massive performance degradation ... it should only be enabled
 * for debugging.
 * </p>
 * <p>
 * When you are having memory allocation problems, it may make more sense
 * to look at the memory allocation debugging functions documented in
 * NSDebug.h, or use the NSZombie features.
 * </p>
 */
+ (void) enableDoubleReleaseCheck: (BOOL)enable
{
  double_release_check_enabled = enable;
}

/**
 * The default (NSObject) implementation of this method simply calls
 * the -description method and discards the locale
 * information.
 */
- (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
{
  return [self description];
}

+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
{
  return [self description];
}

/**
 * The default (NSObject) implementation of this method simply calls
 * the -descriptionWithLocale: method and discards the
 * level information.
 */
- (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
			     indent: (NSUInteger)level
{
  return [self descriptionWithLocale: aLocale];
}

+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
			     indent: (NSUInteger)level
{
  return [self descriptionWithLocale: aLocale];
}

- (BOOL) _dealloc
{
  return YES;
}

- (BOOL) isMetaClass
{
  return NO;
}

- (BOOL) isClass
{
  return class_isMetaClass(object_getClass(self));
}

- (BOOL) isMemberOfClassNamed: (const char*)aClassName
{
  return ((aClassName!=NULL)
          &&!strcmp(class_getName(object_getClass(self)), aClassName));
}

+ (struct objc_method_description *) descriptionForInstanceMethod: (SEL)aSel
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  return ((struct objc_method_description *)
           GSGetMethod(self, aSel, YES, YES));
}

- (struct objc_method_description *) descriptionForMethod: (SEL)aSel
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  return ((struct objc_method_description *)
	  GSGetMethod((GSObjCIsInstance(self)
		       ? object_getClass(self) : (Class)self),
		      aSel,
		      GSObjCIsInstance(self),
		      YES));
}

+ (NSInteger) streamVersion: (TypedStream*)aStream
{
#if !defined(NeXT_RUNTIME) && !defined(__GNUSTEP_RUNTIME__)
  if (aStream->mode == OBJC_READONLY)
    return objc_get_stream_class_version (aStream, self);
  else
#endif
    return class_get_version (self);
}

//NOTE: original comments included the following excerpt, however it is
//      probably not relevant now since the implementations are stubbed out.
//  Subclasses should extend these, by calling
//  [super read/write: aStream] before doing their own archiving.  These
//  methods are private, in the sense that they should only be called from
//  subclasses.

/**
 * Originally used to read the instance variables declared in this
 * particular part of the object from a stream.  Currently stubbed out.
 */
- (id) read: (TypedStream*)aStream
{
  // [super read: aStream];
  return self;
}

/**
 * Originally used to write the instance variables declared in this
 * particular part of the object to a stream.  Currently stubbed out.
 */
- (id) write: (TypedStream*)aStream
{
  // [super write: aStream];
  return self;
}

/**
 * Originally used before [NSCoder] and related classes existed.  Currently
 * stubbed out.
 */
- (id) awake
{
  // [super awake];
  return self;
}

@end



@implementation	NSZombie
- (Class) class
{
  return (Class)isa;
}
- (Class) originalClass
{
  return NSMapGet(zombieMap, (void*)self);
}
- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  GSLogZombie(self, aSel);
  return 0;
}
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  NSUInteger	size = [[anInvocation methodSignature] methodReturnLength];
  unsigned char	v[size];

  memset(v, '\0', size);
  GSLogZombie(self, [anInvocation selector]);
  [anInvocation setReturnValue: (void*)v];
  return;
}
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  Class	c;

  [allocationLock lock];
  c = NSMapGet(zombieMap, (void*)self);
  [allocationLock unlock];
  return [c instanceMethodSignatureForSelector: aSelector];
}
@end

@implementation GSContentAccessingProxy 
- (void) dealloc
{
  [object endContentAccess];
  [super dealloc];
}

- (void) finalize
{
  [object endContentAccess];
}

- (id) forwardingTargetForSelector: (SEL)aSelector
{
  return object;
}
/* Support for legacy runtimes... */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  [anInvocation invokeWithTarget: object];
}

- (id) initWithObject: (id)anObject
{
  ASSIGN(object, anObject);
  [object beginContentAccess];
  return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  return [object methodSignatureForSelector: aSelector];
}
@end
