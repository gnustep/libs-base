/* NSCharacterSet - Character set holder
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <config.h>
#include <Foundation/NSBitmapCharSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSProcessInfo.h>
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
      int i;
      for (i = 0; i < MAX_STANDARD_SETS; i++)
	cache_set[i] = 0;
      one_time = YES;
    }
}

/* Provide a default object for allocation */
+ allocWithZone: (NSZone *)zone
{
  return NSAllocateObject([NSBitmapCharSet self], 0, zone);
}

// Creating standard character sets

+ (NSCharacterSet *) _bitmapForSet: (NSString *)setname number: (int)number
{
  NSCharacterSet* set;
  NSString *user_path, *local_path, *system_path;
  NSBundle *user_bundle = nil, *local_bundle = nil, *system_bundle = nil;
  NSProcessInfo *pInfo;
  NSDictionary *env;
  NSString *user, *local, *system;

  /*
    The path of where to search for the resource files
    is based upon environment variables.
    GNUSTEP_USER_ROOT
    GNUSTEP_LOCAL_ROOT
    GNUSTEP_SYSTEM_ROOT
    */
  pInfo = [NSProcessInfo processInfo];
  env = [pInfo environment];
  user = [env objectForKey: @"GNUSTEP_USER_ROOT"];
  user = [user stringByAppendingPathComponent: @"Libraries"];
  local = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
  local = [local stringByAppendingPathComponent: @"Libraries"];
  system = [env objectForKey: @"GNUSTEP_SYSTEM_ROOT"];
  system = [system stringByAppendingPathComponent: @"Libraries"];

  if (user)
    user_bundle = [NSBundle bundleWithPath: user];
  if (local)
    local_bundle = [NSBundle bundleWithPath: local];
  if (system)
    system_bundle = [NSBundle bundleWithPath: system];

  if (!cache_lock)
    cache_lock = [NSLock new];
  [cache_lock lock];

  set = nil; /* Quiet warnings */
  if (cache_set[number] == nil)
    {
      NS_DURING

	/* Gather up the paths */
	/* Search user first */
	user_path = [user_bundle pathForResource: setname
				 ofType: @"dat"
				 inDirectory: NSCharacterSet_PATH];
        /* Search local second */
        local_path = [local_bundle pathForResource: setname
				   ofType: @"dat"
				   inDirectory: NSCharacterSet_PATH];
	/* Search system last */
	system_path = [system_bundle pathForResource: setname
				     ofType: @"dat"
				     inDirectory: NSCharacterSet_PATH];

	/* Try to load the set from the user path */
        set = nil;
        if (user_path != nil && [user_path length] != 0)
	  {
	    NS_DURING
	      /* Load the character set file */
	      set = [self characterSetWithBitmapRepresentation: 
			    [NSData dataWithContentsOfFile: user_path]];
            NS_HANDLER
              NSLog(@"Unable to read NSCharacterSet file %s",
		    [user_path cString]);
	      set = nil;
            NS_ENDHANDLER
	  }

	/* If we don't have a set yet then check local path */
	if (set == nil && local_path != nil && [local_path length] != 0)
	  {
	    NS_DURING
	      /* Load the character set file */
	      set = [self characterSetWithBitmapRepresentation: 
			    [NSData dataWithContentsOfFile: local_path]];
            NS_HANDLER
              NSLog(@"Unable to read NSCharacterSet file %s",
		    [local_path cString]);
	      set = nil;
            NS_ENDHANDLER
	  }

	/* Lastly if we don't have a set yet then check system path */
	if (set == nil && system_path != nil && [system_path length] != 0)
	  {
	    NS_DURING
	      /* Load the character set file */
	      set = [self characterSetWithBitmapRepresentation: 
			    [NSData dataWithContentsOfFile: system_path]];
            NS_HANDLER
              NSLog(@"Unable to read NSCharacterSet file %s",
		    [system_path cString]);
	      set = nil;
            NS_ENDHANDLER
	  }

	/* If we didn't load a set then raise an exception */
	if (!set)
	  {
	    [NSException raise: NSGenericException
			 format: @"Could not find bitmap file %s",
			 [setname cString]];
	    /* NOT REACHED */
	  }
	else
	  /* Else cache the set */
	  cache_set[number] = RETAIN(set);

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
  return [self _bitmapForSet: @"alphanumericCharSet" number: 0];
}

+ (NSCharacterSet *)controlCharacterSet
{
  return [self _bitmapForSet: @"controlCharSet" number: 1];
}

+ (NSCharacterSet *)decimalDigitCharacterSet
{
  return [self _bitmapForSet: @"decimalDigitCharSet" number: 2];
}

+ (NSCharacterSet *)decomposableCharacterSet
{
  return [self _bitmapForSet: @"decomposableCharSet" number: 3];
}

+ (NSCharacterSet *)illegalCharacterSet
{
  return [self _bitmapForSet: @"illegalCharSet" number: 4];
}

+ (NSCharacterSet *)letterCharacterSet
{
  return [self _bitmapForSet: @"letterCharSet" number: 5];
}

+ (NSCharacterSet *)lowercaseLetterCharacterSet
{
  return [self _bitmapForSet: @"lowercaseLetterCharSet" number: 6];
}

+ (NSCharacterSet *)nonBaseCharacterSet
{
  return [self _bitmapForSet: @"nonBaseCharSet" number: 7];
}

+ (NSCharacterSet *)punctuationCharacterSet;
{
  return [self _bitmapForSet: @"punctuationCharSet" number: 8];
}

+ (NSCharacterSet *)symbolAndOperatorCharacterSet;
{
  return [self _bitmapForSet: @"symbolAndOperatorCharSet" number: 9];
}

+ (NSCharacterSet *)uppercaseLetterCharacterSet
{
  return [self _bitmapForSet: @"uppercaseLetterCharSet" number: 10];
}

+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet
{
  return [self _bitmapForSet: @"whitespaceAndNlCharSet" number: 11];
}

+ (NSCharacterSet *)whitespaceCharacterSet
{
  return [self _bitmapForSet: @"whitespaceCharSet" number: 12];
}

// Creating custom character sets

+ (NSCharacterSet *)characterSetWithBitmapRepresentation: (NSData *)data
{
  return AUTORELEASE([[NSBitmapCharSet alloc] initWithBitmap: data]);
}

+ (NSCharacterSet *)characterSetWithCharactersInString: (NSString *)aString
{
  int   i, length;
  char *bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength: BITMAP_SIZE];

  if (!aString)
    {
      [NSException raise: NSInvalidArgumentException
	  format: @"Creating character set with nil string"];
      /* NOT REACHED */
    }

  length = [aString length];
  bytes  = [bitmap mutableBytes];
  for (i=0; i < length; i++)
    {
      unichar letter = [aString characterAtIndex: i];
      SETBIT(bytes[letter/8], letter % 8);
    }

  return [self characterSetWithBitmapRepresentation: bitmap];
}

+ (NSCharacterSet *)characterSetWithRange: (NSRange)aRange
{
  int   i;
  char *bytes;
  NSMutableData *bitmap = [NSMutableData dataWithLength: BITMAP_SIZE];

  if (NSMaxRange(aRange) > UNICODE_SIZE)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"Specified range exceeds character set"];
      /* NOT REACHED */
    }

  bytes = (char *)[bitmap mutableBytes];
  for (i=aRange.location; i < NSMaxRange(aRange); i++)
      SETBIT(bytes[i/8], i % 8);

  return [self characterSetWithBitmapRepresentation: bitmap];
}

+ (NSCharacterSet *)characterSetWithContentsOfFile: (NSString *)aFile
{
  if ([@"bitmap" isEqual: [aFile pathExtension]])
    {
      NSData	*bitmap = [NSData dataWithContentsOfFile: aFile];
      return [self characterSetWithBitmapRepresentation: bitmap];
    }
  else
    return nil;
}

- (NSData *)bitmapRepresentation
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL)characterIsMember: (unichar)aCharacter
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
      int	i;

      for (i = 0; i <= 0xffff; i++)
        if ([self characterIsMember: (unichar)i] !=
		[anObject characterIsMember: (unichar)i])
	  return NO;
      return YES;
    }
  return NO;
}

- (NSCharacterSet *)invertedSet
{
  int   i, length;
  char *bytes;
  NSMutableData *bitmap;

  bitmap = AUTORELEASE([[self bitmapRepresentation] mutableCopy]);
  length = [bitmap length];
  bytes = [bitmap mutableBytes];
  for (i=0; i < length; i++)
      bytes[i] = ~bytes[i];

  return [[self class] characterSetWithBitmapRepresentation: bitmap];
}


// NSCopying, NSMutableCopying
- (id) copyWithZone: (NSZone *)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject (self, 0, zone);
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSMutableBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

@end

@implementation NSMutableCharacterSet

/* Provide a default object for allocation */
+ allocWithZone: (NSZone *)zone
{
  return NSAllocateObject([NSMutableBitmapCharSet self], 0, zone);
}

/* Override this from NSCharacterSet to create the correct class */
+ (NSCharacterSet *)characterSetWithBitmapRepresentation: (NSData *)data
{
  return AUTORELEASE([[NSMutableBitmapCharSet alloc] initWithBitmap: data]);
}

/* Mutable subclasses must implement ALL of these methods.  */
- (void)addCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

- (void)addCharactersInString: (NSString *)aString
{
  [self subclassResponsibility: _cmd];
}

- (void)formUnionWithCharacterSet: (NSCharacterSet *)otherSet
{
  [self subclassResponsibility: _cmd];
}

- (void)formIntersectionWithCharacterSet: (NSCharacterSet *)otherSet
{
  [self subclassResponsibility: _cmd];
}

- (void)removeCharactersInRange: (NSRange)aRange
{
  [self subclassResponsibility: _cmd];
}

- (void)removeCharactersInString: (NSString *)aString
{
  [self subclassResponsibility: _cmd];
}

- (void)invert
{
  [self subclassResponsibility: _cmd];
}

// NSCopying, NSMutableCopying
- (id)copyWithZone: (NSZone *)zone
{
  NSData *bitmap;
  bitmap = [self bitmapRepresentation];
  return [[NSBitmapCharSet allocWithZone: zone] initWithBitmap: bitmap];
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
  return [super mutableCopyWithZone: zone];
}

@end
