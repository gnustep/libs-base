/* Interface for NSValue for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: 1995
   
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

#ifndef __NSValue_h_GNUSTEP_BASE_INCLUDE
#define __NSValue_h_GNUSTEP_BASE_INCLUDE

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

#ifndef STRICT_OPENSTEP
+ (NSValue*) valueWithBytes: (const void*)value objCType: (const char*)type;
+ (NSValue*) valueFromString: (NSString*)string;
/* Designated initializer for all concrete subclasses */
- (id) initWithBytes: (const void*)value objCType: (const char*)type;
- (BOOL) isEqualToValue: (NSValue*)other;
#endif

// Accessing Data 

- (void) getValue: (void*)value;
- (const char*) objCType;
- (id) nonretainedObjectValue;
- (void*) pointerValue;
- (NSRect) rectValue;
- (NSSize) sizeValue;
- (NSPoint) pointValue;

@end

@interface NSNumber : NSValue <NSCopying,NSCoding>

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

- (id) initWithBool: (BOOL)value;
- (id) initWithChar: (char)value;
- (id) initWithDouble: (double)value;
- (id) initWithFloat: (float)value;
- (id) initWithInt: (int)value;
- (id) initWithLong: (long)value;
- (id) initWithLongLong: (long long)value;
- (id) initWithShort: (short)value;
- (id) initWithUnsignedChar: (unsigned char)value;
- (id) initWithUnsignedInt: (unsigned int)value;
- (id) initWithUnsignedLong: (unsigned long)value;
- (id) initWithUnsignedLongLong: (unsigned long long)value;
- (id) initWithUnsignedShort: (unsigned short)value;

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

- (NSString*) description;
- (NSString*) descriptionWithLocale: (NSDictionary*)locale;

- (NSComparisonResult) compare: (NSNumber*)otherNumber;
- (BOOL) isEqualToNumber: (NSNumber*)otherNumber;

@end

#ifndef	NO_GNUSTEP
/* Note: This method is not in the OpenStep spec, but they makes
   subclassing easier. */
@interface NSValue (Subclassing)

/* Used by value: withObjCType: to determine the concrete subclass to alloc */
+ (Class) valueClassWithObjCType: (const char*)type;

@end

/*
 * Cache info for internal use by NSNumber concrete subclasses.
 */
typedef struct {
  int			typeOrder;
  NSComparisonResult	(*compValue)(NSNumber*, SEL, NSNumber*);
  BOOL			(*boolValue)(NSNumber*, SEL);
  char			(*charValue)(NSNumber*, SEL);
  unsigned char		(*unsignedCharValue)(NSNumber*, SEL);
  short			(*shortValue)(NSNumber*, SEL);
  unsigned short	(*unsignedShortValue)(NSNumber*, SEL);
  int			(*intValue)(NSNumber*, SEL);
  unsigned int		(*unsignedIntValue)(NSNumber*, SEL);
  long			(*longValue)(NSNumber*, SEL);
  unsigned long		(*unsignedLongValue)(NSNumber*, SEL);
  long long		(*longLongValue)(NSNumber*, SEL);
  unsigned long long	(*unsignedLongLongValue)(NSNumber*, SEL);
  float			(*floatValue)(NSNumber*, SEL);
  double		(*doubleValue)(NSNumber*, SEL);
} GSNumberInfo;

GSNumberInfo	*GSNumberInfoFromObject(NSNumber *o);
#define	GS_SMALL	16
/*
 * Get cached values for integers in the range -GS_SMALL to +GS_SMALL
 */
unsigned	GSSmallHash(int n);
#endif

#endif /* __NSValue_h_GNUSTEP_BASE_INCLUDE */
