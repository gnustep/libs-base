/* Implementation for Objective-C CircularArray collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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


#include <objects/CircularArray.h>
#include <objects/CircularArrayPrivate.h>

@implementation CircularArray

+ (void) initialize
{
  if (self == [CircularArray class])
    [self setVersion:0];	/* beta release */
}

/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding 
    capacity: (unsigned)aCapacity
{
  [super initWithType:contentEncoding capacity:aCapacity];
  _start_index = 0;
  return self;
}

/* Archiving must mimic the above designated initializer */

+ _newCollectionWithCoder: (Coder*)coder
{
  CircularArray *n = [super newWithCoder:coder];
  n->_start_index = 0;
  return n;
}

- _readInit: (TypedStream*)aStream
{
  [super _readInit: aStream];
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

- _empty
{
  [super _empty];
  _start_index = 0;
  return self;
}

/* This is the only method that changes the value of the instance
   variable _capacity, except for "-initDescription:capacity:" */

- setCapacity: (unsigned)newCapacity
{
  elt *new_contents;
  int i;

  if (newCapacity > _count) {
    /* This could be more efficient */
    OBJC_MALLOC(new_contents, elt, newCapacity);
    for (i = 0; i < _count; i++)
      new_contents[i] = _contents_array[CIRCULAR_TO_BASIC(i)];
    OBJC_FREE(_contents_array);
    _contents_array = new_contents;
    _start_index = 0;
    _capacity = newCapacity;
  }
  return self;
}

- (elt) removeElementAtIndex: (unsigned)index
{
  unsigned basicIndex;
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  basicIndex = CIRCULAR_TO_BASIC(index);
  ret = _contents_array[basicIndex];
  circularFillHoleAt(self, basicIndex);
  decrementCount(self);
  return AUTORELEASE_ELT(ret);
}

- (elt) removeFirstElement
{
  elt ret;

  ret = _contents_array[_start_index];
  _start_index = (_start_index + 1) % _capacity;
  decrementCount(self);
  return AUTORELEASE_ELT(ret);
}

- (elt) removeLastElement
{
  elt ret;

  if (!_count)
    NO_ELEMENT_FOUND_ERROR();
  ret = _contents_array[CIRCULAR_TO_BASIC(_count-1)];
  decrementCount(self);
  return AUTORELEASE_ELT(ret);
}

- (elt) elementAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[CIRCULAR_TO_BASIC(index)];
}

- appendElement: (elt)newElement
{
  incrementCount(self);
  RETAIN_ELT(newElement);
  _contents_array[CIRCULAR_TO_BASIC(_count-1)] = newElement;
  return self;
}

- prependElement: (elt)newElement
{
  incrementCount(self);
  RETAIN_ELT(newElement);
  _start_index = (_capacity + _start_index - 1) % _capacity;
  _contents_array[_start_index] = newElement;
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  unsigned basicIndex;

  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  incrementCount(self);
  RETAIN_ELT(newElement);
  basicIndex = CIRCULAR_TO_BASIC(index);
  circularMakeHoleAt(self, basicIndex);
  _contents_array[basicIndex] = newElement;
  return self;
}

- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement
{
  elt ret;
  unsigned basicIndex;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  RETAIN_ELT(newElement);
  basicIndex = CIRCULAR_TO_BASIC(index);
  ret = _contents_array[basicIndex];
  _contents_array[basicIndex] = newElement;
  return AUTORELEASE_ELT(ret);
}

- swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  elt tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  index1 = CIRCULAR_TO_BASIC(index1);
  index2 = CIRCULAR_TO_BASIC(index2);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
  return self;
}

/* just temporary for debugging
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
*/

@end

