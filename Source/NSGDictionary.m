/* Concrete implementation of NSDictionary based on GNU Dictionary class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: April 1995
   
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

#include <Foundation/NSGDictionary.h>
#include <gnustep/base/NSDictionary.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/Dictionary.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

@class NSDictionaryNonCore;
@class NSMutableDictionaryNonCore;

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
  [dictionary nextObjectAndKey: &k withEnumState: &enum_state];
  return k;
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
    {
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
      behavior_class_add_class (self, [Dictionary class]);
    }
}

- objectForKey: aKey
{
  /* xxx Should I change the method name in Dictionary?
     I don't really want to; I think "at" is better. */
  return [self objectAtKey: aKey];
}

/* 
   Comes from Dictionary.m 
   - initWithObjects: (id*)objects
	  forKeys: (NSObject**)keys
	    count: (unsigned)count
   - (unsigned) count 
   - (NSEnumerator*) keyEnumerator
   - (NSEnumerator*) objectEnumerator
   */

@end

@implementation NSGMutableDictionary

+ (void) initialize
{
  if (self == [NSGMutableDictionary class])
    {
      behavior_class_add_class (self, [NSMutableDictionaryNonCore class]);
      behavior_class_add_class (self, [NSGDictionary class]);
      behavior_class_add_class (self, [Dictionary class]);
    }
}


/* This is the designated initializer */
/* Comes from Dictionary.m
   - initWithCapacity: (unsigned)numItems
   */

- (void) setObject:anObject forKey:(NSObject *)aKey
{
  [self putObject: anObject atKey: aKey];
}

- (void) removeObjectForKey:(NSObject *)aKey
{
  [self removeObjectAtKey: aKey];
}

@end
