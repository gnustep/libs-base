/* Implementation for Objective-C GapArray collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Kresten Krab Thorup <krab@iesd.auc.dk>
   Dept. of Mathematics and Computer Science, Aalborg U., Denmark

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


#include <objects/GapArray.h>
#include <objects/GapArrayPrivate.h>

@implementation GapArray

+ (void) initialize
{
  if (self == [GapArray class])
    [self setVersion:0];	/* beta release */
}

/* This is the designated initializer of this class */
/* Override designated initializer of superclass */
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity
{
  [super initWithType:contentEncoding
	 capacity:aCapacity];
  _gap_start = 0;
  _gap_size  = aCapacity;
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: (Coder*)aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- _readInit: (TypedStream*)aStream
{
  [super _readInit: aStream];
  _gap_start = 0;
  _gap_size = _capacity;
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

- _empty
{
  [super _empty];
  _gap_start = 0;
  _gap_size = _capacity;
  return self;
}

- setCapacity: (unsigned)newCapacity
{
  if (newCapacity > _count)
    {
      gapMoveGapTo (self, _capacity-_gap_size); /* move gap to end */
      [super setCapacity: newCapacity];	/* resize */
      _gap_size = _capacity - _gap_start;
    }
  return self;
}
      
- (elt) removeElementAtIndex: (unsigned)index
{
  elt res;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  res = _contents_array[GAP_TO_BASIC (index)];
  gapFillHoleAt (self, index);
  decrementCount(self);
  return AUTORELEASE_ELT(res);
}

- (elt) removeFirstElement
{
  elt res = _contents_array[GAP_TO_BASIC (0)];
  gapFillHoleAt (self, 0);
  decrementCount(self);
  return AUTORELEASE_ELT(res);
}

- (elt) removeLastElement
{
  return [self removeElementAtIndex: _count-1];
}

- (elt) elementAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[GAP_TO_BASIC(index)];
}

- appendElement: (elt)newElement
{
  incrementCount(self);
  RETAIN_ELT(newElement);
  gapMakeHoleAt (self, _count-1);
  _contents_array[_count-1] = newElement;
  return self;
}

- prependElement: (elt)newElement
{
  incrementCount(self);
  gapMakeHoleAt (self, 0);
  _contents_array[0] = newElement;
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  incrementCount(self);
  RETAIN_ELT(newElement);
  gapMakeHoleAt (self, index);
  _contents_array[index] = newElement;
  return self;
}

- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  RETAIN_ELT(newElement);
  ret = _contents_array[GAP_TO_BASIC(index)];
  _contents_array[GAP_TO_BASIC(index)] = newElement;
  return AUTORELEASE_ELT(ret);
}

- swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  elt tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  index1 = GAP_TO_BASIC(index1);
  index2 = GAP_TO_BASIC(index2);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
  return self;
}

@end

