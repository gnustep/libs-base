/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

/*
 *	Check consistency of definitions for system compatibility.
 */
#if	defined(STRICT_OPENSTEP)
#define	NO_GNUSTEP	1
#elif	defined(STRICT_MACOS_X)
#define	NO_GNUSTEP	1
#else
#undef	NO_GNUSTEP
#endif

#include <Foundation/NSObjCRuntime.h>
#include <base/preface.h>
#include <GSConfig.h>
#include <objc/objc.h>
#include <objc/Protocol.h>
#include <Foundation/NSZone.h>

@class NSArchiver;
@class NSArray;
@class NSCoder;
@class NSDictionary;
@class NSPortCoder;
@class NSMethodSignature;
@class NSMutableString;
@class NSRecursiveLock;
@class NSString;
@class NSInvocation;
@class Protocol;

@protocol NSObject
- (Class) class;
- (Class) superclass;
- (BOOL) isEqual: anObject;
- (BOOL) isKindOfClass: (Class)aClass;
- (BOOL) isMemberOfClass: (Class)aClass;
- (BOOL) isProxy;
- (unsigned) hash;
- self;
- performSelector: (SEL)aSelector;
- performSelector: (SEL)aSelector withObject: anObject;
- performSelector: (SEL)aSelector withObject: object1 withObject: object2;
- (BOOL) respondsToSelector: (SEL)aSelector;
- (BOOL) conformsToProtocol: (Protocol *)aProtocol;
- retain;
- autorelease;
- (oneway void) release;
- (unsigned) retainCount;
- (NSZone*) zone;
- (NSString*) description;
@end

@protocol NSCopying
- (id) copyWithZone: (NSZone *)zone;
@end

@protocol NSMutableCopying
- (id) mutableCopyWithZone: (NSZone *)zone;
@end

@protocol NSCoding
- (void) encodeWithCoder: (NSCoder*)aCoder;
- (id) initWithCoder: (NSCoder*)aDecoder;
@end


@interface NSObject <NSObject>
{
  Class isa;
}

#if	GS_WITH_GC
+ (BOOL) requiresTypedMemory;
#endif
+ (void) initialize;
+ (id) allocWithZone: (NSZone*)z;
+ (id) alloc;
+ (id) new;
- (id) copy;
- (void) dealloc;
- (id) init;
- (id) mutableCopy;

+ (Class) class;
+ (Class) superclass;

+ (BOOL) instancesRespondToSelector: (SEL)aSelector;

+ (IMP) instanceMethodForSelector: (SEL)aSelector;
- (IMP) methodForSelector: (SEL)aSelector;
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;

- (NSString*) description;
+ (NSString*) description;

+ (void) poseAsClass: (Class)aClass;

- (void) doesNotRecognizeSelector: (SEL)aSelector;

- (void) forwardInvocation: (NSInvocation*)anInvocation;

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) classForArchiver;
- (Class) classForCoder;
- (Class) classForPortCoder;
- (id) replacementObjectForArchiver: (NSArchiver*)anEncoder;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;
- (id) replacementObjectForPortCoder: (NSPortCoder*)anEncoder;


+ (id) setVersion: (int)aVersion;
+ (int) version;

@end

GS_EXPORT NSObject *
NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone);
GS_EXPORT void
NSDeallocateObject(NSObject *anObject);
GS_EXPORT NSObject *
NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone);

GS_EXPORT BOOL
NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone);
GS_EXPORT unsigned
NSExtraRefCount(id anObject);
GS_EXPORT void
NSIncrementExtraRefCount(id anObject);
GS_EXPORT BOOL
NSDecrementExtraRefCountWasZero(id anObject);

typedef enum _NSComparisonResult 
{
  NSOrderedAscending = -1, NSOrderedSame, NSOrderedDescending
} 
NSComparisonResult;

enum {NSNotFound = 0x7fffffff};

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
- notImplemented:(SEL)aSel;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

#ifndef	NO_GNUSTEP
/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

/*
 * The GNUDescriptionDestination protocol declares methods used to
 * append a property-list description string to some output destination
 * so that property-lists can be converted to strings in a stream avoiding
 * the use of ridiculous amounts of memory for deeply nested data structures.
 */
@protocol       GNUDescriptionDestination
- (void) appendFormat: (NSString*)str, ...;
- (void) appendString: (NSString*)str;
@end

@interface NSObject (GNU)
- (int) compare: (id)anObject;
/*
 * Default description methods -
 * [descriptionWithLocale:] calls [description]
 * [descriptionWithLocale:indent:] calls [descriptionWithLocale:]
 * [descriptionWithLocale:indent:to:] calls [descriptionWithLocale:indent:]
 * So - to have working descriptions, it is only necessary to implement the
 * [description] method, and to have efficient property-list generation, it
 * is necessary to override [descriptionWithLocale:indent:to:]
 */
- (NSString*) descriptionWithLocale: (NSDictionary*)aLocale;
+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale;
- (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
			     indent: (unsigned)level;
+ (NSString*) descriptionWithLocale: (NSDictionary*)aLocale
			     indent: (unsigned)level;
- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output;
+ (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output;
- (Class) transmuteClassTo: (Class)aClassObject;
- subclassResponsibility: (SEL)aSel;
- shouldNotImplement: (SEL)aSel;
+ (Class) autoreleaseClass;
+ (void) setAutoreleaseClass: (Class)aClass;
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;
/*
 * If the 'deallocActivationsActive' flag is set, the _dealloc method will be
 * called during the final release of an object, and the dealloc method will
 * then be called only if _dealloc returns YES.
 * You can override the _dealloc implementation to perform some action before
 * an object is deallocated (or disable deallocation by returning NO).
 * The default implementation simply returns YES.
 */
- (BOOL) deallocNotificationsActive;
- (void) setDeallocNotificationsActive: (BOOL)flag;
- (BOOL) _dealloc;
@end

/*
 *	Protocol for garbage collection finalization - same as libFoundation
 *	for compatibility.
 */
@protocol       GCFinalization
- (void) gcFinalize;
@end

#endif

#include <Foundation/NSDate.h>
@interface NSObject (TimedPerformers)
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj
					selector: (SEL)s
					  object: (id)arg;
- (void) performSelector: (SEL)s
	      withObject: (id)arg
	      afterDelay: (NSTimeInterval)seconds;
- (void) performSelector: (SEL)s
	      withObject: (id)arg
	      afterDelay: (NSTimeInterval)seconds
		 inModes: (NSArray*)modes;
@end

/*
 *	RETAIN(), RELEASE(), and AUTORELEASE() are placeholders for the
 *	future day when we have garbage collecting.
 */
#ifndef	GS_WITH_GC
#define	GS_WITH_GC	0
#endif
#if	GS_WITH_GC

#ifndef	RETAIN
#define	RETAIN(object)		((id)object)
#endif
#ifndef	RELEASE
#define	RELEASE(object)		
#endif
#ifndef	AUTORELEASE
#define	AUTORELEASE(object)	((id)object)
#endif

#ifndef	TEST_RETAIN
#define	TEST_RETAIN(object)	((id)object)
#endif
#ifndef	TEST_RELEASE
#define	TEST_RELEASE(object)
#endif
#ifndef	TEST_AUTORELEASE
#define	TEST_AUTORELEASE(object)	((id)object)
#endif

#ifndef	ASSIGN
#define	ASSIGN(object,value)	(object = value)
#endif
#ifndef	ASSIGNCOPY
#define	ASSIGNCOPY(object,value)	(object = [value copy])
#endif
#ifndef	DESTROY
#define	DESTROY(object) 	(object = nil)
#endif

#ifndef	CREATE_AUTORELEASE_POOL
#define	CREATE_AUTORELEASE_POOL(X)	
#endif

#ifndef RECREATE_AUTORELEASE_POOL
#define RECREATE_AUTORELEASE_POOL(X)
#endif

#define	IF_NO_GC(X)	

#else

/*
 *	Basic retain, release, and autorelease operations.
 */
#ifndef	RETAIN
#define	RETAIN(object)		[object retain]
#endif
#ifndef	RELEASE
#define	RELEASE(object)		[object release]
#endif
#ifndef	AUTORELEASE
#define	AUTORELEASE(object)	[object autorelease]
#endif

/*
 *	Tested retain, release, and autorelease operations - only invoke the
 *	objective-c method if the receiver is not nil.
 */
#ifndef	TEST_RETAIN
#define	TEST_RETAIN(object)	(object != nil ? [object retain] : nil)
#endif
#ifndef	TEST_RELEASE
#define	TEST_RELEASE(object)	({ if (object) [object release]; })
#endif
#ifndef	TEST_AUTORELEASE
#define	TEST_AUTORELEASE(object)	({ if (object) [object autorelease]; })
#endif

/*
 *	ASSIGN(object,value) assigns the value to the object with
 *	appropriate retain and release operations.
 */
#ifndef	ASSIGN
#define	ASSIGN(object,value)	({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    object = __value; \
    if (__value != nil) \
      { \
	[__value retain]; \
      } \
    if (__object != nil) \
      { \
	[__object release]; \
      } \
  } \
})
#endif

/*
 *	ASSIGNCOPY(object,value) assignes a copy of the value to the object with
 *	and release operations.
 */
#ifndef	ASSIGNCOPY
#define	ASSIGNCOPY(object,value)	({\
id __value = (value); \
if (__value != (id)object) \
  { \
    if (__value) \
      { \
	__value = [__value copy]; \
      } \
    if (object) \
      { \
	[(id)object release]; \
      } \
    (id)object = __value; \
  } \
})
#endif

/*
 *	DESTROY() is a release operation which also sets the variable to be
 *	a nil pointer for tidyness - we can't accidentally use a DESTROYED
 *	object later.  It also makes sure to set the variable to nil before
 *	releasing the object - to avoid side-effects of the release trying
 *	to reference the object being released through the variable.
 */
#ifndef	DESTROY
#define	DESTROY(object) 	({ \
  if (object) \
    { \
      id __o = object; \
      object = nil; \
      [__o release]; \
    } \
})
#endif

#ifndef	CREATE_AUTORELEASE_POOL
#define	CREATE_AUTORELEASE_POOL(X)	\
  NSAutoreleasePool *(X) = [NSAutoreleasePool new]
#endif

/*
 * Similar, but allows reuse of variables. Be sure to use DESTROY()
 * so the object variable stays nil.
 */

#ifndef RECREATE_AUTORELEASE_POOL
#define RECREATE_AUTORELEASE_POOL(X)  \
  if (X == nil) \
    (X) = [NSAutoreleasePool new]
#endif

#define	IF_NO_GC(X)	X

#endif

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
