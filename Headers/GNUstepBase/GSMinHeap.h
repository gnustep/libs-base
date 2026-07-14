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

typedef NSComparisonResult (*GSMinHeapComparator)(id a, id b);

@interface GSMinHeap : NSObject
{
  void	*_internal;
}
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

/** Returns the first object on the heap or nil if it is empty.
 */
- (id) peek;

/** Removes the first object from the heap and returns it.  Returns nil
 * if the heap was already empty.
 */
- (id) pop;

/** Adds obj to the heap and returns YES on success.  May return NO on failure
 * (of obj was nil or if there is insufficient memory for the heap to grow).
 */
- (BOOL) push: (id)obj;
@end


#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif	/* __GSMinHeap_h_GNUSTEP_BASE_INCLUDE */
