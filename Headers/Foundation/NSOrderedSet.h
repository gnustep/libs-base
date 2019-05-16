
/** Interface for NSOrderedSet, NSMutableOrderedSet for GNUStep
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

*/

#ifndef _NSOrderedSet_h_GNUSTEP_BASE_INCLUDE
#define _NSOrderedSet_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <GNUstepBase/GSBlocks.h>

#if	defined(__cplusplus)
extern "C" {
#endif
  
@class GS_GENERIC_CLASS(NSArray, ElementT);
@class GS_GENERIC_CLASS(NSEnumerator, ElementT);
@class GS_GENERIC_CLASS(NSSet, ElementT);
@class GS_GENERIC_CLASS(NSDictionary, KeyT:id<NSCopying>, ValT);
@class NSString;

@interface GS_GENERIC_CLASS(NSOrderedSet, __covariant ElementT) : NSObject <NSCoding,
  NSCopying,
  NSMutableCopying,
  NSFastEnumeration>

// class methods
+ (instancetype) orderedSet;
+ (instancetype) orderedSetWithArray:(GS_GENERIC_CLASS(NSArray, ElementT)*)objects;
+ (instancetype) orderedSetWithArray:(GS_GENERIC_CLASS(NSArray, ElementT)*)objects
                               range: (NSRange)range
                           copyItems:(BOOL)flag;
+ (instancetype) orderedSetWithObject:(GS_GENERIC_TYPE(ElementT))anObject;
+ (instancetype) orderedSetWithObjects:(GS_GENERIC_TYPE(ElementT))firstObject, ...;
+ (instancetype) orderedSetWithObjects:(const GS_GENERIC_TYPE(ElementT)[])objects
                                 count:(NSUInteger) count;
+ (instancetype) orderedSetWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;
+ (instancetype) orderedSetWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
                                    count:(NSUInteger) count;
+ (instancetype) orderedSetWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;
+ (instancetype) orderedSetWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
                         copyItems:(BOOL)flag;

// instance methods
- (instancetype) initWithArray:(GS_GENERIC_CLASS(NSArray, ElementT)*)other;
- (instancetype) initWithArray:(GS_GENERIC_CLASS(NSArray, ElementT)*)other copyItems:(BOOL)flag;
- (instancetype) initWithArray:(GS_GENERIC_CLASS(NSArray, ElementT)*)other
                         range:(NSRange)range
                     copyItems:(BOOL)flag;
  - (instancetype) initWithObject:(id)object;
- (instancetype) initWithObjects:(GS_GENERIC_TYPE(ElementT))firstObject, ...;
- (instancetype) initWithObjects:(const GS_GENERIC_TYPE(ElementT)[])objects
                           count:(NSUInteger)count;
- (instancetype) initWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;
- (instancetype) initWithOrderedSet:(GS_GENERIC_CLASS(NSArray, ElementT)*)objects
                          copyItems:(BOOL)flag
- (instancetype) initWithOrderedSet:(GS_GENERIC_CLASS(NSArray, ElementT)*)objects
                              range: (NSRange)range
                          copyItems:(BOOL)flag;
- (instancetype) initWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;
- (instancetype) initWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet copyItems:(BOOL)flag;
  - (instancetype) init;
- (NSUInteger) count;
- (BOOL)containsObject:(GS_GENERIC_TYPE(ElementT))anObject;
- (void) enumerateObjectsAtIndexes:(NSIndexSet)indexSet
                           options:(NSEnumerationOptions)opts
                        usingBlock:(GSEnumeratorBlock)aBlock;
- (void) enumerateObjectsUsingBlock: (GSEnumeratorBlock)aBlock;
- (void) enumerateObjectsWithOptions:(NSEnumerationOptions)opts
                          usingBlock:(GSEnumeratorBlock)aBlock;
- (GS_GENERIC_TYPE(ElementT)) firstObject;
- (GS_GENERIC_TYPE(ElementT)) lastObject;
- (GS_GENERIC_TYPE(ElementT)) objectAtIndex: (NSUInteger)index;
- (GS_GENERIC_TYPE(ElementT)) objectAtIndexedSubscript:
- (GS_GENERIC_CLASS(NSArray, ElementT) *) objectsAtIndexes:
  (NSIndexSet *)indexes;
- (NSUInteger) indexOfObject:(GS_GENERIC_TYPE(ElementT))
- (NSUInteger) indexOfObject: (id)key
               inSortedRange: (NSRange)range
                     options: (NSBinarySearchingOptions)options
             usingComparator: (NSComparator)comparator;

- (NSUInteger) indexOfObjectAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate;
- (NSUInteger) indexOfObjectPassingTest:(GSPredicateBlock)predicate;
- (NSUInteger) indexOfObjectWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate;
- (NSIndexSet *) indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate;

- (NSIndexSet *)indexesOfObjectsPassingTest:(GSPredicateBlock)predicate;
- (NSIndexSet *) indexesOfObjectWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate;
- (GS_GENERIC_CLASS(NSEnumerator, ElementT)*) objectEnumerator;
- (GS_GENERIC_CLASS(NSEnumerator, ElementT)*) reverseObjectEnumerator;
- (NSOrderedSet *)reversedOrderedSet
- (void) getObjects: (__unsafe_unretained GS_GENERIC_TYPE(ElementT)[])aBuffer
              range: (NSRange)aRange;

// Key value coding support
- (void) setValue: (GS_GENERIC_TYPE(ElementT))value forKey: (NSString*)key;
- (GS_GENERIC_TYPE(ElementT)) valueForKey: (NSString*)key; 

// Key-Value Observing Support
- addObserver:forKeyPath:options:context:
- removeObserver:forKeyPath:
- removeObserver:forKeyPath:context:

// Comparing Sets
- (BOOL) isEqualToOrderedSet: (NSOrderedSet *)aSet;
  
// Set operations
- (BOOL) intersectsOrderedSet: (NSOrderedSet *)aSet;
- (BOOL) intersectsSet: (NSOrderedSet *)aSet;
- (BOOL) isSubsetOfOrderedSet: (NSOrderedSet *)aSet;
- (BOOL) isSubsetOfSet:(NSOrderedSet *)aSet;

// Creating a Sorted Array
- (GS_GENERIC_CLASS(NSArray, ElementT) *) sortedArrayUsingDescriptors:(NSArray *)sortDescriptors;
- (GS_GENERIC_CLASS(NSArray, ElementT) *) sortedArrayUsingComparator:
    (NSComparator)comparator;
- (GS_GENERIC_CLASS(NSArray, ElementT) *)
    sortedArrayWithOptions: (NSSortOptions)options
           usingComparator: (NSComparator)comparator;

// Filtering Ordered Sets
- (NSOrderedSet *)filteredOrderedSetUsingPredicate: (NSPredicate *)predicate;

// Describing a set
- (NSString *) description;
- (NSString *) descriptionWithLocale: (NSLocale *)locale;
- (NSString*) descriptionWithLocale: (id)locale indent: (BOOL)flag;

@end

// Mutable Ordered Set
@interface GS_GENERIC_CLASS(NSMutableOrderedSet, __covariant ElementT) : NSOrderedSet
									 /*
Creating a Mutable Ordered Set
+ orderedSetWithCapacity:
Creates and returns an mutable ordered set with a given initial capacity.

- initWithCapacity:
Returns an initialized mutable ordered set with a given initial capacity.

- init
Initializes a newly allocated mutable ordered set.

Adding, Removing, and Reordering Entries
- addObject:
Appends a given object to the end of the mutable ordered set, if it is not already a member.

- addObjects:count:
Appends the given number of objects from a given C array to the end of the mutable ordered set.

- addObjectsFromArray:
Appends to the end of the mutable ordered set each object contained in a given array that is not already a member.

- insertObject:atIndex:
Inserts the given object at the specified index of the mutable ordered set, if it is not already a member.

- setObject:atIndexedSubscript:
Replaces the given object at the specified index of the mutable ordered set.

- insertObjects:atIndexes:
Inserts the objects in the array at the specified indexes.

- removeObject:
Removes a given object from the mutable ordered set.

- removeObjectAtIndex:
Removes a the object at the specified index from the mutable ordered set.

- removeObjectsAtIndexes:
Removes the objects at the specified indexes from the mutable ordered set.

- removeObjectsInArray:
Removes the objects in the array from the mutable ordered set.

- removeObjectsInRange:
Removes from the mutable ordered set each of the objects within a given range.

- removeAllObjects
Removes all the objects from the mutable ordered set.

- replaceObjectAtIndex:withObject:
Replaces the object at the specified index with the new object.

- replaceObjectsAtIndexes:withObjects:
Replaces the objects at the specified indexes with the new objects.

- replaceObjectsInRange:withObjects:count:
Replaces the objects in the receiving mutable ordered set at the range with the specified number of objects from a given C array.

- setObject:atIndex:
Appends or replaces the object at the specified index.

- moveObjectsAtIndexes:toIndex:
Moves the objects at the specified indexes to the new location.

- exchangeObjectAtIndex:withObjectAtIndex:
Exchanges the object at the specified index with the object at the other index.

- filterUsingPredicate:
Evaluates a given predicate against the mutable ordered set’s content and leaves only objects that match.

Sorting Entries
- sortUsingDescriptors:
Sorts the receiving ordered set using a given array of sort descriptors.

- sortUsingComparator:
Sorts the mutable ordered set using the comparison method specified by the comparator block.

- sortWithOptions:usingComparator:
Sorts the mutable ordered set using the specified options and the comparison method specified by a given comparator block.

- sortRange:options:usingComparator:
Sorts the specified range of the mutable ordered set using the specified options and the comparison method specified by a given comparator block.

Combining and Recombining Entries
- intersectOrderedSet:
Removes from the receiving ordered set each object that isn’t a member of another ordered set.

- intersectSet:
Removes from the receiving ordered set each object that isn’t a member of another set.

- minusOrderedSet:
Removes each object in another given ordered set from the receiving mutable ordered set, if present.

- minusSet:
Removes each object in another given set from the receiving mutable ordered set, if present.

- unionOrderedSet:
Adds each object in another given ordered set to the receiving mutable ordered set, if not present.

- unionSet:
Adds each object in another given set to the receiving mutable ordered set, if not present.

Initializers
- initWithCoder:
*/

@end
