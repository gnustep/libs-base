/* Interface for NSSet, NSMutableSet, NSCountedSet for GNUStep
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef _NSSet_h_GNUSTEP_BASE_INCLUDE
#define _NSSet_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

@class NSArray, NSString, NSEnumerator, NSDictionary;

@interface NSSet : NSObject <NSCoding, NSCopying, NSMutableCopying>

+ set;
+ setWithArray: (NSArray*)array;
+ setWithObject: anObject;
+ setWithObjects: anObject, ...;

- (id) initWithObjects: (id*)objects
		 count: (unsigned)count;
- (unsigned) count;
- (id) member: (id)anObject;
- (NSEnumerator*) objectEnumerator;

@end

@interface NSSet (NonCore)

- initWithArray: (NSArray*)array;
- initWithObjects: (id)objects, ...;
- initWithSet: (NSSet*)otherSet;
- initWithSet: (NSSet*)otherSet copyItems: (BOOL)flags;

- (NSArray*) allObjects;
- anyObject;
- (BOOL) containsObject: anObject;
- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject:argument;


- (BOOL) intersectsSet: (NSSet*)other;
- (BOOL) isEqualToSet: (NSSet*)other;
- (BOOL) isSubsetOfSet: (NSSet*)other;

- (NSString*) descriptionWithLocale: (NSDictionary*)ld;

@end

@interface NSMutableSet: NSSet

+ setWithCapacity: (unsigned)numItems;

- initWithCapacity: (unsigned)numItems;
- (void) addObject: (id)anObject;
- (void) removeObject: (id)anObject;

@end

@interface NSMutableSet (NonCore)

- (void) addObjectsFromArray: (NSArray*)array;
- (void) unionSet: (NSSet*)other;
- (void) intersectSet: (NSSet*)other;
- (void) minusSet: (NSSet*)other;
- (void) removeAllObjects;

@end

@interface NSCountedSet : NSMutableSet

- (unsigned int) countForObject: anObject;

@end

#ifndef NO_GNUSTEP

#include <gnustep/base/KeyedCollecting.h>
#include <Foundation/NSSet.h>

/* Eventually we'll make a Constant version of this protocol. */
@interface NSSet (GNU) <Collecting>
/* These methods will be moved to NSMutableSet as soon as GNU's
   collection objects are separated by mutability. */
+ (unsigned) defaultCapacity;
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity;
@end

@interface NSMutableSet (GNU)
@end

@interface NSCountedSet (GNU) <Collecting>
@end

#endif /* NO_GNUSTEP */

#endif
