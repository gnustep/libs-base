/* NSMapTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996, 2002  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Dec 13 00:05:02 EST 1994
 * Updated: Thu Mar 21 15:12:42 EST 1996
 * Serial: 96.03.21.05
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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02111 USA.
 */ 

#ifndef __NSMapTable_h_GNUSTEP_BASE_INCLUDE
#define __NSMapTable_h_GNUSTEP_BASE_INCLUDE 1
#import	<GNUstepBase/GSVersionMacros.h>

/**** Included Headers *******************************************************/

#import	<Foundation/NSObject.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSArray.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/**** Type, Constant, and Macro Definitions **********************************/

/**
 * Map table type ... an opaque pointer to a data structure.
 */
typedef void *NSMapTable;

/**
 * Type for enumerating.<br />
 * NB. Implementation detail ... in GNUstep the layout <strong>must</strong>
 * correspond to that used by the GSIMap macros.
 */
typedef struct { void *map; void *node; size_t bucket; } NSMapEnumerator;

/**
 * Callback functions for a key.
 */
typedef struct _NSMapTableKeyCallBacks
{
  /*
   * Hashing function. Must not modify the key.<br />
   * NOTE: Elements with equal values must
   * have equal hash function values.
   */
  unsigned (*hash)(NSMapTable *, const void *);

  /**
   * Comparison function.  Must not modify either key.
   */
  BOOL (*isEqual)(NSMapTable *, const void *, const void *);

  /**
   * Retaining function called when adding elements to table.<br />
   * Notionally this must not modify the key (the key may not
   * actually have a retain count, or the retain count may be stored
   * externally to the key, but in practice this often actually
   * changes a counter within the key).
   */
  void (*retain)(NSMapTable *, const void *);

  /**
   * Releasing function called when a data element is
   * removed from the table.  This may decrease a retain count or may
   * actually destroy the key.
   */
  void (*release)(NSMapTable *, void *);

  /**
   * Description function. Generates a string describing the key
   * and does not modify the key itself.
   */ 
  NSString *(*describe)(NSMapTable *, const void *);

  /**
   * Quantity that is not a key to the map table.
   */
  const void *notAKeyMarker;
} NSMapTableKeyCallBacks;

/**
 * Callback functions for a value.
 */
typedef struct _NSMapTableValueCallBacks NSMapTableValueCallBacks;
struct _NSMapTableValueCallBacks
{
  /**
   * Retaining function called when adding elements to table.<br />
   * Notionally this must not modify the element (the element may not
   * actually have a retain count, or the retain count may be stored
   * externally to the element, but in practice this often actually
   * changes a counter within the element).
   */
  void (*retain)(NSMapTable *, const void *);

  /**
   * Releasing function called when a data element is
   * removed from the table.  This may decrease a retain count or may
   * actually destroy the element.
   */
  void (*release)(NSMapTable *, void *);

  /**
   * Description function. Generates a string describing the element
   * and does not modify the element itself.
   */ 
  NSString *(*describe)(NSMapTable *, const void *);
};

/* Quantities that are never map keys. */
#define NSNotAnIntMapKey     ((const void *)0x80000000)
#define NSNotAPointerMapKey  ((const void *)0xffffffff)

GS_EXPORT const NSMapTableKeyCallBacks NSIntMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSIntMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSObjectMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;

GS_EXPORT NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
                 NSMapTableValueCallBacks valueCallBacks,
                 unsigned int capacity);

GS_EXPORT NSMapTable *
NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks,
                         NSMapTableValueCallBacks valueCallBacks,
                         unsigned int capacity,
                         NSZone *zone);

GS_EXPORT NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone);

GS_EXPORT void
NSFreeMapTable(NSMapTable *table);

GS_EXPORT void
NSResetMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2);

GS_EXPORT unsigned int
NSCountMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSMapMember(NSMapTable *table,
            const void *key,
            void **originalKey,
            void **value);

GS_EXPORT void *
NSMapGet(NSMapTable *table, const void *key);

GS_EXPORT void
NSEndMapTableEnumeration(NSMapEnumerator *enumerator);

GS_EXPORT NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
                        void **key,
                        void **value);

GS_EXPORT NSArray *
NSAllMapTableKeys(NSMapTable *table);

GS_EXPORT NSArray *
NSAllMapTableValues(NSMapTable *table);

GS_EXPORT void
NSMapInsert(NSMapTable *table, const void *key, const void *value);

GS_EXPORT void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value);

GS_EXPORT void
NSMapInsertKnownAbsent(NSMapTable *table,
                       const void *key,
                       const void *value);

GS_EXPORT void
NSMapRemove(NSMapTable *table, const void *key);

GS_EXPORT NSString *NSStringFromMapTable (NSMapTable *table);

#if	defined(__cplusplus)
}
#endif

#endif /* __NSMapTable_h_GNUSTEP_BASE_INCLUDE */
