/* NSNumber - Object encapsulation of numbers
    
   Copyright (C) 1993, 1994, 1996, 2000 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: Mar 1995
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

#include <string.h>
#include <config.h>
#include <base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSObjCRuntime.h>

@implementation NSNumber

static NSMapTable	*numberMap;
static BOOL		multiThreaded = NO;
static NSNumber		*boolN;
static NSNumber		*boolY;
static NSNumber		*smallIntegers[GS_SMALL * 2 + 1];
static unsigned int	smallHashes[GS_SMALL * 2 + 1];

/*
 * Cache info for each number class.
 * In a multi-threaded system we may waste some memory in order to get speed.
 */
GSNumberInfo*
GSNumberInfoFromObject(NSNumber *o)
{
  Class		c;
  GSNumberInfo	*info;

  if (o == nil)
    return 0;
  c = GSObjCClass(o);
  info = (GSNumberInfo*)NSMapGet (numberMap, (void*)c);
  if (info == 0)
    {
      const char	*t = [o objCType];
      int		order = -1;

      if (strlen(t) != 1)
	{
	  NSLog(@"Invalid return value (%s) from [%@ objCType]", t, c);
	}
      else
	{
	  switch (*t)
	    {
	      case 'c':	order = 1;	break;
	      case 'C':	order = 2;	break;
	      case 's':	order = 3;	break;
	      case 'S':	order = 4;	break;
	      case 'i':	order = 5;	break;
	      case 'I':	order = 6;	break;
	      case 'l':	order = 7;	break;
	      case 'L':	order = 8;	break;
	      case 'q':	order = 9;	break;
	      case 'Q':	order = 10;	break;
	      case 'f':	order = 11;	break;
	      case 'd':	order = 12;	break;
	      default:
		NSLog(@"Invalid return value (%s) from [%@ objCType]", t, c);
		break;
	    }
	}
      info = (GSNumberInfo*)NSZoneMalloc(NSDefaultMallocZone(),
	(sizeof(GSNumberInfo)));
      info->typeLevel = order;

      info->getValue = (void (*)(NSNumber*, SEL, void*))
	[o methodForSelector: @selector(getValue:)];

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
      GSNumberInfo	*info;
      CREATE_AUTORELEASE_POOL(pool);

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
      info = GSNumberInfoFromObject(AUTORELEASE([boolNumberClass alloc]));
      /*
       * Set the typeLevel for a boolean to be '0'
       */
      info->typeLevel = 0;
      charNumberClass = [NSCharNumber class];
      GSNumberInfoFromObject(AUTORELEASE([charNumberClass alloc]));
      uCharNumberClass = [NSUCharNumber class];
      GSNumberInfoFromObject(AUTORELEASE([uCharNumberClass alloc]));
      shortNumberClass = [NSShortNumber class];
      GSNumberInfoFromObject(AUTORELEASE([shortNumberClass alloc]));
      uShortNumberClass = [NSUShortNumber class];
      GSNumberInfoFromObject(AUTORELEASE([uShortNumberClass alloc]));
      intNumberClass = [NSIntNumber class];
      GSNumberInfoFromObject(AUTORELEASE([intNumberClass alloc]));
      uIntNumberClass = [NSUIntNumber class];
      GSNumberInfoFromObject(AUTORELEASE([uIntNumberClass alloc]));
      longNumberClass = [NSLongNumber class];
      GSNumberInfoFromObject(AUTORELEASE([longNumberClass alloc]));
      uLongNumberClass = [NSULongNumber class];
      GSNumberInfoFromObject(AUTORELEASE([uLongNumberClass alloc]));
      longLongNumberClass = [NSLongLongNumber class];
      GSNumberInfoFromObject(AUTORELEASE([longLongNumberClass alloc]));
      uLongLongNumberClass = [NSULongLongNumber class];
      GSNumberInfoFromObject(AUTORELEASE([uLongLongNumberClass alloc]));
      floatNumberClass = [NSFloatNumber class];
      GSNumberInfoFromObject(AUTORELEASE([floatNumberClass alloc]));
      doubleNumberClass = [NSDoubleNumber class];
      GSNumberInfoFromObject(AUTORELEASE([doubleNumberClass alloc]));

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
      RELEASE(pool);
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

+ (NSNumber*) numberWithChar: (signed char)value
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

+ (NSNumber*) numberWithInt: (signed int)value
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

+ (NSNumber*) numberWithLong: (signed long)value
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

+ (NSNumber*) numberWithLongLong: (signed long long)value
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

+ (NSNumber*) numberWithShort: (signed short)value
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

/*
 * A moderately sane default init method - a zero value integer.
 */
- (id) init
{
  return [self initWithInt: 0];
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

- (id) initWithChar: (signed char)value
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

- (id) initWithInt: (signed int)value
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

- (id) initWithLong: (signed long)value
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

- (id) initWithLongLong: (signed long long)value
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

- (id) initWithShort: (signed short)value
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

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject(self, 0, zone);
}

- (NSString*) description
{
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  if (GSObjCClass(self) == abstractClass)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"descriptionWithLocale: for abstract NSNumber"];
      return nil;
    }
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    return [self boolValue] ? @"YES" : @"NO";
	  case 1:
	    return [NSString stringWithFormat: @"%c",
	      [self charValue]];
	  case 2:
	    return [NSString stringWithFormat: @"%c",
	      [self unsignedCharValue]];
	  case 3:
	    return [NSString stringWithFormat: @"%hd",
	      [self shortValue]];
	  case 4:
	    return [NSString stringWithFormat: @"%hu",
	      [self unsignedShortValue]];
	  case 5:
	    return [NSString stringWithFormat: @"%d",
	      [self intValue]];
	  case 6:
	    return [NSString stringWithFormat: @"%u",
	      [self unsignedIntValue]];
	  case 7:
	    return [NSString stringWithFormat: @"%ld",
	      [self longValue]];
	  case 8:
	    return [NSString stringWithFormat: @"%lu",
	      [self unsignedLongValue]];
	  case 9:
	    return [NSString stringWithFormat: @"%lld",
	      [self longLongValue]];
	  case 10:
	    return [NSString stringWithFormat: @"%llu",
	      [self unsignedLongLongValue]];
	  case 11:
	    return [NSString stringWithFormat: @"%f",
	      [self floatValue]];
	  case 12:
	    return [NSString stringWithFormat: @"%g",
	      [self doubleValue]];
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for description"];
	    return nil;
	}
    }
}

/* All the rest of these methods must be implemented by a subclass */
- (BOOL) boolValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get boolValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (signed char) charValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get charValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (double) doubleValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get doubleValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (float) floatValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get floatValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (signed int) intValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get intValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (signed long long) longLongValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get longLongValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (signed long) longValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get longValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (signed short) shortValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get shortValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (NSString*) stringValue
{
  return [self descriptionWithLocale: nil];
}

- (unsigned char) unsignedCharValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get unsignedCharrValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (unsigned int) unsignedIntValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get unsignedIntValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (unsigned long long) unsignedLongLongValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get unsignedLongLongValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (unsigned long) unsignedLongValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get unsignedLongValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (unsigned short) unsignedShortValue
{
  if (GSObjCClass(self) == abstractClass)
    [NSException raise: NSInternalInconsistencyException
		format: @"get unsignedShortValue from abstract NSNumber"];
  else
    {
      GSNumberInfo	*info = GSNumberInfoFromObject(self);

      switch (info->typeLevel)
	{
	  case 0:
	    {
	      BOOL	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 1:
	    {
	      signed char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 2:
	    {
	      unsigned char	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 3:
	    {
	      signed short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 4:
	    {
	      unsigned short	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 5:
	    {
	      signed int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 6:
	    {
	      unsigned int	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 7:
	    {
	      signed long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 8:
	    {
	      unsigned long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 9:
	    {
	      signed long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 10:
	    {
	      unsigned long long	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 11:
	    {
	      float	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  case 12:
	    {
	      double	oData;

	      (*(info->getValue))(self, @selector(getValue:), &oData);
	      return oData;
	    }
	  default:
	    [NSException raise: NSInvalidArgumentException
			format: @"unknown number type value for get"];
	}
    }
  return 0;
}

- (NSComparisonResult) compare: (NSNumber*)other
{
  double	otherValue;
  double	myValue;

  if (other == self)
    {
      return NSOrderedSame;
    }
  else if (other == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }

  myValue = [self doubleValue];
  otherValue = [other doubleValue];

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

- (BOOL) isEqual: (id)o
{
  if (o == self)
    {
      return YES;
    }
  else if (o == nil)
    {
      return NO;
    }
  else if (GSObjCIsInstance(o) == YES
    && GSObjCIsKindOf(GSObjCClass(o), abstractClass))
    {
      return [self isEqualToNumber: (NSNumber*)o];
    }
  else
    {
      return [super isEqual: o];
    }
}

- (BOOL) isEqualToNumber: (NSNumber*)o
{
  if (o == self)
    {
      return YES;
    }
  else if (o == nil)
    {
      return NO;
    }
  else if ([self compare: o] == NSOrderedSame)
    {
      return YES;
    }
  return NO;
}

/*
 * NSCoding
 */

- (Class) classForCoder
{
  return abstractClass;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  const char	*t = [self objCType];

  [coder encodeValueOfObjCType: @encode(signed char) at: t];
  [coder encodeValueOfObjCType: t at: [self pointerValue]];
}

- (id) initWithCoder: (NSCoder*)coder
{
  char	t[2];
  union	{
    signed char	c;
    unsigned char C;
    signed short s;
    unsigned short S;
    signed int i;
    unsigned int I;
    signed long	l;
    unsigned long L;
    signed long long q;
    unsigned long long Q;
    float f;
    double d;
  } data;

  [coder decodeValueOfObjCType: @encode(signed char) at: t];
  t[1] = '\0';
  [coder decodeValueOfObjCType: t at: &data];
  switch (*t)
    {
      case 'c':	self = [self initWithChar: data.c];	break;
      case 'C':	self = [self initWithUnsignedChar: data.C]; break;
      case 's':	self = [self initWithShort: data.s]; break;
      case 'S':	self = [self initWithUnsignedShort: data.S]; break;
      case 'i':	self = [self initWithInt: data.i]; break;
      case 'I':	self = [self initWithUnsignedInt: data.I]; break;
      case 'l':	self = [self initWithLong: data.l]; break;
      case 'L':	self = [self initWithUnsignedLong: data.L]; break;
      case 'q':	self = [self initWithLongLong: data.q]; break;
      case 'Q':	self = [self initWithUnsignedLongLong: data.Q]; break;
      case 'f':	self = [self initWithFloat: data.f]; break;
      case 'd':	self = [self initWithDouble: data.d]; break;
      default:
	[self dealloc];
	self = nil;
	NSLog(@"Attempt to decode number with unknown ObjC type");
    }
  return self;
}
@end
