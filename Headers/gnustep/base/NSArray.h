/* Interface for NSArray for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: 1995
   
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

#ifndef __NSArray_h_OBJECTS_INCLUDE
#define __NSArray_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSUtilities.h>

@class NSString;

@interface NSArray : NSObject
- initWithObjects: (id*) objects count: (unsigned) count;
- (unsigned) count;
- objectAtIndex: (unsigned)index;
@end


@class NSArrayNonCore;
@interface NSArray (NonCore) <NSCopying, NSMutableCopying>

+ array;
+ arrayWithObject: anObject;
+ arrayWithObjects: firstObj, ...;
- (NSArray*) arrayByAddingObject: anObject;
- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray;
- initWithObjects: firstObj, ...;
- initWithArray: (NSArray*)array;

    
- (unsigned) indexOfObjectIdenticalTo: anObject;
- (unsigned) indexOfObject: anObject;
- (BOOL) containsObject: anObject;
- (BOOL) isEqualToArray: (NSArray*)otherArray;
- lastObject;

- (void) makeObjectsPerform: (SEL) aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: argument;
    
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator;
- (NSArray*) sortedArrayUsingFunction: (int (*)(id, id, void*))comparator 
	context: (void*)context;
- (NSString*) componentsJoinedByString: (NSString*)separator;

- firstObjectCommonWithArray: (NSArray*) otherArray;
- (NSArray*) subarrayWithRange: (NSRange)range;
- (NSEnumerator*)  objectEnumerator;
- (NSEnumerator*) reverseObjectEnumerator;
- (NSString*) description;
- (NSString*) descriptionWithIndent: (unsigned)level;

@end


@class NSMutableArrayNonCore;
@interface NSMutableArray : NSArray
- initWithCapacity: (unsigned)numItems;
- (void) addObject: anObject;
- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject;
- (void) insertObject: anObject atIndex: (unsigned)index;
- (void) removeObjectAtIndex: (unsigned)index;
@end

@interface NSMutableArray (NonCore)

+ arrayWithCapacity: (unsigned)numItems;

- (void) removeLastObject;
    
- (void) removeObjectIdenticalTo: anObject;
- (void) removeObject: anObject;
- (void) removeAllObjects;
- (void) addObjectsFromArray: (NSArray*)otherArray;
- (void) removeObjectsFromIndices: (unsigned*)indices 
   numIndices: (unsigned)count;
- (void) removeObjectsInArray: (NSArray*)otherArray;
- (void) setArray:(NSArray *)otherArray;
- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
	context: (void*)context;

@end

#endif /* __NSArray_h_OBJECTS_INCLUDE */
