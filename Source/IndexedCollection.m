/* Implementation for Objective-C IndexedCollection object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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

#include <gnustep/base/IndexedCollection.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <stdio.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/behavior.h>

@implementation ReverseEnumerator

- nextObject
{
  return [collection prevObjectWithEnumState: &enum_state];
}

@end


@implementation ConstantIndexedCollection


// GETTING MEMBERS BY INDEX;

- objectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- firstObject
{
  if ([self isEmpty])
    return nil;
  return [self objectAtIndex: 0];
}

- lastObject
{
  if ([self isEmpty])
    return nil;
  return [self objectAtIndex: [self count]-1];
}


// GETTING MEMBERS BY NEIGHBOR;

/* Should be overriden by linked-list-type classes */
- successorOfObject: anObject
{
  int last = [self count] - 1;
  int index = [self indexOfObject: anObject];
  if (index == last)
    return nil;
  return [self objectAtIndex: index+1];
}

/* Should be overriden by linked-list-type classes */
- predecessorOfObject: anObject
{
  int index = [self indexOfObject: anObject];
  if (index == 0)
    return nil;
  return [self objectAtIndex: index-1];
}


// GETTING INDICES BY MEMBER;

- (unsigned) indexOfObject: anObject
{
  int i, count = [self count];
  for (i = 0; i < count; i++)
    if ([anObject isEqual: [self objectAtIndex:i]])
      return i;
  return NO_INDEX;
}

- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange
{
  int i;
  
  /* xxx check that aRange is within count */
  for (i = aRange.location; i < aRange.location+aRange.length; i++)
    if ([anObject isEqual: [self objectAtIndex:i]])
      return i - aRange.location;
  return NO_INDEX;
}


// TESTING;

- (BOOL) contentsEqualInOrder: (id <ConstantIndexedCollecting>)aColl
{
  id o1, o2;
  void *s1, *s2;

  if ([self count] != [aColl count])
    return NO;
  s1 = [self newEnumState];
  s2 = [aColl newEnumState];
  while ((o1 = [self nextObjectWithEnumState:&s1])
	 && (o2 = [aColl nextObjectWithEnumState:&s2]))
    {
      if (![o1 isEqual: o2])
	{
	  [self freeEnumState:&s1];
	  [aColl freeEnumState:&s2];
	  return NO;
	}
    }
  [self freeEnumState:&s1];
  [aColl freeEnumState:&s2];
  return YES;
}

- (int) compareInOrderContentsOf: (id <Collecting>)aCollection
{
  void *es1 = [self newEnumState];
  void *es2 = [aCollection newEnumState];
  id o1, o2;
  int comparison;
  while ((o1 = [self nextObjectWithEnumState:&es1])
	 && (o2 = [aCollection nextObjectWithEnumState:&es2]))
    {
      if ((comparison = [o1 compare: o2]))
	{
	  [self freeEnumState:&es1];
	  [aCollection freeEnumState:&es2];
	  return comparison;
	}
    }
  if ((comparison = ([self count] - [aCollection count])))
    return comparison;
  return 0;
}

- (unsigned) indexOfFirstDifference: (id <ConstantIndexedCollecting>)aColl
{
  unsigned i = 0;
  BOOL flag = YES;
  void *enumState = [self newEnumState];
  id o1, o2;
  FOR_INDEXED_COLLECTION_WHILE_TRUE(self, o1, flag)
    {
      if ((!(o2 = [self nextObjectWithEnumState: &enumState]))
	  || [o1 isEqual: o2])
	flag = NO;
      else
	i++;
    }
  END_FOR_INDEXED_COLLECTION_WHILE_TRUE(self);
  [self freeEnumState: &enumState];
  return i;
}

/* Could be more efficient */
- (unsigned) indexOfFirstIn: (id <ConstantCollecting>)aCollection
{
  unsigned index = 0;
  BOOL flag = YES;
  id o;

  FOR_INDEXED_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      if ([aCollection containsObject: o])
	flag = NO;
      else
	index++;
    }
  END_FOR_INDEXED_COLLECTION(self);
  return index;
}

/* Could be more efficient */
- (unsigned) indexOfFirstNotIn: (id <ConstantCollecting>)aCollection
{
  unsigned index = 0;
  BOOL flag = YES;
  id o;

  FOR_INDEXED_COLLECTION_WHILE_TRUE(self, o, flag)
    {
      if (![aCollection containsObject: o])
	flag = NO;
      else
	index++;
    }
  END_FOR_INDEXED_COLLECTION(self);
  return index;
}


// ENUMERATING;

- (id <Enumerating>) reverseObjectEnumerator
{
  return [[[ReverseEnumerator alloc] initWithCollection: self]
	   autorelease];
}

- (void) withObjectsInRange: (IndexRange)aRange
		     invoke: (id <Invoking>)anInvocation
{
  int i;
  for (i = aRange.location; i < aRange.location + aRange.length; i++)
    [anInvocation invokeWithObject: [self objectAtIndex: i]];
}

- (void) withObjectsInReverseInvoke: (id <Invoking>)anInvocation
{
  int i, count = [self count];
  for (i = count-1; i >= 0; i--)
    [anInvocation invokeWithObject: [self objectAtIndex: i]];
}

- (void) withObjectsInReverseInvoke: (id <Invoking>)anInvocation
			  whileTrue:(BOOL *)flag
{
  int i, count = [self count];
  for (i = count-1; *flag && i >= 0; i--)
    [anInvocation invokeWithObject: [self objectAtIndex: i]];
}

- (void) makeObjectsPerformInReverse: (SEL)aSel
{
  id o;
  FOR_INDEXED_COLLECTION_REVERSE(self, o)
    {
      [o perform: aSel];
    }
  END_FOR_INDEXED_COLLECTION_REVERSE(self);
}

- (void) makeObjectsPerformInReverse: (SEL)aSel withObject: argObject
{
  id o;
  FOR_INDEXED_COLLECTION_REVERSE(self, o)
    {
      [o perform: aSel withObject: argObject];
    }
  END_FOR_INDEXED_COLLECTION_REVERSE(self);
}



// LOW-LEVEL ENUMERATING;

- prevObjectWithEnumState: (void**)enumState
{
  /* *(int*)enumState is the index of the element that was returned
     last time -prevObjectWithEnumState: or -nextObjectWithEnumState
     was called.  In -newEnumState, *(int*)enumState is initialized to
     -2; The implementation of -newEnumState can be found below. */

  /* If there are not objects in this collection, or we are being
     asked for the object before the first object, return nil. */
  if ([self isEmpty] || ((*(int*)enumState) == 0)
       || ((*(int*)enumState) == -1))
    {
      (*(int*)enumState) = -1;
      return NO_OBJECT;
    }

  if (*(int*)enumState == -2)
    /* enumState was just initialized by -newEnumState, start
       at the end of the sequence. */
    *(int*)enumState = [self count]-1;
  else
    /* ...otherwise go the previous index. */
    (*(int*)enumState)--;

  return [self objectAtIndex:(*(unsigned*)enumState)];
}



// COPYING;

- shallowCopyRange: (IndexRange)aRange
{
  [self notImplemented: _cmd];
  return nil;
}

- shallowCopyInReverse
{
  [self notImplemented: _cmd];
  return nil;
}

- shallowCopyInReverseRange: (IndexRange)aRange
{
  [self notImplemented: _cmd];
  return nil;
}


// OVERRIDE SOME COLLECTION METHODS;

- (void*) newEnumState
{
  return (void*) -2;
}

- nextObjectWithEnumState: (void**)enumState
{
  /* *(int*)enumState is the index of the element that was returned
     last time -prevObjectWithEnumState: or -nextObjectWithEnumState
     was called.  In -newEnumState, *(int*)enumState is initialized to
     -2. */

  /* If there are not objects in this collection, or we are being
     asked for the object after the last object, return nil. */
  if ([self isEmpty] || ((*(int*)enumState) >= (int)([self count]-1)))
    {
      (*(int*)enumState) = [self count];
      return NO_OBJECT;
    }

  if (*(int*)enumState == -2)
    /* enumState was just initialized by -newEnumState, start
       at the beginning of the sequence. */
    *(int*)enumState = 0;
  else
    /* ...otherwise go the next index. */
    (*(int*)enumState)++;

  return [self objectAtIndex:(*(unsigned*)enumState)];
}

/* is this what we want? */
- (BOOL) isEqual: anObject
{
  if (self == anObject) 
    return YES;
  if ([anObject class] == [self class]
      && [self count] != [anObject count] 
      && [self contentsEqualInOrder: anObject] )
    return YES;
  else
    return NO;
}

@end



@implementation IndexedCollection

+ (void) initialize
{
  if (self == [IndexedCollection class])
    class_add_behavior(self, [Collection class]);
}


// REPLACING;

- (void) replaceObjectAtIndex: (unsigned)index withObject: newObject
{
  [self subclassResponsibility: _cmd];
}


// REMOVING;

- (void) removeObjectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
}

- (void) removeFirstObject
{
  [self removeObjectAtIndex: 0];
}

- (void) removeLastObject
{
  [self removeObjectAtIndex: [self count]-1];
}

- (void) removeRange: (IndexRange)aRange
{
  int count = aRange.length;

  CHECK_INDEX_RANGE_ERROR(aRange.location, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.location+aRange.length-1, [self count]);
  while (count--)
    [self removeObjectAtIndex: aRange.location];
}


// SORTING;

- (void) sortContents
{
  [self notImplemented: _cmd];
}

- (void) sortAddObject: newObject
{
  [self notImplemented: _cmd];
}

// OVERRIDE SOME COLLECTION METHODS;

- (void) removeObject: anObject
{
  unsigned index;

  /* Retain the object.  Yuck, but necessary in case the array holds
     the last reference to anObject. */
  /* xxx Is there an alternative to this expensive retain/release? */
  [anObject retain];

  for (index = [self indexOfObject: anObject];
       index != NO_INDEX;
       index = [self indexOfObject: anObject])
    [self removeObjectAtIndex: index];

  [anObject release];
}

- (void) replaceObject: oldObject withObject: newObject
{
  unsigned index;

  /* Retain the object.  Yuck, but necessary in case the array holds
     the last reference to anObject. */
  /* xxx Is there an alternative to this expensive retain/release? */
  [oldObject retain];

  for (index = [self indexOfObject: oldObject];
       index != NO_INDEX;
       index = [self indexOfObject: oldObject])
    [self replaceObjectAtIndex: index withObject: newObject];

  [oldObject release];
}

@end


