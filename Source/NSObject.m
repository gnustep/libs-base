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
#include <limits.h>



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


/*
 * retain_counts_gate is needed when running multi-threaded for retain/release
 * to work reliably.
 */
static objc_mutex_t retain_counts_gate = NULL;

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
  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      ((obj)anObject)[-1].retained++;
      objc_mutex_unlock (retain_counts_gate);
    }
  else
    {
      ((obj)anObject)[-1].retained++;
    }
}

#define	NSIncrementExtraRefCount(X) ({ \
  if (retain_counts_gate != 0) \
    { \
      objc_mutex_lock(retain_counts_gate); \
      ((obj)(X))[-1].retained++;            \
      objc_mutex_unlock(retain_counts_gate); \
    } \
  else \
    { \
      ((obj)X)[-1].retained++; \
    } \
})

BOOL
NSDecrementExtraRefCountWasZero(id anObject)
{
  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      if (((obj)anObject)[-1].retained-- == 0)
	{
	  objc_mutex_unlock(retain_counts_gate);
	  return YES;
	}
      else
	{
	  objc_mutex_unlock(retain_counts_gate);
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

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node != 0)
	{
	  (node->value.uint)++;
	}
      else
	{
	  GSIMapAddPair(&retain_counts, (GSIMapKey)anObject, (GSIMapVal)1);
	}
      objc_mutex_unlock(retain_counts_gate);
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

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  objc_mutex_unlock(retain_counts_gate);
	  return YES;
	}
      NSCAssert(node->value.uint > 0, NSInternalInconsistencyException);
      if (--(node->value.uint) == 0)
	{
	  GSIMapRemoveKey((GSIMapTable)&retain_counts, (GSIMapKey)anObject);
	}
      objc_mutex_unlock(retain_counts_gate);
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

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      node = GSIMapNodeForKey(&retain_counts, (GSIMapKey)anObject);
      if (node == 0)
	{
	  ret = 0;
	}
      else
	{
	  ret = node->value.uint;
	}
      objc_mutex_unlock(retain_counts_gate);
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
      ((id)anObject)->class_pointer = (void*) 0xdeadface;
      NSZoneFree(z, o);
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
      ((id)anObject)->class_pointer = (void*) 0xdeadface;
      NSZoneFree(z, anObject);
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
  if (retain_counts_gate == 0)
    {
      retain_counts_gate = objc_mutex_allocate();
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



#include	<Foundation/NSValue.h>
#include	<Foundation/NSKeyValueCoding.h>
#include	<Foundation/NSNull.h>


@implementation NSObject (KeyValueCoding)

static id
GSGetValue(NSObject *self, NSString *key, SEL sel,
  const char *type, unsigned size, int off)
{
  if (sel != 0)
    {
      NSMethodSignature	*sig = [self methodSignatureForSelector: sel];

      if ([sig numberOfArguments] != 2)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"key-value get method has wrong number of args"];
	}
      type = [sig methodReturnType];
    }
  if (type == NULL)
    {
      return [self handleQueryWithUnboundKey: key];
    }
  else
    {
      id	val = nil;

      switch (*type)
	{
	  case _C_ID:
	  case _C_CLASS:
	    {
	      id	v;

	      if (sel == 0)
		{
		  v = *(id *)((char *)self + off);
		}
	      else
		{
		  id	(*imp)(id, SEL) =
		    (id (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = v;
	    }
	    break;

	  case _C_CHR:
	    {
	      signed char	v;

	      if (sel == 0)
		{
		  v = *(char *)((char *)self + off);
		}
	      else
		{
		  signed char	(*imp)(id, SEL) =
		    (signed char (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithChar: v];
	    }
	    break;

	  case _C_UCHR:
	    {
	      unsigned char	v;

	      if (sel == 0)
		{
		  v = *(unsigned char *)((char *)self + off);
		}
	      else
		{
		  unsigned char	(*imp)(id, SEL) =
		    (unsigned char (*)(id, SEL))[self methodForSelector:
		    sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithUnsignedChar: v];
	    }
	    break;

	  case _C_SHT:
	    {
	      short	v;

	      if (sel == 0)
		{
		  v = *(short *)((char *)self + off);
		}
	      else
		{
		  short	(*imp)(id, SEL) =
		    (short (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithShort: v];
	    }
	    break;

	  case _C_USHT:
	    {
	      unsigned short	v;

	      if (sel == 0)
		{
		  v = *(unsigned short *)((char *)self + off);
		}
	      else
		{
		  unsigned short	(*imp)(id, SEL) =
		    (unsigned short (*)(id, SEL))[self methodForSelector:
		    sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithUnsignedShort: v];
	    }
	    break;

	  case _C_INT:
	    {
	      int	v;

	      if (sel == 0)
		{
		  v = *(int *)((char *)self + off);
		}
	      else
		{
		  int	(*imp)(id, SEL) =
		    (int (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithInt: v];
	    }
	    break;

	  case _C_UINT:
	    {
	      unsigned int	v;

	      if (sel == 0)
		{
		  v = *(unsigned int *)((char *)self + off);
		}
	      else
		{
		  unsigned int	(*imp)(id, SEL) =
		    (unsigned int (*)(id, SEL))[self methodForSelector:
		    sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithUnsignedInt: v];
	    }
	    break;

	  case _C_LNG:
	    {
	      long	v;

	      if (sel == 0)
		{
		  v = *(long *)((char *)self + off);
		}
	      else
		{
		  long	(*imp)(id, SEL) =
		    (long (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithLong: v];
	    }
	    break;

	  case _C_ULNG:
	    {
	      unsigned long	v;

	      if (sel == 0)
		{
		  v = *(unsigned long *)((char *)self + off);
		}
	      else
		{
		  unsigned long	(*imp)(id, SEL) =
		    (unsigned long (*)(id, SEL))[self methodForSelector:
		    sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithUnsignedLong: v];
	    }
	    break;

#ifdef	_C_LNG_LNG
	  case _C_LNG_LNG:
	    {
	      long long	v;

	      if (sel == 0)
		{
		  v = *(long long *)((char *)self + off);
		}
	      else
		{
		   long long	(*imp)(id, SEL) =
		    (long long (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithLongLong: v];
	    }
	    break;
#endif

#ifdef	_C_ULNG_LNG
	  case _C_ULNG_LNG:
	    {
	      unsigned long long	v;

	      if (sel == 0)
		{
		  v = *(unsigned long long *)((char *)self + off);
		}
	      else
		{
		  unsigned long long	(*imp)(id, SEL) =
		    (unsigned long long (*)(id, SEL))[self
		    methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithUnsignedLongLong: v];
	    }
	    break;
#endif

	  case _C_FLT:
	    {
	      float	v;

	      if (sel == 0)
		{
		  v = *(float *)((char *)self + off);
		}
	      else
		{
		  float	(*imp)(id, SEL) =
		    (float (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithFloat: v];
	    }
	    break;

	  case _C_DBL:
	    {
	      double	v;

	      if (sel == 0)
		{
		  v = *(double *)((char *)self + off);
		}
	      else
		{
		  double	(*imp)(id, SEL) =
		    (double (*)(id, SEL))[self methodForSelector: sel];

		  v = (*imp)(self, sel);
		}
	      val = [NSNumber numberWithDouble: v];
	    }
	    break;

	  case _C_VOID:
            {
              void        (*imp)(id, SEL) =
                (void (*)(id, SEL))[self methodForSelector: sel];
              
              (*imp)(self, sel);
            }
            val = nil;
            break;

	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"key-value get method has unsupported type"];
	}
      return val;
    }
}

static void
GSSetValue(NSObject *self, NSString *key, id val, SEL sel,
  const char *type, unsigned size, int off)
{
  if (sel != 0)
    {
      NSMethodSignature	*sig = [self methodSignatureForSelector: sel];

      if ([sig numberOfArguments] != 3)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"key-value set method has wrong number of args"];
	}
      type = [sig getArgumentTypeAtIndex: 2];
    }
  if (type == NULL)
    {
      [self handleTakeValue: val forUnboundKey: key];
    }
  else
    {
      switch (*type)
	{
	  case _C_ID:
	  case _C_CLASS:
	    {
	      id	v = val;

	      if (sel == 0)
		{
		  id *ptr = (id *)((char *)self + off);

		  [*ptr autorelease];
		  *ptr = [v retain];
		}
	      else
		{
		  void	(*imp)(id, SEL, id) =
		    (void (*)(id, SEL, id))[self methodForSelector: sel];

		  (*imp)(self, sel, val);
		}
	    }
	    break;

	  case _C_CHR:
	    {
	      char	v = [val charValue];

	      if (sel == 0)
		{
		  char *ptr = (char *)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, char) =
		    (void (*)(id, SEL, char))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_UCHR:
	    {
	      unsigned char	v = [val unsignedCharValue];

	      if (sel == 0)
		{
		  unsigned char *ptr = (unsigned char*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, unsigned char) =
		    (void (*)(id, SEL, unsigned char))[self methodForSelector:
		    sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_SHT:
	    {
	      short	v = [val shortValue];

	      if (sel == 0)
		{
		  short *ptr = (short*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, short) =
		    (void (*)(id, SEL, short))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_USHT:
	    {
	      unsigned short	v = [val unsignedShortValue];

	      if (sel == 0)
		{
		  unsigned short *ptr = (unsigned short*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, unsigned short) =
		    (void (*)(id, SEL, unsigned short))[self methodForSelector:
		    sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_INT:
	    {
	      int	v = [val intValue];

	      if (sel == 0)
		{
		  int *ptr = (int*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, int) =
		    (void (*)(id, SEL, int))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_UINT:
	    {
	      unsigned int	v = [val unsignedIntValue];

	      if (sel == 0)
		{
		  unsigned int *ptr = (unsigned int*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, unsigned int) =
		    (void (*)(id, SEL, unsigned int))[self methodForSelector:
		    sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_LNG:
	    {
	      long	v = [val longValue];

	      if (sel == 0)
		{
		  long *ptr = (long*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, long) =
		    (void (*)(id, SEL, long))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_ULNG:
	    {
	      unsigned long	v = [val unsignedLongValue];

	      if (sel == 0)
		{
		  unsigned long *ptr = (unsigned long*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, unsigned long) =
		    (void (*)(id, SEL, unsigned long))[self methodForSelector:
		    sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

#ifdef	_C_LNG_LNG
	  case _C_LNG_LNG:
	    {
	      long long	v = [val longLongValue];

	      if (sel == 0)
		{
		  long long *ptr = (long long*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, long long) =
		    (void (*)(id, SEL, long long))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;
#endif

#ifdef	_C_ULNG_LNG
	  case _C_ULNG_LNG:
	    {
	      unsigned long long	v = [val unsignedLongLongValue];

	      if (sel == 0)
		{
		  unsigned long long *ptr = (unsigned long long*)((char*)self +
								  off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, unsigned long long) =
		    (void (*)(id, SEL, unsigned long long))[self
		    methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;
#endif

	  case _C_FLT:
	    {
	      float	v = [val floatValue];

	      if (sel == 0)
		{
		  float *ptr = (float*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, float) =
		    (void (*)(id, SEL, float))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  case _C_DBL:
	    {
	      double	v = [val doubleValue];

	      if (sel == 0)
		{
		  double *ptr = (double*)((char *)self + off);

		  *ptr = v;
		}
	      else
		{
		  void	(*imp)(id, SEL, double) =
		    (void (*)(id, SEL, double))[self methodForSelector: sel];

		  (*imp)(self, sel, v);
		}
	    }
	    break;

	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"key-value set method has unsupported type"];
	}
    }
}

+ (BOOL) accessInstanceVariablesDirectly
{
  return YES;
}

+ (BOOL) useStoredAccessor
{
  return YES;
}

- (id) handleQueryWithUnboundKey: (NSString*)aKey
{
  [NSException raise: NSGenericException
	      format: @"%@ -- %@ 0x%x: Unable to find value for key \"%@\"", NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];

  return nil;
}

- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey
{
  [NSException raise: NSGenericException
	      format: @"%@ -- %@ 0x%x: Unable set value \"%@\" for key \"%@\"", NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, anObject, aKey];
}

- (id) storedValueForKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      return [self valueForKey: aKey];
    }

  size = [aKey cStringLength];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"storedValueForKey: ... empty key"];
      return NO;	// avoid compiler warnings.
    }
  else
    {
      SEL		sel = 0;
      const char	*type = NULL;
      unsigned		off;
      const char	*name;
      char		buf[size+5];
      char		lo;
      char		hi;

      strcpy(buf, "_get");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;

      name = buf;	// _getKey
      sel = sel_get_any_uid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  buf[3] = '_';
	  buf[4] = lo;
	  name = &buf[3]; // _key
	  sel = sel_get_any_uid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	    }     
	}
      if (sel == 0)
	{
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      // _key
	      if (GSFindInstanceVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4]; // key
		  GSFindInstanceVariable(self, name, &type, &size, &off);
		}
	    }
	  if (type == NULL)
	    {
	      buf[3] = 't';
	      buf[4] = hi;
	      name = &buf[1]; // getKey
	      sel = sel_get_any_uid(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  buf[4] = lo;
		  name = &buf[4];	// key
		  sel = sel_get_any_uid(name);
		  if (sel == 0 || [self respondsToSelector: sel] == NO)
		    {
		      sel = 0;
		    }
		}
	    }
	}
      return GSGetValue(self, aKey, sel, type, size, off);
    }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
  SEL		sel;
  const char	*type;
  unsigned	size;
  int		off;
  NSString	*cap;
  NSString	*name;

  if ([[self class] useStoredAccessor] == NO)
    {
      [self takeValue: anObject forKey: aKey];
      return;
    }

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"takeStoredValue:forKey: ... empty key"];
    }
  cap = [[aKey substringToIndex: 1] uppercaseString];
  if (size > 1)
    {
      cap = [cap stringByAppendingString: [aKey substringFromIndex: 1]];
    }

  name = [NSString stringWithFormat: @"_set%@:", cap];
  type = NULL;
  sel = NSSelectorFromString(name);
  if (sel == 0 || [self respondsToSelector: sel] == NO)
    {
      sel = 0;
      if ([[self class] accessInstanceVariablesDirectly] == YES)
	{
	  name = [NSString stringWithFormat: @"_%@", aKey];
	  if (GSInstanceVariableInfo(self, name, &type, &size, &off) == NO)
	    {
	      name = aKey;
	      GSInstanceVariableInfo(self, name, &type, &size, &off);
	    }
	}
      if (type == NULL)
	{
	  name = [NSString stringWithFormat: @"set%@:", cap];
	  sel = NSSelectorFromString(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	    }
	}
    }

  GSSetValue(self, aKey, anObject, sel, type, size, off);
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  SEL		sel;
  const char	*type;
  unsigned	size;
  int		off;
  NSString	*cap;
  NSString	*name;

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"takeValue:forKey: ... empty key"];
    }
  cap = [[aKey substringToIndex: 1] uppercaseString];
  if (size > 1)
    {
      cap = [cap stringByAppendingString: [aKey substringFromIndex: 1]];
    }

  name = [NSString stringWithFormat: @"set%@:", cap];
  type = NULL;
  sel = NSSelectorFromString(name);
  if (sel == 0 || [self respondsToSelector: sel] == NO)
    {
      name = [NSString stringWithFormat: @"_set%@:", cap];
      sel = NSSelectorFromString(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  sel = 0;
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      name = [NSString stringWithFormat: @"_%@", aKey];
	      if (GSInstanceVariableInfo(self, name, &type, &size, &off) == NO)
		{
		  name = aKey;
		  GSInstanceVariableInfo(self, name, &type, &size, &off);
		}
	    }
	}
    }

  GSSetValue(self, aKey, anObject, sel, type, size, off);
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSArray	*keys = [aKey componentsSeparatedByString: @"."];
  id		obj = self;
  unsigned	count = [keys count];
  unsigned	pos;

  for (pos = 0; pos + 1 < count; pos++)
    {
      obj = [obj valueForKey: [keys objectAtIndex: pos]];
    }
  if (pos < count)
    {
      [obj takeValue: anObject forKey: [keys objectAtIndex: pos]];
    }
}

- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      id	obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeValue: obj forKey: key];
    }
}

- (void) unableToSetNilForKey: (NSString*)aKey
{
  [NSException raise: NSInvalidArgumentException
	      format: @"%@ -- %@ 0x%x: Given nil value to set for key \"%@\"", NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];
}

- (id) valueForKey: (NSString*)aKey
{
  SEL		sel = 0;
  NSString	*cap;
  NSString	*name = nil;
  const char	*type = NULL;
  unsigned	size;
  int		off;

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"valueForKey: ... empty key"];
    }
  cap = [[aKey substringToIndex: 1] uppercaseString];
  if (size > 1)
    {
      cap = [cap stringByAppendingString: [aKey substringFromIndex: 1]];
    }

  name = [@"get" stringByAppendingString: cap];
  sel = NSSelectorFromString(name);
  if (sel == 0 || [self respondsToSelector: sel] == NO)
    {
      name = aKey;
      sel = NSSelectorFromString(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  name = [@"_get" stringByAppendingString: cap];
	  sel = NSSelectorFromString(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      name = [NSString stringWithFormat: @"_%@", aKey];
	      sel = NSSelectorFromString(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  sel = 0;
		}
	    }
	}
    }

  if (sel == 0 && [[self class] accessInstanceVariablesDirectly] == YES)
    {
      name = [NSString stringWithFormat: @"_%@", aKey];
      if (GSInstanceVariableInfo(self, name, &type, &size, &off) == NO)
	{
	  name = aKey;
	  GSInstanceVariableInfo(self, name, &type, &size, &off);
	}
    }

  return GSGetValue(self, aKey, sel, type, size, off);
}

- (id) valueForKeyPath: (NSString*)aKey
{
  NSArray	*keys = [aKey  componentsSeparatedByString: @"."];
  id		obj = self;
  unsigned	count = [keys count];
  unsigned	pos;

  for (pos = 0; pos < count; pos++)
    {
      obj = [obj valueForKey: [keys objectAtIndex: pos]];
    }
  return obj;
}

- (NSDictionary*) valuesForKeys: (NSArray*)keys
{
  NSMutableDictionary	*dict;
  NSNull		*null = [NSNull null];
  unsigned		count = [keys count];
  unsigned		pos;

  dict = [NSMutableDictionary dictionaryWithCapacity: count];
  for (pos = 0; pos < count; pos++)
    {
      NSString	*key = [keys objectAtIndex: pos];
      id 	val = [self valueForKey: key];

      if (val == nil)
	{
	  val = null;
	}
      [dict setObject: val forKey: key];
    }
  return AUTORELEASE([dict copy]);
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
  // Ordering objects by their address is pretty useless, 
  // so subclasses should override this is some useful way.
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

