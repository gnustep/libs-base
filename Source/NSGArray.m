/* Concrete implementation of NSArray based on GNU Array class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
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

#include <Foundation/NSGArray.h>
#include <objects/NSArray.h>
#include <objects/behavior.h>
#include <objects/Array.h>
#include <objects/ArrayPrivate.h>
#include <Foundation/NSException.h>

#define self ((Array*)self)

@implementation NSGArray

+ (void) initialize
{
  static int done = 0;
  assert(!done);		/* xxx see what the runtime is up to. */
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGArray class], [Array class]);
    }
}

/* This is the designated initializer for NSArray. */
- initWithObjects: (id*)objects count: (unsigned)count
{
  int i;

  for (i = 0; i < count; i++)
    if (objects[i] == nil)
      [NSException raise:NSInvalidArgumentException
		   format:@"Tried to add nil"];
  [self initWithType: @encode(id) capacity: count];
  while (count--)
    [self addObject: [objects[count] retain]];
  return self;
}

/* Force message to go to super class rather than the behavior class */
- (unsigned) indexOfObject: anObject
{
  return [super indexOfObject: anObject];
}

- objectAtIndex: (unsigned)index
{
  if (index >= self->_count)
    [NSException raise: NSRangeException
		 format: @"Index out of bounds"];
  return self->_contents_array[index].id_u;
}


@end

@implementation NSGMutableArray

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGMutableArray class], [NSGArray class]);
      class_add_behavior([NSGMutableArray class], [Array class]);
    }
}

- initWithCapacity: (unsigned)numItems
{
  return [self initWithType: @encode(id) capacity: numItems];
}

/* Comes in from Array behavior 
   - (void) addObject: anObject
   - (void) insertObject: anObject atIndex: (unsigned)index
   */

- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject
{
  [self replaceObjectAtIndex: index with: anObject];
}

@end
