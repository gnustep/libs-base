/**Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

   AutogsdocSource: NSObject.m
   */ 

#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

#import	<Foundation/NSObjCRuntime.h>
#import <objc/objc.h>
#import <objc/typedstream.h>
#import	<Foundation/NSZone.h>

#ifndef	GS_WITH_GC
#define	GS_WITH_GC	0
#endif

#import	<GNUstepBase/GNUstep.h>

#if	defined(__cplusplus)
extern "C" {
#endif

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
- (NSUInteger) hash;			/** See [NSObject-hash] */
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
- (NSUInteger) retainCount;		/** See [NSObject-retainCount] */
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

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/** On a system which performs garbage collection, you should implement
 * this method to execute code when the receiver is collected.<br />
 * You must not call this method yourself (except when a subclass
 * calls the superclass method within its own implementation).
 */
- (void) finalize;
#endif

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (NSString*) className;
#endif

+ (id) allocWithZone: (NSZone*)z;
+ (id) alloc;
+ (Class) class;
+ (NSString*) description;

/**
 * This method is automatically invoked on any class which implements it
 * when the class is loaded into the runtime.<br />
 * It is also invoked on any category where the method is implemented
 * when that category is loaded into the runtime.<br />
 * The +load method is called directly by the runtime and you should never
 * send a +load message to a class yourself.<br />
 * This method is called <em>before</em> the +initialize message is sent
 * to the class, so you cannot depend on class initialisation having been
 * performed, or upon other classes existing (apart from superclasses of
 * the receiver, since +load is called on superclasses before it is called
 * on their subclasses).<br />
 * As a gross generalisation, it is safe to use C code, including
 * most ObjectiveC runtime functions within +load, but attempting to send
 * messages to ObjectiveC objects is likely to fail.<br />
 * In GNUstep, this method is implemented for NSObject to perform some
 * initialisation for the base library.<br />
 * If you implement +load for a class, don't call [super load] in your
 * implementation.
 */
+ (void) load;

/**
 * This message is automatically sent to a class by the runtime.  It is
 * sent once for each class, just before the class is used for the first
 * time (excluding any automatic call to +load by the runtime).<br />
 * The message is sent in a thread-safe manner ... other threads may not
 * call methods of the class until +initialize has finished executing.<br />
 * If the class has a superclass, its implementation of +initialize is
 * called first.<br />
 * If the class does not implement +initialize then the implementation
 * in the closest superclass may be called.  This means that +initialize may
 * be called more than once, and the recommended way to handle this by
 * using the
 * <code>
 * if (self == [classname class])
 * </code>
 * conditional to check whether the method is being called for a subclass.<br />
 * You should never call +initialize yourself ... let the runtime do it.<br />
 * You can implement +initialize in your own class if you need to.
 * NSObject's implementation handles essential root object and base
 * library initialization.<br />
 * Don't call [super initialize] in your implementation of +initialize.
 */
+ (void) initialize;
+ (IMP) instanceMethodForSelector: (SEL)aSelector;
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector;
+ (BOOL) instancesRespondToSelector: (SEL)aSelector;
+ (BOOL) isSubclassOfClass: (Class)aClass;
+ (id) new;
+ (void) poseAsClass: (Class)aClassObject;
+ (id) setVersion: (NSInteger)aVersion;
+ (Class) superclass;
+ (NSInteger) version;

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
- (NSUInteger) hash;
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
- (NSUInteger) retainCount;
- (id) self;
- (Class) superclass;
- (NSZone*) zone;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/**
 * This method will be called when attempting to send a message a class that
 * does not understand it.  The class may install a new method for the given
 * selector and return YES, otherwise it should return NO.
 *
 * Note: This method is only reliable when using the GNUstep runtime.  If you
 * require compatibility with the GCC runtime, you must also implement
 * -forwardInvocation: with equivalent semantics.  This will be considerably
 *  slower, but more portable.
 */
+ (BOOL) resolveClassMethod: (SEL)name;

/**
 * This method will be called when attempting to send a message an instance
 * that does not understand it.  The class may install a new method for the
 * given selector and return YES, otherwise it should return NO.
 *
 * Note: This method is only reliable when using the GNUstep runtime.  If you
 * require compatibility with the GCC runtime, you must also implement
 * -forwardInvocation: with equivalent semantics.  This will be considerably
 *  slower, but more portable.
 */
+ (BOOL) resolveInstanceMethod: (SEL)name;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns an auto-accessing proxy for the given object.  This proxy sends a
 * -beginContentAccess message to the receiver when it is created and an
 * -endContentAccess message when it is destroyed.  This prevents an object
 * that implements the NSDiscardableContent protocol from having its contents
 * discarded for as long as the proxy exists.  
 *
 * On systems using the GNUstep runtime, messages send to the proxy will be
 * slightly slower than direct messages.  With the GCC runtime, they will be
 * approximately two orders of magnitude slower.  The GNUstep runtime,
 * therefore, is strongly recommended for code calling this method.
 */
- (id) autoContentAccessingProxy;

/**
 * If an object does not understand a message, it may delegate it to another
 * object.  Returning nil indicates that forwarding should not take place.  The
 * default implementation of this returns nil, but care should be taken when
 * subclassing NSObject subclasses and overriding this method that
 * the superclass implementation is called if returning nil.
 *
 * Note: This method is only reliable when using the GNUstep runtime and code
 * compiled with clang.  If you require compatibility with GCC and the GCC
 * runtime, you must also implement -forwardInvocation: with equivalent
 * semantics.  This will be considerably slower, but more portable.
 */
- (id) forwardingTargetForSelector: (SEL)aSelector;

#endif
@end

/**
 * Used to allocate memory to hold an object, and initialise the
 * class of the object to be aClass etc.  The allocated memory will
 * be extraBytes larger than the space actually needed to hold the
 * instance variables of the object.<br />
 * This function is used by the [NSObject+allocWithZone:] method.
 */
GS_EXPORT id
NSAllocateObject(Class aClass, NSUInteger extraBytes, NSZone *zone);

/**
 * Used to release the memory used by an object.<br />
 * This function is used by the [NSObject-dealloc] method.
 */
GS_EXPORT void
NSDeallocateObject(id anObject);

/**
 * Used to copy anObject.  This makes a bitwise copy of anObject to
 * memory allocated from zone.  The allocated memory will be extraBytes
 * longer than that necessary to actually store the instance variables
 * of the copied object.<br />
 * This is used by the NSObject implementation of the
 * [(NSCopying)-copyWithZone:] method.
 */
GS_EXPORT NSObject *
NSCopyObject(NSObject *anObject, NSUInteger extraBytes, NSZone *zone);

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

GS_EXPORT NSUInteger
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

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/** Global lock to be used by classes when operating on any global
    data that invoke other methods which also access global; thus,
    creating the potential for deadlock. */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

#if GS_API_VERSION(GS_API_NONE, 011700)
@interface NSObject (GNUstep)
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- (id) read: (TypedStream*)aStream;
- (id) write: (TypedStream*)aStream;
@end
#endif

#endif

#import	<Foundation/NSDate.h>
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

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * The NSDiscardableContent protocol is used by objects which encapsulate data
 * which may be discarded if resource constraints are exceeded.  These
 * constraints are typically, but not always, related memory.  
 */
@protocol NSDiscardableContent

/**
 * This method is called before any access to the object.  It returns YES if
 * the object's content is still valid.  The caller must call -endContentAccess
 * once for every call to -beginContentAccess;
 */
- (BOOL) beginContentAccess;

/**
 * Discards the contents of the object if it is not currently being edited.
 */
- (void) discardContentIfPossible;

/**
 * This method indicates that the caller has finished accessing the contents of
 * the object adopting this protocol.  Every call to -beginContentAccess must
 * be be paired with a call to this method after the caller has finished
 * accessing the contents.
 */
- (void) endContentAccess;

/**
 * Returns YES if the contents of the object have been discarded, either via a
 * call to -discardContentIfPossible while the object is not in use, or by some
 * implementation dependent mechanism.  
 */
- (BOOL) isContentDiscarded;
@end
#endif
#if	defined(__cplusplus)
}
#endif

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
