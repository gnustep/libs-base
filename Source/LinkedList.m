/* Implementation for Objective-C LinkedList collection object
   Copyright (C) 1993,1994, 1995 Free Software Foundation, Inc.

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

#include <objects/LinkedList.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/Coder.h>

@implementation LinkedList

+ (void) initialize
{
  if (self == [LinkedList class])
    [self setVersion:0];	/* beta release */
}

/* This is the designated initializer of this class */
- init
{
  [super initWithType:@encode(id)];
  _count = 0;
  _first_link = nil;
  return self;
}

/* Archiving must mimic the above designated initializer */

- _initCollectionWithCoder: aCoder
{
  [super _initCollectionWithCoder:aCoder];
  _count = 0;
  _first_link = nil;
  return self;
}

- (void) _encodeContentsWithCoder: aCoder
{
  [aCoder startEncodingInterconnectedObjects];
  [super _encodeContentsWithCoder:aCoder];
  [aCoder finishEncodingInterconnectedObjects];
}

/* xxx See Collection _decodeContentsWithCoder:.
   We shouldn't do an -addElement.  finishEncodingInterconnectedObjects
   should take care of all that. */

- (void) _decodeContentsWithCoder: (Coder*)aCoder
{
  [aCoder startDecodingInterconnectedObjects];
  [super _decodeContentsWithCoder:aCoder];
  [aCoder finishDecodingInterconnectedObjects];
}

- _readInit: (TypedStream*)aStream
{
  [super _readInit:aStream];
  _count = 0;
  _first_link = nil;
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  LinkedList *copy = [super emptyCopy];
  copy->_count = 0;
  copy->_first_link = nil;
  return copy;
}

/* This must work without sending any messages to content objects */
- _empty
{
  _count = 0;
  _first_link = nil;
  return self;
}

/* Override the designated initializer for our superclass IndexedCollection
   to make sure we have object values. */
- initWithType: (const char *)contentEncoding
{
  if (!ENCODING_IS_OBJECT(contentEncoding))
    [self error:"LinkedList contents must be objects conforming to "
	  "<LinkedListComprising> protocol"];
  [self init];
  return self;
}

/* These next four methods are the only ones that change the values of
   the instance variables _count, _first_link, except for
   "-initDescription:". */

- (elt) removeElement: (elt)oldElement
{
  if (_first_link == oldElement.id_u)
    {
      if (_count > 1)
	_first_link = [oldElement.id_u nextLink];
      else
	_first_link = nil;
    }
  [[oldElement.id_u nextLink] setPrevLink:[oldElement.id_u prevLink]];
  [[oldElement.id_u prevLink] setNextLink:[oldElement.id_u nextLink]];
  _count--;
  return AUTORELEASE_ELT(oldElement);
}
  
- insertElement: (elt)newElement after: (elt)oldElement
{
  if (_count == 0)
    {
      /* link to self */
      _first_link = newElement.id_u;
      [newElement.id_u setNextLink:newElement.id_u];
      [newElement.id_u setPrevLink:newElement.id_u];
    }
  else
    {
      [newElement.id_u setNextLink:[oldElement.id_u nextLink]];
      [newElement.id_u setPrevLink:oldElement.id_u];
      [[oldElement.id_u nextLink] setPrevLink:newElement.id_u];
      [oldElement.id_u setNextLink:newElement.id_u];
    }
  _count++;
  return self;
}

- insertElement: (elt)newElement before: (elt)oldElement
{
  if (oldElement.id_u == _first_link)
      _first_link = newElement.id_u;
  if (_count == 0)
    {
      /* Link to self */
      [newElement.id_u setNextLink:newElement.id_u];
      [newElement.id_u setPrevLink:newElement.id_u];
    }
  else
    {
      [newElement.id_u setPrevLink:[oldElement.id_u prevLink]];
      [newElement.id_u setNextLink:oldElement.id_u];
      [[oldElement.id_u prevLink] setNextLink:newElement.id_u];
      [oldElement.id_u setPrevLink:newElement.id_u];
    }
  _count++;
  RETAIN_ELT(newElement);
  return self;
}

- (elt) replaceElement: (elt)oldElement with: (elt)newElement
{
  RETAIN_ELT(newElement);
  if (oldElement.id_u == _first_link)
    _first_link = newElement.id_u;
  [newElement.id_u setNextLink:[oldElement.id_u nextLink]];
  [newElement.id_u setPrevLink:[oldElement.id_u prevLink]];
  [[oldElement.id_u prevLink] setNextLink:newElement.id_u];
  [[oldElement.id_u nextLink] setPrevLink:newElement.id_u];
  return AUTORELEASE_ELT(oldElement);
}

/* End of methods that change the instance variables. */


- appendElement: (elt)newElement
{
  if (_count)
    [self insertElement:newElement after:[self lastElement]];
  else
    [self insertElement:newElement after:nil];
  return self;
}

- prependElement: (elt)newElement
{
  [self insertElement:newElement before:_first_link];
  return self;
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, (_count+1));
  if (index == _count)
    [self insertElement:newElement after:[self lastElement]];
  else
    [self insertElement:newElement before:[self elementAtIndex:index]];
  return self;
}

- (elt) removeElementAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return [self removeElement:[self elementAtIndex:index]];
}

- (elt) elementAtIndex: (unsigned)index
{
  id <LinkedListComprising> aLink;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  if (index < _count / 2)
    for (aLink = _first_link;
	 index;
	 aLink = [aLink nextLink], index--)
      ;
  else
    for (aLink = [_first_link prevLink], index = _count - index - 1;
	 index;
	 aLink = [aLink prevLink], index--)
      ;
  return aLink;
}

- (elt) firstElement
{
  return _first_link;
}

- (elt) lastElement
{
  if (_count)
    return [_first_link prevLink];
  else
    return NO_ELEMENT_FOUND_ERROR();
}

- (elt) successorOfElement: (elt)oldElement
{
  id nextElement = [oldElement.id_u nextLink];
  if (_first_link == nextElement)
    return nil;
  else
    return (elt)nextElement;
}

- (elt) predecessorOfElement: (elt)oldElement
{
  if (_first_link == oldElement.id_u)
    return nil;
  else
    return (elt)[oldElement.id_u prevLink];
}

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  if (*enumState == _first_link)
    return NO;
  else if (!(*enumState))
    *enumState = _first_link;
  *anElementPtr = *enumState;
  *enumState = [(id)(*enumState) nextLink];
  return YES;
}

- (BOOL) getPrevElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  if (*enumState == _first_link)
    return NO;
  if (!(*enumState))
    *enumState = _first_link;
  *enumState = [(id)(*enumState) prevLink];
  *anElementPtr = *enumState;
  return YES;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  id link;
  unsigned i;

  for (link = _first_link, i = 0;
       *flag && i < _count;
       link = [link nextLink], i++)
    {
      (*aFunc)(link);
    }
  return self;
}

- withElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  id link;
  unsigned i;

  if (!_first_link)
    return self;
  for (link = [_first_link prevLink], i = 0;
       *flag && i < _count;
       link = [link prevLink], i++)
    {
      (*aFunc)(link);
    }
  return self;
}


- (unsigned) count
{
  return _count;
}

@end



