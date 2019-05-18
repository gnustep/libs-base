
/** Interface for NSOrderedSet, NSMutableOrderedSet for GNUStep
   Copyright (C) 2019 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Created: May 17 2019

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
#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSOrderedSet.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSException.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"

@implementation NSOrderedSet

// NSCoding
- (instancetype) initWithCoder: (NSCoder *)coder
{
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

- (id) copyWithZone: (NSZone*)zone
{
  return nil;
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  return nil;
}

// NSFastEnumeration 
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  return 0;
}

// class methods
+ (instancetype) orderedSet
{
  return nil;
}

+ (instancetype) orderedSetWithArray:(NSArray *)objects
{
  return nil;
}

+ (instancetype) orderedSetWithArray:(NSArray *)objects
                               range: (NSRange)range
                           copyItems:(BOOL)flag
{
  return nil;
}

+ (instancetype) orderedSetWithObject:(GS_GENERIC_TYPE(ElementT))anObject
{
  return nil;
}

+ (instancetype) orderedSetWithObjects:(GS_GENERIC_TYPE(ElementT))firstObject, ...
{
  return nil;
}

+ (instancetype) orderedSetWithObjects:(const GS_GENERIC_TYPE(ElementT)[])objects
                                 count:(NSUInteger) count
{
  return nil;
}

+ (instancetype) orderedSetWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
{
  return nil;
}

+ (instancetype) orderedSetWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
                                    count:(NSUInteger) count
{
  return nil;
}

+ (instancetype) orderedSetWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
{
  return nil;
}

+ (instancetype) orderedSetWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
                         copyItems:(BOOL)flag
{
  return nil;
}

// instance methods
- (instancetype) initWithArray:(NSArray *)other
{
  return nil;
}

- (instancetype) initWithArray:(NSArray *)other copyItems:(BOOL)flag
{
  return nil;
}

- (instancetype) initWithArray:(NSArray *)other
                         range:(NSRange)range
                     copyItems:(BOOL)flag
{
  return nil;
}

- (instancetype) initWithObject:(id)object
{
  return nil;
}

- (instancetype) initWithObjects:(GS_GENERIC_TYPE(ElementT))firstObject, ...
{
  return nil;
}

- (instancetype) initWithObjects:(const GS_GENERIC_TYPE(ElementT)[])objects
                           count:(NSUInteger)count
{
  return nil;
}

- (instancetype) initWithOrderedSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
{
  return nil;
}

- (instancetype) initWithOrderedSet:(NSArray *)objects
                          copyItems:(BOOL)flag
{
  return nil;
}

- (instancetype) initWithOrderedSet:(NSArray *)objects
                              range: (NSRange)range
                          copyItems:(BOOL)flag
{
  return nil;
}

- (instancetype) initWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
{
  return nil;
}

- (instancetype) initWithSet:(GS_GENERIC_CLASS(NSSet, ElementT)*)aSet copyItems:(BOOL)flag
{
  return nil;
}

- (instancetype) init
{
  return nil;
}

- (NSUInteger) count
{
  return 0;
}

- (BOOL)containsObject:(GS_GENERIC_TYPE(ElementT))anObject
{
  return NO;
}

- (void) enumerateObjectsAtIndexes:(NSIndexSet *)indexSet
                           options:(NSEnumerationOptions)opts
                        usingBlock:(GSEnumeratorBlock)aBlock
{
}

- (void) enumerateObjectsUsingBlock: (GSEnumeratorBlock)aBlock
{
}

- (void) enumerateObjectsWithOptions:(NSEnumerationOptions)opts
                          usingBlock:(GSEnumeratorBlock)aBlock
{
}

- (id) firstObject
{
  return nil;
}

- (id) lastObject
{
  return nil;
}

- (id) objectAtIndex: (NSUInteger)index
{
  return nil;
}

- (id) objectAtIndexedSubscript: (NSUInteger)index
{
  return nil;
}

- (NSArray *) objectsAtIndexes: (NSIndexSet *)indexes
{
  return nil;
}

    
- (NSUInteger) indexOfObject:(id)object
{
  return 0;
}

- (NSUInteger) indexOfObject: (id)key
               inSortedRange: (NSRange)range
                     options: (NSBinarySearchingOptions)options
             usingComparator: (NSComparator)comparator
{
  return 0;
}

- (NSUInteger) indexOfObjectAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate
{
  return 0;
}

- (NSUInteger) indexOfObjectPassingTest:(GSPredicateBlock)predicate
{
  return 0;
}

- (NSUInteger) indexOfObjectWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate
{
  return 0;
}

- (NSIndexSet *) indexesOfObjectsAtIndexes:(NSIndexSet *)indexSet
                              options:(NSEnumerationOptions)opts
                          passingTest:(GSPredicateBlock)predicate
{
  return nil;
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(GSPredicateBlock)predicate
{
  return nil;
}

- (NSIndexSet *) indexesOfObjectWithOptions:(NSEnumerationOptions)opts
                            passingTest:(GSPredicateBlock)predicate
{
  return nil;
}

- (NSEnumerator *) objectEnumerator
{
  return nil;
}

- (NSEnumerator *) reverseObjectEnumerator
{
  return nil;
}

- (NSOrderedSet *)reversedOrderedSet
{
  return nil;
}

- (void) getObjects: (__unsafe_unretained id[])aBuffer
              range: (NSRange)aRange
{
}

// Key value coding support
- (void) setValue: (id)value forKey: (NSString*)key
{
}

- (id) valueForKey: (NSString*)key
{
  return nil;
}

// Key-Value Observing Support
/*
- addObserver:forKeyPath:options:context:
- removeObserver:forKeyPath:
- removeObserver:forKeyPath:context:
*/
  
// Comparing Sets
- (BOOL) isEqualToOrderedSet: (NSOrderedSet *)aSet
{
  return NO;
}
  
// Set operations
- (BOOL) intersectsOrderedSet: (NSOrderedSet *)aSet
{
  return NO;
}

- (BOOL) intersectsSet: (NSOrderedSet *)aSet
{
  return NO;
}

- (BOOL) isSubsetOfOrderedSet: (NSOrderedSet *)aSet
{
  return NO;
}

- (BOOL) isSubsetOfSet:(NSOrderedSet *)aSet
{
  return NO;
}

// Creating a Sorted Array
- (NSArray *) sortedArrayUsingDescriptors:(NSArray *)sortDescriptors
{
  return nil;
}

- (NSArray *) sortedArrayUsingComparator: (NSComparator)comparator
{
  return nil;
}

- (NSArray *)
    sortedArrayWithOptions: (NSSortOptions)options
           usingComparator: (NSComparator)comparator
{
  return nil;
}

// Filtering Ordered Sets
- (NSOrderedSet *)filteredOrderedSetUsingPredicate: (NSPredicate *)predicate
{
  return nil;
}

// Describing a set
- (NSString *) description
{
  return @"";
}

- (NSString *) descriptionWithLocale: (NSLocale *)locale
{
  return @"";
}

- (NSString*) descriptionWithLocale: (id)locale indent: (BOOL)flag
{
  return @"";
}
@end

// Mutable Ordered Set
@implementation NSMutableOrderedSet
// Creating a Mutable Ordered Set
+ (instancetype)orderedSetWithCapacity: (NSUInteger)capacity
{
  return nil;
}

- (instancetype)initWithCapacity: (NSUInteger)capacity
{
  return nil;
}

- (instancetype) init
{
  return nil;
}

- (void)addObject:(id)anObject
{
}

- (void)addObjects:(const id[])objects count:(NSUInteger)count
{
}

- (void)addObjectsFromArray:(NSArray *)otherArray
{
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index
{
}

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index
{
}

- (void)insertObjects:(NSArray *)array atIndexes:(NSIndexSet *)indexes
{
}

- (void)removeObject:(id)object
{
}

- (void)removeObjectAtIndex:(NSUInteger)integer
{
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
}

- (void)removeObjectsInArray:(NSArray *)otherArray
{
}

- (void)removeObjectsInRange:(NSRange *)range
{
}

- (void)removeAllObjects
{
}

- (void)replaceObjectAtIndex:(NSUInteger)index
                  withObject:(id)object
{
}

- (void) replaceObjectsAtIndexes: (NSIndexSet *)indexes
                     withObjects: (NSArray *)objects
{
}

- (void) replaceObjectsInRange:(NSRange)range
                   withObjects:(const id[])objects
                         count: (NSUInteger)count
{
}

- (void)setObject:(id)object atIndex:(NSUInteger)index
{
}

- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)index
{
}

- (void) exchangeObjectAtIndex:(NSUInteger)index withObjectAtIndex:(NSUInteger)otherIndex
{
}

- (void)filterUsingPredicate:(NSPredicate *)predicate
{
}

- (void) sortUsingDescriptors:(NSArray *)descriptors
{
}

- (void) sortUsingComparator: (NSComparator)comparator
{
}

- (void) sortWithOptions: (NSSortOptions)options
         usingComparator: (NSComparator)comparator
{
}

- (void) sortRange: (NSRange)range
           options:(NSSortOptions)options
   usingComparator: (NSComparator)comparator
{
}

- (void) intersectOrderedSet:(NSOrderedSet *)aSet
{
}

- (void) intersectSet:(NSOrderedSet *)aSet
{
}

- (void) minusOrderedSet:(NSOrderedSet *)aSet
{
}

- (void) minusSet:(NSOrderedSet *)aSet
{
}

- (void) unionOrderedSet:(NSOrderedSet *)aSet
{
}

- (void) unionSet:(NSOrderedSet *)aSet
{
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  return nil;
}
@end
