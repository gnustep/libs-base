/**Interface for NSObject for GNUStep
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

/**
 * The NSObject protocol describes a minimal set of methods that all
 * objects are expected to support.  You should be able to send any
 * of the messages listed in this protocol to an object, and be safe
 * in assuming that the receiver can handle it.
 */
@protocol NSObject
- (Class) class;			/** See [NSObject-class] */
- (Class) superclass;			/** See [NSObject-superclass] */
- (BOOL) isEqual: (id)anObject;		/** See [NSObject-isEqual:] */
- (BOOL) isKindOfClass: (Class)aClass;	/** See [NSObject-isKindOfClass:] */
- (BOOL) isMemberOfClass: (Class)aClass;/** See [NSObject-isMemberOfClass:] */
- (BOOL) isProxy;			/** See [NSObject-isProxy] */
- (unsigned) hash;			/** See [NSObject-hash] */
- (id) self;				/** See [NSObject-self] */
- (id) performSelector: (SEL)aSelector;	/** See [NSObject-performSelector:] */
/** See [NSObject-performSelector:withObject:] */
- (id) performSelector: (SEL)aSelector
	    withObject: (id)anObject;
/** See [NSObject-performSelector:withObject:withObject:] */
- (id) performSelector: (SEL)aSelector
	    withObject: (id)object1
	    withObject: (id)object2;
/** See [NSObject-respondsToSelector:] */
- (BOOL) respondsToSelector: (SEL)aSelector;
/** See [NSObject-conformsToProtocol:] */
- (BOOL) conformsToProtocol: (Protocol*)aProtocol;
- (id) retain;				/** See [NSObject-retain] */
- (id) autorelease			/** See [NSObject-autorelease] */;
- (oneway void) release;		/** See [NSObject-release] */
- (unsigned) retainCount;		/** See [NSObject-retainCount] */
- (NSZone*) zone;			/** See [NSObject-zone] */
- (NSString*) description;		/** See [NSObject-description] */
@end

/**
 * This protocol must be adopted by any class wishing to support copying.
 */
@protocol NSCopying
- (id) copyWithZone: (NSZone*)zone;
@end

/**
 * This protocol must be adopted by any class wishing to support
 * mutable copying.
 */
@protocol NSMutableCopying
- (id) mutableCopyWithZone: (NSZone*)zone;
@end

/**
 * This protocol must be adopted by any class wishing to support
 * saving and restoring instances to an archive, or copying them
 * to remote processes via the Distributed Objects mechanism.
 */
@protocol NSCoding
- (void) encodeWithCoder: (NSCoder*)aCoder;
- (id) initWithCoder: (NSCoder*)aDecoder;
@end


@interface NSObject <NSObject>
{
  Class isa;
}

#ifndef	NO_GNUSTEP
#if	GS_WITH_GC
+ (BOOL) requiresTypedMemory;
#endif
#endif

#ifndef	STRICT_OPENSTEP
- (NSString*) className;
#endif

+ (id) allocWithZone: (NSZone*)z;
+ (id) alloc;
+ (Class) class;
+ (NSString*) description;
+ (void) initialize;
+ (IMP) instanceMethodForSelector: (SEL)aSelector;
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector;
+ (BOOL) instancesRespondToSelector: (SEL)aSelector;
+ (BOOL) isSubclassOfClass: (Class)aClass;
+ (id) new;
+ (void) poseAsClass: (Class)aClassObject;
+ (id) setVersion: (int)aVersion;
+ (Class) superclass;
+ (int) version;

- (id) autorelease;
- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) class;
- (Class) classForArchiver;
- (Class) classForCoder;
- (Class) classForPortCoder;
- (BOOL) conformsToProtocol: (Protocol*)aProtocol;
- (id) copy;
- (void) dealloc;
- (NSString*) description;
- (void) doesNotRecognizeSelector: (SEL)aSelector;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (unsigned) hash;
- (id) init;
- (BOOL) isEqual: anObject;
- (BOOL) isKindOfClass: (Class)aClass;
- (BOOL) isMemberOfClass: (Class)aClass;
- (BOOL) isProxy;
- (IMP) methodForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;
- (id) mutableCopy;
- (id) performSelector: (SEL)aSelector;
- (id) performSelector: (SEL)aSelector
	    withObject: (id)anObject;
- (id) performSelector: (SEL)aSelector
	    withObject: (id)object1
	    withObject: (id)object2;
- (void) release;
- (id) replacementObjectForArchiver: (NSArchiver*)anArchiver;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;
- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder;
- (BOOL) respondsToSelector: (SEL)aSelector;
- (id) retain;
- (unsigned) retainCount;
- (id) self;
- (Class) superclass;
- (NSZone*) zone;
@end

/**
 * Used to allocate memory to hold an object, and initialise the
 * class of the object to be aClass etc.  The allocated memory will
 * be extraBytes larger than the space actually needed to hold the
 * instance variables of the object.<br />
 * This function is used by the [NSObject+allocWithZone:] mnethod.
 */
GS_EXPORT NSObject *
NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone);

/**
 * Used to release the memory used by an object.<br />
 * This function is used by the [NSObject-dealloc] mnethod.
 */
GS_EXPORT void
NSDeallocateObject(NSObject *anObject);

/**
 * Used to copy anObject.  This makes a bitwise copy of anObject to
 * memory allocated from zone.  The allocated memory will be extraBytes
 * longer than that necessary to actually store the instance variables
 * of the copied object.<br />
 * This is used by the NSObject implementation of the
 * [(NSCopying)-copyWithZone:] method.
 */
GS_EXPORT NSObject *
NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone);

/**
 * Returns a flag to indicate whether anObject should be retained or
 * copied in order to make a copy in the specified zone.<br />
 * Basically, this tests to see if anObject was allocated from
 * requestedZone and returns YES if it was.
 */
GS_EXPORT BOOL
NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone);

GS_EXPORT BOOL
NSDecrementExtraRefCountWasZero(id anObject);

GS_EXPORT unsigned
NSExtraRefCount(id anObject);

GS_EXPORT void
NSIncrementExtraRefCount(id anObject);

typedef enum _NSComparisonResult 
{
  NSOrderedAscending = -1, NSOrderedSame, NSOrderedDescending
} 
NSComparisonResult;

enum {NSNotFound = 0x7fffffff};

#ifndef	NO_GNUSTEP

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
- notImplemented:(SEL)aSel;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

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
- (NSComparisonResult) compare: (id)anObject;
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
- (id) makeImmutableCopyOnFail: (BOOL)force;
- (Class) transmuteClassTo: (Class)aClassObject;
- (id) subclassResponsibility: (SEL)aSel;
- (id) shouldNotImplement: (SEL)aSel;
+ (Class) autoreleaseClass;
+ (void) setAutoreleaseClass: (Class)aClass;
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- (id) read: (TypedStream*)aStream;
- (id) write: (TypedStream*)aStream;
@end

#endif

/*
 *	Protocol for garbage collection finalization - same as libFoundation
 *	for compatibility.
 */
@protocol       GCFinalization
- (void) gcFinalize;
@end

#include <Foundation/NSDate.h>
@interface NSObject (TimedPerformers)
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj;
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
#define	TEST_RETAIN(object)	({\
id __object = (id)(object); (__object != nil) ? [__object retain] : nil; })
#endif
#ifndef	TEST_RELEASE
#define	TEST_RELEASE(object)	({\
id __object = (id)(object); if (__object != nil) [__object release]; })
#endif
#ifndef	TEST_AUTORELEASE
#define	TEST_AUTORELEASE(object)	({\
id __object = (id)(object); (__object != nil) ? [__object autorelease] : nil; })
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
    if (__value != nil) \
      { \
	[__value retain]; \
      } \
    object = __value; \
    if (__object != nil) \
      { \
	[__object release]; \
      } \
  } \
})
#endif

/*
 *	ASSIGNCOPY(object,value) assigns a copy of the value to the object
 *	with release of the original.
 */
#ifndef	ASSIGNCOPY
#define	ASSIGNCOPY(object,value)	({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    if (__value != nil) \
      { \
	__value = [__value copy]; \
      } \
    (id)object = __value; \
    if (__object != nil) \
      { \
	[__object release]; \
      } \
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
