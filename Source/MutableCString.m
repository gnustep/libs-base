/* Implementation for GNU Objective-C MutableCString object
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: January 1995

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

#include <gnustep/base/String.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

typedef struct {
  @defs(MutableCString)
} MutableCStringStruct;

static inline void
stringIncrementCountAndMakeHoleAt(MutableCStringStruct *self, 
				  unsigned index, unsigned size)
{
#ifndef STABLE_MEMCPY
  {
    int i;
    for (i = self->_count; i >= index; i--)
      self->_contents_chars[i+size] = self->_contents_chars[i];
  }
#else
  memcpy(self->_contents_chars + index, 
	 self->_contents_chars + index + size,
	 self->_count - index);
#endif /* STABLE_MEMCPY */
  (self->_count) += size;
}

static inline void
stringDecrementCountAndFillHoleAt(MutableCStringStruct *self, 
				  unsigned index, unsigned size)
{
  (self->_count) -= size;
#ifndef STABLE_MEMCPY
  {
    int i;
    for (i = index; i <= self->_count; i++)
      self->_contents_chars[i] = self->_contents_chars[i+size];
  }
#else
  memcpy(self->_contents_chars + index + size,
	 self->_contents_chars + index, 
	 self->_count - index);
#endif /* STABLE_MEMCPY */
}

@implementation MutableCString

/* This is the designated initializer for this class */
- initWithCapacity: (unsigned)capacity
{
  _count = 0;
  _capacity = capacity;
  OBJC_MALLOC(_contents_chars, char, _capacity+1);
  _contents_chars[0] = '\0';
  _free_contents = YES;
  return self;
}

- (void) dealloc
{
  if (_free_contents)
    OBJC_FREE(_contents_chars);
  [super dealloc];
}

/* xxx This should be made to return void, but we need to change
   IndexedCollecting and its conformers */
- (void) removeRange: (IndexRange)range
{
  stringDecrementCountAndFillHoleAt((MutableCStringStruct*)self, 
				    range.location, range.length);
}

- (void) insertString: (String*)string atIndex: (unsigned)index
{
  unsigned c = [string count];
  if (_count + c >= _capacity)
    {
      _capacity = MAX(_capacity*2, _count+c);
      OBJC_REALLOC(_contents_chars, char, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((MutableCStringStruct*)self, index, c);
  memcpy(_contents_chars + index, [string cString], c);
  _contents_chars[_count] = '\0';
}


- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType:@encode(unsigned) at:&_capacity
	  withName:@"String capacity"];
  [aCoder encodeValueOfObjCType:@encode(char*) at:&_contents_chars 
	  withName:@"String content_chars"];
}

- initWithCoder: aCoder
{
  unsigned cap;
  
  [aCoder decodeValueOfObjCType:@encode(unsigned) at:&cap withName:NULL];
  [self initWithCapacity:cap];
  [aCoder decodeValueOfObjCType:@encode(char*) at:_contents_chars
	  withName:NULL];
  _count = strlen(_contents_chars);
  _capacity = cap;
  _free_contents = YES;
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  MutableCString *copy = [super emptyCopy];
  OBJC_MALLOC(copy->_contents_chars, char, _count+1);
  copy->_count = 0;
  copy->_contents_chars[0] = '\0';
  return copy;
}

- (const char *) cString
{
  return _contents_chars;
}

- (unsigned) count
{
  return _count;
}

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_chars[index];
}

#if 0
/* For IndexedCollecting protocol */

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  // one for the next char, one for the '\0';
  if (_count+1 >= _capacity)
    {
      _capacity *= 2;
      OBJC_REALLOC(_contents_chars, char, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((MutableCStringStruct*)self, index, 1);
  _contents_chars[index] = newElement.char_u;
  _contents_chars[_count] = '\0';
  return self;
}

- (elt) removeElementAtIndex: (unsigned)index
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret = _contents_chars[index];
  stringDecrementCountAndFillHoleAt((MutableCStringStruct*)self, index, 1);
  _contents_chars[_count] = '\0';
  return ret;
}

- (elt) elementAtIndex: (unsigned)index
{
  elt ret_elt;
  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret_elt.char_u = _contents_chars[index];
  return ret_elt;
}

#endif

@end
