# line 1 "NSConcreteNumber.m"	/* So gdb knows which file we are in */
/* NSConcreteNumber - Object encapsulation of numbers
    
   Copyright (C) 1993, 1994, 1996, 2000 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995
   Rewrite: Richard Frith-Macdonald <rfm@gnu.org>
   Date: Mar 2000

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
#include <base/preface.h>
#include <Foundation/NSObjCRuntime.h>
#include <GSConfig.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSCoder.h>

/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 12 cooresponding to each number type */
#if TYPE_ORDER == 0
#  define NumberTemplate	NSBoolNumber
#  define TYPE_FORMAT	@"%u"
#  define TYPE_TYPE	BOOL
#elif TYPE_ORDER == 1
#  define NumberTemplate	NSCharNumber
#  define TYPE_FORMAT	@"%c"
#  define TYPE_TYPE	signed char
#elif TYPE_ORDER == 2
#  define NumberTemplate	NSUCharNumber
#  define TYPE_FORMAT	@"%c"
#  define TYPE_TYPE	unsigned char
#elif TYPE_ORDER == 3
#  define NumberTemplate	NSShortNumber
#  define TYPE_FORMAT	@"%hd"
#  define TYPE_TYPE	signed short
#elif TYPE_ORDER == 4
#  define NumberTemplate	NSUShortNumber
#  define TYPE_FORMAT	@"%hu"
#  define TYPE_TYPE	unsigned short
#elif TYPE_ORDER == 5
#  define NumberTemplate	NSIntNumber
#  define TYPE_FORMAT	@"%d"
#  define TYPE_TYPE	signed int
#elif TYPE_ORDER == 6
#  define NumberTemplate	NSUIntNumber
#  define TYPE_FORMAT	@"%u"
#  define TYPE_TYPE	unsigned int
#elif TYPE_ORDER == 7
#  define NumberTemplate	NSLongNumber
#  define TYPE_FORMAT	@"%ld"
#  define TYPE_TYPE	signed long
#elif TYPE_ORDER == 8
#  define NumberTemplate	NSULongNumber
#  define TYPE_FORMAT	@"%lu"
#  define TYPE_TYPE	unsigned long
#elif TYPE_ORDER == 9
#  define NumberTemplate	NSLongLongNumber
#  define TYPE_FORMAT	@"%lld"
#  define TYPE_TYPE	signed long long
#elif TYPE_ORDER == 10
#  define NumberTemplate	NSULongLongNumber
#  define TYPE_FORMAT	@"%llu"
#  define TYPE_TYPE	unsigned long long
#elif TYPE_ORDER == 11
#  define NumberTemplate	NSFloatNumber
#  define TYPE_FORMAT	@"%f"
#  define TYPE_TYPE	float
#elif TYPE_ORDER == 12
#  define NumberTemplate	NSDoubleNumber
#  define TYPE_FORMAT	@"%g"
#  define TYPE_TYPE	double
#endif

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
  return (BOOL)data;
}

- (signed char) charValue
{
  return (signed char)data;
}

- (double) doubleValue
{
  return (double)data;
}

- (float) floatValue
{
  return (float)data;
}

- (signed int) intValue
{
  return (signed int)data;
}

- (signed long long) longLongValue
{
  return (signed long long)data;
}

- (signed long) longValue
{
  return (signed long)data;
}

- (signed short) shortValue
{
  return (signed short)data;
}

- (unsigned char) unsignedCharValue
{
  return (unsigned char)data;
}

- (unsigned int) unsignedIntValue
{
  return (unsigned int)data;
}

- (unsigned long long) unsignedLongLongValue
{
  return (unsigned long long)data;
}

- (unsigned long) unsignedLongValue
{
  return (unsigned long)data;
}

- (unsigned short) unsignedShortValue
{
  return (unsigned short)data;
}

- (NSComparisonResult) compare: (NSNumber*)other
{
  if (other == self)
    {
      return NSOrderedSame;
    }
  else if (other == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(other);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(other, @selector(getValue:), (void*)&oData);
	      if (data == oData)
		return NSOrderedSame;
	      else if (data < oData)
		return NSOrderedAscending;
	      else
		return NSOrderedDescending;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"number type value for comparison"];
	    return NSOrderedSame;
	}
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

- (id) copy
{
  if (NSShouldRetainWithZone(self, NSDefaultMallocZone()))
    return RETAIN(self);
  else
    return NSCopyObject(self, 0, NSDefaultMallocZone());
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject(self, 0, zone);
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
  memcpy(value, &data, objc_sizeof_type(@encode(TYPE_TYPE)));
}

- (const char*) objCType
{
  return @encode(TYPE_TYPE);
}

- (id) nonretainedObjectValue
{
  return (id)(void*)&data;
}

- (void*) pointerValue
{
  return (void*)&data;
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

- (void) encodeWithCoder: (NSCoder*)coder
{
  [coder encodeValueOfObjCType: @encode(TYPE_TYPE) at: &data];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(TYPE_TYPE) at: &data];
  return self;
}

@end

