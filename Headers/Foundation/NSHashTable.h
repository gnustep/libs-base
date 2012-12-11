/* NSHashTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996, 1997, 2002  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:56:03 EST 1994
 * Updated: Thu Mar 21 15:13:46 EST 1996
 * Serial: 96.03.21.06
 * Modified by: Richard Frith-Macdonald <rfm@gnu.org>
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, 02111 USA.
 */ 

#ifndef __NSHashTable_h_GNUSTEP_BASE_INCLUDE
#define __NSHashTable_h_GNUSTEP_BASE_INCLUDE 1
#import	<GNUstepBase/GSVersionMacros.h>

/**** Included Headers *******************************************************/

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSPointerFunctions.h>
#import	<Foundation/NSString.h>

#if	defined(__cplusplus)
extern "C" {
#endif


@class NSArray, NSSet, NSHashTable;

/**** Type, Constant, and Macro Definitions **********************************/

enum {
  NSHashTableStrongMemory
    = NSPointerFunctionsStrongMemory,
  NSHashTableZeroingWeakMemory
    = NSPointerFunctionsZeroingWeakMemory,
  NSHashTableCopyIn
    = NSPointerFunctionsCopyIn,
  NSHashTableObjectPointerPersonality
    = NSPointerFunctionsObjectPointerPersonality,
  NSHashTableWeakMemory
    = NSPointerFunctionsWeakMemory
};

typedef NSUInteger NSHashTableOptions;

@interface NSHashTable : NSObject <NSCopying, NSCoding, NSFastEnumeration>

+ (id) hashTableWithOptions: (NSPointerFunctionsOptions)options;

+ (id) hashTableWithWeakObjects;
/**
 * Creates a hash table that uses zeroing weak references (either using the
 * automatic reference counting or garbage collection mechanism, depending on
 * which mode this framework is compiled in) so that objects are removed when
 * their last other reference disappears.
 */
+ (id) weakObjectsHashTable;


- (id) initWithOptions: (NSPointerFunctionsOptions)options
	      capacity: (NSUInteger)initialCapacity;

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
		       capacity: (NSUInteger)initialCapacity;

/** Adds the object to the receiver.
 */
- (void) addObject: (id)object;

/** Returns an array containing all objects in the receiver.
 */
- (NSArray*) allObjects;

/** Returns any objct from the receiver, or nil if the receiver contains no
 * objects.
 */
- (id) anyObject;

/** Returns YES if the receiver contains an item equal to anObject, or NO
 * otherwise.
 */
- (BOOL) containsObject: (id)anObject;

/** Return the number of items atored in the receiver.
 */
- (NSUInteger) count;

/** Removes from the receiver any items which are not also present in 'other'.
 */
- (void) intersectHashTable: (NSHashTable*)other;

/** Returns YES if the receiver and 'other' contain any items in common.
 */
- (BOOL) intersectsHashTable: (NSHashTable*)other;

/** Returns YES if the receiver and 'other' contain equal sets of items.
 */
- (BOOL) isEqualToHashTable: (NSHashTable*)other;

/** Returns YES fi all the items in the receiver are also present in 'other'
 */
- (BOOL) isSubsetOfHashTable: (NSHashTable*)other;

/** Returns an item stored in the receiver which is equal to the supplied
 * object argument, or nil if no matchi is found.
 */
- (id) member: (id)object;

/** Removes from the receivr all those items which are prsent in both
 * the receiver and in 'other'.
 */
- (void) minusHashTable: (NSHashTable*)other;

/** Return an enumerator for the receiver.
 */
- (NSEnumerator*) objectEnumerator;

/** Return an NSPointerFunctions value describing the functions used by the
 * receiver to handle its contents.
 */
- (NSPointerFunctions*) pointerFunctions;

/** Removes all objects.
 */
- (void) removeAllObjects;

/** Remove the object (or any equal object) from the receiver.
 */
- (void) removeObject: (id)object;

/** Returns a set containing all the objects in the receiver.
 */
- (NSSet*) setRepresentation; 

/** Adds to the receiver thse items present in 'other' which were
 * not present in the receiver.
 */
- (void) unionHashTable: (NSHashTable*)other;


@end


/**
 * Type for enumerating.<br />
 * NB. Implementation detail ... in GNUstep the layout <strong>must</strong>
 * correspond to that used by the GSIMap macros.
 */
typedef struct { void *map; void *node; size_t bucket; } NSHashEnumerator;

/** Callback functions for an NSHashTable.  See NSCreateHashTable() . <br />*/
typedef struct _NSHashTableCallBacks
{
  /** <code>NSUInteger (*hash)(NSHashTable *, const void *)</code> ...
   *  Hashing function.  NOTE: Elements with equal values must have equal hash
   *  function values.  The default if NULL uses the pointer addresses
   *  directly. <br/>*/
  NSUInteger (*hash)(NSHashTable *, const void *);

  /** <code>BOOL (*isEqual)(NSHashTable *, const void *, const void *)</code>
   *  ... Comparison function.  The default if NULL uses '<code>==</code>'.
   *  <br/>*/
  BOOL (*isEqual)(NSHashTable *, const void *, const void *);

  /** <code>void (*retain)(NSHashTable *, const void *)</code> ...
   *  Retaining function called when adding elements to the table.
   *  The default if NULL is a no-op (no reference counting). <br/> */
  void (*retain)(NSHashTable *, const void *);

  /** <code>void (*release)(NSHashTable *, void *)</code> ... Releasing
   *  function called when a data element is removed from the table.
   *  The default if NULL is a no-op (no reference counting).<br/>*/
  void (*release)(NSHashTable *, void *);

  /** <code>NSString *(*describe)(NSHashTable *, const void *)</code> ...
   *  Description function.  The default if NULL prints boilerplate. <br /> */
  NSString *(*describe)(NSHashTable *, const void *);
} NSHashTableCallBacks;

GS_EXPORT const NSHashTableCallBacks NSIntegerHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSIntHashCallBacks; /*DEPRECATED*/
GS_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks;

GS_EXPORT NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
                  NSUInteger capacity);

GS_EXPORT NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          NSUInteger capacity,
                          NSZone *zone);

GS_EXPORT NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone);

GS_EXPORT void
NSFreeHashTable(NSHashTable *table);

GS_EXPORT void
NSResetHashTable(NSHashTable *table);

GS_EXPORT BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);

GS_EXPORT NSUInteger
NSCountHashTable(NSHashTable *table);

GS_EXPORT void *
NSHashGet(NSHashTable *table, const void *element);

GS_EXPORT NSArray *
NSAllHashTableObjects(NSHashTable *table);

GS_EXPORT void
NSEndHashTableEnumeration(NSHashEnumerator *enumerator);

GS_EXPORT NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table);

GS_EXPORT void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);

GS_EXPORT void
NSHashInsert(NSHashTable *table, const void *element);

GS_EXPORT void
NSHashInsertKnownAbsent(NSHashTable *table, const void *element);

GS_EXPORT void *
NSHashInsertIfAbsent(NSHashTable *table, const void *element);

GS_EXPORT void
NSHashRemove(NSHashTable *table, const void *element);

GS_EXPORT NSString *
NSStringFromHashTable(NSHashTable *table);

#if	defined(__cplusplus)
}
#endif

#endif /* __NSHashTable_h_GNUSTEP_BASE_INCLUDE */
