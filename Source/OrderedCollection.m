/* Implementation for Objective-C OrderedCollection object
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Feb 1996

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

#include <gnustep/base/OrderedCollection.h>
#include <stdio.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/NSString.h>


@implementation OrderedCollection


// ADDING;

- (void) insertObject: newObject atIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
}

- (void) insertObject: newObject before: oldObject
{
  int i = [self indexOfObject: oldObject];
  [self insertObject: newObject atIndex: i];
}

- (void) insertObject: newObject after: oldObject
{
  int i = [self indexOfObject: oldObject];
  [self insertObject: newObject atIndex: i+1];
}

- (void) insertContentsOf: (id <ConstantCollecting>) aCollection
   atIndex: (unsigned)index
{
  [self notImplemented: _cmd];
#if 0
  void doIt(elt e)
    {
      [self insertElement: e atIndex: index];
    }
  if (aCollection == self)
    [self safeWithElementsInReverseCall:doIt];
  else
    {
      if ([(id)aCollection respondsToSelector:
	   @selector(withElemetnsInReverseCall:)])
	[(id)aCollection withElementsInReverseCall:doIt];
      else
	[aCollection withElementsCall:doIt];
    }
#endif
}

- (void) appendObject: newObject
{
  [self insertObject: newObject atIndex: [self count]];
}

- (void) prependObject: newObject
{
  [self insertObject: newObject atIndex: 0];
}

- (void) appendContentsOf: (id <ConstantCollecting>) aCollection
{
  id o;

  assert (aCollection != self);
  /* xxx Could be more efficient. */
  FOR_COLLECTION(aCollection, o)
    {
      [self appendObject: o];
    }
  END_FOR_COLLECTION(aCollection);
}

- (void) prependContentsOf: (id <ConstantCollecting>)aCollection
{
  id o;

  assert (aCollection != self);
  if ([(id)aCollection conformsTo: @protocol(IndexedCollecting)])
    {
      FOR_INDEXED_COLLECTION_REVERSE(self, o)
	{
	  [self prependObject: o];
	}
      END_FOR_INDEXED_COLLECTION_REVERSE(self);
    }
  else
    {
      FOR_COLLECTION(self, o)
	{
	  [self prependObject: o];
	}
      END_FOR_COLLECTION(self);
    }
}


// SWAPPING AND SORTING;

- (void) swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  id tmp = [self objectAtIndex:index1];
  [self replaceObjectAtIndex: index1 with: [self objectAtIndex: index2]];
  [self replaceObjectAtIndex: index2 with: tmp];
}

/* This could be hacked a bit to make it more efficient */
- (void) quickSortContentsFromIndex: (unsigned)p 
    toIndex: (unsigned)r
{
  unsigned i ,j;
  id x;

  if (p < r)
    {
      /* Partition */
      x = [self objectAtIndex:p];
      i = p - 1;
      j = r + 1;
      for (;;)
	{
	  do 
	    j = j - 1; 
	  while ([[self objectAtIndex: j] compare: x] > 0);
	  do 
	    i = i + 1; 
	  while ([[self objectAtIndex: i] compare: x] < 0);
	  if (i < j)
	    [self swapAtIndeces: i : j];
	  else
	      break;
	}
      /* Sort partitions */
      [self quickSortContentsFromIndex: p toIndex: j];
      [self quickSortContentsFromIndex: j+1 toIndex: r];
    }
}

- (void) sortContents
{
  [self quickSortContentsFromIndex: 0 toIndex: [self count]-1];
}


// REPLACING;

- (void) replaceRange: (IndexRange)aRange 
   withCollection: (id <ConstantCollecting>)aCollection
{
  [self notImplemented: _cmd];
}

- (void) replaceRange: (IndexRange)aRange 
   usingCollection: (id <ConstantCollecting>)aCollection
{
  [self notImplemented: _cmd];
}

#if 0
- replaceRange: (IndexRange)aRange
    with: (id <Collecting>)aCollection
{
  CHECK_INDEX_RANGE_ERROR(aRange.location, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.location+aRange.length-1, [self count]);
  [self removeRange:aRange];
  [self insertContentsOf:aCollection atIndex:aRange.location];
  return self;
}

- replaceRange: (IndexRange)aRange
    using: (id <Collecting>)aCollection
{
  int i;
  void *state = [aCollection newEnumState];
  elt e;

  CHECK_INDEX_RANGE_ERROR(aRange.location, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.location+aRange.length-1, [self count]);
  for (i = aRange.location; 
       i < aRange.location + aRange.length 
       && [aCollection getNextElement:&e withEnumState:&state]; 
       i++)
    {
      [self replaceElementAtIndex:i with:e];
    }
  [aCollection freeEnumState:&state];
  return self;
}
#endif



// OVERRIDE SOME COLLECTION METHODS;

- (void) addObject: newObject
{
  [self appendObject: newObject];
}

- (void) addContentsOf: (id <Collecting>)aCollection
{
  [self appendContentsOf: aCollection];
}


#if 0
// OVERRIDE SOME KEYED COLLECTION METHODS;

/* Semantics:  You can "put" an element only at index "count" or less */
- (void) putObject: newObject atIndex: (unsigned)index
{
  unsigned c = [self count];

  if (index < c)
    [self replaceObjectAtIndex: index withObject: newObject];
  else if (index == c)
    [self appendObject: newObject];
  else
    [NSException 
      raise: NSRangeException
      format: @"in %s, can't put an element at index beyond [self count]"];
}

- putObject: newObject atKey: index
{
  return [self putObject: newObject atIndex: [index unsignedIntValue]];
}
#endif


// OVERRIDE SOME INDEXED COLLECTION METHODS;

/* Should be more efficiently overriden by some subclasses. */
- (void) replaceObjectAtIndex: (unsigned)index withObject: newObject
{
  [self removeObjectAtIndex: index];
  [self insertObject: newObject atIndex: index];
}

@end
