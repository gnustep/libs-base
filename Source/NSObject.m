/** Implementation of NSObject for GNUStep
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSObject class reference</title>
   $Date$ $Revision$
   */ 

#include <config.h>
#include <base/preface.h>
#include <stdarg.h>
#include <Foundation/NSObject.h>
#include <objc/Protocol.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSDistantObject.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSMapTable.h>
#include <limits.h>

#include "GSPrivate.h"


#ifndef NeXT_RUNTIME
extern BOOL __objc_responds_to(id, SEL);
#endif

#if GS_WITH_GC

#include	<gc.h>
#include	<gc_typed.h>

#else

@class	_FastMallocBuffer;
static Class	fastMallocClass;
static unsigned	fastMallocOffset;

#endif

static Class	NSConstantStringClass;

@class	NSDataMalloc;
@class	NSMutableDataMalloc;

/*
 * allocationLock is needed when running multi-threaded for retain/release
 * to work reliably.
 * We also use it for protecting the map table of zombie information.
 */
static objc_mutex_t allocationLock = NULL;


BOOL	NSZombieEnabled = NO;
BOOL	NSDeallocateZombies = NO;

@class	NSZombie;
static Class		zombieClass;
static NSMapTable	zombieMap;

static void GSMakeZombie(NSObject *o)
{
  Class	c = ((id)o)->class_pointer;

  ((id)o)->class_pointer = zombieClass;
  if (NSDeallocateZombies == NO)
    {
      if (allocationLock != 0)
	{
	  objc_mutex_lock(allocationLock);
	}
      NSMapInsert(zombieMap, (void*)o, (void*)c);
      if (allocationLock != 0)
	{
	  objc_mutex_unlock(allocationLock);
	}
    }
}

static void GSLogZombie(id o, SEL sel)
{
  Class	c = 0;

  if (NSDeallocateZombies == NO)
    {
      if (allocationLock != 0)
	{
	  objc_mutex_lock(allocationLock);
	}
      c = NSMapGet(zombieMap, (void*)o);
      if (allocationLock != 0)
	{
	  objc_mutex_unlock(allocationLock);
	}
    }
  if (c == 0)
    {
      NSLog(@"Deallocated object (0x%x) sent %@",
	o, NSStringFromSelector(sel));
    }
  else
    {
      NSLog(@"Deallocated %@ (0x%x) sent %@",
	NSStringFromClass(c), o, NSStringFromSelector(sel));
    }
}


/*
 *	Reference count and memory management
 *
 *	If REFCNT_LOCAL is defined, reference counts for object are stored
 *	with the object, otherwise they are stored in a global map table
 *	that has to be protected by mutexes in a multithreraded environment.
 *	You therefore want REFCNT_LOCAL defined for best performance.
 *
 *	If CACHE_ZONE is defined, the zone in which an object has been
 *	allocated is stored with the object - this makes lookup of the
 *	correct zone to free memory very fast.
 */


#if	GS_WITH_GC == 0 && !defined(NeXT_RUNTIME)
#define	REFCNT_LOCAL	1
#define	CACHE_ZONE	1
#endif

#ifdef ALIGN
#undef ALIGN
#endif
#define	ALIGN __alignof__(double)

#if	defined(REFCNT_LOCAL) || defined(CACHE_ZONE)

/*
 *	Define a structure to hold information that is held locally
 *	(before the start) in each object.
 */ 
typedef struct obj_layout_unpadded {
#if	defined(REFCNT_LOCAL)
    unsigned	retained;
#endif
#if	defined(CACHE_ZONE)
    NSZone	*zone;
#endif
} unp;
#define	UNP sizeof(unp)

/*
 *	Now do the REAL version - using the other version to determine
 *	what padding (if any) is required to get the alignment of the
 *	structure correct.
 */
struct obj_layout {
#if	defined(REFCNT_LOCAL)
    unsigned	retained;
#endif
#if	defined(CACHE_ZONE)
    NSZone	*zone;
#endif
    char	padding[ALIGN - ((UNP % ALIGN) ? (UNP % ALIGN) : ALIGN)];
};
typedef	struct obj_layout *obj;

#endif	/* defined(REFCNT_LOCAL) || defined(CACHE_ZONE) */

#if !defined(REFCNT_LOCAL)

/*
 * Set up map table for non-local reference counts.
 */

#define GSI_MAP_EQUAL(M, X, Y)	(X.obj == Y.obj)
#define GSI_MAP_HASH(M, X)	(X.uint >> 2)
#define GSI_MAP_RETAIN_KEY(M, X)
#define GSI_MAP_RELEASE_KEY(M, X)
#define GSI_MAP_RETAIN_VAL(M, X)
#define GSI_MAP_RELEASE_VAL(M, X)
#define GSI_MAP_KTYPES  GSUNION_OBJ|GSUNION_INT
#define GSI_MAP_VTYPES  GSUNION_INT
#define	GSI_MAP_NOCLEAN	1

#include <base/GSIMap.h>

static GSIMapTable_t	retain_counts = {0};

#endif	/* !defined(REFCNT_LOCAL) */


/**
 * Examines the extra reference count for the object and, if non-zero
 * decrements it, otherwise leaves it unchanged.<br />
 * Returns a flag to say whether the count was zero
 * (and hence whether the extra refrence count was decremented).<br />
 * This function is used by the [NSObject-release] method.
 */
inline BOOL
NSDecrementExtraRefCountWasZero(id anObject)
{
#if	GS_WITH_GC
  return NO;
#else	/* GS_WITH_GC */
#if	defined(REFCNT_LOCAL)
  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      if (((obj)anObject)[-1].retained == 0)
	{
	  objc_mutex_unlock(allocationLock);
	  return YES;
	}
      else
	{
	  ((obj)anObject)[-1].retained--;
	  objc_mutex_unlock(allocationLock);
	  return NO;
	}
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
#else
  GSIMapNode	node;

  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  objc_mutex_unlock(allocationLock);
	  return YES;
	}
      if (node->value.uint == 0)
	{
	  GSIMapRemoveKey((GSIMapTable)&retain_counts, (GSIMapKey)anObject);
	  objc_mutex_unlock(allocationLock);
	  return YES;
	}
      else
	{
	  (node->value.uint)--;
	}
      objc_mutex_unlock(allocationLock);
    }
  else
    {
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  return YES;
	}
      if ((node->value.uint) == 0)
	{
	  GSIMapRemoveKey((GSIMapTable)&retain_counts, (GSIMapKey)anObject);
	  return YES;
	}
      else
	{
	  --(node->value.uint);
	}
    }
  return NO;
#endif
#endif
}

/**
 * Return the extra reference count of anObject (a value in the range
 * from 0 to the maximum unsigned integer value minus one).<br />
 * The retain count for an object is this value plus one.
 */
inline unsigned
NSExtraRefCount(id anObject)
{
#if	GS_WITH_GC
  return UINT_MAX - 1;
#else	/* GS_WITH_GC */
#if	defined(REFCNT_LOCAL)
  return ((obj)anObject)[-1].retained;
#else
  GSIMapNode	node;
  unsigned	ret;

  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  ret = 0;
	}
      else
	{
	  ret = node->value.uint;
	}
      objc_mutex_unlock(allocationLock);
    }
  else
    {
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  ret = 0;
	}
      else
	{
	  ret = node->value.uint;
	}
    }
  return ret;
#endif
#endif
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
#if	defined(REFCNT_LOCAL)
  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      if (((obj)anObject)[-1].retained == UINT_MAX - 1)
	{
	  objc_mutex_unlock (allocationLock);
	  [NSException raise: NSInternalInconsistencyException
	    format: @"NSIncrementExtraRefCount() asked to increment too far"];
	}
      ((obj)anObject)[-1].retained++;
      objc_mutex_unlock (allocationLock);
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
  return;
#else
  GSIMapNode	node;

  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node != 0)
	{
	  if ((node->value.uint) == UINT_MAX - 1)
	    {
	      objc_mutex_unlock(allocationLock);
	      [NSException raise: NSInternalInconsistencyException
		format:
		@"NSIncrementExtraRefCount() asked to increment too far"];
	    }
	  (node->value.uint)++;
	}
      else
	{
	  GSIMapAddPair(&retain_counts, (GSIMapKey)anObject, (GSIMapVal)1);
	}
      objc_mutex_unlock(allocationLock);
    }
  else
    {
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node != 0)
	{
	  if ((node->value.uint) == UINT_MAX - 1)
	    {
	      [NSException raise: NSInternalInconsistencyException
		format:
		@"NSIncrementExtraRefCount() asked to increment too far"];
	    }
	  (node->value.uint)++;
	}
      else
	{
	  GSIMapAddPair(&retain_counts, (GSIMapKey)anObject, (GSIMapVal)1);
	}
    }
  return;
#endif
#endif
}


/*
 *	Now do conditional compilation of memory allocation functions
 *	depending on what information (if any) we are storing before
 *	the start of each object.
 */
#if	GS_WITH_GC

inline NSZone *
GSObjCZone(NSObject *object)
{
  return 0;
}

static void
GSFinalize(void* object, void* data)
{
  [(id)object gcFinalize];
#ifndef	NDEBUG
  GSDebugAllocationRemove(((id)object)->class_pointer, (id)object);
#endif
  ((id)object)->class_pointer = (void*)0xdeadface;
}

inline NSObject *
NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone)
{
  id	new;
  int	size;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
  size = aClass->instance_size + extraBytes;
  if (zone == GSAtomicMallocZone())
    {
      new = NSZoneMalloc(zone, size);
    }
  else
    {
      GC_descr	gc_type = (GC_descr)aClass->gc_object_type;

      if (gc_type == 0)
	{
	  new = NSZoneMalloc(zone, size);
	  NSLog(@"No garbage collection information for '%s'",
	    GSNameFromClass(aClass));
	}
      else if ([aClass requiresTypedMemory])
	{
	  new = GC_CALLOC_EXPLICTLY_TYPED(1, size, gc_type);
        }
      else
	{
	  new = NSZoneMalloc(zone, size);
	}
    }

  if (new != nil)
    {
      memset(new, 0, size);
      new->class_pointer = aClass;
      if (__objc_responds_to(new, @selector(gcFinalize)))
	{
#ifndef	NDEBUG
	  /*
	   *	We only do allocation counting for objects that can be
	   *	finalised - for other objects we have no way of decrementing
	   *	the count when the object is collected.
	   */
	  GSDebugAllocationAdd(aClass, new);
#endif
	  GC_REGISTER_FINALIZER (new, GSFinalize, NULL, NULL, NULL);
	}
    }
  return new;
}

inline void
NSDeallocateObject(NSObject *anObject)
{
}

#else	/* GS_WITH_GC */

#if	defined(REFCNT_LOCAL) || defined(CACHE_ZONE)

#if defined(CACHE_ZONE)

inline NSZone *
GSObjCZone(NSObject *object)
{
  if (GSObjCClass(object) == NSConstantStringClass)
    return NSDefaultMallocZone();
  return ((obj)object)[-1].zone;
}

#else	/* defined(CACHE_ZONE)	*/

inline NSZone *
GSObjCZone(NSObject *object)
{
  if (GSObjCClass(object) == NSConstantStringClass)
    return NSDefaultMallocZone();
  return NSZoneFromPointer(&((obj)object)[-1]);
}

#endif	/* defined(CACHE_ZONE)	*/

inline NSObject *
NSAllocateObject (Class aClass, unsigned extraBytes, NSZone *zone)
{
#ifndef	NDEBUG
  extern void GSDebugAllocationAdd(Class c, id o);
#endif
  id	new;
  int	size;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
  size = aClass->instance_size + extraBytes + sizeof(struct obj_layout);
  if (zone == 0)
    {
      zone = NSDefaultMallocZone();
    }
  new = NSZoneMalloc(zone, size);
  if (new != nil)
    {
      memset (new, 0, size);
#if	defined(CACHE_ZONE)
      ((obj)new)->zone = zone;
#endif
      new = (id)&((obj)new)[1];
      new->class_pointer = aClass;
#ifndef	NDEBUG
      GSDebugAllocationAdd(aClass, new);
#endif
    }
  return new;
}

inline void
NSDeallocateObject(NSObject *anObject)
{
#ifndef	NDEBUG
  extern void GSDebugAllocationRemove(Class c, id o);
#endif
  if ((anObject!=nil) && CLS_ISCLASS(((id)anObject)->class_pointer))
    {
      obj	o = &((obj)anObject)[-1];
      NSZone	*z = GSObjCZone(anObject);

#ifndef	NDEBUG
      GSDebugAllocationRemove(((id)anObject)->class_pointer, (id)anObject);
#endif
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

#else

inline NSZone *
GSObjCZone(NSObject *object)
{
  if (GSObjCClass(object) == NSConstantStringClass)
    return NSDefaultMallocZone();
  return NSZoneFromPointer(object);
}

inline NSObject *
NSAllocateObject (Class aClass, unsigned extraBytes, NSZone *zone)
{
  id	new;
  int	size;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
  size = aClass->instance_size + extraBytes;
  new = NSZoneMalloc (zone, size);
  if (new != nil)
    {
      memset (new, 0, size);
      new->class_pointer = aClass;
#ifndef	NDEBUG
      GSDebugAllocationAdd(aClass, new);
#endif
    }
  return new;
}

inline void
NSDeallocateObject(NSObject *anObject)
{
  if ((anObject!=nil) && CLS_ISCLASS(((id)anObject)->class_pointer))
    {
      NSZone	*z = [anObject zone];

#ifndef	NDEBUG
      GSDebugAllocationRemove(((id)anObject)->class_pointer, (id)anObject);
#endif
      if (NSZombieEnabled == YES)
	{
	  GSMakeZombie(anObject);
	  if (NSDeallocateZombies == YES)
	    {
	      NSZoneFree(z, anObject);
	    }
	}
      else
	{
	  ((id)anObject)->class_pointer = (void*) 0xdeadface;
	  NSZoneFree(z, anObject);
	}
    }
  return;
}

#endif	/* defined(REFCNT_LOCAL) || defined(CACHE_ZONE) */

#endif	/* GS_WITH_GC */

BOOL
NSShouldRetainWithZone (NSObject *anObject, NSZone *requestedZone)
{
#if	GS_WITH_GC
  return YES;
#else
  return (!requestedZone || requestedZone == NSDefaultMallocZone()
    || GSObjCZone(anObject) == requestedZone);
#endif
}




/* The Class responsible for handling autorelease's.  This does not
   need mutex protection, since it is simply a pointer that gets read
   and set. */
static id autorelease_class = nil;
static SEL autorelease_sel;
static IMP autorelease_imp;

/* When this is `YES', every call to release/autorelease, checks to
   make sure isn't being set up to release itself too many times.
   This does not need mutex protection. */
static BOOL double_release_check_enabled = NO;



/**
 * <p>
 *   <code>NSObject</code> is the root class (a root class is
 *   a class with no superclass) of the gnustep base library
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
 *   the basic common functionality shared by all gnustep
 *   classes and objects.
 * </p>
 * <p>
 *   The essential methods which must be implemented by all
 *   classes for their instances to be usable within gnustep
 *   are declared in a separate protocol, which is the
 *   <code>NSObject</code> protocol.  Both
 *   <code>NSObject</code> and <code>NSProxy</code> conform to
 *   this protocol, which means all objects in a gnustep
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
 *   interact correctly with the gnustep framework.  Said
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
      allocationLock = objc_mutex_allocate();
    }
}

#if	GS_WITH_GC
+ (BOOL) requiresTypedMemory
{
  return NO;
}
#endif

+ (void) initialize
{
  if (self == [NSObject class])
    {
      extern void		GSBuildStrings(void);	// See externs.m
      extern const char*	GSSetLocaleC(const char*); // See GSLocale.m

#ifdef __MINGW__
      // See libgnustep-base-entry.m
      extern void gnustep_base_socket_init(void);	
      gnustep_base_socket_init();	
#endif
      
#ifdef __FreeBSD__
      // Manipulate the FPU to add the exception mask. (Fixes SIGFPE
      // problems on *BSD)

      {
	volatile short cw;

	__asm__ volatile ("fstcw (%0)" : : "g" (&cw));
	cw |= 1; /* Mask 'invalid' exception */
	__asm__ volatile ("fldcw (%0)" : : "g" (&cw));
      }
#endif

      GSSetLocaleC("");		// Set up locale from environment.

      // Create the global lock
      gnustep_global_lock = [NSRecursiveLock new];

      // Zombie management stuff.
      zombieMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
      zombieClass = [NSZombie class];
      NSZombieEnabled = GSEnvironmentFlag("NSZombieEnabled", NO);
      NSDeallocateZombies = GSEnvironmentFlag("NSDeallocateZombies", NO);

      autorelease_class = [NSAutoreleasePool class];
      autorelease_sel = @selector(addObject:);
      autorelease_imp = [autorelease_class methodForSelector: autorelease_sel];
#if	GS_WITH_GC == 0
      fastMallocClass = [_FastMallocBuffer class];
#if	!defined(REFCNT_LOCAL)
      GSIMapInitWithZoneAndCapacity(&retain_counts,
	NSDefaultMallocZone(), 1024);
#endif
      fastMallocOffset = fastMallocClass->instance_size % ALIGN;
#endif
      NSConstantStringClass = [NSString constantStringClass];
      GSBuildStrings();
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
 * Creates and returns a copy of the reciever by calling -copyWithZone:
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
 *   In some circumstances, an object may wish to prevent itsself from
 *   being deallocated, it can do this simply be refraining from calling
 *   the superclass implementation.
 * </p>
 */
- (void) dealloc
{
  NSDeallocateObject (self);
}

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
 * Creates and rturns a mutable copy of the receiver by calling
 * -mutableCopyWithZone: passing NSDefaultMallocZone().
 */
- (id) mutableCopy
{
  return [(id)self mutableCopyWithZone: NSDefaultMallocZone()];
}

/**
 * Returns the super class from which the recevier was derived.
 */
+ (Class) superclass
{
  return class_get_super_class (self);
}

/**
 * Returns the super class from which the receviers class was derived.
 */
- (Class) superclass
{
  return object_get_super_class (self);
}

/**
 * Returns a flag to say if instances of the receiver class will
 * respond to the specified selector.  This ignores situations
 * where a subclass implements -forwardInvocation: to respond to
 * selectors not normally handled ... in these cases the subclass
 * may override this method to handle it.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
+ (BOOL) instancesRespondToSelector: (SEL)aSelector
{
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];
#if 0
  return (class_get_instance_method(self, aSelector) != METHOD_NULL);
#else
  return __objc_responds_to((id)&self, aSelector);
#endif
}

/**
 * Returns a flag to say whether the receiving class conforms to aProtocol
 */
+ (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  struct objc_protocol_list* proto_list;

  for (proto_list = ((struct objc_class*)self)->protocols;
       proto_list; proto_list = proto_list->next)
    {
      int i;
      
      for (i = 0; i < proto_list->count; i++)
      {
	/* xxx We should add conformsToProtocol to Protocol class. */
        if ([proto_list->list[i] conformsTo: aProtocol])
	  {
	    return YES;
	  }
      }
    }
  
  if ([self superclass])
    {
      return [[self superclass] conformsToProtocol: aProtocol];
    }
  else
    {
      return NO;
    }
}

/**
 * Returns a flag to say whether the class of the receiver conforms
 * to aProtocol.
 */
- (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  return [[self class] conformsToProtocol: aProtocol];
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
   *	If 'self' is an instance, GSObjCClass() will get the class,
   *	and get_imp() will get the instance method.
   *	If 'self' is a class, GSObjCClass() will get the meta-class,
   *	and get_imp() will get the class method.
   */
  return get_imp(GSObjCClass(self), aSelector);
}

/**
 * Returns a pointer to the C function implementing the method used
 * to respond to messages with aSelector whihc are sent to instances
 * of the receiving class.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
  struct objc_method	*mth;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  mth = class_get_instance_method(self, aSelector);
  return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
    : nil;
}
  
/**
 * Returns the method signature describing how the receiver would handle
 * a message with aSelector.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  const char	*types;
  struct objc_method *mth;

  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  mth = (GSObjCIsInstance(self)
    ? class_get_instance_method(GSObjCClass(self), aSelector)
    : class_get_class_method(GSObjCClass(self), aSelector));
  if (mth == 0)
    {
      types = 0;
    }
  else
    {
      types = mth->method_types;
    }
  if (types == 0)
    {
      types = sel_get_type(aSelector);
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
  return [NSString stringWithFormat: @"<%s: %lx>",
    object_get_class_name(self), (unsigned long)self];
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
 * Raises an invalid argument exception providing infomration about
 * the receivers inability to handle aSelector.
 */
- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  [NSException raise: NSInvalidArgumentException
	      format: @"%s(%s) does not recognize %s",
	       object_get_class_name(self), 
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSelector ? sel_get_name(aSelector) : "(null)"];
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
 * The default implemnentation calls -doesNotRecognizeSelector:
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
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

- (Class) classForArchiver
{
  return [self classForCoder];
}

- (Class) classForCoder
{
  return [self class];
}

- (Class) classForPortCoder
{
  return [self classForCoder];
}

- (id) replacementObjectForArchiver: (NSArchiver*)anArchiver
{
  return [self replacementObjectForCoder: (NSCoder*)anArchiver];
}

- (id) replacementObjectForCoder: (NSCoder*)anEncoder
{
  return self;
}

/**
 * Returns the actual object to be encoded for sending over the
 * network on a Distributed Objects connection.<br />
 * The default implementation returns self if the receiver is being
 * sent <em>bycopy</em> and returns a proxy otherwise.<br />
 * Subclasses may override this method to change this behavior,
 * eg. to ensure that they are always copied. 
 */
- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  static Class	proxyClass = 0;
  static IMP	proxyImp = 0;

  if (proxyImp == 0)
    {
      proxyClass = [NSDistantObject class];
      /*
       * use get_imp() because NSDistantObject doesn't implement
       * methodForSelector:
       */
      proxyImp = get_imp(GSObjCClass((id)proxyClass),
	@selector(proxyWithLocal:connection:));
    }

  if ([aCoder isBycopy])
    {
      return self;
    }
  else
    {
      return (*proxyImp)(proxyClass, @selector(proxyWithLocal:connection:),
	self, [aCoder connection]);
    }
}


/* NSObject protocol */

/**
 * Adds the receiver to the current autorelease pool, so that it will be
 * sent a -release message when the pool is destroyed.<br />
 * Returns the receiver.<br />
 * In GNUstep, the [NSObject+enableDoubleReleaseCheck:] method may be used
 * to turn on checking for ratain/release errors in this method.
 */
- (id) autorelease
{
#if	GS_WITH_GC == 0
  if (double_release_check_enabled)
    {
      unsigned release_count;
      unsigned retain_count = [self retainCount];
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
 * same value fro both instances.<br />
 * The default implementation returns the address of the instance.
 */
- (unsigned) hash
{
  return (unsigned)self;
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
  Class class = GSObjCClass(self);

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
  return (GSObjCClass(self) == aClass) ? YES : NO;
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
    
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
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
    
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
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
  
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, object1, object2);
}

/**
 * Decrements the retain count for the receiver if greater than zeron,
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
  if (double_release_check_enabled)
    {
      unsigned release_count;
      unsigned retain_count = [self retainCount];
      release_count = [autorelease_class autoreleaseCountForObject:self];
      if (release_count >= retain_count)
        [NSException raise: NSGenericException
		     format: @"Release would release object too many times."];
    }

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
 * <br />Raises NSInvalidArgumentException if given a null selector.
 */
- (BOOL) respondsToSelector: (SEL)aSelector
{
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

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
 * implicit reference count of 1, and has an 'extra refrence count'
 * returned by the NSExtraRefCount() function, so the value returned by
 * this method is always greater than zero.<br />
 * By convention, objects which should (or can) never be deallocated
 * return the maximum unsigned integer value.
 */
- (unsigned) retainCount
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
+ (unsigned) retainCount
{
  return UINT_MAX;
}

/**
 * Returns the reciever.
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
  return GSObjCZone(self);
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

/**
 * Returns the version number of the receiving class.
 */
+ (int) version
{
  return class_get_version(self);
}

/**
 * Sets the version number of the receiving class.
 */
+ (id) setVersion: (int)aVersion
{
  if (aVersion < 0)
    [NSException raise: NSInvalidArgumentException
	        format: @"%s +setVersion: may not set a negative version",
			object_get_class_name(self)];
  class_set_version(self, aVersion);
  return self;
}

@end


@implementation NSObject (NEXTSTEP)

/* NEXTSTEP Object class compatibility */

- (id) error: (const char *)aString, ...
{
#define FMT "error: %s (%s)\n%s\n"
  char fmt[(strlen((char*)FMT)+strlen((char*)object_get_class_name(self))
            +((aString!=NULL)?strlen((char*)aString):0)+8)];
  va_list ap;

  sprintf(fmt, FMT, object_get_class_name(self),
                    GSObjCIsInstance(self)?"instance":"class",
                    (aString!=NULL)?aString:"");
  va_start(ap, aString);
  /* xxx What should `code' argument be?  Current 0. */
  objc_verror (self, 0, fmt, ap);
  va_end(ap);
  return nil;
#undef FMT
}

/*
- (const char *) name
{
  return object_get_class_name(self);
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

  mth = class_get_instance_method(self, aSelector);
  return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
    : nil;
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

- (id) notImplemented: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"method %s not implemented in %s(%s)",
    aSel ? sel_get_name(aSel) : "(null)", 
    object_get_class_name(self),
    GSObjCIsInstance(self) ? "instance" : "class"];
  return nil;
}

- (id) doesNotRecognize: (SEL)aSel
{
  [NSException raise: NSGenericException
	       format: @"%s(%s) does not recognize %s",
	       object_get_class_name(self), 
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSel ? sel_get_name(aSel) : "(null)"];
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



@implementation NSObject (GNU)

/* GNU Object class compatibility */

/**
 * Called to change the class used for autoreleasing objects.
 */
+ (void) setAutoreleaseClass: (Class)aClass
{
  autorelease_class = aClass;
  autorelease_imp = [self instanceMethodForSelector: autorelease_sel];
}

/**
 * returns the class used to autorelease objects.
 */
+ (Class) autoreleaseClass
{
  return autorelease_class;
}

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
 * Compare the receiver with anObject to see which is greater.
 * The default implementation orders by memory location.
 */
- (int) compare: (id)anObject
{
  if (anObject == self)
    {
      return NSOrderedSame;
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  if ([self isEqual: anObject])
    {
      return NSOrderedSame;
    }
  /*
   * Ordering objects by their address is pretty useless, 
   * so subclasses should override this is some useful way.
   */
  if (self > anObject)
    {
      return NSOrderedDescending;
    }
  else 
    {
      return NSOrderedAscending;
    }
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
			     indent: (unsigned)level
{
  return [self descriptionWithLocale: aLocale];
}

+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
			     indent: (unsigned)level
{
  return [self descriptionWithLocale: aLocale];
}

/**
 * Uses the [NSString] implementation.
 */
- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output
{
  NSString	*tmp =  [(id)self descriptionWithLocale: aLocale];

  [tmp descriptionWithLocale: aLocale indent: level to: output];
}

+ (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output
{
  NSString	*tmp =  [(id)self descriptionWithLocale: aLocale];

  [tmp descriptionWithLocale: aLocale indent: level to: output];
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
  return object_is_class(self);
}

- (BOOL) isInstance
{
  return GSObjCIsInstance(self);
}

- (BOOL) isMemberOfClassNamed: (const char*)aClassName
{
  return ((aClassName!=NULL)
          &&!strcmp(GSNameFromClass(GSObjCClass(self)), aClassName));
}

+ (struct objc_method_description *) descriptionForInstanceMethod: (SEL)aSel
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  return ((struct objc_method_description *)
           class_get_instance_method(self, aSel));
}

- (struct objc_method_description *) descriptionForMethod: (SEL)aSel
{
  if (aSel == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  return ((struct objc_method_description *)
           (GSObjCIsInstance(self)
            ?class_get_instance_method(GSObjCClass(self), aSel)
            :class_get_class_method(GSObjCClass(self), aSel)));
}

/**
 * Transmutes the receiver into an immutable version of the same object
 * and returns the result.<br />
 * If the receiver is not a mutable object or cannot be simply transmuted,
 * then this method either returns the receiver unchanged or,
 * if the force flag is set to YES, returns an autoreleased copy of the
 * receiver.<br />
 * Mutable classes should override this default implementation.<br />
 * This method is used in methods which are declared to return immutable
 * objects (eg. an NSArray), but which create and build mutable ones
 * internally.
 */
- (id) makeImmutableCopyOnFail: (BOOL)force
{
  if (force == YES)
    {
      return AUTORELEASE([self copy]);
    }
  return self;
}

/**
 * Changes the class of the receiver (the 'isa' pointer) to be aClassObject,
 * but only if the receiver is an instance of a subclass of aClassObject
 * which has not added extra instance variables.<br />
 * Returns zero on failure, or the old class on success.
 */
- (Class) transmuteClassTo: (Class)aClassObject
{
  if (GSObjCIsInstance(self) == YES)
    if (class_is_class(aClassObject))
      if (class_get_instance_size(aClassObject)==class_get_instance_size(isa))
        if ([self isKindOfClass: aClassObject])
          {
            Class old_isa = isa;
            isa = aClassObject;
            return old_isa;
          }
  return 0;
}

- (id) subclassResponsibility: (SEL)aSel
{
  [NSException raise: NSGenericException
    format: @"subclass %s(%s) should override %s", 
	       object_get_class_name(self),
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSel ? sel_get_name(aSel) : "(null)"];
  return nil;
}

- (id) shouldNotImplement: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"%s(%s) should not implement %s", 
    object_get_class_name(self), 
    GSObjCIsInstance(self) ? "instance" : "class",
    aSel ? sel_get_name(aSel) : "(null)"];
  return nil;
}

+ (int) streamVersion: (TypedStream*)aStream
{
#ifndef NeXT_RUNTIME
  if (aStream->mode == OBJC_READONLY)
    return objc_get_stream_class_version (aStream, self);
  else
#endif
    return class_get_version (self);
}

// These are used to write or read the instance variables 
// declared in this particular part of the object.  Subclasses
// should extend these, by calling [super read/write: aStream]
// before doing their own archiving.  These methods are private, in
// the sense that they should only be called from subclasses.

- (id) read: (TypedStream*)aStream
{
  // [super read: aStream];  
  return self;
}

- (id) write: (TypedStream*)aStream
{
  // [super write: aStream];
  return self;
}

- (id) awake
{
  // [super awake];
  return self;
}

@end

/*
 *	Stuff for temporary memory management.
 */
#if GS_WITH_GC == 0
@interface	_FastMallocBuffer : NSObject
@end

@implementation	_FastMallocBuffer
@end
#endif

/*
 *	Function for giving us the fastest possible allocation of memory to
 *	be used for temporary storage.
 */
void *
_fastMallocBuffer(unsigned size)
{
#if GS_WITH_GC
	return GC_malloc(size);
#else
  _FastMallocBuffer	*o;

  o = (_FastMallocBuffer*)NSAllocateObject(fastMallocClass,
	size + fastMallocOffset, NSDefaultMallocZone());
  (*autorelease_imp)(autorelease_class, autorelease_sel, o);
  return ((void*)&o[1])+fastMallocOffset;
#endif
}


/*
 * Stuff for compatibility with 'Object' derived classes.
 */
@interface	Object (NSObjectCompat)
+ (NSString*) description;
+ (void) release;
+ (id) retain;
- (NSString*) className;
- (NSString*) description;
- (void) release;
- (BOOL) respondsToSelector: (SEL)aSel;
- (id) retain;
@end

@implementation	Object (NSObjectCompat)
+ (NSString*) description
{
  return NSStringFromClass(self);
}
+ (void) release
{
  return;
}
+ (id) retain
{
  return self;
}
- (NSString*) className
{
  return NSStringFromClass([self class]);
}
- (NSString*) description
{
  return [NSString stringWithFormat: @"<%s: %lx>",
    object_get_class_name(self), (unsigned long)self];
}
- (BOOL) isProxy
{
  return NO;
}
- (void) release
{
  return;
}
- (BOOL) respondsToSelector: (SEL)aSelector
{
  /* Object implements -respondsTo: */
  return [self respondsTo: aSelector];
}
- (id) retain
{
  return self;
}
@end



@interface	NSZombie
- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
@end

@implementation	NSZombie
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
  unsigned	size = [[anInvocation methodSignature] methodReturnLength];
  unsigned char	v[size];

  memset(v, '\0', size);
  GSLogZombie(self, [anInvocation selector]);
  [anInvocation setReturnValue: (void*)v];
  return;
}
@end

