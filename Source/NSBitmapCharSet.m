/** NSBitmapCharSet - Concrete character set holder
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <config.h>
#include <Foundation/NSBitmapCharSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>

@implementation NSBitmapCharSet

- (id) init
{
  return [self initWithBitmap: NULL];
}

/* Designated initializer */
- (id) initWithBitmap: (NSData*)bitmap
{
  [super init];

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

/* Designated initializer */
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
