/* Implementation for Objective-C Heap object
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

#include <objects/Heap.h>
#include <objects/ArrayPrivate.h>

#define HEAP_PARENT(i) (i/2)
#define HEAP_LEFT(i) (2 * i)
#define HEAP_RIGHT(i) ((2 * i) + 1)

@implementation Heap

/* We could take out the recursive call to make it a little more efficient */
- heapifyFromIndex: (unsigned)index
{
  unsigned right, left, largest;
  elt tmp;

  right = HEAP_RIGHT(index);
  left = HEAP_LEFT(index);
  if (left <= _count 
      && COMPARE_ELEMENTS(_contents_array[left],_contents_array[index]) > 0)
    largest = left;
  else
    largest = index;
  if (right <= _count
      && COMPARE_ELEMENTS(_contents_array[right],_contents_array[largest]) > 0)
    largest = right;
  if (largest != index)
    {
      tmp = _contents_array[index];
      _contents_array[index] = _contents_array[largest];
      _contents_array[largest] = tmp;
      [self heapifyFromIndex:largest];
    }
  return self;
}

- heapify
{
  int i;

  // could use objc_msg_lookup here;
  for (i = _count / 2; i >= 1; i--)
    [self heapifyFromIndex:i];
  return self;
}

- (elt) removeFirstElement
{
  elt ret;

  if (_count == 0)
    NO_ELEMENT_FOUND_ERROR();
  ret = _contents_array[0];
  _contents_array[0] = _contents_array[_count-1];
  decrementCount(self);
  [self heapifyFromIndex:0];
  return AUTORELEASE_ELT(ret);
}

- addElement: (elt)newElement
{
  int i;

  incrementCount(self);
  RETAIN_ELT(newElement);
  for (i = _count-1; 
       i > 0 
       && COMPARE_ELEMENTS(_contents_array[HEAP_PARENT(i)], newElement) < 0;
       i = HEAP_PARENT(i))
    {
      _contents_array[i] = _contents_array[HEAP_PARENT(i)];
    }
  _contents_array[i] = newElement;
  return self;
}

@end
