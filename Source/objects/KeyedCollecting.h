/* Protocol for Objective-C objects holding (keyElement,contentElement) pairs.
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

/* The <KeyedCollecting> protocol inherits from the <Collecting> protocol.

   The <KeyedCollecting> protocol defines the interface to a
   collection of elements that are accessible by a key, where the key is
   some unique element.  Pairs of (key element, content element) may be
   added, removed and replaced.  The keys and contents may be tested,
   enumerated and copied.  
*/

#ifndef __KeyedCollecting_h_OBJECTS_INCLUDE
#define __KeyedCollecting_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Collecting.h>

@protocol ConstantKeyedCollecting <ConstantCollecting>

// GETTING ELEMENTS AND KEYS;
- objectAtKey: (elt)aKey;
- keyObjectOfObject: aContentObject;

// TESTING;
- (BOOL) includesKey: (elt)aKey;

// ENUMERATIONS;
- withKeyObjectsCall: (void(*)(id))aFunc;
- withKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc;
- withKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc 
    whileTrue: (BOOL *)flag;

// NON-OBJECT ELEMENT METHOD NAMES;

// INITIALIZING;
- initWithType: (const char *)contentsEncoding
    keyType: (const char *)keyEncoding;
- initKeyType: (const char *)keyEncoding;

// GETTING ELEMENTS AND KEYS;
- (elt) elementAtKey: (elt)aKey;
- (elt) elementAtKey: (elt)aKey ifAbsentCall: (elt(*)(arglist_t))excFunc;
- (elt) keyElementOfElement: (elt)aContentObject;
- (elt) keyElementOfElement: (elt)aContentObject
    ifAbsentCall: (elt(*)(arglist_t))excFunc;

// TESTING;
- (const char *) keyType;

// ENUMERATING;
- (BOOL) getNextKey: (elt*)aKeyPtr content: (elt*)anElementPtr 
  withEnumState: (void**)enumState;
- withKeyElementsCall: (void(*)(elt))aFunc;
- withKeyElementsAndContentElementsCall: (void(*)(elt,elt))aFunc;
- withKeyElementsAndContentElementsCall: (void(*)(elt,elt))aFunc 
    whileTrue: (BOOL *)flag;

@end

@protocol KeyedCollecting <ConstantKeyedCollecting, Collecting>

// ADDING;
- putObject: newContentObject atKey: (elt)aKey;

// REPLACING AND SWAPPING;
- replaceObjectAtKey: (elt)aKey with: newContentObject;
- swapAtKeys: (elt)key1 : (elt)key2;

// REMOVING;
- removeObjectAtKey: (elt)aKey;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeWithKeyObjectsCall: (void(*)(id))aFunc;
- safeWithKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc;
- safeWithKeyObjectsAndContentObjectsCall: (void(*)(id,id))aFunc 
    whileTrue: (BOOL *)flag;


// NON-OBJECT ELEMENT METHOD NAMES;

// ADDING;
- putElement: (elt)newContentElement atKey: (elt)aKey;

// REPLACING;
- (elt) replaceElementAtKey: (elt)aKey with: (elt)newContentElement;
- (elt) replaceElementAtKey: (elt)aKey with: (elt)newContentElement
    ifAbsentCall: (elt(*)(arglist_t))excFunc;

// REMOVING;
- (elt) removeElementAtKey: (elt)aKey;
- (elt) removeElementAtKey: (elt)aKey ifAbsentCall: (elt(*)(arglist_t))excFunc;

// ENUMERATING WHILE CHANGING CONTENTS;
- safeWithKeyElementsCall: (void(*)(elt))aFunc;
- safeWithKeyElementsAndContentElementsCall: (void(*)(elt,elt))aFunc;
- safeWithKeyElementsAndContentElementsCall: (void(*)(elt,elt))aFunc 
    whileTrue: (BOOL *)flag;

@end

#endif /* __KeyedCollecting_h_OBJECTS_INCLUDE */
