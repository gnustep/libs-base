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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

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
#define BITMAP_SIZE	UNICODE_SIZE/8

#ifndef SETBIT
#define SETBIT(a,i)     ((a) |= 1<<(i))
#define CLRBIT(a,i)     ((a) &= ~(1<<(i)))
#define ISSET(a,i)      ((((a) & (1<<(i)))) > 0) ? YES : NO;
#endif

@interface NSBitmapCharSet : NSCharacterSet
{
  char _data[BITMAP_SIZE];
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@interface NSMutableBitmapCharSet : NSMutableCharacterSet
{
  char _data[BITMAP_SIZE];
}
- (id) initWithBitmap: (NSData*)bitmap;
@end

@implementation NSBitmapCharSet
- (id) init
{
  return [self initWithBitmap: NULL];
}

- (id) initWithBitmap: (NSData*)bitmap
{
  if ([bitmap length] != BITMAP_SIZE)
    {
      NSLog(@"attempt to initialize character set with invalid bitmap");
      [self dealloc];
      return nil;
    }
  [bitmap getBytes: _data length: BITMAP_SIZE];
  return self;
}

- (NSData*) bitmapRepresentation
{
  return [NSData dataWithBytes: _data length: BITMAP_SIZE];
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
  return ISSET(_data[aCharacter/8], aCharacter % 8);
}

- (Class) classForCoder
{
  return [self class];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: [self bitmapRepresentation]];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSData	*rep;

  rep = [aCoder decodeObject];
  self = [self initWithBitmap: rep];
  return self;
}

@end

@implementation NSMutableBitmapCharSet

- (id) init
{
  return [self initWithBitmap: NULL];
}

- (id) initWithBitmap: (NSData*)bitmap
{
  [super init];
  if (bitmap)
    [bitmap getBytes: _data length: BITMAP_SIZE];
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: [self bitmapRepresentation]];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSMutableData	*rep;

  rep = [aCoder decodeObject];
  self = [self initWithBitmap: rep];
  return self;
}

/* Need to implement the next two methods just like NSBitmapCharSet */
- (NSData*) bitmapRepresentation
{
  return [NSData dataWithBytes: _data length: BITMAP_SIZE];
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
  return ISSET(_data[aCharacter/8], aCharacter % 8);
}

- (void) addCharactersInRange: (NSRange)aRange
{
  unsigned i;

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  for (i = aRange.location; i < NSMaxRange(aRange); i++)
    {
      SETBIT(_data[i/8], i % 8);
    }
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

	  letter = (*get)(aString, @selector(characterAtIndex:), i);
	  SETBIT(_data[letter/8], letter % 8);
	}
    }
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
  unsigned	i;
  const char	*other_bytes;

  other_bytes = [[otherSet bitmapRepresentation] bytes];
  for (i = 0; i < BITMAP_SIZE; i++)
    {
      _data[i] = (_data[i] | other_bytes[i]);
    }
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet *)otherSet
{
  unsigned	i;
  const char	*other_bytes;

  other_bytes = [[otherSet bitmapRepresentation] bytes];
  for (i = 0; i < BITMAP_SIZE; i++)
    {
      _data[i] = (_data[i] & other_bytes[i]);
    }
}

- (void) removeCharactersInRange: (NSRange)aRange
{
  unsigned	i;

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  for (i = aRange.location; i < NSMaxRange(aRange); i++)
    {
      CLRBIT(_data[i/8], i % 8);
    }
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

	  letter = (*get)(aString, @selector(characterAtIndex:), i);
	  CLRBIT(_data[letter/8], letter % 8);
	}
    }
}

- (void) invert
{
  unsigned	i;

  for (i = 0; i < BITMAP_SIZE; i++)
    {
      _data[i] = ~_data[i];
    }
}

@end



/* A simple array for caching standard bitmap sets */
#define MAX_STANDARD_SETS 15
static NSCharacterSet *cache_set[MAX_STANDARD_SETS];
static NSLock *cache_lock = nil;
static Class abstractClass = nil;

@interface GSStaticCharSet : NSCharacterSet
{
  const unsigned char	*_data;
  int			_index;
}
@end

@implementation GSStaticCharSet

- (id) init
{
  DESTROY(self);
  return nil;
}

- (id) initWithIndex: (int)index bytes: (const unsigned char*)bitmap
{
  _index = index;
  _data = bitmap;
  return self;
}

- (NSData*) bitmapRepresentation
{
  return [NSData dataWithBytes: _data length: BITMAP_SIZE];
}

- (BOOL) characterIsMember: (unichar)aCharacter
{
  return ISSET(_data[aCharacter/8], aCharacter % 8);
}

- (Class) classForCoder
{
  return [NSCharacterSet class];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(int) at: &_index];
}

@end

@implementation NSCharacterSet

+ (void) initialize
{
  static BOOL one_time = NO;

  if (one_time == NO)
    {
      abstractClass = [NSCharacterSet class];
      one_time = YES;
    }
  cache_lock = [GSLazyLock new];
}

/**
 * Creat and cache (or retrieve from cache) a characterset
 * using static bitmap data.
 * Return nil if no data is supplied and the cache is empty.
 */
+ (NSCharacterSet*) _staticSet: (unsigned char*)bytes number: (int)number
{
  [cache_lock lock];
  if (cache_set[number] == nil && bytes != 0)
    {
      cache_set[number]
	= [[GSStaticCharSet alloc] initWithIndex: number bytes: bytes];
    }
  [cache_lock unlock];
  return cache_set[number];
}

+ (NSCharacterSet*) alphanumericCharacterSet
{
  return [self _staticSet: alphanumericCharSet number: 0];
}

+ (NSCharacterSet*) capitalizedLetterCharacterSet
{
  return [self _staticSet: titlecaseLetterCharSet number: 13];
}

+ (NSCharacterSet*) controlCharacterSet
{
  return [self _staticSet: controlCharSet number: 1];
}

+ (NSCharacterSet*) decimalDigitCharacterSet
{
  return [self _staticSet: decimalDigitCharSet number: 2];
}

+ (NSCharacterSet*) decomposableCharacterSet
{
  return [self _staticSet: decomposableCharSet number: 3];
}

+ (NSCharacterSet*) illegalCharacterSet
{
  return [self _staticSet: illegalCharSet number: 4];
}

+ (NSCharacterSet*) letterCharacterSet
{
  return [self _staticSet: letterCharSet number: 5];
}

+ (NSCharacterSet*) lowercaseLetterCharacterSet
{
  return [self _staticSet: lowercaseLetterCharSet number: 6];
}

+ (NSCharacterSet*) nonBaseCharacterSet
{
  return [self _staticSet: nonBaseCharSet number: 7];
}

+ (NSCharacterSet*) punctuationCharacterSet
{
  return [self _staticSet: punctuationCharSet number: 8];
}

+ (NSCharacterSet*) symbolCharacterSet
{
  return [self _staticSet: symbolAndOperatorCharSet number: 9];
}

// FIXME ... deprecated ... remove after next release.
+ (NSCharacterSet*) symbolAndOperatorCharacterSet
{
  GSOnceMLog(@"symbolAndOperatorCharacterSet is deprecated ... use symbolCharacterSet");
  return [self _staticSet: symbolAndOperatorCharSet number: 9];
}

+ (NSCharacterSet*) uppercaseLetterCharacterSet
{
  return [self _staticSet: uppercaseLetterCharSet number: 10];
}

+ (NSCharacterSet*) whitespaceAndNewlineCharacterSet
{
  return [self _staticSet: whitespaceAndNlCharSet number: 11];
}

+ (NSCharacterSet*) whitespaceCharacterSet
{
  return [self _staticSet: whitespaceCharSet number: 12];
}

+ (NSCharacterSet*) characterSetWithBitmapRepresentation: (NSData*)data
{
  return AUTORELEASE([[NSBitmapCharSet alloc] initWithBitmap: data]);
}

+ (NSCharacterSet*) characterSetWithCharactersInString: (NSString*)aString
{
  unsigned	i;
  unsigned	length;
  unsigned char	*bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength: BITMAP_SIZE];

  if (!aString)
    {
      [NSException raise: NSInvalidArgumentException
	  format: @"Creating character set with nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  bytes  = [bitmap mutableBytes];
  for (i = 0; i < length; i++)
    {
      unichar letter = [aString characterAtIndex: i];

      SETBIT(bytes[letter/8], letter % 8);
    }

  return [self characterSetWithBitmapRepresentation: bitmap];
}

+ (NSCharacterSet*) characterSetWithRange: (NSRange)aRange
{
  unsigned	i;
  unsigned char	*bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength: BITMAP_SIZE];

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  bytes = (unsigned char*)[bitmap mutableBytes];
  for (i = aRange.location; i < NSMaxRange(aRange); i++)
    {
      SETBIT(bytes[i/8], i % 8);
    }
  return [self characterSetWithBitmapRepresentation: bitmap];
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
    return RETAIN(self);
  else
    return NSCopyObject (self, 0, zone);
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
      self = RETAIN([abstractClass _staticSet: 0 number: index]);
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
      BOOL	(*rImp)(id, SEL, unichar);
      BOOL	(*oImp)(id, SEL, unichar);
      
      rImp = (BOOL (*)(id,SEL,unichar))
	[self methodForSelector: @selector(characterIsMember:)];
      oImp = (BOOL (*)(id,SEL,unichar))
	[anObject methodForSelector: @selector(characterIsMember:)];

      for (i = 0; i <= 0xffff; i++)
	{
	  if (rImp(self,  @selector(characterIsMember:), i)
	    != oImp(anObject, @selector(characterIsMember:), i))
	    {
	      return NO;
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

/* Provide a default object for allocation */
+ (id) allocWithZone: (NSZone*)zone
{
  return NSAllocateObject([NSMutableBitmapCharSet self], 0, zone);
}

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

- (void) addCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

- (void) addCharactersInString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
  [self subclassResponsibility: _cmd];
}

- (void) formIntersectionWithCharacterSet: (NSCharacterSet*)otherSet
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

- (void) invert
{
  [self subclassResponsibility: _cmd];
}

// NSCopying, NSMutableCopying
- (id) copyWithZone: (NSZone*)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [super mutableCopyWithZone: zone];
}

@end
