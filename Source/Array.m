/* Implementation for Objective-C Array collection object
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

#include <objects/Array.h>
#include <objects/ArrayPrivate.h>

@implementation Array

+ (void) initialize
{
  if (self == [Array class])
    [self setVersion:0];	/* beta release */
}

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_ARRAY_CAPACITY;
}

+ (unsigned) defaultGrowFactor
{
  return DEFAULT_ARRAY_GROW_FACTOR;
}
  
/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity
{
  [super initWithType:contentEncoding];
  _comparison_function = elt_get_comparison_function(contentEncoding);
  _grow_factor = [[self class] defaultGrowFactor];
  _count = 0;
  _capacity = (aCapacity < 1) ? 1 : aCapacity;
  OBJC_MALLOC(_contents_array, elt, _capacity);
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) _encodeCollectioinWitCoder: (Coder*)coder
{
  const char *encoding = [self contentType];

  [super encodeWithCoder:coder];
  [coder encodeValueOfSimpleType:@encode(char*)
	 at:&encoding
	 withName:"Array Encoding Type"];
  [coder encodeValueOfSimpleType:@encode(unsigned)
	 at:&_grow_factor
	 withName:"Array Grow Factor"];
  [coder encodeValueOfSimpleType:@encode(unsigned)
	 at:&_capacity
	 withName:"Array Capacity"];
}

+ _newCollectionWithCoder: (Coder*)coder
{
  char *encoding;
  Array *n = [super newWithCoder:coder];
  [coder decodeValueOfSimpleType:@encode(char*)
	 at:&encoding
	 withName:NULL];
  n->_comparison_function = elt_get_comparison_function(encoding);
  [coder decodeValueOfSimpleType:@encode(unsigned)
	 at:&(n->_grow_factor)
	 withName:NULL];
  n->_count = 0;
  [coder decodeValueOfSimpleType:@encode(unsigned)
	 at:&(n->_capacity)
	 withName:NULL];
  OBJC_MALLOC(n->_contents_array, elt, n->_capacity);
  return n;
}

- _writeInit: (TypedStream*)aStream
{
  const char *encoding = [self contentType];

  [super _writeInit: aStream];
  // This implicitly archives the _comparison_function;
  objc_write_type(aStream, @encode(char*), &encoding);
  objc_write_type(aStream, @encode(unsigned int), &_grow_factor);
  objc_write_type(aStream, @encode(unsigned int), &_capacity);
  return self;
}

- _readInit: (TypedStream*)aStream
{
  char *encoding;

  [super _readInit: aStream];
  objc_read_type(aStream, @encode(char*), &encoding);
  _comparison_function = elt_get_comparison_function(encoding);
  objc_read_type(aStream, @encode(unsigned int), &_grow_factor);
  _count = 0;
  objc_read_type(aStream, @encode(unsigned int), &_capacity);
  OBJC_MALLOC(_contents_array, elt, _capacity);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Array *copy = [super emptyCopy];
  copy->_count = 0;
  OBJC_MALLOC(copy->_contents_array, elt, copy->_capacity);
  return copy;
}

/* This must work without sending any messages to content objects */
- _empty
{
  _count = 0;
  return self;
}

- (void) _collectionDealloc
{
  OBJC_FREE(_contents_array);
  [super dealloc];
}

- initWithContentsOf: (id <Collecting>)aCollection
{
  [self initWithType:[aCollection contentType]
	capacity:[aCollection count]];
  [self addContentsOf:aCollection];
  return self;
}

- initWithCapacity: (unsigned)aCapacity
{
  return [self initWithType:@encode(id) capacity:aCapacity];
}

/* Catch designated initializer for IndexedCollection */
- initWithType: (const char *)contentEncoding
{
  return [self initWithType:contentEncoding
	       capacity:[[self class] defaultCapacity]];
}

// MANAGING CAPACITY;

/* This is the only method that changes the value of the instance
   variable _capacity, except for "-initDescription:capacity:" */

- setCapacity: (unsigned)newCapacity
{
  if (newCapacity > _count) {
    _capacity = newCapacity;
    OBJC_REALLOC(_contents_array, elt, _capacity);
  }
  return self;
}

- (unsigned) growFactor
{
  return _grow_factor;
}

- setGrowFactor: (unsigned)aNum;
{
  _grow_factor = aNum;
  return self;
}

// ADDING;

- appendElement: (elt)newElement
{
  incrementCount(self);
  RETAIN_ELT(newElement);
  _contents_array[_count-1] = newElement;
  return self;
}

- prependElement: (elt)newElement
{
  incrementCount(self);
  RETAIN_ELT(newElement);
  makeHoleAt(self, 0);
  _contents_array[0] = newElement;
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  incrementCount(self);
  RETAIN_ELT(newElement);
  makeHoleAt(self, index);
  _contents_array[index] = newElement;
  return self;
}


// REMOVING, REPLACING AND SWAPPING;

- (elt) removeElementAtIndex: (unsigned)index
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret = _contents_array[index];
  fillHoleAt(self, index);
  decrementCount(self);
  return AUTORELEASE_ELT(ret);
}
  
/* We could be more efficient if we override these also.
   - (elt) removeFirstElement
   - (elt) removeLastElement; */


- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  RETAIN_ELT(newElement);
  ret = _contents_array[index];
  _contents_array[index] = newElement;
  return AUTORELEASE_ELT(ret);
}

- swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  elt tmp;

  CHECK_INDEX_RANGE_ERROR(index1, _count);
  CHECK_INDEX_RANGE_ERROR(index2, _count);
  tmp = _contents_array[index1];
  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = tmp;
  return self;
}


// GETTING ELEMENTS BY INDEX;

- (elt) elementAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_array[index];
}

// TESTING;

- (int(*)(elt,elt)) comparisonFunction
{
  return _comparison_function;
}

- (const char *) contentType
{
  return elt_get_encoding(_comparison_function);
}

- (unsigned) count
{
  return _count;
}

@end


