# line 1 "NSConcreteNumber.m"	/* So gdb knows which file we are in */
/* NSConcreteNumber - Object encapsulation of numbers
    
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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

#include <config.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <gnustep/base/Coder.h>

/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 12 cooresponding to each number type */
#if TYPE_ORDER == 0
#  define NumberTemplate	NSBoolNumber
#  define TYPE_METHOD	boolValue
#  define TYPE_FORMAT	@"%uc"
#  define NEXT_ORDER	4
#  define NEXT_METHOD	shortValue
#  define NEXT_CTYPE	short
#elif TYPE_ORDER == 1
#  define NumberTemplate	NSUCharNumber
#  define TYPE_METHOD	unsignedCharValue
#  define TYPE_FORMAT	@"%uc"
#  define NEXT_ORDER	4
#  define NEXT_METHOD	shortValue
#  define NEXT_CTYPE	short
#elif TYPE_ORDER == 2
#  define NumberTemplate	NSCharNumber
#  define TYPE_METHOD	charValue
#  define TYPE_FORMAT	@"%c"
#  define NEXT_ORDER	4
#  define NEXT_METHOD	shortValue
#  define NEXT_CTYPE	short
#elif TYPE_ORDER == 3
#  define NumberTemplate	NSUShortNumber
#  define TYPE_METHOD	unsignedShortValue
#  define TYPE_FORMAT	@"%hu"
#  define NEXT_ORDER	6
#  define NEXT_METHOD	intValue
#  define NEXT_CTYPE	int
#elif TYPE_ORDER == 4
#  define NumberTemplate	NSShortNumber
#  define TYPE_METHOD	shortValue
#  define TYPE_FORMAT	@"%hd"
#  define NEXT_ORDER	6
#  define NEXT_METHOD	intValue
#  define NEXT_CTYPE	int
#elif TYPE_ORDER == 5
#  define NumberTemplate	NSUIntNumber
#  define TYPE_METHOD	unsignedIntValue
#  define TYPE_FORMAT	@"%u"
#  define NEXT_ORDER	8
#  define NEXT_METHOD	longValue
#  define NEXT_CTYPE	long
#elif TYPE_ORDER == 6
#  define NumberTemplate	NSIntNumber
#  define TYPE_METHOD	intValue
#  define TYPE_FORMAT	@"%d"
#  define NEXT_ORDER	8
#  define NEXT_METHOD	longValue
#  define NEXT_CTYPE	long
#elif TYPE_ORDER == 7
#  define NumberTemplate	NSULongNumber
#  define TYPE_METHOD	unsignedLongValue
#  define TYPE_FORMAT	@"%lu"
#  define NEXT_ORDER	10
#  define NEXT_METHOD	longLongValue
#  define NEXT_CTYPE	long long
#elif TYPE_ORDER == 8
#  define NumberTemplate	NSLongNumber
#  define TYPE_METHOD	longValue
#  define TYPE_FORMAT	@"%ld"
#  define NEXT_ORDER	10
#  define NEXT_METHOD	longLongValue
#  define NEXT_CTYPE	long long
#elif TYPE_ORDER == 9
#  define NumberTemplate	NSULongLongNumber
#  define TYPE_METHOD	unsignedLongLongValue
#  define TYPE_FORMAT	@"%llu"
#  define NEXT_ORDER	12
#  define NEXT_METHOD	doubleValue
#  define NEXT_CTYPE	double
#elif TYPE_ORDER == 10
#  define NumberTemplate	NSLongLongNumber
#  define TYPE_METHOD	longLongValue
#  define TYPE_FORMAT	@"%lld"
#  define NEXT_ORDER	12
#  define NEXT_METHOD	doubleValue
#  define NEXT_CTYPE	double
#elif TYPE_ORDER == 11
#  define NumberTemplate	NSFloatNumber
#  define TYPE_METHOD	floatValue
#  define TYPE_FORMAT	@"%f"
#  define NEXT_ORDER	12
#  define NEXT_METHOD	doubleValue
#  define NEXT_CTYPE	double
#elif TYPE_ORDER == 12
#  define NumberTemplate	NSDoubleNumber
#  define TYPE_METHOD	doubleValue
#  define TYPE_FORMAT	@"%g"
#  define NEXT_ORDER	12
#  define NEXT_METHOD	doubleValue
#  define NEXT_CTYPE	double
#endif

@interface NSNumber (Private)
- (int)_nextOrder;
- (NSComparisonResult) _promotedCompare: (NSNumber*)other;
- (int)_typeOrder;
@end

@implementation NumberTemplate (Private)
- (int)_nextOrder
{
    return NEXT_ORDER;
}
- (NSComparisonResult) _promotedCompare: (NSNumber*)other
{
    NEXT_CTYPE	v0, v1;

    v0 = [self NEXT_METHOD];
    v1 = [other NEXT_METHOD];

    if (v0 == v1)
	return NSOrderedSame;
    else
	return (v0 < v1) ?  NSOrderedAscending : NSOrderedDescending;
}
- (int)_typeOrder
{
    return TYPE_ORDER;
}
@end

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

- (NSComparisonResult)compare:(NSNumber *)other
{
    int	o = [self _typeOrder];

    if (o == [other _typeOrder] || o >= [other _nextOrder]) {
        typedef _dt = data;
        _dt other_data = [other TYPE_METHOD];
    
        if (data == other_data)
    	    return NSOrderedSame;
        else
    	    return (data < other_data) ?
		NSOrderedAscending : NSOrderedDescending;
    }
    o = [self _nextOrder];
    if (o <= [other _typeOrder]) {
	NSComparisonResult	r = [other compare: self];
	if (r == NSOrderedAscending) {
	    return NSOrderedDescending;
	}
	if (r == NSOrderedDescending) {
	    return NSOrderedAscending;
	}
	return r;
    }
    if (o >= [other _nextOrder]) {
	return [self _promotedCompare: other];
    }
    else {
	NSComparisonResult	r = [other _promotedCompare: self];
	if (r == NSOrderedAscending) {
	    return NSOrderedDescending;
	}
	if (r == NSOrderedDescending) {
	    return NSOrderedAscending;
	}
	return r;
    }
}

/* Because of the rule that two numbers which are the same according to
 * [-isEqual:] must generate the same hash, we must generate the hash
 * from the most general representation of the number.
 */
- (unsigned) hash
{
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned	hash = 0;
  int		i;

  val.d = [self doubleValue];
  for (i = 0; i < sizeof(double); i++) {
    hash += val.c[i];
  }
  return hash;
}

- (BOOL) isEqualToNumber: (NSNumber*)o
{
    if ([self compare: o] == NSOrderedSame)
        return YES;
    return NO;
}

- (BOOL) isEqual: o
{
  if ([o isKindOf: [NSNumber class]])
    return [self isEqualToNumber: (NSNumber*)o];
  else
    return [super isEqual: o];
}

- (NSString *)descriptionWithLocale: (NSDictionary*)locale
{
    return [NSString stringWithFormat:TYPE_FORMAT, data];
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
- classForCoder
{
  return [self class];
}

- (void) encodeWithCoder: coder
{
  const char *type = [self objCType];
  [coder encodeValueOfObjCType: type at: &data withName: @"NSNumber value"];
}

- (id) initWithCoder: coder
{
  const char *type = [self objCType];
  [coder decodeValueOfObjCType: type at: &data withName: NULL];
  return self;
}

@end

