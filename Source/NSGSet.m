/* Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: September 1995
   
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

#include <Foundation/NSGSet.h>
#include <objects/NSSet.h>
#include <objects/behavior.h>
#include <objects/Set.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

@interface NSGSetEnumerator : NSEnumerator
{
  NSSet *set;
  void *enum_state;
}
@end

@implementation NSGSetEnumerator

- initWithSet: (NSSet*)d
{
  [super init];
  set = d;
  [set retain];
  enum_state = [set newEnumState];
  return self;
}

- nextObject
{
  return [set nextObjectWithEnumState: &enum_state];
}

- (void) dealloc
{
  [set release];
  [super dealloc];
}

@end


@implementation NSGSet

+ (void) initialize
{
  static int done = 0;

  if (!done)
    {
      done = 1;
      class_add_behavior([NSGSet class], [Set class]);
    }
}


/* This is the designated initializer 
   - initWithObjects: (id*)objects
   count: (unsigned)count
   Implemented by behavior. */

- member: anObject
{
  return ([self containsObject: anObject] ? anObject : nil);
}

- (NSEnumerator*) objectEnumerator
{
  return [[[NSGSetEnumerator alloc] initWithSet:self]
	  autorelease];
}

/* To deal with behavior over-enthusiasm.  Will be fixed later. */
- (BOOL) isEqual: other
{
  /* xxx What is the correct behavior here.
     If we end up calling [NSSet -isEqualToSet:] we end up in
     an infinite loop, since that method enumerates the set, and
     the set enumerator asks if things are equal...
     [Huh? What am I saying here?] */
  return (self == other);
}
@end

@implementation NSGMutableSet

+ (void) initialize
{
  static int done = 0;

  if (!done)
    {
      done = 1;
      class_add_behavior([NSGMutableSet class], [NSGSet class]);
    }
}

/* This is the designated initializer
   - initWithCapacity: (unsigned)numItems
   implemented by behavior. */

/* Implemented by behavior:
   - (void) addObject: newObject;
   - (void) removeObject: anObject
   */

- (void) removeAllObjects
{
  [self empty];
}

/* To deal with behavior over-enthusiasm.  Will be fixed later. */
- (BOOL) isEqual: other
{
  return [super isEqual:other];
}

@end
