/* Interface for NSArray for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995
   
   This file is part of the GNU Objective C Class Library.

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

#ifndef __NSValue_h_OBJECTS_INCLUDE
#define __NSValue_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSString;

@interface NSValue : NSObject <NSCopying, NSCoding>

// Allocating and Initializing 

+ (NSValue*) value: (const void*)value withObjCType: (const char*)type;
+ (NSValue*) valueWithNonretainedObject: (id)anObject;
+ (NSValue*) valueWithPoint: (NSPoint)point;
+ (NSValue*) valueWithPointer: (const void*)pointer;
+ (NSValue*) valueWithRect: (NSRect)rect;
+ (NSValue*) valueWithSize: (NSSize)size;

// Accessing Data 

- (void) getValue: (void*)value;
- (const char*) objCType;
- (id) nonretainedObjectValue;
- (void*) pointerValue;
- (NSRect) rectValue;
- (NSSize) sizeValue;
- (NSPoint) pointValue;

@end

@interface NSNumber : NSValue <NSCoding>
{
}

// Allocating and Initializing

+ (NSNumber*) numberWithBool: (BOOL)value; 
+ (NSNumber*) numberWithChar: (char)value;
+ (NSNumber*) numberWithDouble: (double)value;
+ (NSNumber*) numberWithFloat: (float)value;
+ (NSNumber*) numberWithInt: (int)value;
+ (NSNumber*) numberWithLong: (long)value;
+ (NSNumber*) numberWithLongLong: (long long)value;
+ (NSNumber*) numberWithShort: (short)value;
+ (NSNumber*) numberWithUnsignedChar: (unsigned char)value;
+ (NSNumber*) numberWithUnsignedInt: (unsigned int)value;
+ (NSNumber*) numberWithUnsignedLong: (unsigned long)value;
+ (NSNumber*) numberWithUnsignedLongLong: (unsigned long long)value;
+ (NSNumber*) numberWithUnsignedShort: (unsigned short)value;

// Accessing Data 

- (BOOL) boolValue;
- (char) charValue;
- (double) doubleValue;
- (float) floatValue;
- (int) intValue;
- (long long) longLongValue;
- (long) longValue;
- (short) shortValue;
- (NSString*) stringValue;
- (unsigned char) unsignedCharValue;
- (unsigned int) unsignedIntValue;
- (unsigned long long) unsignedLongLongValue;
- (unsigned long) unsignedLongValue;
- (unsigned short) unsignedShortValue;

- (NSComparisonResult) compare: (NSNumber*)otherNumber;

@end

/* Note: These methods are not in the OpenStep spec, but they may make
   subclassing easier. */
@interface NSValue (Subclassing)

/* Used by value:withObjCType: to determine the concrete subclass to alloc */
+ (Class)valueClassWithObjCType:(const char *)type;

/* Designated initializer for all concrete subclasses */
- initValue:(const void *)value withObjCType:(const char *)type;
@end

#endif /* __NSValue_h_OBJECTS_INCLUDE */
