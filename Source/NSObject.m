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

@class	_FastMallocBuffer;
static Class	fastMallocClass;
static unsigned	fastMallocOffset;

static Class	NSConstantStringClass;

@class	NSDataMalloc;
@class	NSMutableDataMalloc;

static BOOL deallocNotifications = NO;

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


#if	GS_WITH_GC

unsigned
NSExtraRefCount(id anObject)
{
  return 0;
}
void
NSIncrementExtraRefCount(id anObject)
{
}
#define	NSIncrementExtraRefCount(X) 
BOOL
NSDecrementExtraRefCountWasZero(id anObject)
{
  return NO;
}
#define NSDecrementExtraRefCountWasZero(X)	NO

#else	/* GS_WITH_GC	*/

/*
 *	Now do conditional compilation of reference count functions
 *	depending on whether we are using local or global counting.
 */
#if	defined(REFCNT_LOCAL)

unsigned
NSExtraRefCount(id anObject)
{
  return ((obj)anObject)[-1].retained;
}

void
NSIncrementExtraRefCount(id anObject)
{
  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      ((obj)anObject)[-1].retained++;
      objc_mutex_unlock (allocationLock);
    }
  else
    {
      ((obj)anObject)[-1].retained++;
    }
}

#define	NSIncrementExtraRefCount(X) ({ \
  if (allocationLock != 0) \
    { \
      objc_mutex_lock(allocationLock); \
      ((obj)(X))[-1].retained++;            \
      objc_mutex_unlock(allocationLock); \
    } \
  else \
    { \
      ((obj)X)[-1].retained++; \
    } \
})

BOOL
NSDecrementExtraRefCountWasZero(id anObject)
{
  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      if (((obj)anObject)[-1].retained-- == 0)
	{
	  objc_mutex_unlock(allocationLock);
	  return YES;
	}
      else
	{
	  objc_mutex_unlock(allocationLock);
	  return NO;
	}
    }
  else
    {
      if (((obj)anObject)[-1].retained-- == 0)
	{
	  return YES;
	}
      else
	{
	  return NO;
	}
    }
}


#define	NSExtraRefCount(X)	(((obj)(X))[-1].retained)

#else

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

/* The maptable of retain counts on objects */
static GSIMapTable_t	retain_counts;

void
NSIncrementExtraRefCount (id anObject)
{
  GSIMapNode	node;

  if (allocationLock != 0)
    {
      objc_mutex_lock(allocationLock);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node != 0)
	{
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
	  (node->value.uint)++;
	}
      else
	{
	  GSIMapAddPair(&retain_counts, (GSIMapKey)anObject, (GSIMapVal)1);
	}
    }
}

BOOL
NSDecrementExtraRefCountWasZero (id anObject)
{
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
      NSCAssert(node->value.uint > 0, NSInternalInconsistencyException);
      if (--(node->value.uint) == 0)
	{
	  GSIMapRemoveKey((GSIMapTable)&retain_counts, (GSIMapKey)anObject);
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
      NSCAssert(node->value.uint > 0, NSInternalInconsistencyException);
      if (--(node->value.uint) == 0)
	{
	  GSIMapRemoveKey((GSIMapTable)&retain_counts, (GSIMapKey)anObject);
	}
    }
  return NO;
}

unsigned
NSExtraRefCount (id anObject)
{
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
  return ret;	/* ExtraRefCount + 1	*/
}

#endif	/* defined(REFCNT_LOCAL) */

#endif	/* GS_WITH_GC */


/*
 *	Now do conditional compilation of memory allocation functions
 *	depending on what information (if any) we are storing before
 *	the start of each object.
 */
#if	GS_WITH_GC

#include	<gc.h>
#include	<gc_typed.h>

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
  id	new = nil;
  int	size = aClass->instance_size + extraBytes;

  NSCAssert((CLS_ISCLASS(aClass)), @"Bad class for new object");
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
  id new = nil;
  int size = aClass->instance_size + extraBytes + sizeof(struct obj_layout);
  if (CLS_ISCLASS (aClass))
    {
      if (zone == 0)
	zone = NSDefaultMallocZone();
      new = NSZoneMalloc(zone, size);
    }
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
  id new = nil;
  int size = aClass->instance_size + extraBytes;
  if (CLS_ISCLASS (aClass))
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



@implementation NSObject

+ (void) _becomeMultiThreaded: (NSNotification)aNotification
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
      extern void		GSBuildStrings();	// See externs.m
      extern const char*	GSSetLocaleC();		// See GSLocale.m

#ifdef __MINGW__
      // See libgnustep-base-entry.m
      extern void gnustep_base_socket_init();	
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
      gnustep_global_lock = [[NSRecursiveLock alloc] init];

      // Zombie management stuff.
      zombieClass = [NSZombie class];
      zombieMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
      NSZombieEnabled = GSEnvironmentFlag("NSZombieEnabled", NO);
      NSDeallocateZombies = GSEnvironmentFlag("NSDeallocateZombies", NO);

      autorelease_class = [NSAutoreleasePool class];
      autorelease_sel = @selector(addObject:);
      autorelease_imp = [autorelease_class methodForSelector: autorelease_sel];
      fastMallocClass = [_FastMallocBuffer class];
#if	GS_WITH_GC == 0
#if	!defined(REFCNT_LOCAL)
      GSIMapInitWithZoneAndCapacity(&retain_counts,
	NSDefaultMallocZone(), 1024);
#endif
      fastMallocOffset = fastMallocClass->instance_size % ALIGN;
#else
      fastMallocOffset = 0;
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

+ (id) alloc
{
  return [self allocWithZone: NSDefaultMallocZone()];
}

+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject (self, 0, z);
}

+ (id) copyWithZone: (NSZone*)z
{
  return self;
}

+ (id) new
{
  return [[self alloc] init];
}

- (id) copy
{
  return [(id)self copyWithZone: NULL];
}

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

- (id) init
{
  return self;
}

- (id) mutableCopy
{
  return [(id)self mutableCopyWithZone: NULL];
}

+ (Class) superclass
{
  return class_get_super_class (self);
}

- (Class) superclass
{
  return object_get_super_class (self);
}

+ (BOOL) instancesRespondToSelector: (SEL)aSelector
{
#if 0
  return (class_get_instance_method(self, aSelector) != METHOD_NULL);
#else
  return __objc_responds_to((id)&self, aSelector);
#endif
}

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

- (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  return [[self class] conformsToProtocol:aProtocol];
}

+ (IMP) instanceMethodForSelector: (SEL)aSelector
{
  /*
   *	Since 'self' is an class, get_imp() will get the instance method.
   */
  return get_imp((Class)self, aSelector);
}

- (IMP) methodForSelector: (SEL)aSelector
{
  /*
   *	If 'self' is an instance, GSObjCClass() will get the class,
   *	and get_imp() will get the instance method.
   *	If 'self' is a class, GSObjCClass() will get the meta-class,
   *	and get_imp() will get the class method.
   */
  return get_imp(GSObjCClass(self), aSelector);
}

+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
  struct objc_method* mth = class_get_instance_method(self, aSelector);
  return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
    : nil;
}
  
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  const char	*types;
  struct objc_method *mth;

  if (aSelector == 0)
    {
      return nil;
    }
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

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%s: %lx>",
    object_get_class_name(self), (unsigned long)self];
}

+ (NSString*) description
{
  return [NSString stringWithCString: object_get_class_name(self)];
}

+ (void) poseAsClass: (Class)aClassObject
{
  class_pose_as(self, aClassObject);
  /*
   *	We may have replaced a class in the cache, or may have replaced one
   *	which had cached methods, so we must rebuild the cache.
   */
}

- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  [NSException raise: NSInvalidArgumentException
	       format: @"%s(%s) does not recognize %s",
	       object_get_class_name(self), 
	       GSObjCIsInstance(self) ? "instance" : "class",
	       sel_get_name(aSelector)];
}

- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame
{
  NSInvocation *inv;

  inv = AUTORELEASE([[NSInvocation alloc] initWithArgframe: argFrame
				       selector: aSel]);
  [self forwardInvocation:inv];
  return [inv returnFrame: argFrame];
}

- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  [self doesNotRecognizeSelector:[anInvocation selector]];
  return;
}

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
  else if ([self isKindOfClass: proxyClass])
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

+ (id) autorelease
{
  return self;
}

+ (Class) class
{
  return self;
}

- (Class) class
{
  return object_get_class(self);
}

- (unsigned) hash
{
  return (unsigned)self;
}

- (BOOL) isEqual: (id)anObject
{
  return (self == anObject);
}

+ (BOOL) isKindOfClass: (Class)aClass
{
  if (aClass == [NSObject class])
    return YES;
  return NO;
}

- (BOOL) isKindOfClass: (Class)aClass
{
  Class class = GSObjCClass(self);

  return GSObjCIsKindOf(class, aClass);
}

+ (BOOL) isMemberOfClass: (Class)aClass
{
  return (self == aClass) ? YES : NO;
}

- (BOOL) isMemberOfClass: (Class)aClass
{
  return (GSObjCClass(self) == aClass) ? YES : NO;
}

- (BOOL) isProxy
{
  return NO;
}

- (id) performSelector: (SEL)aSelector
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
    
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector);
}

- (id) performSelector: (SEL)aSelector withObject: (id) anObject
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
    
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, anObject);
}

- (id) performSelector: (SEL)aSelector
	    withObject: (id) object1
	    withObject: (id) object2
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
  
  msg = get_imp(GSObjCClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, object1, object2);
}

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
      if (deallocNotifications == NO || [self _dealloc] == YES)
	{
	  [self dealloc];
	}
    }
#endif
}

+ (oneway void) release
{
  return;
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
  return __objc_responds_to(self, aSelector);
}

- (id) retain
{
#if	GS_WITH_GC == 0
  NSIncrementExtraRefCount(self);
#endif
  return self;
}

+ (id) retain
{
  return self;
}

- (unsigned) retainCount
{
#if	GS_WITH_GC
  return UINT_MAX;
#else
  return NSExtraRefCount(self) + 1;
#endif
}

+ (unsigned) retainCount
{
  return UINT_MAX;
}

- (id) self
{
  return self;
}

- (NSZone*) zone
{
  return GSObjCZone(self);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  return;
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  return self;
}

+ (int) version
{
  return class_get_version(self);
}

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

- error: (const char *)aString, ...
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

- (const char *) name
{
  return object_get_class_name(self);
}

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
  return objc_msg_sendv(self, aSel, argFrame);
}

+ (IMP) instanceMethodFor: (SEL)aSel
{
  return [self instanceMethodForSelector:aSel];
}

+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
  struct objc_method* mth = class_get_instance_method(self, aSelector);

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
    format: @"method %s not implemented in %s(%s)", sel_get_name(aSel), 
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
	       sel_get_name(aSel)];
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

+ (void) setAutoreleaseClass: (Class)aClass
{
  autorelease_class = aClass;
  autorelease_imp = [self instanceMethodForSelector: autorelease_sel];
}

+ (Class) autoreleaseClass
{
  return autorelease_class;
}

+ (void) enableDoubleReleaseCheck: (BOOL)enable
{
  double_release_check_enabled = enable;
}

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

- (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
{
  return [self description];
}

+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
{
  return [self description];
}

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

- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output
{
  [output appendString:
    [(id)self descriptionWithLocale: aLocale indent: level]];
}

+ (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output
{
  [output appendString:
    [(id)self descriptionWithLocale: aLocale indent: level]];
}

- (BOOL) deallocNotificationsActive
{
  return deallocNotifications;
}

- (void) setDeallocNotificationsActive: (BOOL)flag
{
  deallocNotifications = flag;
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
  return ((struct objc_method_description *)
           class_get_instance_method(self, aSel));
}

- (struct objc_method_description *) descriptionForMethod: (SEL)aSel
{
  return ((struct objc_method_description *)
           (GSObjCIsInstance(self)
            ?class_get_instance_method(GSObjCClass(self), aSel)
            :class_get_class_method(GSObjCClass(self), aSel)));
}

- (Class) transmuteClassTo: (Class)aClassObject
{
  if (GSObjCIsInstance(self) == YES)
    if (class_is_class(aClassObject))
      if (class_get_instance_size(aClassObject)==class_get_instance_size(isa))
        if ([self isKindOfClass:aClassObject])
          {
            Class old_isa = isa;
            isa = aClassObject;
            return old_isa;
          }
  return nil;
}

- (id) subclassResponsibility: (SEL)aSel
{
  [NSException raise: NSGenericException
    format: @"subclass %s(%s) should override %s", 
	       object_get_class_name(self),
	       GSObjCIsInstance(self) ? "instance" : "class",
	       sel_get_name(aSel)];
  return nil;
}

- (id) shouldNotImplement: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"%s(%s) should not implement %s", 
    object_get_class_name(self), 
    GSObjCIsInstance(self) ? "instance" : "class",
    sel_get_name(aSel)];
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
@interface	_FastMallocBuffer : NSObject
@end

@implementation	_FastMallocBuffer
@end

/*
 *	Function for giving us the fastest possible allocation of memory to
 *	be used for temporary storage.
 */
void *
_fastMallocBuffer(unsigned size)
{
  _FastMallocBuffer	*o;

  o = (_FastMallocBuffer*)NSAllocateObject(fastMallocClass,
	size + fastMallocOffset, NSDefaultMallocZone());
  (*autorelease_imp)(autorelease_class, autorelease_sel, o);
  return ((void*)&o[1])+fastMallocOffset;
}


/*
 * Stuff for compatibility with 'Object' derived classes.
 */
@interface	Object (NSObjectCompat)
+ (void) release;
+ (id) retain;
- (void) release;
- (id) retain;
@end

@implementation	Object (NSObjectCompat)
+ (void) release
{
  return;
}
+ (id) retain
{
  return self;
}
- (void) release
{
  return;
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

