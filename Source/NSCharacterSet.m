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
#include "Foundation/NSBitmapCharSet.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSException.h"
#include "Foundation/NSData.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSNotification.h"

#include "../NSCharacterSets/NSCharacterSetData.h"

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

/**
 *  Represents a set of unicode characters.  Used by [NSScanner] and [NSString]
 *  for parsing-related methods.
 */
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

/**
 *  Returns a character set containing letters, numbers, and diacritical
 *  marks.  Note that "letters" includes all alphabetic as well as Chinese
 *  characters, etc..
 */
+ (NSCharacterSet*) alphanumericCharacterSet
{
  return [self _staticSet: alphanumericCharSet number: 0];
}

/**
 *  Returns a character set containing control and format characters.
 */
+ (NSCharacterSet*) controlCharacterSet
{
  return [self _staticSet: controlCharSet number: 1];
}

/**
 * Returns a character set containing characters that represent
 * the decimal digits 0 through 9.
 */
+ (NSCharacterSet*) decimalDigitCharacterSet
{
  return [self _staticSet: decimalDigitCharSet number: 2];
}

/**
 * Returns a character set containing individual charactars that
 * can be represented also by a composed character sequence.
 */
+ (NSCharacterSet*) decomposableCharacterSet
{
  return [self _staticSet: decomposableCharSet number: 3];
}

/**
 * Returns a character set containing unassigned (illegal)
 * character values.
 */
+ (NSCharacterSet*) illegalCharacterSet
{
  return [self _staticSet: illegalCharSet number: 4];
}

/**
 *  Returns a character set containing letters, including all alphabetic as
 *  well as Chinese characters, etc..
 */
+ (NSCharacterSet*) letterCharacterSet
{
  return [self _staticSet: letterCharSet number: 5];
}

/**
 * Returns a character set that contains the lowercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in uppercase and/or titlecase.
 */
+ (NSCharacterSet*) lowercaseLetterCharacterSet
{
  return [self _staticSet: lowercaseLetterCharSet number: 6];
}

/**
 *  Returns a character set containing characters for diacritical marks, which
 *  are usually only rendered in conjunction with another character.
 */
+ (NSCharacterSet*) nonBaseCharacterSet
{
  return [self _staticSet: nonBaseCharSet number: 7];
}

/**
 *  Returns a character set containing punctuation marks.
 */
+ (NSCharacterSet*) punctuationCharacterSet
{
  return [self _staticSet: punctuationCharSet number: 8];
}

/**
 *  Returns a character set containing mathematical symbols, etc..
 */
+ (NSCharacterSet*) symbolAndOperatorCharacterSet
{
  return [self _staticSet: symbolAndOperatorCharSet number: 9];
}

/**
 * Returns a character set that contains the uppercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in lowercase and/or titlecase.
 */
+ (NSCharacterSet*) uppercaseLetterCharacterSet
{
  return [self _staticSet: uppercaseLetterCharSet number: 10];
}

/**
 * Returns a character set that contains the whitespace characters,
 * plus the newline characters, values 0x000A and 0x000D.
 */
+ (NSCharacterSet*) whitespaceAndNewlineCharacterSet
{
  return [self _staticSet: whitespaceAndNlCharSet number: 11];
}

/**
 * Returns a character set that contains the whitespace characters.
 */
+ (NSCharacterSet*) whitespaceCharacterSet
{
  return [self _staticSet: whitespaceCharSet number: 12];
}

// Creating custom character sets

/**
 * Returns a character set containing characters as encoded in the
 * data object.
 */
+ (NSCharacterSet*) characterSetWithBitmapRepresentation: (NSData*)data
{
  return AUTORELEASE([[NSBitmapCharSet alloc] initWithBitmap: data]);
}

/**
 *  Returns set with characters in aString, or empty set for empty string.
 *  Raises an exception if given a nil string.
 */
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

/**
 *  Returns set containing unicode index range given by aRange.
 */
+ (NSCharacterSet*)characterSetWithRange: (NSRange)aRange
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

/**
 *  Initializes from a bitmap.  (See [NSBitmapCharSet].)  File must have
 *  extension "<code>.bitmap</code>".  (To get around this load the file
 *  into data yourself and use
 *  [NSCharacterSet -characterSetWithBitmapRepresentation].
 */
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

/**
 * Returns a bitmap representation of the receiver's character set
 * suitable for archiving or writing to a file, in an NSData object.
 */
- (NSData*) bitmapRepresentation
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 * Returns YES if the receiver contains <em>aCharacter</em>, NO if
 * it does not.
 */
- (BOOL) characterIsMember: (unichar)aCharacter
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
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

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOfClass: abstractClass])
    {
      unsigned	i;

      for (i = 0; i <= 0xffff; i++)
	{
	  if ([self characterIsMember: (unichar)i]
	    != [anObject characterIsMember: (unichar)i])
	    {
	      return NO;
	    }
	}
      return YES;
    }
  return NO;
}

/**
 * Returns a character set containing only characters that the
 * receiver does not contain.
 */
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


// NSCopying, NSMutableCopying
- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject (self, 0, zone);
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSMutableBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

@end

/**
 *  An [NSCharacterSet] that can be modified.
 */
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

/* Mutable subclasses must implement ALL of these methods. */

/**
 *  Adds characters specified by unicode indices in aRange to set.
 */
- (void) addCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Adds characters in aString to set.
 */
- (void) addCharactersInString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Set union of character sets.
 */
- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Set intersection of character sets.
 */
- (void) formIntersectionWithCharacterSet: (NSCharacterSet*)otherSet
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Drop given range of characters.  No error for characters not currently in
 *  set.
 */
- (void) removeCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Drop characters in aString.  No error for characters not currently in
 *  set.
 */
- (void) removeCharactersInString: (NSString*)aString
{
  [self subclassResponsibility: _cmd];
}

/**
 *  Remove all characters currently in set and add all other characters.
 */
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
