/* Concrete implementation of NSDictionary based on GNU Dictionary class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: April 1995
   
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

#include <Foundation/NSGDictionary.h>
#include <objects/NSDictionary.h>
#include <objects/behavior.h>
#include <objects/Dictionary.h>
#include <objects/eltfuncs.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

@interface NSGDictionaryKeyEnumerator : NSEnumerator
{
  NSDictionary *dictionary;
  void *enum_state;
}
@end

@implementation NSGDictionaryKeyEnumerator

- initWithDictionary: (NSDictionary*)d
{
  [super init];
  dictionary = d;
  [dictionary retain];
  enum_state = 0;
  return self;
}

- nextObject
{
  id k;
  return [dictionary nextObjectAndKey: &k withEnumState: &enum_state];
}

- (void) dealloc
{
  [dictionary release];
  [super dealloc];
}

@end

@interface NSGDictionaryObjectEnumerator : NSGDictionaryKeyEnumerator
@end

@implementation NSGDictionaryObjectEnumerator

- nextObject
{
  id k;
  [dictionary nextObjectAndKey: &k withEnumState: &enum_state];
  return k;
}

@end


@implementation NSGDictionary

+ (void) initialize
{
  if (self == [NSGDictionary class])
    class_add_behavior([NSGDictionary class], [Dictionary class]);
}

/* 
   Comes from Dictionary.m 
   - initWithObjects: (id*)objects
	  forKeys: (NSString**)keys
	    count: (unsigned)count
   - (unsigned) count 
   - objectForKey: (NSString*)aKey
   - (NSEnumerator*) keyEnumerator
   - (NSEnumerator*) objectEnumerator
   */

@end

@implementation NSGMutableDictionary

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGMutableDictionary class], [NSGDictionary class]);
    }
}

/* This is the designated initializer */
/* Comes from Dictionary.m
   - initWithCapacity: (unsigned)numItems
   */

- (void) setObject:anObject forKey:(NSString *)aKey
{
  [self putObject: anObject atKey: aKey];
}

- (void) removeObjectForKey:(NSString *)aKey
{
  [self removeObjectAtKey: aKey];
}

@end
