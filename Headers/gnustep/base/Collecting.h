/* Protocol for Objective-C objects that hold collections of elements.
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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

/* The <Collecting> protocol is root of the collection protocol heirarchy. 

   The <Collecting> protocol defines the most general interface to a
   collection of elements.  Elements can be added, removed, and replaced.
   The contents can be tested, enumerated, and enumerated through various
   filters.  Elements may be objects, or any C type included in the 
   "elt" union given in elt.h, but all elements of a collection must be of
   the same C type.
*/

#ifndef __Collecting_h_GNUSTEP_BASE_INCLUDE
#define __Collecting_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Coding.h>
#include <base/Invoking.h>
#include <base/Enumerating.h>

@protocol ConstantCollecting <NSObject>

// INITIALIZING;
- init;
- initWithObjects: (id*)objc count: (unsigned)c;
- initWithObjects: firstObject, ...;
- initWithObjects: firstObject rest: (va_list)ap;
- initWithContentsOf: (id <ConstantCollecting>)aCollection;

// QUERYING COUNTS;
- (BOOL) isEmpty;
- (unsigned) count;
- (BOOL) containsObject: anObject;
- (unsigned) occurrencesOfObject: anObject;

// COMPARISON WITH OTHER COLLECTIONS;
- (BOOL) isSubsetOf: (id <ConstantCollecting>)aCollection;
- (BOOL) isDisjointFrom: (id <ConstantCollecting>)aCollection;
- (BOOL) isEqual: anObject;
- (int) compare: anObject;
- (BOOL) contentsEqual: (id <ConstantCollecting>)aCollection;

// PROPERTIES OF CONTENTS;
- (BOOL) trueForAllObjectsByInvoking: (id <Invoking>)anInvocation;
- (BOOL) trueForAnyObjectsByInvoking: (id <Invoking>)anInvocation;
- detectObjectByInvoking: (id <Invoking>)anInvocation;
- maxObject;
- minObject;

// ENUMERATING
- (id <Enumerating>) objectEnumerator;
- (void) withObjectsInvoke: (id <Invoking>)anInvocation;
- (void) withObjectsInvoke: (id <Invoking>)anInvocation whileTrue:(BOOL *)flag;
- (void) makeObjectsPerform: (SEL)aSel;
- (void) makeObjectsPerform: (SEL)aSel withObject: argObject;

// FILTERED ENUMERATING;
- (void) withObjectsTrueByInvoking: (id <Invoking>)testInvocation
    invoke: (id <Invoking>)anInvocation;
- (void) withObjectsFalseByInvoking: (id <Invoking>)testInvocation
    invoke: (id <Invoking>)anInvocation;
- (void) withObjectsTransformedByInvoking: (id <Invoking>)transInvocation
    invoke: (id <Invoking>)anInvocation;

// LOW-LEVEL ENUMERATING;
- (void*) newEnumState;
- nextObjectWithEnumState: (void**)enumState;
- (void) freeEnumState: (void**)enumState;

// COPYING;
- allocCopy;
- emptyCopy;
- emptyCopyAs: (Class)aCollectionClass;
- shallowCopy;
- shallowCopyAs: (Class)aCollectionClass;
- copyAs: (Class)aCollectionClass;
- species;

@end


@protocol Collecting <ConstantCollecting>

// ADDING;
- (void) addObject: newObject;
- (void) addObjectIfAbsent: newObject;
- (void) addContentsOf: (id <ConstantCollecting>)aCollection;
- (void) addContentsIfAbsentOf: (id <ConstantCollecting>)aCollection;
- (void) addWithObjects: (id*)objc count: (unsigned)c;
- (void) addObjects: firstObject, ...;
- (void) addObjects: firstObject rest: (va_list)ap;

// REMOVING;
- (void) removeObject: oldObject;
- (void) removeAllOccurrencesOfObject: oldObject;
- (void) removeContentsIn: (id <ConstantCollecting>)aCollection;
- (void) removeContentsNotIn: (id <ConstantCollecting>)aCollection;
- (void) uniqueContents;
- (void) empty;

// REPLACING;
- (void) replaceObject: oldObject withObject: newObject;
- (void) replaceAllOccurrencesOfObject: oldObject withObject: newObject;

@end

#define NO_OBJECT nil

#endif /* __Collecting_h_GNUSTEP_BASE_INCLUDE */
