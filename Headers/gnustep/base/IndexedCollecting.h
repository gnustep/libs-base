/* Protocol for Objective-C objects that hold elements accessible by index
   Copyright (C) 1993, 1994, 1995 Free Software Foundation, Inc.

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

/* The <IndexedCollecting> protocol inherits from the 
   <KeyedCollecting> protocol.

   The <IndexedCollecting> protocol defines the interface to a
   collection of elements that are accessible by a key that is an index,
   where the indeces in a collection are a contiguous series of unsigned
   integers beginning at 0.  This is the root of the protocol heirarchy
   for all collections that hold their elements in some order.  Elements
   may be accessed, inserted, replaced and removed by their index.  
*/

#ifndef __IndexedCollecting_h_OBJECTS_INCLUDE
#define __IndexedCollecting_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/KeyedCollecting.h>

typedef struct _IndexRange { 
  unsigned location;
  unsigned length;
} IndexRange;

#define IndexRangeInside(RANGE1,RANGE2) \
  ({IndexRange __a=(RANGE1), __b=(RANGE2); \
    __a.start<=__b.start && __a.end>=__b.end;})


@protocol ConstantIndexedCollecting <ConstantKeyedCollecting>

// GETTING MEMBERS BY INDEX;
- objectAtIndex: (unsigned)index;
- firstObject;
- lastObject;

// GETTING MEMBERS BY NEIGHBOR;
- successorOfObject: anObject;
- predecessorOfObject: anObject;

// GETTING INDICES BY MEMBER;
- (unsigned) indexOfObject: anObject;
- (unsigned) indexOfObject: anObject 
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc;
- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange;
- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc;

// TESTING;
- (BOOL) includesIndex: (unsigned)index;
- (BOOL) contentsEqualInOrder: (id <IndexedCollecting>)aColl;
- (unsigned) indexOfFirstDifference: (id <IndexedCollecting>)aColl;
- (unsigned) indexOfFirstIn: (id <Collecting>)aColl;
- (unsigned) indexOfFirstNotIn: (id <Collecting>)aColl;

// ENUMERATING;
- (BOOL) getPrevObject: (id*)anIdPtr withEnumState: (void**)enumState;
- withObjectsInRange: (IndexRange)aRange call:(void(*)(id))aFunc;
- withObjectsInReverseCall: (void(*)(id))aFunc;
- withObjectsInReverseCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag;

// NON-OBJECT MESSAGE NAMES;

// GETTING ELEMENTS BY INDEX;
- (elt) elementAtIndex: (unsigned)index;
- (elt) firstElement;
- (elt) lastElement;

// GETTING MEMBERS BY NEIGHBOR;
- (elt) successorOfElement: (elt)anElement;
- (elt) predecessorOfElement: (elt)anElement;

// GETTING INDICES BY MEMBER;
- (unsigned) indexOfElement: (elt)anElement;
- (unsigned) indexOfElement: (elt)anElement
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc;
- (unsigned) indexOfElement: (elt)anElement inRange: (IndexRange)aRange;
- (unsigned) indexOfElement: (elt)anElement inRange: (IndexRange)aRange
    ifAbsentCall: (unsigned(*)(arglist_t))excFunc;

// ENUMERATING;
- (BOOL) getPrevElement:(elt*)anElementPtr withEnumState: (void**)enumState;
- withElementsInRange: (IndexRange)aRange call:(void(*)(elt))aFunc;
- withElementsInReverseCall: (void(*)(elt))aFunc;
- withElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag;

@end

@protocol IndexedCollecting <ConstantIndexedCollecting, KeyedCollecting>

// ADDING;
- insertObject: newObject atIndex: (unsigned)index;
- insertObject: newObject before: oldObject;
- insertObject: newObject after: oldObject;
- insertContentsOf: (id <Collecting>)aCollection atIndex: (unsigned)index;
- appendObject: newObject;
- prependObject: newObject;
- appendContentsOf: (id <Collecting>)aCollection;
- prependContentsOf: (id <Collecting>)aCollection;

// REPLACING AND SWAPPING
- replaceObjectAtIndex: (unsigned)index with: newObject;
- replaceRange: (IndexRange)aRange with: (id <Collecting>)aCollection;
- replaceRange: (IndexRange)aRange using: (id <Collecting>)aCollection;
- swapAtIndeces: (unsigned)index1 : (unsigned)index2;

// REMOVING
- removeObjectAtIndex: (unsigned)index;
- removeFirstObject;
- removeLastObject;
- removeRange: (IndexRange)aRange;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeWithObjectsInReverseCall: (void(*)(id))aFunc;
- safeWithObjectsInReverseCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag;

// SORTING;
- sortContents;
- sortObjectsByCalling: (int(*)(id,id))aFunc;
- sortAddObject: newObject;
- sortAddObject: newObject byCalling: (int(*)(id,id))aFunc;


// NON-OBJECT MESSAGE NAMES;

// ADDING;
- appendElement: (elt)newElement;
- prependElement: (elt)newElement;
- insertElement: (elt)newElement atIndex: (unsigned)index;
- insertElement: (elt)newElement before: (elt)oldElement;
- insertElement: (elt)newElement after: (elt)oldElement;

// REMOVING AND REPLACING;
- (elt) removeElementAtIndex: (unsigned)index;
- (elt) removeFirstElement;
- (elt) removeLastElement;
- (elt) replaceElementAtIndex: (unsigned)index with: (elt)newElement;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeWithElementsInRange: (IndexRange)aRange call:(void(*)(elt))aFunc;
- safeWithElementsInReverseCall: (void(*)(elt))aFunc;
- safeWithElementsInReverseCall: (void(*)(elt))aFunc whileTrue:(BOOL *)flag;

// SORTING;
- sortElementsByCalling: (int(*)(elt,elt))aFunc;
- sortAddElement: (elt)newElement;
- sortAddElement: (elt)newElement byCalling: (int(*)(elt,elt))aFunc;

@end

/* Most methods in the KeyedCollecting protocol that mention a key are
   duplicated in the IndexedCollecting protocol, with their names 
   modified to reflect that the "key" now must be an unsigned integer, 
   (an "index").  The programmer should be able to use either of the 
   corresponding method names to the same effect.

   The new methods are provided in the IndexedCollecting protocol for:
      1) Better type checking for when an unsigned int is required.
      2) More intuitive method names.

   IndexedCollecting                        KeyedCollecting
   ----------------------------------------------------------------------
   insertObject:atIndex                     insertObject:atKey:
   replaceObjectAtIndex:with:               replaceObjectAtKey:with:
   removeObjectAtIndex:                     removeObjectAtKey:
   objectAtIndex:                           objectAtKey:
   includesIndex:                           includesKey:

   insertElement:atIndex                    insertElement:atKey:
   replaceElementAtIndex:with:              replaceElementAtKey:with:
   removeElementAtIndex:                    removeElementAtKey:
   elementAtIndex:                          elementAtKey:

*/

#endif /* __IndexedCollecting_h_OBJECTS_INCLUDE */
