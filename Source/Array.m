/* Implementation for Objective-C Array collection object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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
#include <base/Array.h>
#include <base/ArrayPrivate.h>
#include <base/NSString.h>
#include <base/OrderedCollection.h>
#include <base/behavior.h>

@implementation ConstantArray

/* This is the designated initializer of this class */
- initWithObjects: (id*)objs count: (unsigned)c
{
  _count = c;
  OBJC_MALLOC(_contents_array, id, _count);
  while (c--)
    _contents_array[c] = objs[c];
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Array *copy = [super emptyCopy];
  copy->_count = 0;
  OBJC_MALLOC(copy->_contents_array, id, copy->_capacity);
  return copy;
}

- (void) _collectionDealloc
{
  OBJC_FREE(_contents_array);
  [super _collectionDealloc];
}


// GETTING ELEMENTS BY INDEX;

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[index];
}


// TESTING;

- (unsigned) count
{
  return _count;
}

@end


@implementation Array

+ (void) initialize
{
  if (self == [Array class])
    class_add_behavior (self, [OrderedCollection class]);
}

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_ARRAY_CAPACITY;
}

+ (int) defaultGrowFactor
{
  return DEFAULT_ARRAY_GROW_FACTOR;
}

/* This is the designated initializer for this class */
- initWithCapacity: (unsigned)aCapacity
{
  _grow_factor = [[self class] defaultGrowFactor];
  _count = 0;
  _capacity = (aCapacity < 1) ? 1 : aCapacity;
  OBJC_MALLOC(_contents_array, id, _capacity);
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) _encodeCollectionWithCoder: (id <Encoding>)coder
{
  [super _encodeCollectionWithCoder:coder];
  [coder encodeValueOfCType:@encode(unsigned)
	 at:&_grow_factor
	 withName:@"Array Grow Factor"];
  [coder encodeValueOfCType:@encode(unsigned)
	 at:&_capacity
	 withName:@"Array Capacity"];
}

- _initCollectionWithCoder: (id <Decoding>)coder
{
  [super _initCollectionWithCoder:coder];
  [coder decodeValueOfCType:@encode(unsigned)
	 at:&_grow_factor
	 withName:NULL];
  _count = 0;
  [coder decodeValueOfCType:@encode(unsigned)
	 at:&_capacity
	 withName:NULL];
  return self;
}

/* Override superclass' designated initializer to call ours */
- initWithObjects: (id*)objs count: (unsigned)c
{
  int i;
  [self initWithCapacity: c];
  for (i = 0; i < c; i++)
    [self insertObject: objs[i] atIndex: i]; // xxx this most efficient method?
  return self;
}

/* This must work without sending any messages to content objects */
- (void) empty
{
  int i;

  for (i = 0; i < _count; i++)
    [_contents_array[i] release];
  _count = 0;
  /* Note this may not work for subclassers.  Beware. */
}

// MANAGING CAPACITY;

/* This is the only method that changes the value of the instance
   variable _capacity, except for "-initDescription:capacity:" */

- (void) setCapacity: (unsigned)newCapacity
{
  if (newCapacity > _count) {
    _capacity = newCapacity;
    OBJC_REALLOC(_contents_array, id, _capacity);
  }
}

- (int) growFactor
{
  return _grow_factor;
}

- (void) setGrowFactor: (int)aNum;
{
  _grow_factor = aNum;
}


// ADDING;

- (void) appendObject: newObject
{
	/*	Check to make sure that anObject is not nil, first.	*/
	if (newObject == nil)
	{
		[NSException  raise: NSInvalidArgumentException
					 format: @"Array: object to add is nil"
		];
	}

	/*	Now we can add it.	*/
	incrementCount(self);
	[newObject retain];
	_contents_array[_count-1] = newObject;
}

- (void) prependObject: newObject
{
  incrementCount(self);
  [newObject retain];
  makeHoleAt(self, 0);
  _contents_array[0] = newObject;
}

- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);

	/*	Check to make sure that anObject is not nil, first.	*/
	if (newObject == nil)
	{
		[NSException  raise: NSInvalidArgumentException
					 format: @"Array: object to insert is nil"
		];
	}

  incrementCount(self);
  [newObject retain];
  makeHoleAt(self, index);
  _contents_array[index] = newObject;
}


// REMOVING, REPLACING AND SWAPPING;

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [_contents_array[index] release];
  fillHoleAt(self, index);
  decrementCount(self);
}
  
/* We could be more efficient if we override these also.
   - removeFirstObject
   - removeLastObject; 
   If you do, remember, you will have to implement this methods
   in GapArray also! */


- (void) replaceObjectAtIndex: (unsigned)index withObject: newObject
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [newObject retain];
  [_contents_array[index] release];
  _contents_array[index] = newObject;
}

- (void) swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  id tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
}
  
@end
