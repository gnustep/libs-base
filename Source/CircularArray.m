/* Implementation for Objective-C CircularArray collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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
#include <gnustep/base/CircularArray.h>
#include <gnustep/base/CircularArrayPrivate.h>

@implementation CircularArray

/* This is the designated initializer of this class */
- initWithCapacity: (unsigned)aCapacity
{
  [super initWithCapacity:aCapacity];
  _start_index = 0;
  return self;
}

/* Archiving must mimic the above designated initializer */

- _initCollectionWithCoder: coder
{
  [super _initCollectionWithCoder:coder];
  _start_index = 0;
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */

- emptyCopy
{
  CircularArray *copy = [super emptyCopy];
  copy->_start_index = 0;
  return copy;
}

- (void) empty
{
  [super empty];
  _start_index = 0;
}

/* This is the only method that changes the value of the instance
   variable _capacity, except for "-initWithCapacity:" */

- (void) setCapacity: (unsigned)newCapacity
{
  id *new_contents;
  int i;

  if (newCapacity > _count) {
    /* This could be more efficient */
    OBJC_MALLOC(new_contents, id, newCapacity);
    for (i = 0; i < _count; i++)
      new_contents[i] = _contents_array[CIRCULAR_TO_BASIC(i)];
    OBJC_FREE(_contents_array);
    _contents_array = new_contents;
    _start_index = 0;
    _capacity = newCapacity;
  }
}

- (void) removeObjectAtIndex: (unsigned)index
{
  unsigned basicIndex;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  basicIndex = CIRCULAR_TO_BASIC(index);
  [_contents_array[basicIndex] release];
  circularFillHoleAt(self, basicIndex);
  decrementCount(self);
}

- (void) removeFirstObject
{
  if (!_count)
    return;
  [_contents_array[_start_index] release];
  _start_index = (_start_index + 1) % _capacity;
  decrementCount(self);
}

- (void) removeLastObject
{
  if (!_count)
    return;
  [_contents_array[CIRCULAR_TO_BASIC(_count-1)] release];
  decrementCount(self);
}

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[CIRCULAR_TO_BASIC(index)];
}

- (void) appendObject: newObject
{
  incrementCount(self);
  [newObject retain];
  _contents_array[CIRCULAR_TO_BASIC(_count-1)] = newObject;
}

- (void) prependElement: newObject
{
  incrementCount(self);
  [newObject retain];
  _start_index = (_capacity + _start_index - 1) % _capacity;
  _contents_array[_start_index] = newObject;
}

- (void) insertElement: newObject atIndex: (unsigned)index
{
  unsigned basicIndex;

  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  incrementCount(self);
  [newObject retain];
  basicIndex = CIRCULAR_TO_BASIC(index);
  circularMakeHoleAt(self, basicIndex);
  _contents_array[basicIndex] = newObject;
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: newObject
{
  unsigned basicIndex;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  [newObject retain];
  basicIndex = CIRCULAR_TO_BASIC(index);
  [_contents_array[basicIndex] release];
  _contents_array[basicIndex] = newObject;
}

- (void) swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  id tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  index1 = CIRCULAR_TO_BASIC(index1);
  index2 = CIRCULAR_TO_BASIC(index2);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
}

#if 0
/* just temporary for debugging */
- circularArrayPrintForDebugger
{
  int i;

  printf("_start_index=%d, _count=%d, _capacity=%d\n",
	 _start_index, _count, _capacity);
  for (i = 0; i < _capacity; i++)
    {
      printf("%3d ", i);
    }
  printf("\n");
  for (i = 0; i < _capacity; i++)
    {
      printf("%3d ", _contents_array[i].int_t);
    }
  printf("\n");
  for (i = 0; i < _capacity; i++)
    {
      printf("%3d ", _contents_array[CIRCULAR_TO_BASIC(i)].int_t);
    }
  printf("\n");

  return self;
}
#endif

@end

