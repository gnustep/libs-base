/* Implementation for Objective-C Bag collection object
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

#include <gnustep/base/Bag.h>
#include <gnustep/base/CollectionPrivate.h>

#define DEFAULT_BAG_CAPACITY 32

@implementation Bag

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_BAG_CAPACITY;
}
  
// INITIALIZING AND FREEING;

/* This is the designated initializer of this class */
/* Override designated initializer of superclass */
- initWithCapacity: (unsigned)cap
{
  _contents_map = NSCreateMapTable (NSObjectMapKeyCallBacks,
				    NSIntMapValueCallBacks,
				    cap);
  _count = 0;
  return self;
}

/* Override Collection's designated initializer */
- initWithObjects: (id*)objs count: (unsigned)count
{
  [self initWithCapacity: count];
  while (count--)
    [self addObject: objs[count]];
  return self;
}


/* Archiving must mimic the above designated initializer */

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

- initWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Bag *copy = [super emptyCopy];
  copy->_contents_map = NSCreateMapTable (NSObjectMapKeyCallBacks,
					  NSIntMapValueCallBacks,
					  0);
  copy->_count = 0;
  return copy;
}

- (void) dealloc
{
  NSFreeMapTable (_contents_map);
  [super _collectionDealloc];
}

/* This must work without sending any messages to content objects */
- (void) _collectionEmpty
{
  NSResetMapTable (_contents_map);
  _count = 0;
}

// ADDING;

- (void) addObject: newObject withOccurrences: (unsigned)count
{
  unsigned new_count = (unsigned) NSMapGet (_contents_map, newObject);
  new_count += count;
  NSMapInsert (_contents_map, newObject, (void*)new_count);
  _count += count;
}

- (void) addObject: newObject
{
  [self addObject: newObject withOccurrences: 1];
}


// REMOVING AND REPLACING;

- (void) removeObject: oldObject occurrences: (unsigned)count
{
  unsigned c = (unsigned) NSMapGet (_contents_map, oldObject);
  if (c)
    {
      if (c <= count)
	{
	  NSMapRemove (_contents_map, oldObject);
	  _count -= c;
	}
      else
	{
	  NSMapInsert (_contents_map, oldObject, (void*)(c - count));
	  _count -= count;
	}
    }
}

- (void) removeObject: oldObject
{
  [self removeObject: oldObject occurrences:1];
}

- (void) uniqueContents
{
  [self notImplemented: _cmd];
}


// TESTING;

- (unsigned) count
{
  return _count;
}

- (unsigned) uniqueCount
{
  return NSCountMapTable (_contents_map);
}

- (unsigned) occurrencesOfObject: anObject
{
  return (unsigned) NSMapGet (_contents_map, anObject);
}


// ENUMERATING;

struct BagEnumState
{
  NSMapEnumerator me;
  id object;
  unsigned count;
};

#define ES ((struct BagEnumState *) *enumState)

- nextObjectWithEnumState: (void**)enumState
{
  if (!(ES->count))
    if (!NSNextMapEnumeratorPair (&(ES->me), 
				  (void**) &(ES->object), 
				  (void**) &(ES->count)))
      return NO_OBJECT;
  ES->count--;
  return ES->object;
}  

- (void*) newEnumState
{
  /* init for start of enumeration. */
  void *vp;
  void **enumState = &vp;
  OBJC_MALLOC(*enumState, struct BagEnumState, 1);
  ES->me = NSEnumerateMapTable (_contents_map);
  ES->object = nil;
  ES->count = 0;
  return vp;
}

- (void) freeEnumState: (void**)enumState
{
  if (*enumState)
    OBJC_FREE(*enumState);
}

@end


