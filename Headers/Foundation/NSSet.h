/** Interface for NSSet, NSMutableSet, NSCountedSet for GNUStep
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   AutogsdocSource: NSSet.m
   AutogsdocSource: NSCountedSet.m

   */ 

#ifndef _NSSet_h_GNUSTEP_BASE_INCLUDE
#define _NSSet_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <GNUstepBase/GSBlocks.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray, NSString, NSEnumerator, NSDictionary;

@interface NSSet : NSObject <NSCoding, NSCopying, NSMutableCopying, NSFastEnumeration>

+ (id) set;
+ (id) setWithArray: (NSArray*)objects;
+ (id) setWithObject: (id)anObject;
+ (id) setWithObjects: (id)firstObject, ...;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
+ (id) setWithObjects: (const id[])objects
		count: (NSUInteger)count;
#endif
+ (id) setWithSet: (NSSet*)aSet;

- (NSArray*) allObjects;
- (id) anyObject;
- (BOOL) containsObject: (id)anObject;
- (NSUInteger) count;
- (NSString*) description;
- (NSString*) descriptionWithLocale: (id)locale;

- (id) init;
- (id) initWithArray: (NSArray*)other;
- (id) initWithObjects: (id)firstObject, ...;
- (id) initWithObjects: (const id[])objects
		 count: (NSUInteger)count;
- (id) initWithSet: (NSSet*)other;
- (id) initWithSet: (NSSet*)other copyItems: (BOOL)flag;

- (BOOL) intersectsSet: (NSSet*)otherSet;
- (BOOL) isEqualToSet: (NSSet*)other;
- (BOOL) isSubsetOfSet: (NSSet*)otherSet;

- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) makeObjectsPerformSelector: (SEL)aSelector;
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)argument;
#endif
- (id) member: (id)anObject;
- (NSEnumerator*) objectEnumerator;

#if OS_API_VERSION(100600, GS_API_LATEST)

DEFINE_BLOCK_TYPE(GSSetEnumeratorBlock, void, id, BOOL*);
/**
 * Enumerate over the collection using a given block.  The first argument is
 * the object.  The second argument is a pointer to a BOOL indicating
 * whether the enumeration should stop.  Setting this to YES will interupt
 * the enumeration.
 */
- (void) enumerateObjectsUsingBlock:(GSSetEnumeratorBlock)aBlock;

/**
 * Enumerate over the collection using the given block.  The first argument is
 * the object.  The second argument is a pointer to a BOOL indicating whether
 * the enumeration should stop.  Setting  this to YES will interrupt the
 * enumeration.
 *
 * The opts argument is a bitfield.  Setting the NSNSEnumerationConcurrent flag
 * specifies that it is thread-safe.  The NSEnumerationReverse bit specifies
 * that it should be enumerated in reverse order.
 */
- (void) enumerateObjectsWithOptions: (NSEnumerationOptions)opts
                          usingBlock: (GSSetEnumeratorBlock)aBlock;
#endif

#if OS_API_VERSION(100500,GS_API_LATEST) 
- (NSSet *) setByAddingObject: (id)anObject;
- (NSSet *) setByAddingObjectsFromSet: (NSSet *)other;
- (NSSet *) setByAddingObjectsFromArray: (NSArray *)other;
#endif
@end

@interface NSMutableSet: NSSet

+ (id) setWithCapacity: (NSUInteger)numItems;

- (void) addObject: (id)anObject;
- (void) addObjectsFromArray: (NSArray*)array;
- (id) initWithCapacity: (NSUInteger)numItems;
- (void) intersectSet: (NSSet*)other;
- (void) minusSet: (NSSet*)other;
- (void) removeAllObjects;
- (void) removeObject: (id)anObject;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void) setSet: (NSSet*)other;
#endif
- (void) unionSet: (NSSet*)other;
@end

@interface NSCountedSet : NSMutableSet

- (NSUInteger) countForObject: (id)anObject;

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/**
 * Utility methods for using a counted set to handle uniquing of objects.
 */
@interface NSCountedSet (GNU_Uniquing)
/**
 * <p>
 *   This method removes from the set all objects whose count is
 *   less than or equal to the specified value.
 * </p>
 * <p>
 *   This is useful where a counted set is used for uniquing objects.
 *   The set can be periodically purged of objects that have only
 *   been added once - and are therefore simply wasting space.
 * </p>
 */
- (void) purge: (NSInteger)level;

/**
 * <p>
 *   If the supplied object (or one equal to it as determined by
 *   the [NSObject-isEqual:] method) is already present in the set, the
 *   count for that object is incremented, the supplied object
 *   is released, and the object in the set is retained and returned.
 *   Otherwise, the supplied object is added to the set and returned.
 * </p>
 * <p> 
 *   This method is useful for uniquing objects - the init method of
 *   a class need simply end with -
 *   <code>
 *     return [myUniquingSet unique: self];
 *   </code>
 * </p>
 */
- (id) unique: (id) NS_CONSUMED anObject NS_RETURNS_RETAINED;
@end

/*
 * Functions for managing a global uniquing set.
 */

/*
 * GSUniquing() turns on/off the action of the GSUnique() function.
 * if uniquing is turned off, GSUnique() simply returns its argument.
 *
 */
void	GSUniquing(BOOL flag);	

/*
 * GSUnique() returns an object that is equal to the one passed to it.
 * If the returned object is not the same object as the object passed in,
 * the original object is released and the returned object is retained.
 * Thus, an -init method that wants to implement uniquing simply needs
 * to end with 'return GSUnique(self);'
 */
id	GSUnique(id NS_CONSUMED anObject) NS_RETURNS_RETAINED;

/*
 * Management functions -
 */

/*
 * GSUPurge() can be used to purge infrequently referenced objects from the
 * set by removing any objec whose count is less than or equal to that given.
 *
 */
void	GSUPurge(NSUInteger count);

/*
 * GSUSet() can be used to artificially set the count for a particular object
 * Setting the count to zero will remove the object from the global set.
 */
id	GSUSet(id anObject, NSUInteger count);

#endif	/* GS_API_NONE */

#if	defined(__cplusplus)
}
#endif

#endif
