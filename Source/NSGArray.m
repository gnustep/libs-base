/* Concrete implementation of NSArray based on GNU Array class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
   This file is part of the Gnustep Base Library.
   
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

#include <gnustep/base/preface.h>
#include <Foundation/NSGArray.h>
#include <Foundation/NSArray.h>
#include <gnustep/base/NSArray.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/ArrayPrivate.h>
#include <Foundation/NSException.h>

@implementation NSGArray

+ (void) initialize
{
  if (self == [NSGArray class])
    {
      behavior_class_add_class (self, [NSArrayNonCore class]);
      behavior_class_add_class (self, [Array class]);
    }
}

/* #define self ((Array*)self) */

#if 0
/* This is the designated initializer for NSArray. */
- initWithObjects: (id*)objects count: (unsigned)count
{
  int i;

  for (i = 0; i < count; i++)
    if (objects[i] == nil)
      [NSException raise:NSInvalidArgumentException
		   format:@"Tried to add nil"];
  [self initWithCapacity: count];
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
  return self->_contents_array[index];
}
#endif

@end

@implementation NSGMutableArray

+ (void) initialize
{
  if (self == [NSGMutableArray class])
    {
      behavior_class_add_class (self, [NSMutableArrayNonCore class]);
      behavior_class_add_class (self, [NSGArray class]);
      behavior_class_add_class (self, [Array class]);
    }
}

#if 0
/* Comes in from Array behavior 
   - initWithCapacity:
   - (void) addObject: anObject
   - (void) insertObject: anObject atIndex: (unsigned)index
   */

- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject
{
  [self replaceObjectAtIndex: index with: anObject];
}
#endif

@end
