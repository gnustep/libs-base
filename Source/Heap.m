/* Implementation for Objective-C Heap object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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

/* This class could be improved by somehow making is a subclass of
   IndexedCollection, but not OrderedCollection. */

#include <gnustep/base/Heap.h>
#include <gnustep/base/ArrayPrivate.h>

#define HEAP_PARENT(i) (i/2)
#define HEAP_LEFT(i) (2 * i)
#define HEAP_RIGHT(i) ((2 * i) + 1)

@implementation Heap

/* We could take out the recursive call to make it a little more efficient */
- (void) heapifyFromIndex: (unsigned)index
{
  unsigned right, left, largest;
  id tmp;

  right = HEAP_RIGHT(index);
  left = HEAP_LEFT(index);
  if (left <= _count 
      && [_contents_array[index] compare: _contents_array[left]] > 0)
    largest = left;
  else
    largest = index;
  if (right <= _count
      && [_contents_array[largest] compare: _contents_array[right]] > 0)
    largest = right;
  if (largest != index)
    {
      tmp = _contents_array[index];
      _contents_array[index] = _contents_array[largest];
      _contents_array[largest] = tmp;
      [self heapifyFromIndex:largest];
    }
}

- (void) heapify
{
  int i;

  // could use objc_msg_lookup here;
  for (i = _count / 2; i >= 1; i--)
    [self heapifyFromIndex:i];
}

- (void) removeFirstObject
{
  if (_count == 0)
    return;
  [_contents_array[0] release];
  _contents_array[0] = _contents_array[_count-1];
  decrementCount(self);
  [self heapifyFromIndex:0];
}

- (void) addObject: newObject
{
  int i;

  incrementCount(self);
  [newObject retain];
  for (i = _count-1; 
       i > 0 
       && [newObject compare: _contents_array[HEAP_PARENT(i)]] < 0;
       i = HEAP_PARENT(i))
    {
      _contents_array[i] = _contents_array[HEAP_PARENT(i)];
    }
  _contents_array[i] = newObject;
}

@end
