/** Interface for Tree classes

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

   AutogsdocSource: Additions/GSTree.m
*/

#ifndef __GSTree_h_GNUSTEP_BASE_INCLUDE
#define __GSTree_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#import <Foundation/Foundation.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/** GSTree instances can work with wrappers (where objects of arbitrary
 * classes are held within tree nodes), or with intrusive storage where
 * only objects of classes incorporating tree node information into each
 * instance can be held in the tree.<br />
 * An intrusive storage tree will be substantially faster, but each object
 * can only be in one tree at a time and the tree can only hold objects of
 * particular classes.
 */
typedef NS_ENUM(uint8_t, GSTreeStorage)
{
  GSTreeStorageWrapper,
  GSTreeStorageIntrusive
};

/** Each tree must be configured with a Ccomparator function capable of
 * comparing objects of all classes that will be held in the tree.
 */
typedef NSComparisonResult
  (*GSTreeCompareFunction)(id lhs, id rhs, void *context);

/** A tree configuration specifies how it will operate.  If the comparator
 * is NULL it is replaced with a function which will use the -compare:
 * selector.
 */
typedef struct
{
  GSTreeStorage 	storageType;	/** wrapper or intrusive operation */
  NSUInteger 		nodeOffset;	/** used only for intrusive mode */
  GSTreeCompareFunction comparator;	/** comparator function for nodes */
  void 			*context;	/** context for comparator */
} GSTreeConfiguration;

@interface GSTree : NSObject

- (instancetype) initWithConfiguration: (const GSTreeConfiguration *)conf;
- (void) insertObject: (id)object;
- (void) removeObject: (id)object;
- (id) findObject: (id)object;

@property(nonatomic, readonly) NSUInteger count;
@end

typedef struct
{
  uintptr_t	_private[4];
} GSTreeNodeStorage;

#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif	/* __GSTree_h_GNUSTEP_BASE_INCLUDE */
