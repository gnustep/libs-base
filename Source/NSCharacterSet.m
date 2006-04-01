/** NSCharacterSet - Character set holder
   Copyright (C) 1995, 1996, 1997, 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Apr 1995

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSCharacterSet class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/GSLock.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSException.h"
#include "Foundation/NSData.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSCharacterSet.h"
#include <Foundation/NSData.h>
#include "Foundation/NSDebug.h"

#include "NSCharacterSetData.h"

//PENDING: may want to make these less likely to conflict
#define UNICODE_SIZE	65536
#define UNICODE_MAX	1048576
#define BITMAP_SIZE	8192
#define BITMAP_MAX	131072

#ifndef SETBIT
#define SETBIT(a,i)     ((a) |= 1<<(i))
#define CLRBIT(a,i)     ((a) &= ~(1<<(i)))
#define ISSET(a,i)      ((a) & (1<<(i)))
#endif

@class	NSDataStatic;
@interface	NSDataStatic : NSObject	// Help the compiler
@end

@interface NSBitmapCharSet : NSCharacterSet
{
  const unsigned char	*_data;
  unsigned		_length;
  NSData		*_obj;
  unsigned		_known;
  unsigned		_present;
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@interface NSMutableBitmapCharSet : NSMutableCharacterSet
{
  unsigned char		*_data;
  unsigned		_length;
  NSMutableData		*_obj;
  unsigned		_known;
  unsigned		_present;
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@implementation NSBitmapCharSet

- (NSData*) bitmapRepresentation
{
  unsigned	i = 16;

  while (i > 0 && [self hasMemberInPlane: i-1] == NO)
    {
      i--;
    }
  i *= BITMAP_SIZE;
  if (i < _length)
    {
      return [NSData dataWithBytes: _data length: i];
    }
  return _obj;
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
  unsigned	byte = aCharacter/8;

  if (byte < _length && ISSET(_data[byte], aCharacter % 8))
    {
      return YES;
    }
  return NO;
}

- (Class) classForCoder
{
  return [self class];
}

- (void) dealloc
{
  DESTROY(_obj);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: [self bitmapRepresentation]];
}

- (BOOL) hasMemberInPlane: (uint8_t)aPlane
{
  unsigned	bit;

  if (aPlane >= 16)
    {
      return NO;
    }
  bit = (1 << aPlane);
  if (_known & bit)
    {
      if (_present & bit)
	{
	  return YES;
	}
      else
	{
	  return NO;
	}
    }
  if (aPlane * BITMAP_SIZE < _length)
    {
      unsigned	i = BITMAP_SIZE * aPlane;
      unsigned	e = BITMAP_SIZE * (aPlane + 1);

      while (i < e)
	{
	  if (_data[i] != 0)
	    {
	      _present |= bit;
	      _known |= bit;
	      return YES;
	    }
	  i++;
	}
    }
  _present &= ~bit;
  _known |= bit;
  return NO;
}

- (id) init
{
  return [self initWithBitmap: nil];
}

- (id) initWithBitmap: (NSData*)bitmap
{
  unsigned	length = [bitmap length];

  if ((length % BITMAP_SIZE) != 0 || length > BITMAP_MAX)
    {
      NSLog(@"attempt to initialize character set with invalid bitmap");
      [self dealloc];
      return nil;
    }
  if (bitmap == nil)
    {
      bitmap = [NSData data];
    }
  ASSIGNCOPY(_obj, bitmap);
  _length = length;
  _data = [_obj bytes];
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSData	*rep;

  rep = [aCoder decodeObject];
  self = [self initWithBitmap: rep];
  return self;
}

- (BOOL) longCharacterIsMember: (UTF32Char)aCharacter
{
  unsigned	byte = aCharacter/8;

  if (byte < _length && ISSET(_data[byte], aCharacter % 8))
    {
      return YES;
    }
  return NO;
}
@end

@implementation NSMutableBitmapCharSet

+ (void) initialize
{
  if (self == [NSMutableBitmapCharSet class])
    {
      [self setVersion: 1];
      GSObjCAddClassBehavior(self, [NSBitmapCharSet class]);
    }
}

- (void) addCharactersInRange: (NSRange)aRange
{
  unsigned i;

  if (NSMaxRange(aRange) > UNICODE_MAX)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  for (i = aRange.location; i < NSMaxRange(aRange); i++)
    {
      unsigned	byte = i/8;

      while (byte >= _length)
	{
	  [_obj setLength: _length + BITMAP_SIZE];
	  _length += BITMAP_SIZE;
	  _data = [_obj mutableBytes];
	}
      SETBIT(_data[byte], i % 8);
    }
  _known = 0;	// Invalidate cache
}

- (void) addCharactersInString: (NSString*)aString
{
  unsigned   length;

  if (!aString)
    {
      [NSException raise:NSInvalidArgumentException
          format:@"Adding characters from nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  if (length > 0)
    {
      unsigned	i;
      unichar	(*get)(id, SEL, unsigned);

      get = (unichar (*)(id, SEL, unsigned))
	[aString methodForSelector: @selector(characterAtIndex:)];
      for (i = 0; i < length; i++)
	{
	  unichar	letter;
	  unichar	second;
	  unsigned	byte;

	  letter = (*get)(aString, @selector(characterAtIndex:), i);
	  // Convert a surrogate pair if necessary
	  if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
	    && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
	    >= 0xdc00 && second <= 0xdfff)
	    {
	      i++;
	      letter = ((letter - 0xd800) << 10)
		+ (second - 0xdc00) + 0x0010000;
	    }
	  byte = letter/8;
	  while (byte >= _length)
	    {
	      [_obj setLength: _length + BITMAP_SIZE];
	      _length += BITMAP_SIZE;
	      _data = [_obj mutableBytes];
	    }
	  SETBIT(_data[byte], letter % 8);
	}
    }
  _known = 0;	// Invalidate cache
}

- (NSData*) bitmapRepresentation
{
  unsigned	i = 16;

  while (i > 0 && [self hasMemberInPlane: i-1] == NO)
    {
      i--;
    }
  i *= BITMAP_SIZE;
  return [NSData dataWithBytes: _data length: i];
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet *)otherSet
{
  unsigned		i;
  NSData		*otherData = [otherSet bitmapRepresentation];
  unsigned		other_length = [otherData length];
  const unsigned char	*other_bytes = [otherData bytes];

  if (_length > other_length)
    {
      [_obj setLength: other_length];
      _length = other_length;
      _data = [_obj mutableBytes];
    }
  for (i = 0; i < _length; i++)
    {
      _data[i] = (_data[i] & other_bytes[i]);
    }
  _known = 0;	// Invalidate cache
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
  unsigned		i;
  NSData		*otherData = [otherSet bitmapRepresentation];
  unsigned		other_length = [otherData length];
  const unsigned char	*other_bytes = [otherData bytes];

  if (other_length > _length)
    {
      [_obj setLength: other_length];
      _length = other_length;
      _data = [_obj mutableBytes];
    }
  for (i = 0; i < other_length; i++)
    {
      _data[i] = (_data[i] | other_bytes[i]);
    }
  _known = 0;	// Invalidate cache
}

- (id) initWithBitmap: (NSData*)bitmap
{
  unsigned	length = [bitmap length];
  id		tmp;

  if ((length % BITMAP_SIZE) != 0 || length > BITMAP_MAX)
    {
      NSLog(@"attempt to initialize character set with invalid bitmap");
      [self dealloc];
      return nil;
    }
  if (bitmap == nil)
    {
      tmp = [NSMutableData new];
    }
  else
    {
      tmp = [bitmap mutableCopy];
    }
  DESTROY(_obj);
  _obj = tmp;
  _length = length;
  _data = [_obj mutableBytes];
  _known = 0;	// Invalidate cache
  return self;
}

- (void) invert
{
  unsigned	i;

  if (_length < BITMAP_MAX)
    {
      [_obj setLength: BITMAP_MAX];
      _length = BITMAP_MAX;
      _data = [_obj mutableBytes];
    }
  for (i = 0; i < _length; i++)
    {
      _data[i] = ~_data[i];
    }
  _known = 0;	// Invalidate cache
}

- (void) removeCharactersInRange: (NSRange)aRange
{
  unsigned	i;
  unsigned	limit = NSMaxRange(aRange);

  if (NSMaxRange(aRange) > UNICODE_MAX)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  if (limit > _length * 8)
    {
      limit = _length * 8;
    }
  for (i = aRange.location; i < limit; i++)
    {
      CLRBIT(_data[i/8], i % 8);
    }
  _known = 0;	// Invalidate cache
}

- (void) removeCharactersInString: (NSString*)aString
{
  unsigned	length;

  if (!aString)
    {
      [NSException raise:NSInvalidArgumentException
          format:@"Removing characters from nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  if (length > 0)
    {
      unsigned	i;
      unichar	(*get)(id, SEL, unsigned);

      get = (unichar (*)(id, SEL, unsigned))
	[aString methodForSelector: @selector(characterAtIndex:)];

      for (i = 0; i < length; i++)
	{
	  unichar	letter;
	  unichar	second;
	  unsigned	byte;

	  letter = (*get)(aString, @selector(characterAtIndex:), i);
	  // Convert a surrogate pair if necessary
	  if (letter >= 0xd800 && letter <= 0xdbff && i < length-1
	    && (second = (*get)(aString, @selector(characterAtIndex:), i+1))
	    >= 0xdc00 && second <= 0xdfff)
	    {
	      i++;
	      letter = ((letter - 0xd800) << 10)
		+ (second - 0xdc00) + 0x0010000;
	    }
	  byte = letter/8;
	  if (byte < _length)
	    {
	      CLRBIT(_data[byte], letter % 8);
	    }
	}
    }
  _known = 0;	// Invalidate cache
}

@end



/* A simple array for caching standard bitmap sets */
#define MAX_STANDARD_SETS 15
static NSCharacterSet *cache_set[MAX_STANDARD_SETS];
static NSLock *cache_lock = nil;
static Class abstractClass = nil;
static Class abstractMutableClass = nil;

@interface GSStaticCharSet : NSCharacterSet
{
  const unsigned char	*_data;
  unsigned		_length;
  NSData		*_obj;
  unsigned		_known;
  unsigned		_present;
  int			_index;
}
@end

@implementation GSStaticCharSet

+ (void) initialize
{
  GSObjCAddClassBehavior(self, [NSBitmapCharSet class]);
}

- (Class) classForCoder
{
  return [NSCharacterSet class];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(int) at: &_index];
}

- (id) init
{
  DESTROY(self);
  return nil;
}

- (id) initWithBitmap: (NSData*)bitmap number: (int)number
{
  if ((self = [(NSBitmapCharSet*)self initWithBitmap: bitmap]) != nil)
    {
      _index = number;
    }
  return self;
}

@end

@implementation NSCharacterSet

+ (void) initialize
{
  static BOOL one_time = NO;

  if (one_time == NO)
    {
      abstractClass = [NSCharacterSet class];
      abstractMutableClass = [NSMutableCharacterSet class];
      one_time = YES;
    }
  cache_lock = [GSLazyLock new];
}

/**
 * Creat and cache (or retrieve from cache) a characterset
 * using static bitmap data.
 * Return nil if no data is supplied and the cache is empty.
 */
+ (NSCharacterSet*) _staticSet: (const unsigned char*)bytes
			length: (unsigned)length
			number: (int)number
{
  [cache_lock lock];
  if (cache_set[number] == nil && bytes != 0)
    {
      NSData	*bitmap;

      bitmap = [[NSDataStatic alloc] initWithBytesNoCopy: (void*)bytes
						  length: length
					    freeWhenDone: NO];
      cache_set[number]
	= [[GSStaticCharSet alloc] initWithBitmap: bitmap number: number];
      RELEASE(bitmap);
    }
  [cache_lock unlock];
  return cache_set[number];
}

+ (NSCharacterSet*) alphanumericCharacterSet
{
  return [self _staticSet: alphanumericCharSet
		   length: sizeof(alphanumericCharSet)
		   number: 0];
}

+ (NSCharacterSet*) capitalizedLetterCharacterSet
{
  return [self _staticSet: titlecaseLetterCharSet
		   length: sizeof(titlecaseLetterCharSet)
		   number: 13];
}

+ (NSCharacterSet*) controlCharacterSet
{
  return [self _staticSet: controlCharSet
		   length: sizeof(controlCharSet)
		   number: 1];
}

+ (NSCharacterSet*) decimalDigitCharacterSet
{
  return [self _staticSet: decimalDigitCharSet
		   length: sizeof(decimalDigitCharSet)
		   number: 2];
}

+ (NSCharacterSet*) decomposableCharacterSet
{
  return [self _staticSet: decomposableCharSet
		   length: sizeof(decomposableCharSet)
		   number: 3];
}

+ (NSCharacterSet*) illegalCharacterSet
{
  return [self _staticSet: illegalCharSet
		   length: sizeof(illegalCharSet)
		   number: 4];
}

+ (NSCharacterSet*) letterCharacterSet
{
  return [self _staticSet: letterCharSet
		   length: sizeof(letterCharSet)
		   number: 5];
}

+ (NSCharacterSet*) lowercaseLetterCharacterSet
{
  return [self _staticSet: lowercaseLetterCharSet
		   length: sizeof(lowercaseLetterCharSet)
		   number: 6];
}

+ (NSCharacterSet*) nonBaseCharacterSet
{
  return [self _staticSet: nonBaseCharSet
		   length: sizeof(nonBaseCharSet)
		   number: 7];
}

+ (NSCharacterSet*) punctuationCharacterSet
{
  return [self _staticSet: punctuationCharSet
		   length: sizeof(punctuationCharSet)
		   number: 8];
}

+ (NSCharacterSet*) symbolCharacterSet
{
  return [self _staticSet: symbolAndOperatorCharSet
		   length: sizeof(symbolAndOperatorCharSet)
		   number: 9];
}

// FIXME ... deprecated ... remove after next release.
+ (NSCharacterSet*) symbolAndOperatorCharacterSet
{
  GSOnceMLog(@"symbolAndOperatorCharacterSet is deprecated ... use symbolCharacterSet");
  return [self _staticSet: symbolAndOperatorCharSet
		   length: sizeof(symbolAndOperatorCharSet)
		   number: 9];
}

+ (NSCharacterSet*) uppercaseLetterCharacterSet
{
  return [self _staticSet: uppercaseLetterCharSet
		   length: sizeof(uppercaseLetterCharSet)
		   number: 10];
}

+ (NSCharacterSet*) whitespaceAndNewlineCharacterSet
{
  return [self _staticSet: whitespaceAndNlCharSet
		   length: sizeof(whitespaceAndNlCharSet)
		   number: 11];
}

+ (NSCharacterSet*) whitespaceCharacterSet
{
  return [self _staticSet: whitespaceCharSet
		   length: sizeof(whitespaceCharSet)
		   number: 12];
}

+ (NSCharacterSet*) characterSetWithBitmapRepresentation: (NSData*)data
{
  return AUTORELEASE([[NSBitmapCharSet alloc] initWithBitmap: data]);
}

+ (NSCharacterSet*) characterSetWithCharactersInString: (NSString*)aString
{
  NSMutableCharacterSet	*ms;
  NSCharacterSet	*cs;

  ms = [NSMutableCharacterSet new];
  [ms addCharactersInString: aString];
  cs = [ms copy];
  RELEASE(ms);
  return AUTORELEASE(cs);
}

+ (NSCharacterSet*) characterSetWithRange: (NSRange)aRange
{
  NSMutableCharacterSet	*ms;
  NSCharacterSet	*cs;

  ms = [NSMutableCharacterSet new];
  [ms addCharactersInRange: aRange];
  cs = [ms copy];
  RELEASE(ms);
  return AUTORELEASE(cs);
}

+ (NSCharacterSet*) characterSetWithContentsOfFile: (NSString*)aFile
{
  if ([@"bitmap" isEqual: [aFile pathExtension]])
    {
      NSData	*bitmap = [NSData dataWithContentsOfFile: aFile];
      return [self characterSetWithBitmapRepresentation: bitmap];
    }
  else
    return nil;
}

- (NSData*) bitmapRepresentation
{
  BOOL		(*imp)(id, SEL, unichar);
  NSMutableData	*m = [NSMutableData dataWithLength: 8192];
  unsigned char	*p = (unsigned char*)[m mutableBytes];
  unsigned	i;

  imp = (BOOL (*)(id,SEL,unichar))
    [self methodForSelector: @selector(characterIsMember:)];
  for (i = 0; i <= 0xffff; i++)
    {
      if (imp(self, @selector(characterIsMember:), i) == YES)
	{
	  SETBIT(p[i/8], i % 8);
	}
    }
  return m;
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  else
    {
      id	obj;

      obj = [NSBitmapCharSet allocWithZone: zone];
      obj = [obj initWithBitmap: [self bitmapRepresentation]];
      return obj;
    }
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
}

- (BOOL) hasMemberInPlane: (uint8_t)aPlane
{
  if (aPlane == 0)
    {
      return YES;
    }
  return NO;
}

- (id) init
{
  if (GSObjCClass(self) == abstractClass)
    {
      id	obj;

      obj = [NSBitmapCharSet allocWithZone: [self zone]];
      obj = [obj initWithBitmap: nil];
      RELEASE(self);
      self = obj;
    }
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([self class] == abstractClass)
    {
      int	index;

      /*
       * Abstract class returns characterset from cache.
       */
      DESTROY(self);
      [aCoder decodeValueOfObjCType: @encode(int) at: &index];
      self = RETAIN([abstractClass _staticSet: 0 length: 0 number: index]);
    }
  else
    {
    }
  return self;
}

- (NSCharacterSet*) invertedSet
{
  unsigned	i;
  unsigned	length;
  unsigned char	*bytes;
  NSMutableData	*bitmap;

  bitmap = AUTORELEASE([[self bitmapRepresentation] mutableCopy]);
  length = [bitmap length];
  bytes = [bitmap mutableBytes];
  for (i = 0; i < length; i++)
    {
      bytes[i] = ~bytes[i];
    }
  return [[self class] characterSetWithBitmapRepresentation: bitmap];
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOfClass: abstractClass])
    {
      unsigned	i;
      unsigned	p;
      BOOL	(*rImp)(id, SEL, unichar);
      BOOL	(*oImp)(id, SEL, unichar);
      
      rImp = (BOOL (*)(id,SEL,unichar))
	[self methodForSelector: @selector(characterIsMember:)];
      oImp = (BOOL (*)(id,SEL,unichar))
	[anObject methodForSelector: @selector(characterIsMember:)];

      for (p = 0; p < 16; p++)
	{
	  if ([self hasMemberInPlane: p] == YES)
	    {
	      if ([anObject hasMemberInPlane: p] == YES)
		{
		  for (i = 0; i <= 0xffff; i++)
		    {
		      if (rImp(self,  @selector(characterIsMember:), i)
			!= oImp(anObject, @selector(characterIsMember:), i))
			{
			  return NO;
			}
		    }
		}
	      else
		{
		  return NO;
		}
	    }
	  else
	    {
	      if ([anObject hasMemberInPlane: p] == YES)
		{
		  return NO;
		}
	    }
	}
      return YES;
    }
  return NO;
}

- (BOOL) isSupersetOfSet: (NSCharacterSet*)aSet
{
  NSMutableCharacterSet	*m = [self mutableCopy];
  BOOL			superset;

  [m formUnionWithCharacterSet: aSet];
  superset = [self isEqual: m];
  RELEASE(m);
  return superset;
}

- (BOOL) longCharacterIsMember: (UTF32Char)aCharacter
{
  int	plane = (aCharacter >> 16);

  if (plane == 0)
    {
      unichar	u = (unichar)(aCharacter & 0xffff);

      return [self characterIsMember: u];
    }
  else
    {
      return NO;
    }
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSMutableBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

@end

@implementation NSMutableCharacterSet

/* Override this from NSCharacterSet to create the correct class */
+ (NSCharacterSet*) characterSetWithBitmapRepresentation: (NSData*)data
{
  return AUTORELEASE([[NSMutableBitmapCharSet alloc] initWithBitmap: data]);
}

+ (NSCharacterSet*) alphanumericCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) capitalizedLetterCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) controlCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) decimalDigitCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) decomposableCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) illegalCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) letterCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) lowercaseLetterCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) nonBaseCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) punctuationCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) symbolCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

// FIXME ... deprecated ... remove after next release.
+ (NSCharacterSet*) symbolAndOperatorCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) uppercaseLetterCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) whitespaceAndNewlineCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) whitespaceCharacterSet
{
  return AUTORELEASE([[abstractClass performSelector: _cmd] mutableCopy]);
}

+ (NSCharacterSet*) characterSetWithCharactersInString: (NSString*)aString
{
  NSMutableCharacterSet	*ms;

  ms = [abstractMutableClass new];
  [ms addCharactersInString: aString];
  return AUTORELEASE(ms);
}

+ (NSCharacterSet*) characterSetWithRange: (NSRange)aRange
{
  NSMutableCharacterSet	*ms;

  ms = [abstractMutableClass new];
  [ms addCharactersInRange: aRange];
  return AUTORELEASE(ms);
}

- (void) addCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

- (void) addCharactersInString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

- (id) copyWithZone: (NSZone*)zone
{
  NSData	*bitmap;

  bitmap = [self bitmapRepresentation];
  return [[NSBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet*)otherSet
{
  [self subclassResponsibility: _cmd];
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
  [self subclassResponsibility: _cmd];
}

- (id) init
{
  if (GSObjCClass(self) == abstractMutableClass)
    {
      id	obj;

      obj = [NSMutableBitmapCharSet allocWithZone: [self zone]];
      obj = [obj initWithBitmap: nil];
      RELEASE(self);
      self = obj;
    }
  return self;
}

- (id) initWithBitmap: (NSData*)bitmap
{
  if (GSObjCClass(self) == abstractMutableClass)
    {
      id	obj;

      obj = [NSMutableBitmapCharSet allocWithZone: [self zone]];
      obj = [obj initWithBitmap: bitmap];
      RELEASE(self);
      self = obj;
    }
  return self;
}

- (void) invert
{
  [self subclassResponsibility: _cmd];
}

- (void) removeCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

- (void) removeCharactersInString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

@end
