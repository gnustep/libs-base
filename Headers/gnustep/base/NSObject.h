/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>
#include <objc/Protocol.h>
#include <Foundation/NSZone.h>
#include <gnustep/base/fake-main.h>

@class NSArchiver;
@class NSArray;
@class NSCoder;
@class NSPortCoder;
@class NSMethodSignature;
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
- (NSZone *) zone;
- (NSString *) description;
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
- (id) replacementObjectForArchiver: (NSCoder*)anEncoder;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;
- (id) replacementObjectForPortCoder: (NSPortCoder*)anEncoder;


+ setVersion: (int)aVersion;
+ (int) version;

@end

/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
extern NSRecursiveLock *gnustep_global_lock;

NSObject *NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone);
void NSDeallocateObject(NSObject *anObject);
NSObject *NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone);

BOOL NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone);
void NSIncrementExtraRefCount(id anObject);
BOOL NSDecrementExtraRefCountWasZero(id anObject);

typedef enum _NSComparisonResult 
{
  NSOrderedAscending = -1, NSOrderedSame, NSOrderedDescending
} 
NSComparisonResult;

enum {NSNotFound = 0x7fffffff};

@interface NSObject (GNUstep)
+ (id) newWithCoder: (NSCoder*)aCoder inZone: (NSZone*)aZone;
@end

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
- notImplemented:(SEL)aSel;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

@interface NSObject (GNU)
- (int) compare: anObject;
- (Class)transmuteClassTo:(Class)aClassObject;
- subclassResponsibility:(SEL)aSel;
- shouldNotImplement:(SEL)aSel;
+ (Class) autoreleaseClass;
+ (void) setAutoreleaseClass: (Class)aClass;
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;
@end

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

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
