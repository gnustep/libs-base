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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.

   AutogsdocSource: NSObject.m
   AutogsdocSource: Additions/GSCategories.m
   */ 

#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

#if	defined(__cplusplus)
extern "C" {
#endif

/*
 *	Check consistency of definitions for system compatibility.
 */
#if	defined(STRICT_OPENSTEP)
#define GS_OPENSTEP_V	010000
#define	NO_GNUSTEP	1
#elif	defined(STRICT_MACOS_X)
#define GS_OPENSTEP_V	100000
#define	NO_GNUSTEP	1
#else
#undef	NO_GNUSTEP
#endif

/*
 * NB. The version values below must be integers ... by convention these are
 * made up of two digits each for major, minor and subminor version numbers
 * (ie each is in the range 00 to 99 though a leading zero in the major
 * number is not permitted).
 * So for a MacOS-X 10.3.9 release the version number would be 100309
 *
 * You may define GS_GNUSTEP_V or GS_OPENSTEP_V to ensure that your
 * program only 'sees' the specified varsion of the API.
 */

/**
 * <p>Macro to check a defined GNUstep version number (GS_GNUSTEP_V) against
 * the supplied arguments.  Returns true if no GNUstep version is specified,
 * or if ADD &lt;= version &lt; REM, where ADD is the version
 * number at which a feature guarded by the macro was introduced and
 * REM is the version number at which it was removed.
 * </p>
 * <p>The version number arguments are six digit integers where the first
 * two digits are the major version number, the second two are the minor
 * version number and the last two are the subminor number (all left padded
 * with a zero where necessary).  However, for convenience you can also
 * use any of several predefined constants ... 
 * <ref type="macro" id="GS_API_NONE">GS_API_NONE</ref>,
 * <ref type="macro" id="GS_API_LATEST">GS_API_LATEST</ref>,
 * <ref type="macro" id="GS_API_OSSPEC">GS_API_OSSPEC</ref>,
 * <ref type="macro" id="GS_API_OPENSTEP">GS_API_OPENSTEP</ref>,
 * <ref type="macro" id="GS_API_MACOSX">GS_API_MACOSX</ref>
 * </p>
 * <p>Also see <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * </p>
 * <p>NB. If you are changing the API (eg adding a new feature) you need
 * to control the visibility io the new header file code using<br />
 * <code>#if GS_API_VERSION(ADD,GS_API_LATEST)</code><br />
 * where <code>ADD</code> is the version number of the next minor
 * release after the most recent one.<br />
 * As a general principle you should <em>not</em> change the API with
 * changing subminor version numbers ... as that tends to confuse
 * people (though Apple has sometimes done it).
 * </p>
 */
#define	GS_API_VERSION(ADD,REM) \
  (!defined(GS_GNUSTEP_V) || (GS_GNUSTEP_V >= ADD && GS_GNUSTEP_V < REM))

/**
 * <p>Macro to check a defined OpenStep/OPENSTEP/MacOS-X version against the
 * supplied arguments.  Returns true if no version is specified, or if
 * ADD &lt;= version &lt; REM, where ADD is the version
 * number at which a feature guarded by the macro was introduced and
 * REM is the version number at which it was removed.
 * </p>
 * <p>The version number arguments are six digit integers where the first
 * two digits are the major version number, the second two are the minor
 * version number and the last two are the subminor number (all left padded
 * with a zero where necessary).  However, for convenience you can also
 * use any of several predefined constants ... 
 * <ref type="macro" id="GS_API_NONE">GS_API_NONE</ref>,
 * <ref type="macro" id="GS_API_LATEST">GS_API_LATEST</ref>,
 * <ref type="macro" id="GS_API_OSSPEC">GS_API_OSSPEC</ref>,
 * <ref type="macro" id="GS_API_OPENSTEP">GS_API_OPENSTEP</ref>,
 * <ref type="macro" id="GS_API_MACOSX">GS_API_MACOSX</ref>
 * </p>
 * <p>Also see <ref type="macro" id="GS_API_VERSION">GS_API_VERSION</ref>
 * </p>
 */
#define	OS_API_VERSION(ADD,REM) \
  (!defined(GS_OPENSTEP_V) || (GS_OPENSTEP_V >= ADD && GS_OPENSTEP_V < REM))

/**
 * A constant which is the lowest possible version number (0) so that
 * when used as the removal version (second argument of the GS_API_VERSION
 * or OS_API_VERSION macro) represents a feature which is not present in
 * any version.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_NONE, GS_API_NONE)<br />
 * denotes  code not present in OpenStep/OPENSTEP/MacOS-X
 */
#define	GS_API_NONE	     0

/**
 * A constant to represent a feature which is still present in the latest
 * version.  This is the highest possible version number.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_MACOSX, GS_API_LATEST)<br />
 * denotes code present from the initial MacOS-X version onwards.
 */
#define	GS_API_LATEST	999999

/**
 * The version number of the initial OpenStep specification.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_OSSPEC, GS_API_LATEST)<br />
 * denotes code present from the OpenStep specification onwards.
 */
#define	GS_API_OSSPEC	 10000

/**
 * The version number of the first OPENSTEP implementation.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_OPENSTEP, GS_API_LATEST)<br />
 * denotes code present from the initial OPENSTEP version onwards.
 */
#define	GS_API_OPENSTEP	 40000

/**
 * The version number of the first MacOS-X implementation.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_MACOSX, GS_API_LATEST)<br />
 * denotes code present from the initial MacOS-X version onwards.
 */
#define	GS_API_MACOSX	100000

#include <Foundation/NSObjCRuntime.h>
#include <GNUstepBase/preface.h>
#include <GSConfig.h>
#include <objc/objc.h>
#include <objc/typedstream.h>
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
 * This protocol must be adopted by any class wishing to support copying -
 * ie where instances of the class should be able to create new instances
 * which are copies of the original and, where a class has mutable and
 * immutable versions, where the copies are immutable.
 */
@protocol NSCopying
/**
 * Called by [NSObject-copy] passing NSDefaultMallocZone() as zone.<br />
 * This method returns a copy of the receiver and, where the receiver is a
 * mutable variant of a class which has an immutable partner class, the
 * object returned is an instance of that immutable class.<br />
 * The new object is <em>not</em> autoreleased, and is considered to be
 * 'owned' by the calling code ... which is therefore responsible for
 * releasing it.<br />
 * In the case where the receiver is an instance of a container class,
 * it is undefined whether contained objects are merely retained in the
 * new copy, or are themselves copied, or whether some other mechanism
 * entirely is used.
 */
- (id) copyWithZone: (NSZone*)zone;
@end

/**
 * This protocol must be adopted by any class wishing to support
 * mutable copying - ie where instances of the class should be able
 * to create mutable copies of themselves.
 */
@protocol NSMutableCopying
/**
 * Called by [NSObject-mutableCopy] passing NSDefaultMallocZone() as zone.<br />
 * This method returns a copy of the receiver and, where the receiver is an
 * immutable variant of a class which has a mutable partner class, the
 * object returned is an instance of that mutable class.
 * The new object is <em>not</em> autoreleased, and is considered to be
 * 'owned' by the calling code ... which is therefore responsible for
 * releasing it.<br />
 * In the case where the receiver is an instance of a container class,
 * it is undefined whether contained objects are merely retained in the
 * new copy, or are themselves copied, or whether some other mechanism
 * entirely is used.
 */
- (id) mutableCopyWithZone: (NSZone*)zone;
@end

/**
 * This protocol must be adopted by any class wishing to support
 * saving and restoring instances to an archive, or copying them
 * to remote processes via the Distributed Objects mechanism.
 */
@protocol NSCoding

/**
 * Called when it is time for receiver to be serialized for writing to an
 * archive or network connection.  Receiver should record all of its instance
 * variables using methods on aCoder.  See documentation for [NSCoder],
 * [NSArchiver], [NSKeyedArchiver], and/or [NSPortCoder] for more information.
 */
- (void) encodeWithCoder: (NSCoder*)aCoder;

/**
 * Called on a freshly allocated receiver when it is time to reconstitute from
 * serialized bytes in an archive or from a network connection.  Receiver
 * should load all of its instance variables using methods on aCoder.  See
 * documentation for [NSCoder], [NSUnarchiver], [NSKeyedUnarchiver], and/or
 * [NSPortCoder] for more information.
 */
- (id) initWithCoder: (NSCoder*)aDecoder;
@end


@interface NSObject <NSObject>
{
 /**
  * Points to instance's class.  Used by runtime to access method
  * implementations, etc..  Set in +alloc, Unlike other instance variables,
  * which are cleared there.
  */
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
 * This function is used by the [NSObject+allocWithZone:] method.
 */
GS_EXPORT NSObject *
NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone);

/**
 * Used to release the memory used by an object.<br />
 * This function is used by the [NSObject-dealloc] method.
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

/**
 * Contains values <code>NSOrderedSame</code>, <code>NSOrderedAscending</code>
 * <code>NSOrderedDescending</code>, for left hand side equals, less than, or
 * greater than right hand side.
 */
typedef enum _NSComparisonResult 
{
  NSOrderedAscending = -1, NSOrderedSame, NSOrderedDescending
} 
NSComparisonResult;

enum {NSNotFound = 0x7fffffff};

#ifndef	NO_GNUSTEP

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

/** Global lock to be used by classes when operating on any global
    data that invoke other methods which also access global; thus,
    creating the potential for deadlock. */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

@interface NSObject (GNUstep)
- (BOOL) isInstance;
- (id) makeImmutableCopyOnFail: (BOOL)force;
- (Class) transmuteClassTo: (Class)aClassObject;
+ (Class) autoreleaseClass;
+ (void) setAutoreleaseClass: (Class)aClass;
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- (id) read: (TypedStream*)aStream;
- (id) write: (TypedStream*)aStream;
@end

/**
 * Provides a number of GNUstep-specific methods that are used to aid
 * implementation of the Base library.
 */
@interface NSObject (GSCategories)

/**
 * Message sent when an implementation wants to explicitly exclude a method
 * (but cannot due to compiler constraint), and wants to make sure it is not
 * called by mistake.  Default implementation raises an exception at runtime.
 */
- notImplemented:(SEL)aSel;

/**
 * Message sent when an implementation wants to explicitly require a subclass
 * to implement a method (but cannot at compile time since there is no
 * <code>abstract</code> keyword in Objective-C).  Default implementation
 * raises an exception at runtime to alert developer that he/she forgot to
 * override a method.
 */
- (id) subclassResponsibility: (SEL)aSel;

/**
 * Message sent when an implementation wants to explicitly exclude a method
 * (but cannot due to compiler constraint) and forbid that subclasses
 * implement it.  Default implementation raises an exception at runtime.  If a
 * subclass <em>does</em> implement this method, however, the superclass's
 * implementation will not be called, so this is not a perfect mechanism.
 */
- (id) shouldNotImplement: (SEL)aSel;

/**
  WARNING: The -compare: method for NSObject is deprecated
           due to subclasses declaring the same selector with
           conflicting signatures.
           Comparison of arbitrary objects is not just meaningless
           but also dangerous as most concrete implementations
           expect comparable objects as arguments often accessing
           instance variables directly.
           This method will be removed in a future release.
*/
- (NSComparisonResult) compare: (id)anObject;
@end

#endif

/**
 *	Protocol for garbage collection finalization - same as libFoundation
 *	for compatibility.
 */
@protocol       GCFinalization
/**
 *  Called before receiver is deallocated by garbage collector.  If you want
 *  to do anything special before [NSObject -dealloc] is called, do it here.
 */
- (void) gcFinalize;
@end

#include <Foundation/NSDate.h>
/**
 *  Declares some methods for sending messages to self after a fixed delay.
 *  (These methods <em>are</em> in OpenStep and OS X.)
 */
@interface NSObject (TimedPerformers)

/**
 * Cancels any perform operations set up for the specified target
 * in the current run loop.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj;

/**
 * Cancels any perform operations set up for the specified target
 * in the current loop, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj
					selector: (SEL)s
					  object: (id)arg;
/**
 * Sets given message to be sent to this instance after given delay,
 * in any run loop mode.  See [NSRunLoop].
 */
- (void) performSelector: (SEL)s
	      withObject: (id)arg
	      afterDelay: (NSTimeInterval)seconds;

/**
 * Sets given message to be sent to this instance after given delay,
 * in given run loop modes.  See [NSRunLoop].
 */
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

#ifndef	RETAIN
/**
 *	Basic retain operation ... calls [NSObject-retain]
 */
#define	RETAIN(object)		[object retain]
#endif

#ifndef	RELEASE
/**
 *	Basic release operation ... calls [NSObject-release]
 */
#define	RELEASE(object)		[object release]
#endif

#ifndef	AUTORELEASE
/**
 *	Basic autorelease operation ... calls [NSObject-autorelease]
 */
#define	AUTORELEASE(object)	[object autorelease]
#endif

#ifndef	TEST_RETAIN
/**
 *	Tested retain - only invoke the
 *	objective-c method if the receiver is not nil.
 */
#define	TEST_RETAIN(object)	({\
id __object = (id)(object); (__object != nil) ? [__object retain] : nil; })
#endif
#ifndef	TEST_RELEASE
/**
 *	Tested release - only invoke the
 *	objective-c method if the receiver is not nil.
 */
#define	TEST_RELEASE(object)	({\
id __object = (id)(object); if (__object != nil) [__object release]; })
#endif
#ifndef	TEST_AUTORELEASE
/**
 *	Tested autorelease - only invoke the
 *	objective-c method if the receiver is not nil.
 */
#define	TEST_AUTORELEASE(object)	({\
id __object = (id)(object); (__object != nil) ? [__object autorelease] : nil; })
#endif

#ifndef	ASSIGN
/**
 *	ASSIGN(object,value) assigns the value to the object with
 *	appropriate retain and release operations.
 */
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

#ifndef	ASSIGNCOPY
/**
 *	ASSIGNCOPY(object,value) assigns a copy of the value to the object
 *	with release of the original.
 */
#define	ASSIGNCOPY(object,value)	({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    if (__value != nil) \
      { \
	__value = [__value copy]; \
      } \
    object = __value; \
    if (__object != nil) \
      { \
	[__object release]; \
      } \
  } \
})
#endif

#ifndef	DESTROY
/**
 *	DESTROY() is a release operation which also sets the variable to be
 *	a nil pointer for tidiness - we can't accidentally use a DESTROYED
 *	object later.  It also makes sure to set the variable to nil before
 *	releasing the object - to avoid side-effects of the release trying
 *	to reference the object being released through the variable.
 */
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
/**
 * Declares an autorelease pool variable and creates and initialises
 * an autorelease pool object.
 */
#define	CREATE_AUTORELEASE_POOL(X)	\
  NSAutoreleasePool *(X) = [NSAutoreleasePool new]
#endif

#ifndef RECREATE_AUTORELEASE_POOL
/**
 * Similar, but allows reuse of variables. Be sure to use DESTROY()
 * so the object variable stays nil.
 */
#define RECREATE_AUTORELEASE_POOL(X)  \
  if (X == nil) \
    (X) = [NSAutoreleasePool new]
#endif

#define	IF_NO_GC(X)	X

#endif

#if	defined(__cplusplus)
}
#endif

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
