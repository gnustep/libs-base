/* Concrete implementation of NSArray based on GNU Array class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
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
  /* "super" call into IndexedCollection */
#if 1
  CALL_METHOD_IN_CLASS([IndexedCollection class], initWithType:,
		       @encode(id));
#else
  (*(imp))
#endif
  _comparison_function = elt_get_comparison_function(@encode(id));
  _grow_factor = [[self class] defaultGrowFactor];
  _count = count;
  _capacity = (count < 1) ? 1 : count;
  OBJC_MALLOC(_contents_array, elt, _capacity);
  while (count--)
    {
      [objects[count] retain];
      _contents_array[count] = objects[count];
    }
  return self;
}

- (unsigned) count
{
  return _count;
}

- objectAtIndex: (unsigned)index
{
  assert(index < _count);	/* xxx should raise NSException instead */
  return _contents_array[index].id_u;
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
  /* "super" call into IndexedCollection */
  CALL_METHOD_IN_CLASS([IndexedCollection class], initWithType:,
		       @encode(id));
  _comparison_function = elt_get_comparison_function(@encode(id));
  _grow_factor = [[self class] defaultGrowFactor];
  _count = 0;
  _capacity = (numItems < 1) ? 1 : numItems;
  OBJC_MALLOC(_contents_array, elt, _capacity);
  return self;
}

/* Comes in from Array behavior 
   - (void) addObject: anObject
   - (void)replaceObjectAtIndex: (unsigned)index withObject: anObject
   - (void)insertObject: anObject atIndex: (unsigned)index
   */

@end
