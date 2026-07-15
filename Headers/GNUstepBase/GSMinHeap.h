/** Interface for GSMinHeap class

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald  <rfm@gnu.org>

   Date: July 2026
   
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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   AutogsdocSource: Additions/GSMinHeap.m
*/

#ifndef __GSMinHeap_h_GNUSTEP_BASE_INCLUDE
#define __GSMinHeap_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#import <Foundation/Foundation.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/* Comparator for GSMinHeap contents.  This is called on apirs of objects and
 * must return NSOrderedAscending if b is greater than a, NSOrderedDescending
 * if b is less than a, or NSOrderedSame if the two objects are to be ordered
 * identically.
 */
typedef NSComparisonResult (*GSMinHeapComparator)(id a, id b);

/** The GSMinHeap class provides a container for objects which are pushed into
 * it, from which objects can be popped out such that the popped object is
 * the lowest in the sort order provided by the comparator function.<br />
 * Popping the lowest object removes it, but you can also peek to see the
 * lowest object without removing it.<br />
 * This class is fast, but not thread-safe.<br />
 * NB. objects with the same value may be popped in any order.  You must not
 * assume that they will be popped in the same order in which they were pushed.
 */
GS_EXPORT_CLASS
@interface GSMinHeap : NSObject
{
  void	*_internal;
}

/** Returns YES if any objects in the heap matches obj using the -isEqual: method.
 */
- (BOOL) containsObject: (id)obj;

/** Returns YES if obj is present in the heap.
 */
- (BOOL) containsObjectIdenticalTo: (id)obj;

/** Returns the number of objects in the heap.
 */
- (NSUInteger) count;

/** Removes the first object from the heap.
 */
- (void) drop;

/** Removes all objects from the heap.
 */
- (void) empty;

/** Initialises a heap with the specified capacity and comparator.<br />
 * If cap is zero the initial capacity is one item.<br />
 * If cmp is NULL the -compare: method is used as a comparator.<br />
 * If there is insufficient memory, the method returns nil.
 */
- (instancetype) initWithCapacity: (size_t)cap
		    andComparator: (GSMinHeapComparator)cmp;

/** Discards the first object from the heap and returns the next object.
 * (equivalent to -drop followed by -peek).
 */
- (id) next;

/** Returns the first object on the heap or nil if it is empty
 */
- (id) peek;

/** Removes the first object from the heap and returns it.  Returns nil
 * if the heap was already empty.  The returned object is autoreleased.
 */
- (id) pop;

/** Adds obj to the heap and returns YES on success.  May return NO on failure
 * (if obj was nil or if there is insufficient memory for the heap to grow).
 * The heap takes ownership of (retains) obj on success, but not on failure.
 * It is possible to push the same object ot the heap more than once.
 */
- (BOOL) push: (id)obj;

/** Adds obj to the heap if (and only if) it is not already present.
 * Returns YES on success (the object was present or was added).
 * May return NO on failure (if obj was nil or if there is insufficient
 * memory for the heap to grow).
 * The heap takes ownership of (retains) obj on success if it was added.
 */
- (BOOL) pushIfNotPresent: (id)obj;

/** Removes all objects matching obj using the -isEqual: method.
 */
- (void) removeObject: (id)obj;

/** Removes all occurrences of obj from the heap.
 */
- (void) removeObjectIdenticalTo: (id)obj;

/** If obj (as determined by pointer equality) is present in the heap, removes duplicates
 * and are-establishes obj at its correct location on the heap.  Use this if obj is mutable
 * and has changed its value in the comparator ordering. <br />
 * Returns obj if it was present, nil otherwise.
 */
- (id) repositionObject: (id)obj;

@end


#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif	/* __GSMinHeap_h_GNUSTEP_BASE_INCLUDE */
