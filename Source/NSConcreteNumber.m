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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <config.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSPortCoder.h>
#include <base/Coder.h>

/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 12 cooresponding to each number type */
#if TYPE_ORDER == 0
#  define NumberTemplate	NSBoolNumber
#  define TYPE_METHOD	boolValue
#  define TYPE_FORMAT	@"%u"
#elif TYPE_ORDER == 1
#  define NumberTemplate	NSCharNumber
#  define TYPE_METHOD	charValue
#  define TYPE_FORMAT	@"%c"
#elif TYPE_ORDER == 2
#  define NumberTemplate	NSUCharNumber
#  define TYPE_METHOD	unsignedCharValue
#  define TYPE_FORMAT	@"%c"
#elif TYPE_ORDER == 3
#  define NumberTemplate	NSShortNumber
#  define TYPE_METHOD	shortValue
#  define TYPE_FORMAT	@"%hd"
#elif TYPE_ORDER == 4
#  define NumberTemplate	NSUShortNumber
#  define TYPE_METHOD	unsignedShortValue
#  define TYPE_FORMAT	@"%hu"
#elif TYPE_ORDER == 5
#  define NumberTemplate	NSIntNumber
#  define TYPE_METHOD	intValue
#  define TYPE_FORMAT	@"%d"
#elif TYPE_ORDER == 6
#  define NumberTemplate	NSUIntNumber
#  define TYPE_METHOD	unsignedIntValue
#  define TYPE_FORMAT	@"%u"
#elif TYPE_ORDER == 7
#  define NumberTemplate	NSLongNumber
#  define TYPE_METHOD	longValue
#  define TYPE_FORMAT	@"%ld"
#elif TYPE_ORDER == 8
#  define NumberTemplate	NSULongNumber
#  define TYPE_METHOD	unsignedLongValue
#  define TYPE_FORMAT	@"%lu"
#elif TYPE_ORDER == 9
#  define NumberTemplate	NSLongLongNumber
#  define TYPE_METHOD	longLongValue
#  define TYPE_FORMAT	@"%lld"
#elif TYPE_ORDER == 10
#  define NumberTemplate	NSULongLongNumber
#  define TYPE_METHOD	unsignedLongLongValue
#  define TYPE_FORMAT	@"%llu"
#elif TYPE_ORDER == 11
#  define NumberTemplate	NSFloatNumber
#  define TYPE_METHOD	floatValue
#  define TYPE_FORMAT	@"%f"
#elif TYPE_ORDER == 12
#  define NumberTemplate	NSDoubleNumber
#  define TYPE_METHOD	doubleValue
#  define TYPE_FORMAT	@"%g"
#endif

@interface NSNumber (Private)
- (int) _typeOrder;
@end

@implementation NumberTemplate (Private)
- (int) _typeOrder
{
  return TYPE_ORDER;
}
@end

@implementation NumberTemplate

- (id) initWithBytes: (const void*)value objCType: (const char*)type
{
  typedef __typeof__(data) _dt;
  data = *(_dt*)value;
  return self;
}

/*
 * Because of the rule that two numbers which are the same according to
 * [-isEqual: ] must generate the same hash, we must generate the hash
 * from the most general representation of the number.
 * NB. Don't change this without changing the matching function in
 * NSNumber.m
 */
- (unsigned) hash
{
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned	hash = 0;
  unsigned	i;

/*
 * If possible use a cached hash value for small integers.
 */
#if	TYPE_ORDER < 11
#if	(TYPE_ORDER & 1)
  if (data <= GS_SMALL && data >= -GS_SMALL)
#else
  if (data <= GS_SMALL)
#endif
    {
      return GSSmallHash((int)data);
    }
#endif

  val.d = [self doubleValue];
  for (i = 0; i < sizeof(double); i++)
    {
      hash += val.c[i];
    }
  return hash;
}

- (BOOL) boolValue
{
  return data;
}

- (char) charValue
{
  return data;
}

- (double) doubleValue
{
  return data;
}

- (float) floatValue
{
  return data;
}

- (int) intValue
{
  return data;
}

- (long long) longLongValue
{
  return data;
}

- (long) longValue
{
  return data;
}

- (short) shortValue
{
  return data;
}

- (unsigned char) unsignedCharValue
{
  return data;
}

- (unsigned int) unsignedIntValue
{
  return data;
}

- (unsigned long long) unsignedLongLongValue
{
  return data;
}

- (unsigned long) unsignedLongValue
{
  return data;
}

- (unsigned short) unsignedShortValue
{
  return data;
}

- (NSComparisonResult) compare: (NSNumber*)other
{
  GSNumberInfo	*info;

  if (other == self)
    {
      return NSOrderedSame;
    }
  info = GSNumberInfoFromObject(other);
  if (TYPE_ORDER >= info->typeOrder)
    {
      typedef __typeof__(data) _dt;
      _dt other_data = (*(info->TYPE_METHOD))(other, @selector(TYPE_METHOD));
  
      if (data == other_data)
	{
	  return NSOrderedSame;
	}
      else if (data < other_data)
	{
	  return  NSOrderedAscending;
	}
      else
	{
	  return NSOrderedDescending;
	}
    }
  else
    {
      NSComparisonResult	r;

      r = (*(info->compValue))(other, @selector(compare:), self); 

      if (r == NSOrderedAscending)
	{
	  return NSOrderedDescending;
	}
      if (r == NSOrderedDescending)
	{
	  return NSOrderedAscending;
	}
      return r;
    }
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
#if TYPE_ORDER == 0
  return (data) ? @"YES" : @"NO";
#else
  return [NSString stringWithFormat: TYPE_FORMAT, data];
#endif
}

// Override these from NSValue
- (void) getValue: (void*)value
{
  if (value == 0)
    {
      [NSException raise: NSInvalidArgumentException
	      format: @"Cannot copy value into NULL pointer"];
      /* NOT REACHED */ 
    }
  memcpy(value, &data, objc_sizeof_type([self objCType]));
}

- (const char*) objCType
{
  typedef __typeof__(data) _dt;
  return @encode(_dt);
}

// NSCoding
- (Class) classForCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

- (void) encodeWithCoder: coder
{
  const char *type = [self objCType];
  [coder encodeValueOfObjCType: type at: &data];
}

- (id) initWithCoder: coder
{
  const char *type = [self objCType];
  [coder decodeValueOfObjCType: type at: &data];
  return self;
}

@end

