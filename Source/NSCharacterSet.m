/* NSCharacterSet - Character set holder
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Apr 1995

   This file is part of the GNU Objective C Class Library.

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

#include <Foundation/NSBitmapCharSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>

/* FIXME: Where should bitmaps go? Maybe should be defined with configure */
#ifndef BITMAP_PATH
#define BITMAP_PATH @"/usr/local/share/objects"
#endif

@implementation NSCharacterSet

/* Provide a default object for allocation */
+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([NSBitmapCharSet self], 0, zone);
}

// Creating standard character sets

+ (NSData *)_bitmapForSet:(NSString *)setname
{
  NSString *path;

  path = [NSBundle pathForResource:setname
			ofType:@".dat"
			inDirectory:BITMAP_PATH
			withVersion:0];
  /* This is for testing purposes */
  if (path == nil || [path length] == 0)
    {
      path = [NSBundle pathForResource:setname
			ofType:@".dat"
			inDirectory:@"../share"
			withVersion:0];
    }

  if (path == nil || [path length] == 0)
    {
      [NSException raise:NSGenericException
	  format:@"Could not find bitmap file %s", [setname cString]];
      /* NOT REACHED */
    }

  return [NSData dataWithContentsOfFile:path];
}


+ (NSCharacterSet *)alphanumericCharacterSet
{
  NSData *data = [self _bitmapForSet:@"alphanumCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)controlCharacterSet
{
  NSData *data = [self _bitmapForSet:@"controlCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)decimalDigitCharacterSet
{
  NSData *data = [self _bitmapForSet:@"decimalCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)decomposableCharacterSet
{
  NSData *data = [self _bitmapForSet:@"decomposableCharSet"];

  fprintf(stderr, "Warning: Decomposable set not yet fully specified\n");
  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)illegalCharacterSet
{
  NSData *data = [self _bitmapForSet:@"illegalCharSet"];

  fprintf(stderr, "Warning: Illegal set not yet fully specified\n");
  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)letterCharacterSet
{
  NSData *data = [self _bitmapForSet:@"lettercharCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)lowercaseLetterCharacterSet
{
  NSData *data = [self _bitmapForSet:@"lowercaseCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)nonBaseCharacterSet
{
  NSData *data = [self _bitmapForSet:@"nonbaseCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)uppercaseLetterCharacterSet
{
  NSData *data = [self _bitmapForSet:@"uppercaseCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet
{
  NSData *data = [self _bitmapForSet:@"whitespaceandnlCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}

+ (NSCharacterSet *)whitespaceCharacterSet
{
  NSData *data = [self _bitmapForSet:@"whitespaceCharSet"];

  return [self characterSetWithBitmapRepresentation:data];
}


// Creating custom character sets

+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data
{
  return [[[NSBitmapCharSet alloc] initWithBitmap:data] autorelease];
}

+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)aString
{
  int   i, length;
  char *bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength:BITMAP_SIZE];

  if (!aString)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Creating character set with nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  bytes  = [bitmap mutableBytes];
  for (i=0; i < length; i++)
    {
      unichar letter = [aString characterAtIndex:i];
      SETBIT(bytes[letter/8], letter % 8);
    }

  return [self characterSetWithBitmapRepresentation:bitmap];
}

+ (NSCharacterSet *)characterSetWithRange:(NSRange)aRange
{
  int   i;
  char *bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength:BITMAP_SIZE];

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise:NSInvalidArgumentException
          format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  bytes = (char *)[bitmap mutableBytes];
  for (i=aRange.location; i < NSMaxRange(aRange); i++)
      SETBIT(bytes[i/8], i % 8);

  return [self characterSetWithBitmapRepresentation:bitmap];
}

- (NSData *)bitmapRepresentation
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (NSCharacterSet *)invertedSet
{
  int   i, length;
  char *bytes;
  NSMutableData *bitmap = [[self bitmapRepresentation] mutableCopy];

  length = [bitmap length];
  bytes = [bitmap mutableBytes];
  for (i=0; i < length; i++)
      bytes[i] = ~bytes[i];

  return [[self class] characterSetWithBitmapRepresentation:bitmap];
}


// NSCopying, NSMutableCopying
- (id)copyWithZone:(NSZone *)zone
{
  if (NSShouldRetainWithZone(self, zone))
      return [self retain];
  else
      return [super copyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSMutableBitmapCharSet allocWithZone:zone] initWithBitmap:bitmap];
}

@end

@implementation NSMutableCharacterSet

/* Provide a default object for allocation */
+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([NSMutableBitmapCharSet self], 0, zone);
}

/* Override this from NSCharacterSet to create the correct class */
+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data
{
  return [[[NSMutableBitmapCharSet alloc] initWithBitmap:data] autorelease];
}

/* Mutable subclasses must implement ALL of these methods.  */
- (void)addCharactersInRange:(NSRange)aRange
{
  [self subclassResponsibility:_cmd];
}

- (void)addCharactersInString:(NSString *)aString
{
  [self subclassResponsibility:_cmd];
}

- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet
{
  [self subclassResponsibility:_cmd];
}

- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet
{
  [self subclassResponsibility:_cmd];
}

- (void)removeCharactersInRange:(NSRange)aRange
{
  [self subclassResponsibility:_cmd];
}

- (void)removeCharactersInString:(NSString *)aString
{
  [self subclassResponsibility:_cmd];
}

- (void)invert
{
  [self subclassResponsibility:_cmd];
}

// NSCopying, NSMutableCopying
- (id)copyWithZone:(NSZone *)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSBitmapCharSet allocWithZone:zone] initWithBitmap:bitmap];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  return [super mutableCopyWithZone:zone];
}

@end
