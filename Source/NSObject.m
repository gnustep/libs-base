/* Implementation of NSObject for GNUStep
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
   */ 

#include <config.h>
#include <base/preface.h>
#include <stdarg.h>
#include <Foundation/NSObject.h>
#include <objc/Protocol.h>
#include <objc/objc-api.h>
#include <Foundation/NSMethodSignature.h>
#include <base/Invocation.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <base/o_map.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSDistantObject.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSNotification.h>
#include <limits.h>

#include <base/fast.x>

extern BOOL __objc_responds_to(id, SEL);

fastCls	_fastCls;	/* Structure to cache classes.	*/
fastImp	_fastImp;	/* Structure to cache methods.	*/

@class	_FastMallocBuffer;
static Class	fastMallocClass;
static unsigned	fastMallocOffset;

@class	NSDataMalloc;
@class	NSMutableDataMalloc;

void	_fastBuildCache()
{
  /*
   *	Cache some classes for quick access later.
   */

  _fastCls._NSArray = [NSArray class];
  _fastCls._NSMutableArray = [NSMutableArray class];
  _fastCls._NSDictionary = [NSDictionary class];
  _fastCls._NSMutableDictionary = [NSMutableDictionary class];
  _fastCls._NSString = [NSString class];
  _fastCls._NSMutableString = [NSMutableString class];
  _fastCls._NSGString = [NSGString class];
  _fastCls._NSGMutableString = [NSGMutableString class];
  _fastCls._NSGCString = [NSGCString class];
  _fastCls._NSGMutableCString = [NSGMutableCString class];
  _fastCls._NXConstantString = [NXConstantString class];
  _fastCls._NSDataMalloc = [NSDataMalloc class];
  _fastCls._NSMutableDataMalloc = [NSMutableDataMalloc class];

  /*
   *	Cache some method implementations for quick access later.
   */

  _fastImp._NSString_hash = (unsigned (*)())[_fastCls._NSString
	    instanceMethodForSelector: @selector(hash)];
  _fastImp._NSString_isEqualToString_ = (BOOL (*)())[_fastCls._NSString
	    instanceMethodForSelector: @selector(isEqualToString:)];
  _fastImp._NSGString_isEqual_ = (BOOL (*)())[_fastCls._NSGString
	    instanceMethodForSelector: @selector(isEqual:)];
  _fastImp._NSGCString_isEqual_ = (BOOL (*)())[_fastCls._NSGCString
	    instanceMethodForSelector: @selector(isEqual:)];
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

/*
 * retain_counts_gate is needed when running multi-threaded for retain/release
 * to work reliably.
 */
static objc_mutex_t retain_counts_gate = NULL;

#if	GS_WITH_GC == 0
#define	REFCNT_LOCAL	1
#define	CACHE_ZONE	1
#endif

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
#ifdef ALIGN
#undef ALIGN
#endif
#define	ALIGN __alignof__(double)

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

/* The maptable of retain counts on objects */
static o_map_t *retain_counts = NULL;

void
NSIncrementExtraRefCount (id anObject)
{
  o_map_node_t *node;
  extern o_map_node_t *o_map_node_for_key(o_map_t *m, const void *k);

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      node = o_map_node_for_key (retain_counts, anObject);
      if (node)
	((int)(node->value))++;
      else
	o_map_at_key_put_value_known_absent (retain_counts, anObject, (void*)1);
      objc_mutex_unlock(retain_counts_gate);
    }
  else
    {
      node = o_map_node_for_key (retain_counts, anObject);
      if (node)
	((int)(node->value))++;
      else
	o_map_at_key_put_value_known_absent (retain_counts, anObject, (void*)1);
    }
}

BOOL
NSDecrementExtraRefCountWasZero (id anObject)
{
  o_map_node_t *node;
  extern o_map_node_t *o_map_node_for_key (o_map_t *m, const void *k);
  extern void o_map_remove_node (o_map_node_t *node);

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      node = o_map_node_for_key (retain_counts, anObject);
      if (!node)
	{
	  objc_mutex_unlock(retain_counts_gate);
	  return YES;
	}
      NSAssert((int)(node->value) > 0, NSInternalInconsistencyException);
      if (!--((int)(node->value)))
	{
	  o_map_remove_node (node);
	}
      objc_mutex_unlock(retain_counts_gate);
    }
  else
    {
      node = o_map_node_for_key (retain_counts, anObject);
      if (!node)
	{
	  return YES;
	}
      NSAssert((int)(node->value) > 0, NSInternalInconsistencyException);
      if (!--((int)(node->value)))
	{
	  o_map_remove_node (node);
	}
    }
  return NO;
}

unsigned
NSExtraRefCount (id anObject)
{
  unsigned ret;

  if (retain_counts_gate != 0)
    {
      objc_mutex_lock(retain_counts_gate);
      ret = (unsigned) o_map_value_at_key(retain_counts, anObject);
      if (ret == (unsigned)o_map_not_a_key_marker(retain_counts)
	|| ret == (unsigned)o_map_not_a_value_marker(retain_counts))
	{
	  ret = 0;
	}
      objc_mutex_unlock(retain_counts_gate);
    }
  else
    {
      ret = (unsigned) o_map_value_at_key(retain_counts, anObject);
      if (ret == (unsigned)o_map_not_a_key_marker(retain_counts)
	|| ret == (unsigned)o_map_not_a_value_marker(retain_counts))
	{
	  ret = 0;
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
fastZone(NSObject *object)
{
  return 0;
}

static void
GSFinalize(void* object, void* data)
{
  [(id)object gcFinalize];
#ifndef	NDEBUG
  GSDebugAllocationRemove(((id)object)->class_pointer);
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
	  NSLog(@"No garbage collection information for '%s'", aClass->name);
	}
      else
	{
	  new = GC_CALLOC_EXPLICTLY_TYPED(1, size, gc_type);
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
	  GSDebugAllocationAdd(aClass);
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
fastZone(NSObject *object)
{
  if (fastClass(object) == _fastCls._NXConstantString)
    return NSDefaultMallocZone();
  return ((obj)object)[-1].zone;
}

#else	/* defined(CACHE_ZONE)	*/

inline NSZone *
fastZone(NSObject *object)
{
  if (fastClass(object) == _fastCls._NXConstantString)
    return NSDefaultMallocZone();
  return NSZoneFromPointer(&((obj)object)[-1]);
}

#endif	/* defined(CACHE_ZONE)	*/

inline NSObject *
NSAllocateObject (Class aClass, unsigned extraBytes, NSZone *zone)
{
#ifndef	NDEBUG
  extern void GSDebugAllocationAdd(Class);
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
      GSDebugAllocationAdd(aClass);
#endif
    }
  return new;
}

inline void
NSDeallocateObject(NSObject *anObject)
{
#ifndef	NDEBUG
  extern void GSDebugAllocationRemove(Class);
#endif
  if ((anObject!=nil) && CLS_ISCLASS(((id)anObject)->class_pointer))
    {
      obj	o = &((obj)anObject)[-1];
      NSZone	*z = fastZone(anObject);

#ifndef	NDEBUG
      GSDebugAllocationRemove(((id)anObject)->class_pointer);
#endif
      ((id)anObject)->class_pointer = (void*) 0xdeadface;
      NSZoneFree(z, o);
    }
  return;
}

#else

inline NSZone *
fastZone(NSObject *object)
{
    if (fastClass(object) == _fastCls._NXConstantString)
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
      GSDebugAllocationAdd(aClass);
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
      GSDebugAllocationRemove(((id)anObject)->class_pointer);
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
	  || fastZone(anObject) == requestedZone);
#endif
}




/* The Class responsible for handling autorelease's.  This does not
   need mutex protection, since it is simply a pointer that gets read
   and set. */
static id autorelease_class = nil;
static SEL autorelease_sel = @selector(addObject:);
static IMP autorelease_imp = 0;

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

+ (void) initialize
{
  if (self == [NSObject class])
    {
#ifdef __FreeBSD__
      // Manipulate the FPU to add the exception mask. (Fixes SIGFPE
      // problems on *BSD)

      volatile short cw;

      __asm__ volatile ("fstcw (%0)" : : "g" (&cw));
      cw |= 1; /* Mask 'invalid' exception */
      __asm__ volatile ("fldcw (%0)" : : "g" (&cw));
#endif

      // Create the global lock
      gnustep_global_lock = [[NSRecursiveLock alloc] init];
      autorelease_class = [NSAutoreleasePool class];
      autorelease_imp = [autorelease_class methodForSelector: autorelease_sel];
      fastMallocClass = [_FastMallocBuffer class];
#if	GS_WITH_GC == 0
#if	!defined(REFCNT_LOCAL)
      retain_counts = o_map_with_callbacks (o_callbacks_for_non_owned_void_p,
					    o_callbacks_for_int);
#endif
      fastMallocOffset = fastMallocClass->instance_size % ALIGN;
#else
      fastMallocOffset = 0;
#endif
      _fastBuildCache();
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

static BOOL deallocNotifications = NO;

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

- free
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
  int i;
  struct objc_protocol_list* proto_list;

  for (proto_list = ((struct objc_class*)self)->class_pointer->protocols;
       proto_list; proto_list = proto_list->next)
    {
      for (i=0; i < proto_list->count; i++)
      {
	/* xxx We should add conformsToProtocol to Protocol class. */
        if ([proto_list->list[i] conformsTo: aProtocol])
          return YES;
      }
    }

  if ([self superclass])
    return [[self superclass] conformsToProtocol: aProtocol];
  else
    return NO;
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
   *	If 'self' is an instance, fastClass() will get the class,
   *	and get_imp() will get the instance method.
   *	If 'self' is a class, fastClass() will get the meta-class,
   *	and get_imp() will get the class method.
   */
  return get_imp(fastClass(self), aSelector);
}

+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector
{
    struct objc_method* mth = class_get_instance_method(self, aSelector);
    return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
		: nil;
}
  
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
    struct objc_method* mth =
	    (object_is_instance(self) ?
		  class_get_instance_method(self->isa, aSelector)
		: class_get_class_method(self->isa, aSelector));
    return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
		: nil;
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

- (void) descriptionTo: (id<GNUDescriptionDestination>)output
{
  [output appendString: [self description]];
}

- (void) descriptionWithLocale: (NSDictionary*)aLocale
			    to: (id<GNUDescriptionDestination>)output
{
  [output appendString: [(id)self descriptionWithLocale: aLocale]];
}

- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output
{
  [output appendString: [(id)self descriptionWithLocale: aLocale indent: level]];
}

+ (void) poseAsClass: (Class)aClassObject
{
  class_pose_as(self, aClassObject);
  /*
   *	We may have replaced a class in the cache, or may have replaced one
   *	which had cached methods, so we must rebuild the cache.
   */
  _fastBuildCache();
}

- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  [NSException raise: NSInvalidArgumentException
	       format: @"%s does not recognize %s",
	       object_get_class_name(self), sel_get_name(aSelector)];
}

- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame
{
  NSInvocation *inv;

  inv = [[[NSInvocation alloc] initWithArgframe: argFrame
				       selector: aSel] autorelease];
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
    if ([aCoder isBycopy]) {
	return self;
    }
    else if ([self isKindOfClass: [NSDistantObject class]]) {
	return self;
    }
    else {
	return [NSDistantObject proxyWithLocal: self
				    connection: [aCoder connection]];
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

+ autorelease
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

- (BOOL) isEqual: anObject
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
  Class class;

  for (class = self->isa; 
       class != Nil;
       class = class_get_super_class (class))
    {
      if (class == aClass)
	return YES;
    }
  return NO;
}

+ (BOOL) isMemberOfClass: (Class)aClass
{
  return self == aClass;
}

- (BOOL) isMemberOfClass: (Class)aClass
{
  return self->isa==aClass;
}

- (BOOL) isProxy
{
  return NO;
}

- performSelector: (SEL)aSelector
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
    
  msg = get_imp(fastClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
  return (*msg)(self, aSelector);
}

- performSelector: (SEL)aSelector withObject: anObject
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
    
  msg = get_imp(fastClass(self), aSelector);
  if (!msg)
    {
      [NSException raise: NSGenericException
		  format: @"invalid selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }

  return (*msg)(self, aSelector, anObject);
}

- performSelector: (SEL)aSelector withObject: object1 withObject: object2
{
  IMP msg;

  if (aSelector == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nul selector passed to %s", sel_get_name(_cmd)];
      return nil;
    }
  
  msg = get_imp(fastClass(self), aSelector);
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
#if 0
  if (fastIsInstance(self))
    return (class_get_instance_method(fastClass(self), aSelector)!=METHOD_NULL);
  else
    return (class_get_class_method(fastClass(self), aSelector)!=METHOD_NULL);
#else
  return __objc_responds_to(self, aSelector);
#endif
}

- retain
{
#if	GS_WITH_GC == 0
  NSIncrementExtraRefCount(self);
#endif
  return self;
}

+ retain
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

- self
{
  return self;
}

- (NSZone *)zone
{
    return fastZone(self);
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  return;
}

- initWithCoder: (NSCoder*)aDecoder
{
  return self;
}

+ (int)version
{
  return class_get_version(self);
}

+ setVersion:(int)aVersion
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

- error:(const char *)aString, ...
{
#define FMT "error: %s (%s)\n%s\n"
  char fmt[(strlen((char*)FMT)+strlen((char*)object_get_class_name(self))
            +((aString!=NULL)?strlen((char*)aString):0)+8)];
  va_list ap;

  sprintf(fmt, FMT, object_get_class_name(self),
                    object_is_instance(self)?"instance":"class",
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

- (BOOL)isKindOf:(Class)aClassObject
{
  return [self isKindOfClass:aClassObject];
}

- (BOOL)isMemberOf:(Class)aClassObject
{
  return [self isMemberOfClass:aClassObject];
}

+ (BOOL)instancesRespondTo:(SEL)aSel
{
  return [self instancesRespondToSelector:aSel];
}

- (BOOL)respondsTo:(SEL)aSel
{
  return [self respondsToSelector:aSel];
}

+ (BOOL) conformsTo: (Protocol*)aProtocol
{
  return [self conformsToProtocol:aProtocol];
}

- (BOOL) conformsTo: (Protocol*)aProtocol
{
  return [self conformsToProtocol:aProtocol];
}

- (retval_t)performv:(SEL)aSel :(arglist_t)argFrame
{
  return objc_msg_sendv(self, aSel, argFrame);
}

+ (IMP) instanceMethodFor:(SEL)aSel
{
  return [self instanceMethodForSelector:aSel];
}

+ (NSMethodSignature*)instanceMethodSignatureForSelector:(SEL)aSelector
{
    struct objc_method* mth = class_get_instance_method(self, aSelector);

    return mth ? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
		: nil;
}

- (IMP) methodFor:(SEL)aSel
{
  return [self methodForSelector:aSel];
}

+ poseAs:(Class)aClassObject
{
  [self poseAsClass:aClassObject];
  return self;
}

- notImplemented:(SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"method %s not implemented in %s", sel_get_name(aSel), object_get_class_name(self)];
  return nil;
}

- doesNotRecognize:(SEL)aSel
{
  [NSException raise: NSGenericException
	       format: @"%s does not recognize %s",
	       object_get_class_name(self), sel_get_name(aSel)];
  return nil;
}

- perform: (SEL)sel with: anObject
{
  return [self performSelector:sel withObject:anObject];
}

- perform: (SEL)sel with: anObject with: anotherObject
{
  return [self performSelector:sel withObject:anObject 
	       withObject:anotherObject];
}

@end


@implementation NSObject (GNUstep)

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

- (int)compare:anotherObject;
{
  if ([self isEqual:anotherObject])
    return 0;
  // Ordering objects by their address is pretty useless, 
  // so subclasses should override this is some useful way.
  else if (self > anotherObject)
    return 1;
  else 
    return -1;
}

- (BOOL)isMetaClass
{
  return NO;
}

- (BOOL)isClass
{
  return object_is_class(self);
}

- (BOOL)isInstance
{
  return object_is_instance(self);
}

- (BOOL)isMemberOfClassNamed:(const char *)aClassName
{
  return ((aClassName!=NULL)
          &&!strcmp(class_get_class_name(self->isa), aClassName));
}

+ (struct objc_method_description *)descriptionForInstanceMethod:(SEL)aSel
{
  return ((struct objc_method_description *)
           class_get_instance_method(self, aSel));
}

- (struct objc_method_description *)descriptionForMethod:(SEL)aSel
{
  return ((struct objc_method_description *)
           (object_is_instance(self)
            ?class_get_instance_method(self->isa, aSel)
            :class_get_class_method(self->isa, aSel)));
}

- (Class)transmuteClassTo:(Class)aClassObject
{
  if (object_is_instance(self))
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

- subclassResponsibility:(SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"subclass %s should override %s", object_get_class_name(self), sel_get_name(aSel)];
  return nil;
}

- shouldNotImplement:(SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"%s should not implement %s", 
    object_get_class_name(self), sel_get_name(aSel)];
  return nil;
}

+ (int)streamVersion: (TypedStream*)aStream
{
  if (aStream->mode == OBJC_READONLY)
    return objc_get_stream_class_version (aStream, self);
  else
    return class_get_version (self);
}

// These are used to write or read the instance variables 
// declared in this particular part of the object.  Subclasses
// should extend these, by calling [super read/write: aStream]
// before doing their own archiving.  These methods are private, in
// the sense that they should only be called from subclasses.

- read: (TypedStream*)aStream
{
  // [super read: aStream];  
  return self;
}

- write: (TypedStream*)aStream
{
  // [super write: aStream];
  return self;
}

- awake
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

