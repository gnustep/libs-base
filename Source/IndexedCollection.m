/* Implementation for Objective-C IndexedCollection object
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

#include <objects/IndexedCollection.h>
#include <objects/IndexedCollectionPrivate.h>
#include <stdio.h>
#include <objects/Array.h>

@implementation IndexedCollection

+ (void) initialize
{
  if (self == [IndexedCollection class])
    [self setVersion:0];	/* beta release */
}

/* This is the designated initializer of this class */
- initWithType: (const char *)contentEncoding
{
  [super initWithType:contentEncoding
	 keyType:@encode(unsigned int)];
  return self;
}

/* Override the designated initializer for our superclass KeyedCollection
   to make sure we have unsigned int keys. */
- initWithType: (const char *)contentEncoding
    keyType: (const char *)keyEncoding
{
  if (strcmp(keyEncoding, @encode(unsigned int)))
    [self error:"IndexedCollection key must be an unsigned integer."];
  return [self initWithType:contentEncoding];
}

// ADDING;

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  return [self subclassResponsibility:_cmd];
}

/* Semantics:  You can "put" an element only at index "count" or less */
- putElement: (elt)newElement atIndex: (unsigned)index
{
  unsigned c = [self count];

  if (index < c)
    [self replaceElementAtIndex:index with:newElement];
  else if (index == c)
    [self appendElement:newElement];
  else
    [self error:"in %s, can't put an element at index beyond [self count]"];
  return self;
}

- putElement: (elt)newElement atKey: (elt)index
{
  return [self putElement: newElement atIndex: index.unsigned_int_u];
}

- insertObject: newObject atIndex: (unsigned)index
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self insertElement:newObject atIndex:index];
}

- insertElement: (elt)newElement before: (elt)oldElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  [self insertElement:newElement atIndex:index];
  return self;
}

- insertObject: newObject before: oldObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self insertElement:newObject before:oldObject];
}

- insertElement: (elt)newElement after: (elt)oldElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  [self insertElement:newElement atIndex:index+1];
  return self;
}

- insertObject: newObject after: oldObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self insertElement:newObject after:oldObject];
}

/* Possibly inefficient.  Should be overridden. */
- appendElement: (elt)newElement
{
  return [self insertElement:newElement atIndex:[self count]];
}

- appendObject: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self appendElement:newObject];
}

/* Possibly inefficient.  Should be overridden. */
- prependElement: (elt)newElement
{
  return [self insertElement:newElement atIndex:0];
}

- prependObject: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self prependElement:newObject];
}

- appendContentsOf: (id <Collecting>) aCollection
{
  void doIt(elt e)
    {
      [self appendElement:e];
    }
  if (aCollection == self)
    [self safeWithElementsCall:doIt];
  else
    [aCollection withElementsCall:doIt];
  return self;
}

- prependContentsOf: (id <Collecting>) aCollection
{
  void doIt(elt e)
    {
      /* could use objc_msg_lookup here */
      [self prependElement:e];
    }
  if (aCollection == self)
    [self safeWithElementsInReverseCall:doIt];
  else
    {
      /* Can I assume that all Collections will inherit from Object? */
      if ([aCollection 
	   respondsToSelector:@selector(withElementsInReverseCall:)])
	[(id)aCollection withElementsInReverseCall:doIt];
      else
	[aCollection withElementsCall:doIt];
    }
  return self;
}

- addContentsOf: (id <Collecting>)aCollection
{
  [self appendContentsOf:aCollection];
  return self;
}

- insertContentsOf: (id <Collecting>)aCollection atIndex: (unsigned)index
{
  void doIt(elt e)
    {
      [self insertElement: e atIndex: index];
    }
  if (aCollection == self)
    [self safeWithElementsInReverseCall:doIt];
  else
    {
      if ([aCollection respondsToSelector:
		       @selector(withElemetnsInReverseCall:)])
	[(id)aCollection withElementsInReverseCall:doIt];
      else
	[aCollection withElementsCall:doIt];
    }
  return self;
}

/* We can now implement this <Collecting> protocol method */
- addElement: (elt)newElement
{
  return [self appendElement:newElement];
}


// REPLACING;

/* Subclasses may require different ordering semantics */
- (elt) replaceElement: (elt)oldElement with: (elt)newElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  return [self replaceElementAtIndex:index with:newElement];
}

/* Inefficient.  Should be overridden */
- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement
{
  elt ret;

  ret = [self removeElementAtIndex:index];
  [self insertElement:newElement atIndex:index];
  return ret;
}

- replaceObjectAtIndex: (unsigned)index with: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self replaceElementAtIndex:index with:newObject].id_u;
}

- replaceRange: (IndexRange)aRange
    with: (id <Collecting>)aCollection
{
  CHECK_INDEX_RANGE_ERROR(aRange.start, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.end-1, [self count]);
  [self removeRange:aRange];
  [self insertContentsOf:aCollection atIndex:aRange.start];
  return self;
}

- replaceRange: (IndexRange)aRange
    using: (id <Collecting>)aCollection
{
  int i;
  void *state = [aCollection newEnumState];
  elt e;

  CHECK_INDEX_RANGE_ERROR(aRange.start, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.end-1, [self count]);
  for (i = aRange.start; 
       i < aRange.end 
       && [aCollection getNextElement:&e withEnumState:&state]; 
       i++)
    {
      [self replaceElementAtIndex:i with:e];
    }
  [aCollection freeEnumState:&state];
  return self;
}


// SWAPPING;

/* Perhaps inefficient.  May be overridden. */
- swapAtIndeces: (unsigned)index1 : (unsigned)index2
{
  elt tmp = [self elementAtIndex:index1];
  [self replaceElementAtIndex:index1 with:[self elementAtIndex:index2]];
  [self replaceElementAtIndex:index2 with:tmp];
  return self;
}


// REMOVING;

- (elt) removeElementAtIndex: (unsigned)index
{
  return [self subclassResponsibility:_cmd];
}

- removeObjectAtIndex: (unsigned)index
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeElementAtIndex:index].id_u;
}

- (elt) removeFirstElement
{
  return [self removeElementAtIndex:0];
}

- removeFirstObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeFirstElement].id_u;
}

- (elt) removeLastElement
{
  return [self removeElementAtIndex:[self count]-1];
}

- removeLastObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self removeLastElement].id_u;
}

- removeRange: (IndexRange)aRange
{
  int i;

  CHECK_INDEX_RANGE_ERROR(aRange.start, [self count]);
  CHECK_INDEX_RANGE_ERROR(aRange.end-1, [self count]);
  for (i = aRange.start; i < aRange.end; i++)
    [self removeElementAtIndex:aRange.start];
  return self;
}

/* We can now implement this <Collecting> protocol method */
- (elt) removeElement: (elt)oldElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  return [self removeElementAtIndex:index];
}
  

// GETTING MEMBERS BY INDEX;

- (elt) elementAtIndex: (unsigned)index
{
  return [self subclassResponsibility:_cmd];
}

- objectAtIndex: (unsigned)index
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self elementAtIndex:index].id_u;
}

- (elt) firstElement
{
  return [self elementAtIndex:0];
}

- firstObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self firstElement].id_u;
}

- (elt) lastElement
{
  return [self elementAtIndex:[self count]-1];
}

- lastObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self lastElement].id_u;
}


// GETTING MEMBERS BY NEIGHBOR;

// This method should be overridden by linkedlists and trees;
- (elt) successorOfElement: (elt)oldElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  return [self elementAtIndex:index+1];
}

// This method should be overridden by linkedlists and trees;
- (elt) predecessorOfElement: (elt)oldElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(oldElement);
      return 0;
    }
  unsigned index = [self indexOfElement:oldElement ifAbsentCall:err];

  return [self elementAtIndex:index-1];
}

- successorOfObject: anObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self successorOfElement:anObject].id_u;
}

- predecessorOfObject: anObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self predecessorOfElement:anObject].id_u;
}


// GETTING INDICES BY ELEMENT;

/* Possibly inefficient. */
- (unsigned) indexOfElement: (elt)anElement
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(anElement);
      return 0;
    }
  return [self indexOfElement:anElement ifAbsentCall:err];
}

- (unsigned) indexOfElement: (elt)anElement
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc
{
  unsigned index = 0;
  BOOL flag = YES;
  int (*cf)(elt,elt) = [self comparisonFunction];
  void doIt(elt e)
    {
      if (!((*cf)(anElement, e)))
	flag = NO;
      else
	index++;
    }

  [self withElementsCall:doIt whileTrue:&flag];
  if (flag)
    RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
  return index;
}

- (unsigned) indexOfObject: anObject
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self indexOfElement:anObject ifAbsentCall:excFunc];
}

- (unsigned) indexOfElement: (elt)anElement inRange: (IndexRange)aRange
{
  unsigned err(arglist_t argFrame)
    {
      ELEMENT_NOT_FOUND_ERROR(anElement);
      return 0;
    }
  return [self indexOfElement:anElement inRange:aRange ifAbsentCall:err];
}

- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self indexOfElement:anObject inRange:aRange];
}

- (unsigned) indexOfElement: (elt)anElement inRange: (IndexRange)aRange
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc
{
  int i;
  int (*cf)(elt,elt) = [self comparisonFunction];

  for (i = aRange.start; i < aRange.end; i++)
    if (!((*cf)(anElement, [self elementAtIndex:i])))
      return i - aRange.start;
  RETURN_BY_CALLING_EXCEPTION_FUNCTION(excFunc);
}

- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self indexOfElement:anObject inRange:aRange ifAbsentCall:excFunc];
}

- (unsigned) indexOfFirstDifference: (id <IndexedCollecting>)aColl
{
  unsigned i = 0;
  BOOL flag = YES;
  void *enumState = [self newEnumState];
  int (*cf)(elt,elt);
  elt e2;
  void doIt(elt e1)
    {
      if ((![self getNextElement:&e2 withEnumState:&enumState])
	  || ((*cf)(e1, e2)))
	flag = NO;
      else
	i++;
    }

  if ((cf = [self comparisonFunction]) != [aColl comparisonFunction])
    return 0;
  [aColl withElementsCall:doIt whileTrue:&flag];
  [self freeEnumState:&enumState];
  return i;
}

/* Could be more efficient */
- (unsigned) indexOfFirstIn: (id <Collecting>)aColl
{
  unsigned index = 0;
  BOOL flag = YES;
  void doIt(elt e)
    {
      if ([aColl includesElement:e])
	flag = NO;
      else
	index++;
    }
  if ([self comparisonFunction] != [aColl comparisonFunction])
    return [self count];
  [self withElementsCall:doIt whileTrue:&flag];
  return index;
}

/* Could be more efficient */
- (unsigned) indexOfFirstNotIn: (id <Collecting>)aColl
{
  unsigned index = 0;
  BOOL flag = YES;
  void doIt(elt e)
    {
      if (![aColl includesElement:e])
	flag = NO;
      else
	index++;
    }
  if ([self comparisonFunction] != [aColl comparisonFunction])
    return [self count];
  [self withElementsCall:doIt whileTrue:&flag];
  return index;
}

- (unsigned) indexOfObject: anObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self indexOfElement:anObject];
}

// TESTING;

- (const char *) keyDescription
{
  return @encode(unsigned int);
}

- (BOOL) includesIndex: (unsigned)index
{
  if (index < [self count])
    return YES;
  else
    return NO;
}

- (BOOL) contentsEqualInOrder: (id <IndexedCollecting>)anIndexedColl
{
  elt e1, e2;
  void *s1, *s2;
  int (*cf)(elt,elt) = [self comparisonFunction];

  if ([self count] != [anIndexedColl count])
    return NO;
  s1 = [self newEnumState];
  s2 = [anIndexedColl newEnumState];
  while ([self getNextElement:&e1 withEnumState:&s1]
	 && [anIndexedColl getNextElement:&e2 withEnumState:&s2])
    {
      if ((*cf)(e1, e2))
	return NO;
    }
  [self freeEnumState:&s1];
  [anIndexedColl freeEnumState:&s2];
  return YES;
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

- (int) compareContentsOfInOrder: (id <Collecting>)aCollection
{
  int (*cf)(elt,elt) = [self comparisonFunction];
  if ([aCollection comparisonFunction] == cf)
    {
      void *es1 = [self newEnumState];
      void *es2 = [aCollection newEnumState];
      elt e1, e2;
      int comparison;
      while ([self getNextElement:&e1 withEnumState:&es1]
	     && [aCollection getNextElement:&e1 withEnumState:&es2])
	{
	  if ((comparison = (*cf)(e1,e2)))
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
  [self error:"Can't compare contents of collections with different "
	"comparison functions"];
  return -1;
}


// COPYING;
  
- shallowCopyRange: (IndexRange)aRange
{
  id newColl = [self emptyCopyAs:[self species]];
  unsigned i, myCount = [self count];
  
  for (i = aRange.start; i < aRange.end && i < myCount; i++)
    [newColl addElement:[self elementAtIndex:i]];
  return newColl;
}

- withElementsInRange: (IndexRange)aRange call:(void(*)(elt))aFunc
{
  unsigned i, myCount = [self count];
  
  for (i = aRange.start; i < aRange.end && i < myCount; i++)
    (*aFunc)([self elementAtIndex:i]);
  return self;
}

- withObjectsInRange: (IndexRange)aRange call:(void(*)(id))aFunc
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsInRange:aRange call:doIt];
}

- safeWithElementsInRange: (IndexRange)aRange call:(void(*)(elt))aFunc
{
  unsigned i, myCount = [self count];
  id tmpColl = [[Array alloc] initWithType:[self contentType]
		capacity:aRange.end - aRange.start];
  
  for (i = aRange.start; i < aRange.end && i < myCount; i++)
    [tmpColl addElement:[self elementAtIndex:i]];
  [tmpColl withElementsCall:aFunc];
  [tmpColl release];
  return self;
}

- shallowCopyReplaceRange: (IndexRange)aRange
    with: (id <Collecting>)replaceCollection
{
  id newColl = [self emptyCopyAs:[self species]];
  unsigned i, myCount = [self count];
  
  for (i = 0; i < aRange.start && i < myCount; i++)
    [newColl appendElement:[self elementAtIndex:i]];
  [newColl appendContentsOf:replaceCollection];
  for (i = aRange.end; i < myCount; i++)
    [newColl appendElement:[self elementAtIndex:i]];
  return newColl;
}

- shallowCopyReplaceRange: (IndexRange)aRange
    using: (id <Collecting>)replaceCollection
{
  id newColl = [self shallowCopy];
  unsigned index = aRange.start;
  BOOL cont = YES;
  void doIt (elt e)
    {
      [newColl replaceElementAtIndex: index with: e];
      cont = (++index != aRange.end);
    }
  [replaceCollection withElementsCall: doIt whileTrue: &cont];
  return newColl;
}

- shallowCopyInReverseAs: aCollectionClass
{
  id newColl = [self emptyCopyAs:aCollectionClass];
  void doIt(elt e)
    {
      [newColl appendElement:e];
    }
  [self withElementsInReverseCall:doIt];
  return self;
}


// ENUMERATING;

- (BOOL) getNextKey: (elt*)aKeyPtr content: (elt*)anElementPtr 
  withEnumState: (void**)enumState
{
  /* *(unsigned*)enumState is the index of the element that will be returned */
  if ((*(unsigned*)enumState) > [self count]-1)
    return NO;
  *anElementPtr = [self elementAtIndex:(*(unsigned*)enumState)];
  *aKeyPtr = (*(unsigned*)enumState);
  (*(unsigned*)enumState)++;
  return YES;
}

- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  /* *(unsigned*)enumState is the index of the element that will be returned */
  if ((*(unsigned*)enumState) > [self count]-1)
    return NO;
  *anElementPtr = [self elementAtIndex:(*(unsigned*)enumState)];
  (*(unsigned*)enumState)++;
  return YES;
}

- (BOOL) getPrevElement:(elt *)anElementPtr withEnumState: (void**)enumState
{
  /* *(unsigned*)enumState-1 is the index of the element 
     that will be returned */
  if (!(*enumState))
    *(unsigned*)enumState = [self count]-1;
  else
    (*(unsigned*)enumState)--;
  *anElementPtr = [self elementAtIndex:(*(unsigned*)enumState)];
  return YES;
}

- (BOOL) getPrevObject:(id *)anObjectPtr withEnumState: (void**)enumState
{
  /* *(unsigned*)enumState-1 is the index of the element 
     that will be returned */
  CHECK_CONTAINS_OBJECTS_ERROR();
  if (!(*enumState))
    *(unsigned*)enumState = [self count]-1;
  else
    (*(unsigned*)enumState)--;
  *anObjectPtr = [self elementAtIndex:(*(unsigned*)enumState)].id_u;
  return YES;
}

- withElementsInReverseCall: (void(*)(elt))aFunc;
{
  BOOL flag = NO;
  [self withElementsInReverseCall:aFunc whileTrue:&flag];
  return self;
}

- safeWithElementsInReverseCall: (void(*)(elt))aFunc;
{
  BOOL flag = NO;
  [self safeWithElementsInReverseCall:aFunc whileTrue:&flag];
  return self;
}

- withObjectsInReverseCall: (void(*)(id))aFunc
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsInReverseCall:doIt];
}

- safeWithObjectsInReverseCall: (void(*)(id))aFunc
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsInReverseCall:doIt];
}

- withElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  int i;

  for (i = [self count]-1; *flag && i >= 0; i--)
    (*aFunc)([self elementAtIndex:i]);
  return self;
}

- safeWithElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  id tmp = [[Array alloc] initWithContentsOf:self];
  [tmp withElementsInReverseCall:aFunc whileTrue:flag];
  [tmp release];
  return self;
}

- withObjectsInReverseCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsInReverseCall:doIt whileTrue:flag];
}

- safeWithObjectsInReverseCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag
{
  void doIt(elt e)
    {
      (*aFunc)(e.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsInReverseCall:doIt whileTrue:flag];
}

- makeObjectsPerformInReverse: (SEL)aSel
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel];
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsInReverseCall:doIt];
}

- safeMakeObjectsPerformInReverse: (SEL)aSel
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel];
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsInReverseCall:doIt];
}

- makeObjectsPerformInReverse: (SEL)aSel with: argObject
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel with:argObject];
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self withElementsInReverseCall:doIt];
}

- safeMakeObjectsPerformInReverse: (SEL)aSel with: argObject
{
  void doIt(elt e)
    {
      [e.id_u perform:aSel with:argObject];
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self safeWithElementsInReverseCall:doIt];
}

- withElementsCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag
{
  unsigned i;
  unsigned count = [self count];

  for (i = 0; *flag && i < count; i++)
    (*aFunc)([self elementAtIndex:i]);
  return self;
}

- withKeyElementsAndContentElementsCall: (void(*)(const elt,elt))aFunc 
    whileTrue: (BOOL *)flag
{
  unsigned index = 0;
  void doIt(elt e)
    {
      (*aFunc)(index, e);
      index++;
    }
  [self withElementsCall:doIt];
  return self;
}

  
// SORTING;

/* This could be hacked a bit to make it more efficient */
- quickSortContentsFromIndex: (unsigned)p 
    toIndex: (unsigned)r
    byCalling: (int(*)(elt,elt))aFunc
{
  unsigned i ,j;
  elt x;

  if (p < r)
    {
      /* Partition */
      x = [self elementAtIndex:p];
      i = p - 1;
      j = r + 1;
      for (;;)
	{
	  do 
	    j = j - 1; 
	  while ((*aFunc)([self elementAtIndex:j],x) > 0);
	  do 
	    i = i + 1; 
	  while ((*aFunc)([self elementAtIndex:i],x) < 0);
	  if (i < j)
	    [self swapAtIndeces:i :j];
	  else
	      break;
	}
      /* Sort partitions */
      [self quickSortContentsFromIndex:p toIndex:j byCalling:aFunc];
      [self quickSortContentsFromIndex:j+1 toIndex:r byCalling:aFunc];
    }
  return self;
}

- sortElementsByCalling: (int(*)(elt,elt))aFunc
{
  if ([self count] == 0)
    return self;
  [self quickSortContentsFromIndex:0 
	toIndex:[self count]-1
	byCalling:aFunc];
  return self;
}

- sortObjectsByCalling: (int(*)(id,id))aFunc
{
  int comp(elt e1, elt e2)
    {
      return (*aFunc)(e1.id_u, e2.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self sortElementsByCalling:comp];
}

- sortContents
{
  [self sortElementsByCalling:COMPARISON_FUNCTION];
  return self;
}

- sortAddElement: (elt)newElement byCalling: (int(*)(elt,elt))aFunc
{
  unsigned insertionIndex = 0;
  BOOL insertionNotFound = YES;
  void test(elt e)
    {
      if ((*aFunc)(newElement, e) < 0)
	insertionNotFound = NO;
      else
	insertionIndex++;
    }
  [self withElementsCall:test whileTrue:&insertionNotFound];
  [self insertElement:newElement atIndex:insertionIndex];
  return self;
}

- sortAddElement: (elt)newElement
{
  return [self sortAddElement:newElement byCalling:COMPARISON_FUNCTION];
}

- sortAddObject: newObject
{
  CHECK_CONTAINS_OBJECTS_ERROR();
  return[self sortAddElement:newObject];
}

- sortAddObject: newObject byCalling: (int(*)(id,id))aFunc
{
  int comp(elt e1, elt e2)
    {
      return (*aFunc)(e1.id_u, e2.id_u);
    }
  CHECK_CONTAINS_OBJECTS_ERROR();
  return [self sortAddElement:newObject byCalling:comp];
}


// RELATION WITH KeyedCollection;

- insertElement: (elt)newContentElement atKey: (elt)aKey
{
  return [self insertElement:newContentElement atIndex:aKey.unsigned_int_u];
}

- (elt) replaceElementAtKey: (elt)aKey with: (elt)newContentElement
{
  return [self replaceElementAtIndex:aKey.unsigned_int_u 
	       with:newContentElement];
}

- (elt) removeElementAtKey: (elt)aKey
{
  return [self removeElementAtIndex:aKey.unsigned_int_u];
}

- (elt) elementAtKey: (elt)aKey
{
  return [self elementAtIndex:aKey.unsigned_int_u];
}

- (BOOL) includesKey: (elt)aKey
{
  return [self includesIndex:aKey.unsigned_int_u];
}

- printForDebugger
{
  void doIt(elt e)
    {
      [self printElement:e];
      printf(" ");
    }
  [self withElementsCall:doIt];
  printf(" :%s\n", [self name]);
  return self;
}

- (void) _encodeContentsWithCoder: (Coder*)coder
{
  unsigned int count = [self count];
  const char *encoding = [self contentType];
  void archiveElement(elt e)
    {
      [coder encodeValueOfType:encoding
	     at:elt_get_ptr_to_member(encoding, &e)
	     withName:"IndexedCollection Element"];
    }

  [coder encodeValueOfSimpleType:@encode(unsigned int)
	 at:&count
	 withName:"IndexedCollection Contents Count"];
  [self withElementsCall:archiveElement];
}

- (void) _decodeContentsWithCoder: (Coder*)coder
{
  unsigned int count, i;
  elt newElement;  
  const char *encoding = [self contentType];

  [coder decodeValueOfSimpleType:@encode(unsigned int)
	 at:&count
	 withName:NULL];
  for (i = 0; i < count; i++)
    {
      [coder decodeValueOfType:encoding
	     at:elt_get_ptr_to_member(encoding, &newElement)
	     withName:NULL];
      [self appendElement:newElement];
    }
}

- _writeContents: (TypedStream*)aStream
{
  unsigned int count = [self count];
  const char *encoding = [self contentType];
  void archiveElement(elt e)
    {
      objc_write_types(aStream, encoding,
		       elt_get_ptr_to_member(encoding, &e));
    }

  objc_write_type(aStream, @encode(unsigned int), &count);
  [self withElementsCall:archiveElement];
  return self;
}

- _readContents: (TypedStream*)aStream
{
  unsigned int count, i;
  elt newElement;  
  const char *encoding = [self contentType];

  objc_read_type(aStream, @encode(unsigned int), &count);
  for (i = 0; i < count; i++)
    {
      objc_read_types(aStream, encoding, 
		      elt_get_ptr_to_member(encoding, &newElement));
      [self appendElement:newElement];
    }
  return self;
}

@end    

