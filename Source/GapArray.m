/* Implementation for Objective-C GapArray collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Kresten Krab Thorup <krab@iesd.auc.dk>
   Dept. of Mathematics and Computer Science, Aalborg U., Denmark

   Overhauled by: Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 


#include <config.h>
#include <base/GapArray.h>
#include <base/GapArrayPrivate.h>

@implementation GapArray

/* This is the designated initializer of this class */
/* Override designated initializer of superclass */
- initWithCapacity: (unsigned)aCapacity
{
  [super initWithCapacity: aCapacity];
  _gap_start = 0;
  _gap_size  = aCapacity;
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */

- emptyCopy
{
  GapArray *copy = [super emptyCopy];
  copy->_gap_start = 0;
  copy->_gap_size = copy->_capacity;
  return copy;
}

- (void) empty
{
  [super empty];
  _gap_start = 0;
  _gap_size = _capacity;
}

- (void) setCapacity: (unsigned)newCapacity
{
  if (newCapacity > _count)
    {
      gapMoveGapTo (self, _capacity-_gap_size); /* move gap to end */
      [super setCapacity: newCapacity];	/* resize */
      _gap_size = _capacity - _gap_start;
    }
}
      
- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [_contents_array[GAP_TO_BASIC (index)] release];
  gapFillHoleAt (self, index);
  decrementCount(self);
}

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[GAP_TO_BASIC(index)];
}

- (void) appendObject: newObject
{
  incrementCount(self);
  [newObject retain];
  gapMakeHoleAt (self, _count-1);
  _contents_array[_count-1] = newObject;
}

- (void) prependObject: newObject
{
  incrementCount(self);
  [newObject retain];
  gapMakeHoleAt (self, 0);
  _contents_array[0] = newObject;
}

- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  incrementCount(self);
  [newObject retain];
  gapMakeHoleAt (self, index);
  _contents_array[index] = newObject;
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: newObject
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [newObject retain];
  [_contents_array[GAP_TO_BASIC(index)] release];
  _contents_array[GAP_TO_BASIC(index)] = newObject;
}

- (void) swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  id tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  index1 = GAP_TO_BASIC(index1);
  index2 = GAP_TO_BASIC(index2);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
}

@end

