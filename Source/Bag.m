/* Implementation for Objective-C Bag collection object
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

#include <objects/Bag.h>
#include <objects/CollectionPrivate.h>

@implementation Bag

+ (void) initialize
{
  if (self == [Bag class])
    [self setVersion:0];	/* beta release */
}

// INITIALIZING AND FREEING;

/* This is the designated initializer of this class */
/* Override designated initializer of superclass */
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity
{
  [super initWithType:contentEncoding
	 capacity:aCapacity];
  _count = 0;
  return self;
}

/* Archiving must mimic the above designated initializer */

- _readInit: (TypedStream*)aStream
{
  [super _readInit:aStream];
  _count = 0;
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Bag *copy = [super emptyCopy];
  copy->_count = 0;
  return copy;
}

/* This must work without sending any messages to content objects */
- empty
{
  coll_hash_empty(_contents_hash);
  _count = 0;
  return self;
}

// ADDING;

- addElement: (elt)newElement withOccurrences: (unsigned)count
{
  coll_node_ptr node = 
    coll_hash_node_for_key(_contents_hash, newElement);
  if (node)
    node->value.unsigned_int_u += count;
  else
    coll_hash_add(&_contents_hash, newElement, count);
  _count += count;
  return self;
}

- addElement: (elt)newElement
{
  return [self addElement:newElement withOccurrences:1];
}


// REMOVING AND REPLACING;

- (elt) removeElement:(elt)oldElement occurrences: (unsigned)count
{
  elt err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(oldElement);
    }
  return [self removeElement:oldElement occurrences:count
	       ifAbsentCall:err];
}

- (elt) removeElement:(elt)oldElement occurrences: (unsigned)count
    ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  coll_node_ptr node = 
    coll_hash_node_for_key(_contents_hash, oldElement);
  if (!node || node->value.unsigned_int_u < count)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  if (node->value.unsigned_int_u > count)
    {
      (node->value.unsigned_int_u) -= count;
    }
  else /* (node->value.unsigned_int_u == count) */
    {
      coll_hash_remove(_contents_hash, oldElement);
    }
  _count -= count;
  return oldElement;
}

- (elt) removeElement: (elt)oldElement ifAbsentCall: (elt(*)(arglist_t))excFunc
{
  return [self removeElement:oldElement occurrences:1 ifAbsentCall:excFunc];
}

- uniqueContents
{
  void *state = 0;
  coll_node_ptr node = 0;

  _count = 0;
  while ((node = coll_hash_next(_contents_hash, &state)))
    {
      node->value.unsigned_int_u = 1;
      _count++;
    }
  return self;
}


// TESTING;

- (unsigned) count
{
  return _count;
}

- (unsigned) uniqueCount
{
  return _contents_hash->used;
}

- (unsigned) occurrencesOfElement: (elt)anElement
{
  coll_node_ptr node = 
    coll_hash_node_for_key(_contents_hash, anElement);

  if (node)
    return node->value.unsigned_int_u;
  else
    return 0;
}


// ENUMERATING;

struct BagEnumState
{
  void *state;
  coll_node_ptr node;
  unsigned count;
};

#define ES ((struct BagEnumState *) *enumState)

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  if (!(*enumState))
    {
    }
  else if (ES->count >= ES->node->value.unsigned_int_u)
    {
      /* time to get the next different element */
      ES->node = coll_hash_next(_contents_hash, &(ES->state));
      ES->count = 0;
    }
  if (!(ES->node))
    {
      /* at end of enumeration */
      OBJC_FREE(*enumState);
      *enumState = 0;
      return NO;
    }
  *anElementPtr = ES->node->key;
  (ES->count)++;
  return YES;
}  

- (void*) newEnumState
{
  /* init for start of enumeration. */
  void *vp;
  void **enumState = &vp;
  OBJC_MALLOC(*enumState, struct BagEnumState, 1);
  ES->state = 0;
  ES->node = coll_hash_next(_contents_hash, &(ES->state));
  ES->count = 0;
  return vp;
}

- freeEnumState: (void**)enumState
{
  if (*enumState)
    OBJC_FREE(*enumState);
  return self;
}

- withElementsCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  int i;
  void *state = 0;
  coll_node_ptr node;

  while ((node = coll_hash_next(_contents_hash, &state)))
    {
      for (i = 0; i < node->value.unsigned_int_u; i++) 
	{
	  if (!(*flag))
	    return self;
	  (*aFunc)(node->key);
	}
    }
  return self;
}

- withElementsCall: (void(*)(elt))aFunc
{
  int i;
  void *state = 0;
  coll_node_ptr node;
  int test = 0;

  while ((node = coll_hash_next(_contents_hash, &state)))
    {
      test++;
      for (i = 0; i < node->value.unsigned_int_u; i++) 
	{
	  (*aFunc)(node->key);
	}
    }
  return self;
}


// OBJECT-COMPATIBLE MESSAGE NAMES;

- addObject: newObject withOccurrences: (unsigned)count
{
  return [self addElement:newObject withOccurrences:count];
}

- removeObject: oldObject occurrences: (unsigned)count
{
  id err(arglist_t argFrame)
    {
      return ELEMENT_NOT_FOUND_ERROR(oldObject);
    }
  return [self removeObject:oldObject occurrences:count ifAbsentCall:err];
}

- removeObject: oldObject occurrences: (unsigned)count
    ifAbsentCall: (id(*)(arglist_t))excFunc
{
  elt elt_exc(arglist_t argFrame)
    {
      RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
    }
  return [self removeElement:oldObject occurrences:count
	       ifAbsentCall:elt_exc].id_u;
}

@end


