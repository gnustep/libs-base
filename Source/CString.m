/* Implementation for GNU Objective-C CString object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994

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

#include <gnustep/base/String.h>
#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <Foundation/NSValue.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

@implementation CString

/* These next two methods are the two designated initializers for this class */
- initWithCString: (const char*)aCharPtr range: (IndexRange)aRange
{
  _count = aRange.length;
  OBJC_MALLOC(_contents_chars, char, _count+1);
  memcpy(_contents_chars, aCharPtr + aRange.location, _count);
  _contents_chars[_count] = '\0';
  _free_contents = YES;
  return self;
}

- initWithCStringNoCopy: (const char*)aCharPtr freeWhenDone: (BOOL)f
{
  _count = strlen(aCharPtr);
  _contents_chars = (char *) aCharPtr;
  _free_contents = f;
  return self;
}

- (void) _collectionReleaseContents
{
}

- (void) _collectionDealloc 
{
  if (_free_contents)
    OBJC_FREE(_contents_chars);
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfObjCType: @encode(char*)
	  at: &_contents_chars 
	  withName: @"Concrete String content_chars"];
}

- initWithCoder: aCoder
{
  [super initWithCoder:aCoder];
  [aCoder decodeValueOfObjCType: @encode(char*) 
	  at: &_contents_chars
	  withName: NULL];
  _count = strlen(_contents_chars);
  _free_contents = YES;
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  CString *copy = [super emptyCopy];
  OBJC_MALLOC(copy->_contents_chars, char, _count+1);
  copy->_count = 0;
  copy->_contents_chars[0] = '\0';
  return copy;
}

/* xxx This should return an autoreleased, malloc'ed copy */
- (const char *) cString
{
  return _contents_chars;
}

- (const char *) cStringNoCopy
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

// FOR IndexedCollection SUPPORT;

- objectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return [NSNumber numberWithChar: _contents_chars[index]];
}

@end
