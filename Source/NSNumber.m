/** Implementation of NSNumber for GNUStep
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  David Chisnall
   Partial rewrite:  Richard Frith-Macdonld <rfm@gnu.org>
    (to compile on gnu/linux and mswindows, to meet coding/style standards)
   
   Date: February 2010

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

   */


#import "common.h"

#if	defined(HAVE_STDINT_H)
#include	<stdint.h>
#endif
#if	defined(HAVE_LIMITS_H)
#include	<limits.h>
#endif

#if	!defined(LLONG_MAX)
#  if	defined(__LONG_LONG_MAX__)
#    define LLONG_MAX __LONG_LONG_MAX__
#    define LLONG_MIN	(-LLONG_MAX-1)
#    define ULLONG_MAX	(LLONG_MAX * 2ULL + 1)
#  else
#    error Neither LLONG_MAX nor __LONG_LONG_MAX__ found
#  endif
#endif


#import "Foundation/NSCoder.h"
#import "Foundation/NSDecimalNumber.h"
#import "Foundation/NSException.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

/*
 * NSNumber implementation.  This matches the behaviour of Apple's
 * implementation.  Values in the range -1 to 12 inclusive are mapped to
 * singletons.  All other values are mapped to the smallest signed value that
 * will store them, unless they are greater than LLONG_MAX, in which case
 * they are stored in an unsigned long long.
 */

@interface NSSignedIntegerNumber : NSNumber
@end

@interface NSIntNumber : NSSignedIntegerNumber
{
@public
  int value;
}
@end

@interface NSLongLongNumber : NSSignedIntegerNumber
{
@public
  long long int value;
}
@end

@interface NSUnsignedLongLongNumber : NSNumber
{
@public
  unsigned long long int value;
}
@end

// The value ivar in all of the concrete classes contains the real value.
#define VALUE value
#define COMPARE(value, other) \
if (value < other)\
  {\
    return NSOrderedAscending;\
  }\
if (value > other)\
  {\
    return NSOrderedDescending;\
  }\
return NSOrderedSame;

@implementation NSSignedIntegerNumber
- (NSComparisonResult) compare: (NSNumber*)aNumber
{
  if (aNumber == self)
    {
      return NSOrderedSame;
    }
  if (aNumber == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }

  switch ([aNumber objCType][0])
    {
      /* For cases smaller than or equal to an int, we could get the int
       * value and compare.
       */
      case 'c':
      case 'C':
      case 's':
      case 'S':
      case 'i':
      case 'I':
      case 'l':
      case 'L':
      case 'q':
	{
	  long long value = [self longLongValue];
	  long long other = [aNumber longLongValue];

	  COMPARE (value, other);
	}
      case 'Q':
	{
	  unsigned long long other;
	  unsigned long long value;
	  long long v;

	  /* According to the C type promotion rules, we should cast this to
	   * an unsigned long long, however Apple's code does not do this.
	   * Instead, it performs a real comparison.
	   */
	  v = [self longLongValue];

	  /* If this value is less than 0, then it is less than any value
	   * that can possibly be stored in an unsigned value.
	   */
	  if (v < 0)
	    {
	      return NSOrderedAscending;
	    }

	  other = [aNumber unsignedLongLongValue];
	  value = (unsigned long long) v;
	  COMPARE (value, other);
	}
      case 'f':
      case 'd':
	{
	  double other = [aNumber doubleValue];
	  double value = [self doubleValue];

	  COMPARE (value, other);
	}
      default:
	[NSException raise: NSInvalidArgumentException
		    format: @"unrecognised type for compare:"];
    }
  return 0;			// Not reached.
}
@end

@implementation NSIntNumber
#define FORMAT @"%i"
#include "NSNumberMethods.h"
@end

@implementation NSLongLongNumber
#define FORMAT @"%lli"
#include "NSNumberMethods.h"
@end

@implementation NSUnsignedLongLongNumber
#define FORMAT @"%llu"
#include "NSNumberMethods.h"
- (NSComparisonResult) compare: (NSNumber*)aNumber
{
  if (aNumber == self)
    {
      return NSOrderedSame;
    }
  if (aNumber == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }

  switch ([aNumber objCType][0])
    {
      /* For cases smaller than or equal to an int, we could get the int
       * value and compare.
       */
      case 'c':
      case 'C':
      case 's':
      case 'S':
      case 'i':
      case 'I':
      case 'l':
      case 'L':
      case 'q':
	{
	  long long other = [aNumber longLongValue];

	  if (other < 0)
	    {
	      return NSOrderedDescending;
	    }
	  COMPARE (value, ((unsigned long long) other));
	}
      case 'Q':
	{
	  unsigned long long other = [aNumber unsignedLongLongValue];

	  COMPARE (value, other);
	}
      case 'f':
      case 'd':
	{
	  double other = [aNumber doubleValue];

	  COMPARE (((double) value), other);
	}
      default:
	[NSException raise: NSInvalidArgumentException
		    format: @"unrecognised type for compare:"];
    }
  return 0;			// Not reached.
}
@end

/*
 * Abstract superclass for floating point numbers.
 */
@interface NSFloatingPointNumber : NSNumber
@end
 
@implementation NSFloatingPointNumber
/* For floats, the type promotion rules say that we always promote to a
 * floating point type, even if the other value is really an integer.
 */
- (BOOL) isEqualToNumber: (NSNumber*)aNumber
{
  return [self doubleValue] == [aNumber doubleValue];
}

- (NSComparisonResult) compare: (NSNumber*)aNumber
{
  double other;
  double value;

  if (aNumber == self)
    {
      return NSOrderedSame;
    }
  if (aNumber == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  other = [aNumber doubleValue];
  value = [self doubleValue];
  COMPARE (value, other);
}
@end

@interface NSFloatNumber : NSFloatingPointNumber
{
@public
  float value;
}
@end

@implementation NSFloatNumber
#define FORMAT @"%0.7g"
#include "NSNumberMethods.h"
@end

@interface NSDoubleNumber : NSFloatingPointNumber
{
@public
  double value;
}
@end

@implementation NSDoubleNumber
#define FORMAT @"%0.16g"
#include "NSNumberMethods.h"
@end

@implementation NSNumber

/*
 * Numbers from -1 to 12 inclusive that are reused.
 */
static NSNumber *ReusedInstances[14];
static Class NSNumberClass;
static Class NSIntNumberClass;
static Class NSLongLongNumberClass;
static Class NSUnsignedLongLongNumberClass;
static Class NSFloatNumberClass;
static Class NSDoubleNumberClass;

+ (void) initialize
{
  int i;

  if ([NSNumber class] != self)
    {
      return;
    }

  NSNumberClass = self;
  NSIntNumberClass = [NSIntNumber class];
  NSLongLongNumberClass = [NSLongLongNumber class];
  NSUnsignedLongLongNumberClass = [NSUnsignedLongLongNumber class];
  NSFloatNumberClass = [NSFloatNumber class];
  NSDoubleNumberClass = [NSDoubleNumber class];

  for (i = 0; i < 14; i++)
    {
      NSIntNumber *n = NSAllocateObject (NSIntNumberClass, 0,[self zone]);

      n->value = i - 1;
      ReusedInstances[i] = n;
    }
}

- (const char *) objCType
{
  /* All concrete NSNumber types must implement this so we know which oen
   * they are.
   */
  [self subclassResponsibility: _cmd];
  return NULL;			// Not reached
}

- (BOOL) isEqualToNumber: (NSNumber*)aNumber
{
  return [self compare: aNumber] == NSOrderedSame;
}

- (BOOL) isEqual: (id)anObject
{
  if ([anObject isKindOfClass: NSNumberClass])
    {
      return [self isEqualToNumber: anObject];
    }
  return [super isEqual: anObject];
}

- (BOOL) isEqualToValue: (NSValue*)aValue
{
  if ([aValue isKindOfClass: NSNumberClass])
    {
      return [self isEqualToNumber: (NSNumber*)aValue];
    }
  return NO;
}

- (unsigned) hash
{
  return (unsigned)[self doubleValue];
}

- (NSString*) stringValue
{
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (id)aLocale
{
  [self subclassResponsibility: _cmd];
  return nil;			// Not reached
}

- (NSComparisonResult) compare: (NSNumber*)aNumber
{
  [self subclassResponsibility: _cmd];
  return 0;			// Not reached
}

#define INTEGER_MACRO(type, ignored, name) \
- (id) initWith ## name: (type)aValue \
{\
  [self release];\
  return [[NSNumberClass numberWith ## name: aValue] retain];\
}

#include "GSNumberTypes.h"

/*
 * Macro for checking whether this value is the same as one of the singleton
 * instances.  
 */
#define CHECK_SINGLETON(aValue) \
if (aValue >= -1 && aValue <= 12)\
{\
  return ReusedInstances[aValue+1];\
}

+ (NSNumber *) numberWithBool: (BOOL)aValue
{
  CHECK_SINGLETON (((signed char) aValue));
  return [self numberWithInt: aValue];
  // Not reached (BOOL is always 0 or 1)
}

+ (NSNumber *) numberWithChar: (signed char)aValue
{
  return [self numberWithInt: aValue];
}

+ (NSNumber *) numberWithUnsignedChar: (unsigned char)aValue
{
  return [self numberWithInt: aValue];
}

+ (NSNumber *) numberWithShort: (short)aValue
{
  return [self numberWithInt: aValue];
}

+ (NSNumber *) numberWithUnsignedShort: (unsigned short)aValue
{
  return [self numberWithInt: aValue];
}

+ (NSNumber *) numberWithInt: (int)aValue
{
  NSIntNumber *n;

  CHECK_SINGLETON (aValue);
  n = NSAllocateObject (NSIntNumberClass, 0,[self zone]);
  n->value = aValue;
  return n;
}

+ (NSNumber *) numberWithUnsignedInt: (unsigned int)aValue
{
  CHECK_SINGLETON (aValue);

  if (aValue < (unsigned int) INT_MAX)
    {
      return [self numberWithInt: (int)aValue];
    }
  return [self numberWithLongLong: aValue];
}

+ (NSNumber *) numberWithLong: (long)aValue
{
  return [self numberWithLongLong: aValue];
}

+ (NSNumber *) numberWithUnsignedLong: (unsigned long)aValue
{
  return [self numberWithUnsignedLongLong: aValue];
}

+ (NSNumber *) numberWithLongLong: (long long)aValue
{
  NSLongLongNumber *n;

  CHECK_SINGLETON (aValue);
  if (aValue < (long long)INT_MAX && aValue > (long long)INT_MIN)
    {
      return [self numberWithInt: (int) aValue];
    }
  n = NSAllocateObject (NSLongLongNumberClass, 0,[self zone]);
  n->value = aValue;
  return n;
}

+ (NSNumber *) numberWithUnsignedLongLong: (unsigned long long)aValue
{
  NSUnsignedLongLongNumber *n;

  if (aValue < (unsigned long long) LLONG_MAX)
    {
      return [self numberWithLongLong: (long long) aValue];
    }
  n = NSAllocateObject (NSUnsignedLongLongNumberClass, 0,[self zone]);
  n->value = aValue;
  return n;
}

+ (NSNumber *) numberWithFloat: (float)aValue
{
  NSFloatNumber *n = NSAllocateObject (NSFloatNumberClass, 0,[self zone]);

  n->value = aValue;
  return n;
}

+ (NSNumber *) numberWithDouble: (double)aValue
{
  NSDoubleNumber *n = NSAllocateObject (NSDoubleNumberClass, 0,[self zone]);

  n->value = aValue;
  return n;
}

+ (NSNumber *) numberWithInteger: (NSInteger)aValue
{
  // Compile time constant; the compiler will remove this conditional
  if (sizeof (NSInteger) == sizeof (int))
    {
      return [self numberWithInt: aValue];
    }
  return [self numberWithLongLong: aValue];
}

+ (NSNumber *) numberWithUnsignedInteger: (NSUInteger)aValue
{
  // Compile time constant; the compiler will remove this conditional
  if (sizeof (NSUInteger) == sizeof (unsigned int))
    {
      return [self numberWithUnsignedInt: aValue];
    }
  return [self numberWithUnsignedLongLong: aValue];
}

- (id) initWithBytes: (const void *)
      value objCType: (const char *)type
{
  switch (type[0])
    {
      case 'c':
	return [self initWithInteger: *(char *) value];
      case 'C':
	return [self initWithInteger: *(unsigned char *) value];
      case 's':
	return [self initWithInteger: *(short *) value];
      case 'S':
	return [self initWithInteger: *(unsigned short *) value];
      case 'i':
	return [self initWithInteger: *(int *) value];
      case 'I':
	return [self initWithInteger: *(unsigned int *) value];
      case 'l':
	return [self initWithLong: *(long *) value];
      case 'L':
	return [self initWithUnsignedLong: *(unsigned long *) value];
      case 'q':
	return [self initWithLongLong: *(long long *) value];
      case 'Q':
	return [self initWithUnsignedLongLong: *(unsigned long long *) value];
      case 'f':
	return [self initWithFloat: *(float *) value];
      case 'd':
	return [self initWithDouble: *(double *) value];
    }
  return [super initWithBytes: value objCType: type];
}

- (void *) pointerValue
{
  return (void *)[self unsignedIntegerValue];
}

- (id) replacementObjectForPortCoder: (NSPortCoder *) encoder
{
  return self;
}

- (Class) classForCoder
{
  return NSNumberClass;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
  const char *type = [self objCType];
  char buffer[16];

  [coder encodeValueOfObjCType: @encode (char) at: type];
  /* The most we currently store in an NSNumber is 8 bytes (double or long
   * long), but we may add support for vectors or long doubles in future, so
   * make this 16 bytes now so stuff doesn't break in fun and exciting ways
   * later.
   */
  [self getValue: buffer];
  [coder encodeValueOfObjCType: type at: buffer];
}

- (id) copyWithZone: (NSZone *) aZone
{
  if (NSShouldRetainWithZone (self, aZone))
    {
      return RETAIN (self);
    }
  else
    {
      return NSCopyObject (self, 0, aZone);
    }
}

- (id) initWithCoder: (NSCoder *) coder
{
  char type[2] = { 0 };
  char buffer[16];

  [coder decodeValueOfObjCType: @encode (char) at: type];
  [coder decodeValueOfObjCType: type at: buffer];
  return [self initWithBytes: buffer objCType: type];
}

- (NSString *) description
{
  return [self stringValue];
}

/* Return nil for an NSNumber that is allocated and initalized without
 * providing a real value.  Yes, this seems weird, but it is actually what
 * happens on OS X.
 */
- (id) init
{
  [self release];
  return nil;
}

/* Stop the compiler complaining about unimplemented methods.  Throwing an
 * exception here matches OS X behaviour, although they throw an invalid
 * argument exception.
 */
#define INTEGER_MACRO(type, name, ignored) \
- (type) name ## Value\
{\
  [self subclassResponsibility: _cmd];\
  return (type)0;\
}

#include "GSNumberTypes.h"
- (NSDecimal) decimalValue
{
  NSDecimalNumber *dn;
  NSDecimal decimal;

  dn = [[NSDecimalNumber alloc] initWithString: [self stringValue]];
  decimal = [dn decimalValue];
  [dn release];
  return decimal;
}

@end
