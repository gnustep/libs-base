/* 
    NSValue.h - Object encapsulation for C types.
    
    Copyright 1994 NeXT, Inc. All rights reserved.

 */

#ifndef __NSValue_INCLUDE_GNU_
#define __NSValue_INCLUDE_GNU_

#include <foundation/NSObject.h>
#include <foundation/NSGeometry.h>

@class NSString;

@interface NSValue : NSObject <NSCopying, NSCoding>
{
    void		*_dataptr;
    NSString		*objctype;
}

// Allocating and Initializing 

+ (NSValue *)value:(const void *)value
      withObjCType:(const char *)type;
+ (NSValue *)valueWithNonretainedObject: (id)anObject;
+ (NSValue *)valueWithPoint:(NSPoint)point;
+ (NSValue *)valueWithPointer:(const void *)pointer;
+ (NSValue *)valueWithRect:(NSRect)rect;
+ (NSValue *)valueWithSize:(NSSize)size;

/* Note: not in OpenStep specification */
- initValue:(const void *)value
      withObjCType:(const char *)type;

// Accessing Data 

- (void)getValue:(void *)value;
- (const char *)objCType;
- (id)nonretainedObjectValue;
- (void *)pointerValue;
- (NSRect)rectValue;
- (NSSize)sizeValue;
- (NSPoint)pointValue;

@end

@interface NSNumber : NSValue
{
}

// Allocating and Initializing

+ (NSNumber *)numberWithBool:(BOOL)value; 
+ (NSNumber *)numberWithChar:(char)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithFloat:(float)value;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithLong:(long)value;
+ (NSNumber *)numberWithLongLong:(long long)value;
+ (NSNumber *)numberWithShort:(short)value;
+ (NSNumber *)numberWithUnsignedChar:(unsigned char)value;
+ (NSNumber *)numberWithUnsignedInt:(unsigned int)value;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value;
+ (NSNumber *)numberWithUnsignedShort:(unsigned short)value;

// Accessing Data 

- (BOOL)boolValue;
- (char)charValue;
- (double)doubleValue;
- (float)floatValue;
- (int)intValue;
- (long long)longLongValue;
- (long)longValue;
- (short)shortValue;
- (NSString *)stringValue;
- (unsigned char)unsignedCharValue;
- (unsigned int)unsignedIntValue;
- (unsigned long long)unsignedLongLongValue;
- (unsigned long)unsignedLongValue;
- (unsigned short)unsignedShortValue;

- (NSComparisonResult)compare:(NSNumber *)otherNumber;

@end
#endif
