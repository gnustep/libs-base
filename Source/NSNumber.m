/* NSNumber - Object encapsulation of numbers
    
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: Mar 1995

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

#include <string.h>
#include <config.h>
#include <base/preface.h>
#include <base/fast.x>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSCoder.h>

@interface NSNumber (Private)
- (int) _typeOrder;
@end

@implementation NSNumber

static NSMapTable	*numberMap;
static BOOL		multiThreaded = NO;
static NSNumber		*boolN;
static NSNumber		*boolY;
static NSNumber		*smallIntegers[GS_SMALL * 2 + 1];
static unsigned int	smallHashes[GS_SMALL * 2 + 1];

/*
 * Cache info for each number class.  The caches for all the standard types
 * of number are built in the NSNumber +initialize method - which is protected
 * by locks.  Therafter, in a multi-threaded system we may waste some memory
 * in order to get speed.
 */
GSNumberInfo*
GSNumberInfoFromObject(NSNumber *o)
{
  Class		c;
  GSNumberInfo	*info;

  c = fastClass(o);
  info = (GSNumberInfo*)NSMapGet (numberMap, (void*)c);
  if (info == 0)
    {
      info = (GSNumberInfo*)objc_malloc(sizeof(GSNumberInfo));
      info->typeOrder = [o _typeOrder];
      info->compValue = (NSComparisonResult (*)(NSNumber*, SEL, NSNumber*))
	[o methodForSelector: @selector(compare:)];
      info->boolValue = (BOOL (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(boolValue)];
      info->charValue = (char (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(charValue)];
      info->unsignedCharValue = (unsigned char (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(unsignedCharValue)];
      info->shortValue = (short (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(shortValue)];
      info->unsignedShortValue = (unsigned short (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(unsignedShortValue)];
      info->intValue = (int (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(intValue)];
      info->unsignedIntValue = (unsigned int (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(unsignedIntValue)];
      info->longValue = (long (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(longValue)];
      info->unsignedLongValue = (unsigned long (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(unsignedLongValue)];
      info->longLongValue = (long long (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(longLongValue)];
      info->unsignedLongLongValue = (unsigned long long (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(unsignedLongLongValue)];
      info->floatValue = (float (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(floatValue)];
      info->doubleValue = (double (*)(NSNumber*, SEL))
	[o methodForSelector: @selector(doubleValue)];

      if (multiThreaded == YES)
	{
	  NSMapTable	*table;

	  /*
	   * Memory leak for efficiency - the old map table is never
	   * deallocated, so we don't have to do any locking.
	   */
	  table = NSCopyMapTableWithZone(numberMap, NSDefaultMallocZone());
	  NSMapInsert(table, (void*)c, (void*)info);
	  numberMap = table;
	}
      else
	{
	  NSMapInsert(numberMap, (void*)c, (void*)info);
	}
    }
  return info;
}

unsigned int
GSSmallHash(int n)
{
  return smallHashes[n + GS_SMALL];
}

static Class	abstractClass;
static Class	boolNumberClass;
static Class	charNumberClass;
static Class	uCharNumberClass;
static Class	shortNumberClass;
static Class	uShortNumberClass;
static Class	intNumberClass;
static Class	uIntNumberClass;
static Class	longNumberClass;
static Class	uLongNumberClass;
static Class	longLongNumberClass;
static Class	uLongLongNumberClass;
static Class	floatNumberClass;
static Class	doubleNumberClass;

+ (void) _becomeThreaded: (NSNotification*)notification
{
  multiThreaded = YES;
}

+ (void) initialize
{
  if (self == [NSNumber class])
    {
      BOOL	boolean;
      int	integer;
      unsigned	(*hasher)(NSNumber*, SEL);

      abstractClass = self;
      hasher = (unsigned (*)(NSNumber*, SEL))
	[self instanceMethodForSelector: @selector(hash)];

      /*
       * Create cache for per-subclass method implementations etc.
       */
      numberMap = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
	NSOwnedPointerMapValueCallBacks, 0);

      /*
       * cache standard subclass info.
       */
      boolNumberClass = [NSBoolNumber class];
      charNumberClass = [NSCharNumber class];
      uCharNumberClass = [NSUCharNumber class];
      shortNumberClass = [NSShortNumber class];
      uShortNumberClass = [NSUShortNumber class];
      intNumberClass = [NSIntNumber class];
      uIntNumberClass = [NSUIntNumber class];
      longNumberClass = [NSLongNumber class];
      uLongNumberClass = [NSULongNumber class];
      longLongNumberClass = [NSLongLongNumber class];
      uLongLongNumberClass = [NSULongLongNumber class];
      floatNumberClass = [NSFloatNumber class];
      doubleNumberClass = [NSDoubleNumber class];

      /*
       * cache bool values.
       */
      boolN = (NSNumber*)NSAllocateObject(boolNumberClass, 0,
	NSDefaultMallocZone());
      boolean = NO;
      boolN = [boolN initWithBytes: &boolean objCType: NULL];

      boolY = (NSNumber*)NSAllocateObject(boolNumberClass, 0,
	NSDefaultMallocZone());
      boolean = YES;
      boolY = [boolY initWithBytes: &boolean objCType: NULL];

      /*
       * cache small integer values.
       */
      for (integer = -GS_SMALL; integer <= GS_SMALL; integer++)
	{
	  NSNumber	*num;

	  num = (NSNumber*)NSAllocateObject(intNumberClass, 0,
	    NSDefaultMallocZone());
	  num = [num initWithBytes: &integer objCType: NULL];
	  smallIntegers[integer + GS_SMALL] = num;
	  smallHashes[integer + GS_SMALL] = (*hasher)(num, @selector(hash));
	}

      /*
       * Make sure we know if we are multi-threaded so that if the caches
       * need to grow, we do it by copying and replacing without deleting
       * an old cache that may be in use by another thread.
       */
      if ([NSThread isMultiThreaded])
	{
	  [self _becomeThreaded: nil];
	}
      else
	{
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	       selector: @selector(_becomeThreaded:)
		   name: NSWillBecomeMultiThreadedNotification
		 object: nil];
	}
    }
}

/* Returns the concrete class associated with the type encoding. Note 
   that we don't allow NSNumber to instantiate any class but its own
   concrete subclasses (see check at end of method) */
+ (Class) valueClassWithObjCType: (const char*)type
{
  Class theClass = Nil;

  switch (*type)
    {
      case _C_CHR: 	return charNumberClass;
      case _C_UCHR: 	return uCharNumberClass;
      case _C_SHT: 	return shortNumberClass;
      case _C_USHT: 	return uShortNumberClass;
      case _C_INT: 	return intNumberClass;
      case _C_UINT:	return uIntNumberClass;
      case _C_LNG:	return longNumberClass;
      case _C_ULNG:	return uLongNumberClass;
#ifdef	_C_LNGLNG
      case _C_LNGLNG:
#else
      case 'q':
#endif
	return longLongNumberClass;
#ifdef	_C_ULNGLNG
      case _C_ULNGLNG:
#else
      case 'Q':
#endif
	return uLongLongNumberClass;
      case _C_FLT:	return floatNumberClass;
      case _C_DBL:	return doubleNumberClass;
      default: 
	break;
    }

  if (theClass == Nil && self == abstractClass)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Invalid number type"];
	/* NOT REACHED */
    }
  else if (theClass == Nil)
    {
      theClass = [super valueClassWithObjCType: type];
    }
  return theClass;
}

+ (NSNumber*) numberWithBool: (BOOL)value
{
  if (value == YES)
    {
      return boolY;
    }
  else
    {
      return boolN;
    }
}

+ (NSNumber*) numberWithChar: (char)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(charNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithDouble: (double)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(doubleNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithFloat: (float)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(floatNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithInt: (int)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(intNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithLong: (long)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(longNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithLongLong: (long long)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(longLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithShort: (short)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(shortNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithUnsignedChar: (unsigned char)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(uCharNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithUnsignedInt: (unsigned int)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(uIntNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithUnsignedLong: (unsigned long)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(uLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithUnsignedLongLong: (unsigned long long)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(uLongLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber*) numberWithUnsignedShort: (unsigned short)value
{
  NSNumber	*theObj;

  if (value <= GS_SMALL)
    {
      return smallIntegers[value + GS_SMALL];
    }
  theObj = (NSNumber*)NSAllocateObject(uShortNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueFromString: (NSString*)string
{
  /* FIXME: implement this better */
  const char *str;

  str = [string cString];
  if (strchr(str, '.') >= 0 || strchr(str, 'e') >= 0 
      || strchr(str, 'E') >= 0)
    return [NSNumber numberWithDouble: atof(str)];
  else if (strchr(str, '-') >= 0)
    return [NSNumber numberWithInt: atoi(str)];
  else
    return [NSNumber numberWithUnsignedInt: atoi(str)];
  return [NSNumber numberWithInt: 0];
}

- (id) initWithBool: (BOOL)value
{
  NSDeallocateObject(self);
  if (value == YES)
    {
      self = boolY;
    }
  else
    {
      self = boolN;
    }
  return RETAIN(self);
}

- (id) initWithChar: (char)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(charNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithDouble: (double)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(doubleNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithFloat: (float)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(floatNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithInt: (int)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(intNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithLong: (long)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(longNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithLongLong: (long long)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(longLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithShort: (short)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL && value >= -GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(shortNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithUnsignedChar: (unsigned char)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(uCharNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithUnsignedInt: (unsigned int)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(uIntNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithUnsignedLong: (unsigned long)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(uLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithUnsignedLongLong: (unsigned long long)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(uLongLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) initWithUnsignedShort: (unsigned short)value
{
  NSDeallocateObject(self);
  if (value <= GS_SMALL)
    {
      return RETAIN(smallIntegers[value + GS_SMALL]);
    }
  self = (NSNumber*)NSAllocateObject(uShortNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id) copy
{
  return RETAIN(self);
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

- (NSString*) description
{
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/* All the rest of these methods must be implemented by a subclass */
- (BOOL) boolValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (char) charValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (double) doubleValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (float) floatValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (int) intValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (long long) longLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (long) longValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (short) shortValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSString*) stringValue
{
  return [self descriptionWithLocale: nil];
}

- (unsigned char) unsignedCharValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned int) unsignedIntValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned long long) unsignedLongLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned long) unsignedLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned short) unsignedShortValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSComparisonResult) compare: (NSNumber*)other
{
  GSNumberInfo	*otherInfo;
  GSNumberInfo	*myInfo;
  double	otherValue;
  double	myValue;

  myInfo = GSNumberInfoFromObject(self);
  otherInfo = GSNumberInfoFromObject(other);
  myValue = (*(myInfo->doubleValue))(self, @selector(doubleValue));
  otherValue = (*(otherInfo->doubleValue))(other, @selector(doubleValue));
  
  if (myValue == otherValue)
    {
      return NSOrderedSame;
    }
  else if (myValue < otherValue)
    {
      return  NSOrderedAscending;
    }
  else
    {
      return NSOrderedDescending;
    }
}

/*
 * Because of the rule that two numbers which are the same according to
 * [-isEqual: ] must generate the same hash, we must generate the hash
 * from the most general representation of the number.
 * NB. Don't change this without changing the matching function in
 * NSConcreteNumber.m
 */
- (unsigned) hash
{
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  unsigned	hash = 0;
  unsigned	i;

  val.d = [self doubleValue];
  for (i = 0; i < sizeof(double); i++)
    {
      hash += val.c[i];
    }
  return hash;
}

- (BOOL) isEqual: o
{
  if (o == self)
    {
      return YES;
    }
  if (o != nil && fastIsInstance(o)
    && fastInstanceIsKindOfClass(o, abstractClass))
    {
      return [self isEqualToNumber: (NSNumber*)o];
    }
  return [super isEqual: o];
}

- (BOOL) isEqualToNumber: (NSNumber*)o
{
  if (o == self)
    {
      return YES;
    }
  if ([self compare: o] == NSOrderedSame)
    {
      return YES;
    }
  return NO;
}

// NSCoding (done by subclasses)
- (void) encodeWithCoder: (NSCoder*)coder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (int) _typeOrder
{
  return 12;
}

@end
