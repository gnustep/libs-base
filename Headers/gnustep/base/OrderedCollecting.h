/* Protocol for Objective-C objects that hold elements, user gets to set order
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: Feb 1996

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

/* The <OrderedCollecting> protocol inherits from the 
   <KeyedCollecting> protocol.

   The <OrderedCollecting> protocol defines the interface to a
   collection of elements that are accessible by a key that is an index,
   where the indeces in a collection are a contiguous series of unsigned
   integers beginning at 0.  This is the root of the protocol heirarchy
   for all collections that hold their elements in some order.  Elements
   may be accessed, inserted, replaced and removed by their index.  
*/

#ifndef __OrderedCollecting_h_OBJECTS_INCLUDE
#define __OrderedCollecting_h_OBJECTS_INCLUDE

#include <gnustep/base/prefix.h>
#include <gnustep/base/IndexedCollecting.h>

@protocol OrderedCollecting <IndexedCollecting>

// ADDING;
- (void) insertObject: newObject atIndex: (unsigned)index;
- (void) insertObject: newObject before: oldObject;
- (void) insertObject: newObject after: oldObject;
- (void) insertContentsOf: (id <ConstantCollecting>)aCollection
   atIndex: (unsigned)index;
- (void) appendObject: newObject;
- (void) prependObject: newObject;
- (void) appendContentsOf: (id <ConstantCollecting>)aCollection;
- (void) prependContentsOf: (id <ConstantCollecting>)aCollection;

// SWAPPING AND SORTING
- (void) swapAtIndeces: (unsigned)index1 : (unsigned)index2;
- (void) sortContents;

// REPLACING;
- (void) replaceRange: (IndexRange)aRange
    with: (id <ConstantCollecting>)aCollection;
- replaceRange: (IndexRange)aRange
    using: (id <ConstantCollecting>)aCollection;

@end

#endif /* __OrderedCollecting_h_OBJECTS_INCLUDE */
