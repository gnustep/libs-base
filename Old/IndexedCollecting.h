/* Protocol for Objective-C objects that hold elements accessible by index
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
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

#ifndef __IndexedCollecting_h_GNUSTEP_BASE_INCLUDE
#define __IndexedCollecting_h_GNUSTEP_BASE_INCLUDE

#include <base/Collecting.h>
#include <Foundation/NSRange.h>

#define	IndexRange	NSRange

#define IndexRangeInside(RANGE1,RANGE2) \
  ({IndexRange __a=(RANGE1), __b=(RANGE2); \
    __a.start<=__b.start && __a.end>=__b.end;})


@protocol ConstantIndexedCollecting <ConstantCollecting>

// GETTING MEMBERS BY INDEX;
- objectAtIndex: (unsigned)index;
- firstObject;
- lastObject;

// GETTING MEMBERS BY NEIGHBOR;
- successorOfObject: anObject;
- predecessorOfObject: anObject;

// GETTING INDICES BY MEMBER;
- (unsigned) indexOfObject: anObject;
- (unsigned) indexOfObject: anObject inRange: (IndexRange)aRange;

// TESTING;
- (BOOL) contentsEqualInOrder: (id <ConstantIndexedCollecting>)aColl;
- (int) compareInOrderContentsOf: (id <Collecting>)aCollection;
- (unsigned) indexOfFirstDifference: (id <ConstantIndexedCollecting>)aColl;
- (unsigned) indexOfFirstIn: (id <ConstantCollecting>)aColl;
- (unsigned) indexOfFirstNotIn: (id <ConstantCollecting>)aColl;

// ENUMERATING;
- (id <Enumerating>) reverseObjectEnumerator;
- (void) withObjectsInRange: (IndexRange)aRange
    invoke: (id <Invoking>)anInvocation;
- (void) withObjectsInReverseInvoke: (id <Invoking>)anInvocation;
- (void) withObjectsInReverseInvoke: (id <Invoking>)anInvocation
    whileTrue:(BOOL *)flag;
- (void) makeObjectsPerformInReverse: (SEL)aSel;
- (void) makeObjectsPerformInReverse: (SEL)aSel withObject: argObject;

// LOW-LEVEL ENUMERATING;
- prevObjectWithEnumState: (void**)enumState;

@end


@protocol IndexedCollecting <ConstantIndexedCollecting, Collecting>

// REPLACING;
- (void) replaceObjectAtIndex: (unsigned)index with: newObject;

// REMOVING;
- (void) removeObjectAtIndex: (unsigned)index;
- (void) removeFirstObject;
- (void) removeLastObject;
- (void) removeRange: (IndexRange)aRange;

// SORTING;
- (void) sortContents;
- (void) sortAddObject: newObject;

@end

#define NO_INDEX NSNotFound

/* xxx Fix this comment: */

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

#endif /* __IndexedCollecting_h_GNUSTEP_BASE_INCLUDE */
