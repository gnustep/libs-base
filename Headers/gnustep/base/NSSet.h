/* Interface for NSSet, NSMutableSet, NSCountedSet for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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

#ifndef _NSSet_h_OBJECTS_INCLUDE
#define _NSSet_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>

@class NSArray, NSString, NSEnumerator, NSDictionary;

@interface NSSet : NSObject <NSCopying>

+ allocWithZone: (NSZone*)zone;
+ set;
+ setWithArray: (NSArray*)array;
+ setWithObject: anObject;
+ setWithObjects: (NSArray*)objects, ...;
- initWithArray: (NSArray*)array;
- initWithObjects: (NSArray*)objects, ...;
- initWithObjects: (id*)objects
	    count: (unsigned)count;
- initWithSet: (NSSet*)otherSet;
- initWithSet: (NSSet*)otherSet copyItems: (BOOL)flags;

- (NSArray*) allObjects;
- anyObject;
- (BOOL) containsObject: anObject;
- (unsigned) count;
- member: anObject;
- (NSEnumerator*) objectEnumerator;
- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject:argument;


- (BOOL) intersectsSet: (NSSet*)other;
- (BOOL) isEqualToSet: (NSSet*)other;
- (BOOL) isSubsetOfSet: (NSSet*)other;

- (NSString*) description;
- (NSString*) descriptionWithLocale: (NSDictionary*)ld;

@end

@interface NSMutableSet: NSSet

+ allocWithZone: (NSZone*)zone;
+ setWithCapacity: (unsigned)numItems;
- initWithCapacity: (unsigned)numItems;

- (void) addObject: anObject;
- (void) addObjectsFromArray: (NSArray*)array;
- (void) unionSet: (NSSet*)other;
- (void) intersectSet: (NSSet*)other;
- (void) minusSet: (NSSet*)other;
- (void) removeAllObjects;
- (void) removeObject: anObject;

@end

@interface NSCountedSet : NSMutableSet <NSCoding, NSCopying>

+ allocWithZone: (NSZone*)zone;
- initWithCapacity: (unsigned)numItems;
- initWithArray: (NSArray*)array;
- initWithSet: (NSSet*)otherSet;

- (void) addObject: anObject;
- (void) removeObject: anObject;
- (unsigned int) countForObject: anObject;
- (NSEnumerator*) objectEnumerator;

@end


#endif
