/* Protocol for Objective-C objects that hold collections of elements.
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

/* The <Collecting> protocol is root of the collection protocol heirarchy. 

   The <Collecting> protocol defines the most general interface to a
   collection of elements.  Elements can be added, removed, and replaced.
   The contents can be tested, enumerated, and enumerated through various
   filters.  Elements may be objects, or any C type included in the 
   "elt" union given in elt.h, but all elements of a collection must be of
   the same C type.
*/

#ifndef __Collecting_h_INCLUDE_GNU
#define __Collecting_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objc/Object.h>
#include <objects/elt.h>

@protocol Collecting

// INITIALIZING;
- init;
- initWithContentsOf: (id <Collecting>)aCollection;

// RELEASING;
- (oneway void) release;
- releaseObjects;

// ADDING;
- addObject: newObject;
- addObjectIfAbsent: newObject;
- addContentsOf: (id <Collecting>)aCollection;
- addContentsOfIfAbsent: (id <Collecting>)aCollection;
- addObjectsCount: (unsigned)count, ...;

// REMOVING;
- removeObject: oldObject;
- removeObject: oldObject ifAbsentCall: (id(*)(arglist_t))excFunc;
- removeAllOccurrencesOfObject: oldObject;
- removeContentsIn: (id <Collecting>)aCollection;
- removeContentsNotIn: (id <Collecting>)aCollection;
- uniqueContents;
- empty;

// REPLACING;
- replaceObject: oldObject with: newObject;
- replaceObject: oldObject with: newObject 
    ifAbsentCall:(id(*)(arglist_t))excFunc;
- replaceAllOccurrencesOfObject: oldObject with: newObject;

// TESTING;
- (BOOL) isEmpty;
- (BOOL) includesObject: anObject;
- (BOOL) isSubsetOf: (id <Collecting>)aCollection;
- (BOOL) isDisjointFrom: (id <Collecting>)aCollection;
- (int) compare: anObject;
- (BOOL) isEqual: anObject;
- (BOOL) contentsEqual: (id <Collecting>)aCollection;
- (unsigned) count;
- (unsigned) occurrencesOfObject: anObject;
- (BOOL) trueForAllObjectsByCalling: (BOOL(*)(id))aFunc;
- (BOOL) trueForAnyObjectsByCalling: (BOOL(*)(id))aFunc;
- detectObjectByCalling: (BOOL(*)(id))aFunc;
- detectObjectByCalling: (BOOL(*)(id))aFunc 
    ifNoneCall: (id(*)(arglist_t))excFunc;
- maxObject;
- maxObjectByCalling: (int(*)(id,id))aFunc;
- minObject;
- minObjectByCalling: (int(*)(id,id))aFunc;

// ENUMERATING
- (void*) newEnumState;
- (BOOL) getNextObject:(id *)anObjectPtr withEnumState: (void**)enumState;
- freeEnumState: (void**)enumState;
- withObjectsCall: (void(*)(id))aFunc;
- withObjectsCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag;
- injectObject: initialArgObject byCalling:(id(*)(id,id))aFunc;
- makeObjectsPerform: (SEL)aSel;
- makeObjectsPerform: (SEL)aSel with: argObject;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeMakeObjectsPerform: (SEL)aSel;
- safeMakeObjectsPerform: (SEL)aSel with: argObject;
- safeWithObjectsCall: (void(*)(id))aFunc;
- safeWithObjectsCall: (void(*)(id))aFunc whileTrue:(BOOL *)flag;

// FILTERED ENUMERATING;
- withObjectsTrueByCalling: (BOOL(*)(id))testFunc 
    call: (void(*)(id))destFunc;
- withObjectsFalseByCalling: (BOOL(*)(id))testFunc 
    call: (void(*)(id))destFunc;
- withObjectsTransformedByCalling: (id(*)(id))transFunc
    call: (void(*)(id))destFunc;

// COPYING 
- emptyCopy;
- emptyCopyAs: (id <Collecting>)aCollectionClass;
- shallowCopy;
- shallowCopyAs: (id <Collecting>)aCollectionClass;
- copy;
- copyAs: (id <Collecting>)aCollectionClass;
- species;


// NON-OBJECT ELEMENT METHOD NAMES;

// INITIALIZING;
- initWithType:(const char *)contentEncoding;

// ADDING;
- addElement: (elt)newElement;
- addElementIfAbsent: (elt)newElement;
- addElementsCount: (unsigned)count, ...;

// REMOVING;
- (elt) removeElement: (elt)oldElement;
- (elt) removeElement: (elt)oldElement 
    ifAbsentCall: (elt(*)(arglist_t))excFunc;
- removeAllOccurrencesOfElement: (elt)oldElement;

// REPLACING;
- (elt) replaceElement: (elt)oldElement with: (elt)newElement;
- (elt) replaceElement: (elt)oldElement with: (elt)newElement
    ifAbsentCall: (elt(*)(arglist_t))excFunc;
- replaceAllOccurrencesOfElement: (elt)oldElement with: (elt)newElement;

// TESTING;
- (BOOL) includesElement: (elt)anElement;
- (unsigned) occurrencesOfElement: (elt)anElement;
- (elt) detectElementByCalling: (BOOL(*)(elt))aFunc;
- (elt) detectElementByCalling: (BOOL(*)(elt))aFunc 
    ifNoneCall: (elt(*)(arglist_t))excFunc;
- (elt) maxElement;
- (elt) maxElementByCalling: (int(*)(elt,elt))aFunc;
- (elt) minElement;
- (elt) minElementByCalling: (int(*)(elt,elt))aFunc;
- (BOOL) trueForAllElementsByCalling: (BOOL(*)(elt))aFunc;
- (BOOL) trueForAnyElementsByCalling: (BOOL(*)(elt))aFunc;
- (const char *) contentType;
- (BOOL) contentsAreObjects;
- (int(*)(elt,elt)) comparisonFunction;

// ENUMERATING;
- (BOOL) getNextElement:(elt *)anElementPtr withEnumState: (void**)enumState;
- withElementsCall: (void(*)(elt))aFunc;
- withElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag;
- (elt) injectElement: (elt)initialElement byCalling: (elt(*)(elt,elt))aFunc;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeWithElementsCall: (void(*)(elt))aFunc;
- safeWithElementsCall: (void(*)(elt))aFunc whileTrue: (BOOL*)flag;

// FILTERED ENUMERATING;
- withElementsTrueByCalling: (BOOL(*)(elt))testFunc 
    call: (void(*)(elt))destFunc;
- withElementsFalseByCalling: (BOOL(*)(elt))testFunc 
    call: (void(*)(elt))destFunc;
- withElementsTransformedByCalling: (elt(*)(elt))transFunc
    call: (void(*)(elt))destFunc;

@end

#endif /* __Collecting_h_INCLUDE_GNU */
