/* NSBitmapCharSet - Concrete character set holder
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <Foundation/NSBitmapCharSet.h>
#include <Foundation/NSException.h>

@implementation NSBitmapCharSet

- init
{
  return [self initWithBitmap:NULL];
}

/* Designated initializer */
- initWithBitmap:(NSData *)bitmap
{
  [super init];
  [bitmap getBytes:data length:BITMAP_SIZE];
  return self;
}

- (NSData *)bitmapRepresentation
{
  return [NSData dataWithBytes:data length:BITMAP_SIZE];
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
  return ISSET(data[aCharacter/8], aCharacter % 8);
}

@end

@implementation NSMutableBitmapCharSet

- init
{
  return [self initWithBitmap:NULL];
}

/* Designated initializer */
- initWithBitmap:(NSData *)bitmap
{
  [super init];
  if (bitmap)
      [bitmap getBytes:data length:BITMAP_SIZE];
  return self;
}

/* Need to implement the next two methods just like NSBitmapCharSet */
- (NSData *)bitmapRepresentation
{
  return [NSData dataWithBytes:data length:BITMAP_SIZE];
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
  return ISSET(data[aCharacter/8], aCharacter % 8);
}

- (void)addCharactersInRange:(NSRange)aRange
{
  int i;

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  for (i=aRange.location; i < NSMaxRange(aRange); i++)
      SETBIT(data[i/8], i % 8);
}

- (void)addCharactersInString:(NSString *)aString
{
  int   i, length;

  if (!aString)
    {
      [NSException raise:NSInvalidArgumentException
          format:@"Adding characters from nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  for (i=0; i < length; i++)
    {
      unichar letter = [aString characterAtIndex:i];
      SETBIT(data[letter/8], letter % 8);
    }
}

- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet
{
  int i;
  const char *other_bytes;

  other_bytes = [[otherSet bitmapRepresentation] bytes];
  for (i=0; i < BITMAP_SIZE; i++)
      data[i] = (data[i] || other_bytes[i]);
}

- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet
{
  int i;
  const char *other_bytes;

  other_bytes = [[otherSet bitmapRepresentation] bytes];
  for (i=0; i < BITMAP_SIZE; i++)
      data[i] = (data[i] && other_bytes[i]);
}

- (void)removeCharactersInRange:(NSRange)aRange
{
  int i;

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise:NSInvalidArgumentException
	  format:@"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  for (i=aRange.location; i < NSMaxRange(aRange); i++)
      CLRBIT(data[i/8], i % 8);
}

- (void)removeCharactersInString:(NSString *)aString
{
  int   i, length;

  if (!aString)
    {
      [NSException raise:NSInvalidArgumentException
          format:@"Removing characters from nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  for (i=0; i < length; i++)
    {
      unichar letter = [aString characterAtIndex:i];
      CLRBIT(data[letter/8], letter % 8);
    }
}

- (void)invert
{
  int i;

  for (i=0; i < BITMAP_SIZE; i++)
      data[i] = ~data[i];
}

@end
