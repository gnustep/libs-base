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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <config.h>
#include <base/preface.h>
#include <base/fast.x>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSCoder.h>

@implementation NSNumber

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

+ (void) initialize
{
  if (self == [NSNumber class])
    {
      abstractClass = self;

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
    }
}

/* Returns the concrete class associated with the type encoding. Note 
   that we don't allow NSNumber to instantiate any class but its own
   concrete subclasses (see check at end of method) */
+ (Class)valueClassWithObjCType: (const char *)type
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
    theClass = [super valueClassWithObjCType: type];

  return theClass;
}

+ (NSNumber *)numberWithBool: (BOOL)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(boolNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithChar: (char)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(charNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithDouble: (double)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(doubleNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithFloat: (float)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(floatNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithInt: (int)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(intNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithLong: (long)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(longNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithLongLong: (long long)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(longLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithShort: (short)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(shortNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithUnsignedChar: (unsigned char)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(uCharNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithUnsignedInt: (unsigned int)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(uIntNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithUnsignedLong: (unsigned long)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(uLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithUnsignedLongLong: (unsigned long long)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(uLongLongNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSNumber *)numberWithUnsignedShort: (unsigned short)value
{
  NSNumber	*theObj;

  theObj = (NSNumber*)NSAllocateObject(uShortNumberClass, 0,
    NSDefaultMallocZone());
  theObj = [theObj initWithBytes: &value objCType: NULL];
  return AUTORELEASE(theObj);
}

+ (NSValue*)valueFromString: (NSString *)string
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

- (id)initWithBool: (BOOL)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(boolNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithChar: (char)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(charNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithDouble: (double)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(doubleNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithFloat: (float)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(floatNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithInt: (int)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(intNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithLong: (long)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(longNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithLongLong: (long long)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(longLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithShort: (short)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(shortNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithUnsignedChar: (unsigned char)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(uCharNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithUnsignedInt: (unsigned int)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(uIntNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithUnsignedLong: (unsigned long)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(uLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithUnsignedLongLong: (unsigned long long)value
{
  NSDeallocateObject(self);
  self = (NSNumber*)NSAllocateObject(uLongLongNumberClass, 0,
    NSDefaultMallocZone());
  self = [self initWithBytes: &value objCType: NULL];
  return self;
}

- (id)initWithUnsignedShort: (unsigned short)value
{
  NSDeallocateObject(self);
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
- (BOOL)boolValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (char)charValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (double)doubleValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (float)floatValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (int)intValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (long long)longLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (long)longValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (short)shortValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSString *)stringValue
{
  return [self descriptionWithLocale: nil];
}

- (unsigned char)unsignedCharValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned int)unsignedIntValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned long long)unsignedLongLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned long)unsignedLongValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned short)unsignedShortValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSComparisonResult)compare: (NSNumber *)otherNumber
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned) hash
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) isEqual: o
{
  if (o != nil && fastIsInstance(o)
    && fastInstanceIsKindOfClass(o, abstractClass))
    return [self isEqualToNumber: (NSNumber*)o];
  else
    return [super isEqual: o];
}

- (BOOL)isEqualToNumber: (NSNumber *)otherNumber
{
  [self subclassResponsibility: _cmd];
  return NO;
}

// NSCoding (done by subclasses)
- (void)encodeWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
}

- (id)initWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end
