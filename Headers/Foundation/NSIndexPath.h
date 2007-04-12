/** Interface for NSIndexPath for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Created: Feb 2006
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   AutogsdocSource: NSIndexPath.m

   */ 

#ifndef _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#define _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(100400,GS_API_LATEST) && GS_API_VERSION(010200,GS_API_LATEST)

/**
 * Instances of this class represent a series of indexes into a hierarchy
 * of arrays.<br />
 * Each instance is a unique shared object.
 */
@interface	NSIndexPath : NSObject <NSCopying, NSCoding>
{
  unsigned	_hash;
  unsigned	_length;
  unsigned	*_indexes;
}

/**
 * Return a path containing the single value anIndex.
 */
+ (id) indexPathWithIndex: (unsigned)anIndex;

/**
 * Return a path containing all the indexes in the supplied array.
 */
+ (id) indexPathWithIndexes: (unsigned*)indexes length: (unsigned)length;

/**
 * Compares other with the receiver.<br />
 * Returns NSOrderedSame if the two are identical.<br />
 * Returns NSOrderedAscending if other is less than the receiver in a
 * depth-wise comparison.<br />
 * Returns NSOrderedDescending otherwise.
 */
- (NSComparisonResult) compare: (NSIndexPath*)other;

/**
 * Copies all index values from the receiver into aBuffer.
 */
- (void) getIndexes: (unsigned*)aBuffer;

/**
 * Return the index at the specified position or NSNotFound if there
 * is no index at the specified position.
 */
- (unsigned) indexAtPosition: (unsigned)position;

/**
 * Return path formed by adding anIndex to the receiver.
 */
- (NSIndexPath *) indexPathByAddingIndex: (unsigned)anIndex;

/**
 * Return path formed by removing the last index from the receiver.
 */
- (NSIndexPath *) indexPathByRemovingLastIndex;

/** <init />
 * Returns the shared instance containing the specified index, creating it
 * and destroying the receiver if necessary.
 */
- (id) initWithIndex: (unsigned)anIndex;

/** <init />
 * Returns the shared instance containing the specified index array,
 * creating it and destroying the receiver if necessary.
 */
- (id) initWithIndexes: (unsigned*)indexes length: (unsigned)length;

/**
 * Returns the number of index values present in the receiver.
 */
- (unsigned) length;

@end

#endif

#if	defined(__cplusplus)
}
#endif

#endif
