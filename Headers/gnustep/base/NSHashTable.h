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
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */ 

#ifndef __NSHashTable_h_GNUSTEP_BASE_INCLUDE
#define __NSHashTable_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

/**** Type, Constant, and Macro Definitions **********************************/

/**
 * Hash table type ... an opaque pointer to a data structure.
 */
typedef void* NSHashTable;

/**
 * Type for enumerating.<br />
 * NB. Implementation detail ... in GNUstep the layout <strong>must</strong>
 * correspond to that used by the GSIMap macros.
 */
typedef struct { void *map; void *node; size_t bucket; } NSHashEnumerator;

/** Callback functions. <br />*/
typedef struct _NSHashTableCallBacks
{
  /** hash() ... Hashing function. NOTE: Elements with equal values must have
   * equal hash function values. <br />*/
  unsigned int (*hash)(NSHashTable *, const void *);

  /** isEqual() ... Comparison function. <br />*/
  BOOL (*isEqual)(NSHashTable *, const void *, const void *);

  /** retain() ... Retaining function called when adding elements
   * to the table. <br />*/
  void (*retain)(NSHashTable *, const void *);

  /** release() ... Releasing function called when a data element is
   * removed from the table. <br />*/
  void (*release)(NSHashTable *, void *);

  /** describe() ... Description function. <br />*/
  NSString *(*describe)(NSHashTable *, const void *);
} NSHashTableCallBacks;

GS_EXPORT const NSHashTableCallBacks NSIntHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks;
GS_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks;

GS_EXPORT NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
                  unsigned int capacity);

GS_EXPORT NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          unsigned int capacity,
                          NSZone *zone);

GS_EXPORT NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone);

GS_EXPORT void
NSFreeHashTable(NSHashTable *table);

GS_EXPORT void
NSResetHashTable(NSHashTable *table);

GS_EXPORT BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);

GS_EXPORT unsigned int
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

#endif /* __NSHashTable_h_GNUSTEP_BASE_INCLUDE */
