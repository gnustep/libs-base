/* Concrete implementation of NSArray based on GNU Array class
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
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
#include <gnustep/base/preface.h>
#include <Foundation/NSGArray.h>
#include <Foundation/NSArray.h>
#include <gnustep/base/NSArray.h>
#include <gnustep/base/behavior.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/ArrayPrivate.h>
#include <Foundation/NSException.h>

@class NSArrayNonCore;

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

- (void) getObjects: (id*)aBuffer
{
  unsigned i;
  for (i = 0; i < _count; i++)
    aBuffer[i] = _contents_array[i];
}

- (void) getObjects: (id*)aBuffer range: (IndexRange)aRange
{
  unsigned i, j = 0, e = aRange.location + aRange.length;
  if (_count < e)
    e = _count;
  for (i = aRange.location; i < _count; i++)
    aBuffer[j++] = _contents_array[i];
}

@end

@class NSMutableArrayNonCore;

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

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  unsigned c,d, stride;
  BOOL found;
  int count = _count;

  stride = 1;
  while (stride <= count)
    stride = stride * STRIDE_FACTOR + 1;
    
  while(stride > (STRIDE_FACTOR - 1)) {
    // loop to sort for each value of stride
    stride = stride / STRIDE_FACTOR;
    for (c = stride; c < count; c++) {
      found = NO;
      if (stride > c)
	break;
      d = c - stride;
      while (!found) {
	// move to left until correct place
	id a = _contents_array[d + stride];
	id b = _contents_array[d];
	if ((*compare)(a, b, context) == NSOrderedAscending) {
	  _contents_array[d+stride] = b;
	  _contents_array[d] = a;
	  if (stride > d)
	    break;
	  d -= stride;		// jump by stride factor
	}
	else found = YES;
      }
    }
  }
}

@end
