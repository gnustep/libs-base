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

#include <config.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSBitmapCharSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSDictionary.h>

static NSString* NSCharacterSet_PATH = @"NSCharacterSets";

/* A simple array for caching standard bitmap sets */
#define MAX_STANDARD_SETS 15
static NSCharacterSet* cache_set[MAX_STANDARD_SETS];
static NSLock* cache_lock = nil;

@implementation NSCharacterSet

+ (void) initialize
{
  static BOOL one_time = NO;

  if (one_time == NO)
    {
      unsigned	i;

      for (i = 0; i < MAX_STANDARD_SETS; i++)
	{
	  cache_set[i] = 0;
	}
      one_time = YES;
    }
}

/* Provide a default object for allocation */
+ (id) allocWithZone: (NSZone*)zone
{
  return NSAllocateObject([NSBitmapCharSet self], 0, zone);
}

// Creating standard character sets

+ (NSCharacterSet*) _bitmapForSet: (NSString*)setname number: (int)number
{
  NSCharacterSet *set;
  NSArray *paths;
  NSString *bundle_path, *set_path;
  NSBundle *bundle;
  NSEnumerator *enumerator;

  if (!cache_lock)
    cache_lock = [NSLock new];
  [cache_lock lock];

  set = nil; /* Quiet warnings */
  if (cache_set[number] == nil)
    {
      NS_DURING

        paths = NSSearchPathForDirectoriesInDomains(GSLibrariesDirectory,
                                                    NSAllDomainsMask, YES);
        enumerator = [paths objectEnumerator];
        while ((set == nil) && (bundle_path = [enumerator nextObject]))
          {
            bundle = [NSBundle bundleWithPath: bundle_path];

            set_path = [bundle pathForResource: setname
                                        ofType: @"dat"
                                   inDirectory: NSCharacterSet_PATH];
            if (set_path != nil)
              {
                NS_DURING
                  /* Load the character set file */
                  set = [self characterSetWithBitmapRepresentation:
                                [NSData dataWithContentsOfFile: set_path]];
                NS_HANDLER
                  NSLog(@"Unable to read NSCharacterSet file %@", set_path);
                  set = nil;
                NS_ENDHANDLER
              }
          }

	/* If we didn't load a set then raise an exception */
	if (!set)
	  {
	    [NSException raise: NSGenericException
			 format: @"Could not find bitmap file %@", setname];
	    /* NOT REACHED */
	  }
	else
	  {
	    /* Else cache the set */
	    cache_set[number] = RETAIN(set);

	  }
      NS_HANDLER
	[cache_lock unlock];
        [localException raise];
	abort (); /* quiet warnings about `set' clobbered by longjmp. */
      NS_ENDHANDLER
    }
  else
    set = cache_set[number];

  [cache_lock unlock];
  return set;
}


+ (NSCharacterSet*) alphanumericCharacterSet
{
  return [self _bitmapForSet: @"alphanumericCharSet" number: 0];
}

+ (NSCharacterSet*) controlCharacterSet
{
  return [self _bitmapForSet: @"controlCharSet" number: 1];
}

/**
 * Returns a character set containing characters that represent
 * the decimal digits 0 through 9.
 */
+ (NSCharacterSet*) decimalDigitCharacterSet
{
  return [self _bitmapForSet: @"decimalDigitCharSet" number: 2];
}

/**
 * Returns a character set containing individual charactars that
 * can be represented also by a composed character sequence.
 */
+ (NSCharacterSet*) decomposableCharacterSet
{
  return [self _bitmapForSet: @"decomposableCharSet" number: 3];
}

/**
 * Returns a character set containing unassigned (illegal)
 * character values.
 */
+ (NSCharacterSet*) illegalCharacterSet
{
  return [self _bitmapForSet: @"illegalCharSet" number: 4];
}

+ (NSCharacterSet*) letterCharacterSet
{
  return [self _bitmapForSet: @"letterCharSet" number: 5];
}

/**
 * Returns a character set that contains the lowercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in uppercase and/or titlecase.
 */
+ (NSCharacterSet*) lowercaseLetterCharacterSet
{
  return [self _bitmapForSet: @"lowercaseLetterCharSet" number: 6];
}

+ (NSCharacterSet*) nonBaseCharacterSet
{
  return [self _bitmapForSet: @"nonBaseCharSet" number: 7];
}

+ (NSCharacterSet*) punctuationCharacterSet
{
  return [self _bitmapForSet: @"punctuationCharSet" number: 8];
}

+ (NSCharacterSet*) symbolAndOperatorCharacterSet
{
  return [self _bitmapForSet: @"symbolAndOperatorCharSet" number: 9];
}

/**
 * Returns a character set that contains the uppercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in lowercase and/or titlecase.
 */
+ (NSCharacterSet*) uppercaseLetterCharacterSet
{
  return [self _bitmapForSet: @"uppercaseLetterCharSet" number: 10];
}

/**
 * Returns a character set that contains the whitespace characters,
 * plus the newline characters, values 0x000A and 0x000D.
 */
+ (NSCharacterSet*) whitespaceAndNewlineCharacterSet
{
  return [self _bitmapForSet: @"whitespaceAndNlCharSet" number: 11];
}

/**
 * Returns a character set that contains the whitespace characters.
 */
+ (NSCharacterSet*) whitespaceCharacterSet
{
  return [self _bitmapForSet: @"whitespaceCharSet" number: 12];
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
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    return YES;
  if ([anObject isKindOfClass: [NSCharacterSet class]])
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

/* Mutable subclasses must implement ALL of these methods.  */
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
