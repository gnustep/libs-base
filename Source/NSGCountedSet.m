/* Concrete implementation of NSCountedSet based on GNU Bag class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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

#include <Foundation/NSGSet.h>
#include <gnustep/base/NSSet.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/Set.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

@interface NSGCountedSetEnumerator : NSEnumerator
{
  NSCountedSet *bag;
  void *enum_state;
}
@end

@implementation NSGCountedSetEnumerator

- initWithCountedSet: (NSCountedSet*)d
{
  [super init];
  bag = d;
  [bag retain];
  enum_state = 0;
  return self;
}

- nextObject
{
  return [bag nextObjectWithEnumState: &enum_state];
}

- (void) dealloc
{
  [bag release];
  [super dealloc];
}

@end


@implementation NSGCountedSet

+ (void) initialize
{
  static int done = 0;

  if (!done)
    {
      done = 1;
      class_add_behavior([NSGCountedSet class], [Bag class]);
    }
}

- initWithCapacity: (unsigned)numItems
{
  return [self initWithType:@encode(id)
	       capacity:numItems];
}

- (NSEnumerator*) objectEnumerator
{
  return [[[NSGCountedSetEnumerator alloc] initWithCountedSet:self]
	  autorelease];
}

- (unsigned int) countForObject: anObject
{
  return [self occurrencesOfObject: anObject];
}

/* To deal with behavior over-enthusiasm.  Will be fixed later. */
- (BOOL) isEqual: other
{
  return [super isEqual:other];
}

@end
