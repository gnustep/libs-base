/* NSConcreteNumber - Object encapsulation of numbers
    
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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

#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>

/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 12 cooresponding to each number type */
#if TYPE_ORDER == 0
#  define NumberTemplate	NSBoolNumber
#  define TYPE_METHOD	boolValue
#  define TYPE_FORMAT	@"%uc"
#elif TYPE_ORDER == 1
#  define NumberTemplate	NSUCharNumber
#  define TYPE_METHOD	unsignedCharValue
#  define TYPE_FORMAT	@"%uc"
#elif TYPE_ORDER == 2
#  define NumberTemplate	NSCharNumber
#  define TYPE_METHOD	charValue
#  define TYPE_FORMAT	@"%c"
#elif TYPE_ORDER == 3
#  define NumberTemplate	NSUShortNumber
#  define TYPE_METHOD	unsignedShortValue
#  define TYPE_FORMAT	@"%hu"
#elif TYPE_ORDER == 4
#  define NumberTemplate	NSShortNumber
#  define TYPE_METHOD	shortValue
#  define TYPE_FORMAT	@"%hd"
#elif TYPE_ORDER == 5
#  define NumberTemplate	NSUIntNumber
#  define TYPE_METHOD	unsignedIntValue
#  define TYPE_FORMAT	@"%u"
#elif TYPE_ORDER == 6
#  define NumberTemplate	NSIntNumber
#  define TYPE_METHOD	intValue
#  define TYPE_FORMAT	@"%d"
#elif TYPE_ORDER == 7
#  define NumberTemplate	NSULongNumber
#  define TYPE_METHOD	unsignedLongValue
#  define TYPE_FORMAT	@"%lu"
#elif TYPE_ORDER == 8
#  define NumberTemplate	NSLongNumber
#  define TYPE_METHOD	longValue
#  define TYPE_FORMAT	@"%ld"
#elif TYPE_ORDER == 9
#  define NumberTemplate	NSULongLongNumber
#  define TYPE_METHOD	unsignedLongLongValue
#  define TYPE_FORMAT	@"%llu"
#elif TYPE_ORDER == 10
#  define NumberTemplate	NSLongLongNumber
#  define TYPE_METHOD	longLongValue
#  define TYPE_FORMAT	@"%lld"
#elif TYPE_ORDER == 11
#  define NumberTemplate	NSFloatNumber
#  define TYPE_METHOD	floatValue
#  define TYPE_FORMAT	@"%f"
#elif TYPE_ORDER == 12
#  define NumberTemplate	NSDoubleNumber
#  define TYPE_METHOD	doubleValue
#  define TYPE_FORMAT	@"%g"
#endif

@implementation NumberTemplate

- initValue:(const void *)value withObjCType:(const char *)type;
{
    typedef _dt = data;
    self = [super init];
    data = *(_dt *)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (char)charValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (NSString *)stringValue
{
    return [NSString stringWithFormat:TYPE_FORMAT, data];
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    typedef _dt = data;
    _dt other_data = [otherNumber TYPE_METHOD];
    
    if (data == other_data)
    	return NSOrderedSame;
    else
    	return (data < other_data) ? NSOrderedAscending : NSOrderedDescending;
}

// Override these from NSValue
- (void)getValue:(void *)value
{
    if (!value) {
    	[NSException raise:NSInvalidArgumentException
		format:@"Cannot copy value into NULL pointer"];
	/* NOT REACHED */ 
    }
    memcpy( value, &data, objc_sizeof_type([self objCType]) );
}

- (const char *)objCType
{
    typedef _dt = data;
    return @encode(_dt);
}

// NSCoding
- (void)encodeWithCoder:(NSCoder *)coder
{
//FIXME    [super encodeWithCoder:coder];
    [coder encodeValueOfObjCType:[self objCType] at:&data];
}

- (id)initWithCoder:(NSCoder *)coder
{
//FIXME    self = [super initWithCoder:coder];
    [coder decodeValueOfObjCType:[self objCType] at:&data];
    return self;
}

@end

