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

#include <Foundation/NSCharacterSet.h>


@implementation NSCharacterSet

// Creating standard character sets

+ (NSCharacterSet *)alphanumericCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)controlCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)decimalDigitCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)decomposableCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)illegalCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)letterCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)lowercaseLetterCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)nonBaseCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)uppercaseLetterCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)whitespaceCharacterSet
{
  [self notImplemented:_cmd];
  return 0;
}


// Creating custom character sets

+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)aString
{
  [self notImplemented:_cmd];
  return 0;
}

+ (NSCharacterSet *)characterSetWithRange:(NSRange)aRange
{
  [self notImplemented:_cmd];
  return 0;
}


/* Other instance methods - only the first TWO must be implemented by all 
   subclasses.  There is an abstract implementation of the inverted set.
*/
- (NSData *)bitmapRepresentation
{
  [self notImplemented:_cmd];
  return 0;
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSCharacterSet *)invertedSet
{
  [self notImplemented:_cmd];
  return 0;
}


// NSCopying, NSMutableCopying
/* deepening is done by concrete subclasses */
- deepen
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  if (NSShouldRetainWithZone(self, zone))
      return [self retain];
  else
      return [[super copyWithZone:zone] deepen];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  NSMutableCharacterSet *copy;
  copy = [[NSMutableCharacterSet allocWithZone:zone] init];
  [copy formUnionWithCharacterSet:self];
  return copy;
}

@end

@implementation NSMutableCharacterSet

/* Mutable subclasses must implement ALL of these methods.  */
- (void)addCharactersInRange:(NSRange)aRange
{
  [self notImplemented:_cmd];
}

- (void)addCharactersInString:(NSString *)aString
{
  [self notImplemented:_cmd];
}

- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet
{
  [self notImplemented:_cmd];
}

- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet
{
  [self notImplemented:_cmd];
}

- (void)removeCharactersInRange:(NSRange)aRange
{
  [self notImplemented:_cmd];
}

- (void)removeCharactersInString:(NSString *)aString
{
  [self notImplemented:_cmd];
}

- (void)invert
{
  [self notImplemented:_cmd];
}

// NSCopying, NSMutableCopying
/* deepening is done by concrete subclasses */
- deepen
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[super copyWithZone:zone] deepen];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  return [[super copyWithZone:zone] deepen];
}

@end
