/* Implementation for Objective-C Set collection object
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
#include <gnustep/base/Set.h>
#include <gnustep/base/CollectionPrivate.h>
#include <gnustep/base/Coder.h>
#include <Foundation/NSHashTable.h>

#define DEFAULT_SET_CAPACITY 32

@implementation Set 

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_SET_CAPACITY;
}
  
// INITIALIZING AND FREEING;

/* This is the designated initializer of this class */
- initWithCapacity: (unsigned)cap
{
  _contents_hash = NSCreateHashTable(NSObjectsHashCallBacks, cap);
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

- _initCollectionWithCoder: aCoder
{
  [super _initCollectionWithCoder:aCoder];
  _contents_hash = NSCreateHashTable(NSObjectsHashCallBacks, 
				     DEFAULT_SET_CAPACITY);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  Set *copy = [super emptyCopy];
  copy->_contents_hash =
    NSCreateHashTable (NSObjectsHashCallBacks, 0);
  return copy;
}

- (void) dealloc
{
  if (_contents_hash)
    {
      NSFreeHashTable (_contents_hash);
      _contents_hash = 0;
    }
  [super dealloc];
}

// SET OPERATIONS;

- (void) intersectWithCollection: (id <Collecting>)aCollection
{
  [self removeContentsNotIn: aCollection];
}

- (void) unionWithCollection: (id <Collecting>)aCollection
{
  [self addContentsIfAbsentOf: aCollection];
}

- (void) differenceWithCollection: (id <Collecting>)aCollection
{
  [self removeContentsIn: aCollection];
}

- shallowCopyIntersectWithCollection: (id <Collecting>)aCollection
{
  [self notImplemented: _cmd];
  return nil;
#if 0
  id newColl = [self emptyCopyAs:[self species]];
  void doIt(elt e)
    {
      if ([aCollection includesElement:e])
	[newColl addElement:e];
    }
  [self withElementsCall:doIt];
  return newColl;
#endif
}

- shallowCopyUnionWithCollection: (id <Collecting>)aCollection
{
  [self notImplemented: _cmd];
  return nil;
#if 0
  id newColl = [self shallowCopy];
  [newColl addContentsOf:aCollection];
  return newColl;
#endif
}

- shallowCopyDifferenceWithCollection: (id <Collecting>)aCollection
{
  [self notImplemented: _cmd];
  return nil;
#if 0
  id newColl = [self emptyCopyAs:[self species]];
  void doIt(elt e)
    {
      if (![aCollection includesElement:e])
	[newColl addElement:e];
    }
  [self withElementsCall:doIt];
  return newColl;
#endif
}


// ADDING;

- (void) addObject: newObject
{
  NSHashInsert (_contents_hash, newObject);
}


// REMOVING AND REPLACING;

- (void) removeObject: oldObject
{
  NSHashRemove (_contents_hash, oldObject);
}

/* This must work without sending any messages to content objects */
- (void) _collectionEmpty
{
  NSResetHashTable (_contents_hash);
}

- (void) uniqueContents
{
  return;
}


// TESTING;

- (BOOL) containsObject: anObject
{
  return (NSHashGet (_contents_hash, anObject) ? 1 : 0);
}

- (unsigned) count
{
  if (!_contents_hash)
    return 0;
  return NSCountHashTable (_contents_hash);
}

- (unsigned) occurrencesOfObject: anObject
{
  if ([self containsObject: anObject])
    return 1;
  else
    return 0;
}

- member: anObject
{
  return NSHashGet(_contents_hash, anObject);
}


// ENUMERATING;

- nextObjectWithEnumState: (void**)enumState
{
  return NSNextHashEnumeratorItem ((*(NSHashEnumerator**)enumState));
}

- (void*) newEnumState
{
  void *es;

  OBJC_MALLOC (es, NSMapEnumerator, 1);
  *((NSHashEnumerator*)es) = NSEnumerateHashTable (_contents_hash);
  return es;
}

- (void) freeEnumState: (void**)enumState
{
  OBJC_FREE (*enumState);
}

@end

