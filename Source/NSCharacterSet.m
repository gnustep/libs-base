/* NSCharacterSet - Character set holder
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.

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
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSLock.h>

#ifndef NSCharacterSet_PATH
#define NSCharacterSet_PATH OBJC_STRINGIFY(GNUSTEP_INSTALL_LIBDIR) @"/NSCharacterSets"
#endif

/* A simple array for caching standard bitmap sets */
#define MAX_STANDARD_SETS 12
static NSCharacterSet* cache_set[MAX_STANDARD_SETS];
static NSLock* cache_lock = nil;

@implementation NSCharacterSet

+ (void) initialize
{
  static BOOL one_time = NO;

  if (one_time == NO)
    {
      int i;
      for (i = 0; i < MAX_STANDARD_SETS; i++)
	cache_set[i] = 0;
      one_time = YES;
    }
}

/* Provide a default object for allocation */
+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([NSBitmapCharSet self], 0, zone);
}

// Creating standard character sets

+ (NSCharacterSet *) _bitmapForSet: (NSString *)setname number: (int)number
{
  NSCharacterSet* set;
  NSString *path;

  if (!cache_lock)
    cache_lock = [NSLock new];
  [cache_lock lock];

  set = nil; /* Quiet warnings */
  if (cache_set[number] == nil)
    {
      NS_DURING
	path = [NSBundle pathForResource:setname
			ofType:@"dat"
			inDirectory:NSCharacterSet_PATH];
        /* This is for testing purposes */
        if (path == nil || [path length] == 0)
	  {
	    path = [NSBundle pathForResource:setname
			ofType:@"dat"
			inDirectory:@"../NSCharacterSets"];
	  }

        if (path == nil || [path length] == 0)
	  {
	    [NSException raise:NSGenericException
	      format:@"Could not find bitmap file %s", [setname cString]];
	    /* NOT REACHED */
	  }

        set = [self characterSetWithBitmapRepresentation: 
	        [NSData dataWithContentsOfFile: path]];
        cache_set[number] = [set retain];
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


+ (NSCharacterSet *)alphanumericCharacterSet
{
  return [self _bitmapForSet:@"alphanumCharSet" number: 0];
}

+ (NSCharacterSet *)controlCharacterSet
{
  return [self _bitmapForSet:@"controlCharSet" number: 1];
}

+ (NSCharacterSet *)decimalDigitCharacterSet
{
  return [self _bitmapForSet:@"decimalCharSet" number: 2];
}

+ (NSCharacterSet *)decomposableCharacterSet
{
  fprintf(stderr, "Warning: Decomposable set not yet fully specified\n");
  return [self _bitmapForSet:@"decomposableCharSet" number: 3];
}

+ (NSCharacterSet *)illegalCharacterSet
{
  fprintf(stderr, "Warning: Illegal set not yet fully specified\n");
  return [self _bitmapForSet:@"illegalCharSet" number: 4];
}

+ (NSCharacterSet *)letterCharacterSet
{
  return [self _bitmapForSet:@"lettercharCharSet" number: 5];
}

+ (NSCharacterSet *)lowercaseLetterCharacterSet
{
  return [self _bitmapForSet:@"lowercaseCharSet" number: 6];
}

+ (NSCharacterSet *)nonBaseCharacterSet
{
  return [self _bitmapForSet:@"nonbaseCharSet" number: 7];
}

+ (NSCharacterSet *)uppercaseLetterCharacterSet
{
  return [self _bitmapForSet:@"uppercaseCharSet" number: 8];
}

+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet
{
  return [self _bitmapForSet:@"whitespaceandnlCharSet" number: 9];
}

+ (NSCharacterSet *)whitespaceCharacterSet
{
  return [self _bitmapForSet:@"whitespaceCharSet" number: 10];
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
