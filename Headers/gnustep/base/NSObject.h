/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the Gnustep Base Library.

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

@class NSArchiver;
@class NSCoder;
@class NSMethodSignature;
@class NSString;
@class NSInvocation;
@class Protocol;

@protocol NSObject
- autorelease;
- (Class) class;
- (BOOL) conformsToProtocol: (Protocol *)aProtocol;
- (unsigned) hash;
- (BOOL) isEqual: anObject;
- (BOOL) isKindOfClass: (Class)aClass;
- (BOOL) isMemberOfClass: (Class)aClass;
- (BOOL) isProxy;
- perform: (SEL)aSelector;
- perform: (SEL)aSelector withObject: anObject;
- perform: (SEL)aSelector withObject: object1 withObject: object2;
- (oneway void) release;
- (BOOL) respondsToSelector: (SEL)aSelector;
- retain;
- (unsigned) retainCount;
- self;
- (NSZone *) zone;
- (NSString *) description;
@end

@protocol NSCopying
- copyWithZone: (NSZone *)zone;
- copy;
@end

@protocol NSMutableCopying
- mutableCopyWithZone:(NSZone *)zone;
- mutableCopy;
@end

@protocol NSCoding
- (void) encodeWithCoder: (NSCoder*)aCoder;
- (id) initWithCoder: (NSCoder*)aDecoder;
@end


@interface NSObject <NSObject, NSCoding, NSCopying>
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

- (Class) class;
- (Class) superclass;

+ (BOOL) instancesRespondToSelector: (SEL)aSelector;

+ (IMP) instanceMethodForSelector: (SEL)aSelector;
- (IMP) methodForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;

- (NSString*) description;
+ (NSString*) description;

+ (void) poseAsClass: (Class)aClass;

- (void) doesNotRecognizeSelector: (SEL)aSelector;

- (void) forwardInvocation: (NSInvocation*)anInvocation;

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) classForCoder;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;

@end

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

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
