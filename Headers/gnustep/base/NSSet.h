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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef _NSSet_h_GNUSTEP_BASE_INCLUDE
#define _NSSet_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSArray, NSString, NSEnumerator, NSDictionary;

@interface NSSet : NSObject <NSCoding, NSCopying, NSMutableCopying>

+ (id) set;
+ (id) setWithArray: (NSArray*)array;
+ (id) setWithObject: (id)anObject;
+ (id) setWithObjects: (id)anObject, ...;
+ (id) setWithSet: (NSSet*)aSet;

- (NSArray*) allObjects;
- (id) anyObject;
- (BOOL) containsObject: (id)anObject;
- (unsigned) count;
- (NSString*) descriptionWithLocale: (NSDictionary*)ld;

- (id) initWithArray: (NSArray*)array;
- (id) initWithObjects: (id)objects, ...;
- (id) initWithObjects: (id*)objects
		 count: (unsigned)count;
- (id) initWithObjects: firstObject
		  rest: (va_list)ap;
- (id) initWithSet: (NSSet*)otherSet;
- (id) initWithSet: (NSSet*)otherSet copyItems: (BOOL)flags;

- (BOOL) intersectsSet: (NSSet*)other;
- (BOOL) isEqualToSet: (NSSet*)other;
- (BOOL) isSubsetOfSet: (NSSet*)other;

- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument;
- (id) member: (id)anObject;
- (NSEnumerator*) objectEnumerator;

@end

@interface NSMutableSet: NSSet

+ (id) setWithCapacity: (unsigned)numItems;

- (void) addObject: (id)anObject;
- (void) addObjectsFromArray: (NSArray*)array;
- (id) initWithCapacity: (unsigned)numItems;
- (void) intersectSet: (NSSet*)other;
- (void) minusSet: (NSSet*)other;
- (void) removeAllObjects;
- (void) removeObject: (id)anObject;
#ifndef	STRICT_OPENSTEP
- (void) setSet: (NSSet*)other;
#endif
- (void) unionSet: (NSSet*)other;
@end

@interface NSCountedSet : NSMutableSet

- (unsigned int) countForObject: (id)anObject;

@end

#ifndef NO_GNUSTEP

/*
 * Utility methods for using a counted set to handle uniquing of objects.
 */
@interface NSCountedSet (GNU_Uniquing)
- (void) purge: (int)level;
- (id) unique: (id)anObject;
@end

/*
 * Functions for managing a global uniquing set.
 *
 * GSUniquing() turns on/off the action of the GSUnique() function.
 * if uniquing is turned off, GSUnique() simply returns its argument.
 *
 * GSUnique() returns an object that is equal to the one passed to it.
 * If the returned object is not the same object as the object passed in,
 * the original object is released and the returned object is retained.
 * Thus, an -init method that wants to implement uniquing simply needs
 * to end with 'return GSUnique(self);'
 */
void	GSUniquing(BOOL flag);	
id	GSUnique(id anObject);

/*
 * Management functions -
 *
 * GSUPurge() can be used to purge infrequently referenced objects from the
 * set by removing any objec whose count is less than or equal to that given.
 *
 * GSUSet() can be used to artificially set the count for a particular object
 * Setting the count to zero will remove the object from the global set.
 */
void	GSUPurge(unsigned count);
id	GSUSet(id anObject, unsigned count);

#endif /* NO_GNUSTEP */

#endif
