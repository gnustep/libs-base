
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
