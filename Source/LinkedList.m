/* Implementation for Objective-C LinkedList collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <gnustep/base/LinkedList.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/Coder.h>

@implementation LinkedList

/* This is the designated initializer of this class */
- init
{
  _count = 0;
  _first_link = nil;
  _last_link = nil;
  return self;
}

- initWithObjects: (id*)objs count: (unsigned)c
{
  [self init];
  while (c--)
    [self prependObject: objs[c]];
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: coder
{
  id l;

  [super encodeWithCoder: coder];
  [coder encodeValueOfCType: @encode (typeof (_count))
	 at: &_count
	 withName: @"LinkedList count"];
  FOR_COLLECTION (self, l)
    {
      [coder encodeObject: l
	     withName: @"LinkedList element"];
    }
  END_FOR_COLLECTION (self);
  [coder encodeObjectReference: _first_link
	 withName: @"LinkedList first link"];
  [coder encodeObjectReference: _last_link
	 withName: @"LinkedList last link"];
}

- initWithCoder: coder
{
  int i;
  // id link;

  self = [super initWithCoder: coder];
  [coder decodeValueOfCType: @encode (typeof (_count))
	 at: &_count
	 withName: NULL];
  /* We don't really care about storing the elements decoded, because
     we access them through their own link pointers. */
  for (i = 0; i < _count; i++)
    [coder decodeObjectAt: NULL
	   withName: NULL];
  [coder decodeObjectAt: &_first_link
	 withName: NULL];
  [coder decodeObjectAt: &_last_link
	 withName: NULL];
#if 0
  /* xxx Not necessary, since the links encode this?  
     But should we rely on the links encoding this?
     BUT! Look out: the next link pointers may not be set until
     the last finishDecoding... method is run... */
  FOR_COLLECTION (self, link)
    {
      [link setLinkedList: self];
    }
  END_FOR_COLLECTION (self);
#endif
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  LinkedList *copy = [super emptyCopy];
  copy->_first_link = nil;
  copy->_last_link = nil;
  copy->_count = 0;
  return copy;
}

/* This must work without sending any messages to content objects */
- (void) _empty
{
  _count = 0;
  _first_link = nil;
  _last_link = nil;
}

/* These next four methods are the only ones that change the values of
   the instance variables _count, _first_link, except for
   "-init". */

- (void) removeObject: oldObject
{
  assert ([oldObject linkedList] == self);
  if (_first_link == oldObject)
    {
      if (_count > 1)
	_first_link = [oldObject nextLink];
      else
	_first_link = nil;
    }
  else
    [[oldObject prevLink] setNextLink:[oldObject nextLink]];
  if (_last_link == oldObject)
    {
      if (_count > 1)
	_last_link = [oldObject prevLink];
      else
	_first_link = nil;
    }
  else
    [[oldObject nextLink] setPrevLink:[oldObject prevLink]];
  _count--;
  [oldObject setNextLink: NO_OBJECT];
  [oldObject setPrevLink: NO_OBJECT];
  [oldObject release];
}
  
- (void) insertObject: newObject after: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      _count = 1;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    {
      if (oldObject == _last_link)
	_last_link = newObject;
      [newObject setNextLink: [oldObject nextLink]];
      [newObject setPrevLink: oldObject];
      [[oldObject nextLink] setPrevLink: newObject];
      [oldObject setNextLink: newObject];
    }
  _count++;
}

- (void) insertObject: newObject before: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      _count = 1;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    {
      if (oldObject == _first_link)
	_first_link = newObject;
      [newObject setPrevLink: [oldObject prevLink]];
      [newObject setNextLink: oldObject];
      [[oldObject prevLink] setNextLink: newObject];
      [oldObject setPrevLink: newObject];
    }
  _count++;
}

- (void) replaceObject: oldObject with: newObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Do the replacement. */
  if (oldObject == _first_link)
    _first_link = newObject;
  [newObject setNextLink:[oldObject nextLink]];
  [newObject setPrevLink:[oldObject prevLink]];
  [[oldObject prevLink] setNextLink:newObject];
  [[oldObject nextLink] setPrevLink:newObject];

  /* Release ownership of the oldObject. */
  [oldObject setNextLink: NO_OBJECT];
  [oldObject setPrevLink: NO_OBJECT];
  [oldObject setLinkedList: NO_OBJECT];
  [oldObject release];
}

/* End of methods that change the instance variables. */


- (void) appendObject: newObject
{
  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Insert it. */
  if (_count == 0)
    {
      /* Claim ownership of the newObject. */
      [newObject retain];
      [newObject setLinkedList: self];

      /* Put it in as the only node. */
      _first_link = newObject;
      _last_link = newObject;
      _count = 1;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    [self insertObject: newObject after: _last_link];
}

- (void) prependObject: newObject
{
  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Insert it. */
  if (_count == 0)
    {
      /* Claim ownership of the newObject. */
      [newObject retain];
      [newObject setLinkedList: self];

      /* Put it in as the only node. */
      _first_link = newObject;
      _last_link = newObject;
      _count = 1;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    [self insertObject: newObject before: _first_link];
}

- (void) insertObject: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, (_count+1));

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Insert it. */
  if (_count == 0)
    {
      /* Claim ownership of the newObject. */
      [newObject retain];
      [newObject setLinkedList: self];

      /* Put it in as the only node. */
      _first_link = newObject;
      _last_link = newObject;
      _count = 1;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else if (index == _count)
    [self insertObject: newObject after: _last_link];
  else
    [self insertObject:newObject before: [self objectAtIndex: index]];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [self removeObject: [self objectAtIndex: index]];
}

- objectAtIndex: (unsigned)index
{
  id <LinkedListComprising> link;

  CHECK_INDEX_RANGE_ERROR(index, _count);

  if (index < _count / 2)
    for (link = _first_link;
	 index;
	 link = [link nextLink], index--)
      ;
  else
    for (link = _last_link, index = _count - index - 1;
	 index;
	 link = [link prevLink], index--)
      ;
  return link;
}

- firstObject
{
  return _first_link;
}

- lastObject
{
  return _last_link;
}

- successorOfObject: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  return [oldObject nextLink];
}

- predecessorOfObject: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  return [oldObject prevLink];
}

- (void*) newEnumState
{
  return _first_link;
}

- nextObjectWithEnumState: (void**)enumState
{
  id ret;

  if (!*enumState)
    return nil;
  ret = *enumState;
  *enumState = [(id)(*enumState) nextLink];
  /* *enumState points to the next object to be returned. */
  return ret;
}

- prevObjectWithEnumState: (void**)enumState
{
  /* *enumState points to the object returned last time. */
  if (!*enumState)
    return nil;
  if (*enumState == _first_link)
    /* enumState was just initialized from -newEnumState. */
    return *enumState = _last_link;
  return (id) *enumState = [(id)(*enumState) prevLink];
}

- (unsigned) count
{
  return _count;
}

@end



