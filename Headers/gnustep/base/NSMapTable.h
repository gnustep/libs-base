/* NSMapTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Dec 13 00:05:02 EST 1994
 * Updated: Sat Feb 10 15:55:51 EST 1996
 * Serial: 96.02.10.02
 * 
 * This file is part of the GNU Objective C Class Library.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 
 */ 

#ifndef __NSMapTable_h_OBJECTS_INCLUDE
#define __NSMaptable_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <objects/map.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef objects_map_t NSMapTable;
typedef objects_map_enumerator_t NSMapEnumerator;
typedef struct _NSMapTableKeyCallBacks NSMapTableKeyCallBacks;
typedef struct _NSMapTableValueCallBacks NSMapTableValueCallBacks;

struct _NSMapTableKeyCallBacks
{
  unsigned (*hash) (NSMapTable *, const void *);
  BOOL (*isEqual) (NSMapTable *, const void *, const void *);
  void (*retain) (NSMapTable *, const void *);
  void (*release) (NSMapTable *, void *);
  NSString *(*describe) (NSMapTable *, const void *);
  const void *notAKeyMarker;
};

struct _NSMapTableValueCallBacks
{
  void (*retain) (NSMapTable *, const void *);
  void (*release) (NSMapTable *, void *);
  NSString *(*describe) (NSMapTable *, const void *);
};

/* FIXME: What to do here?  These can't be right. */
#define NSNotAnIntMapKey     0
#define NSNotAPointerMapKey  NULL

extern const NSMapTableKeyCallBacks NSIntMapKeyCallBacks;
extern const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks;
extern const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks;
extern const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks;
extern const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks;
extern const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks;

extern const NSMapTableValueCallBacks NSIntMapValueCallBacks;
extern const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
extern const NSMapTableValueCallBacks NSObjectMapValueCallBacks;
extern const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;

/**** Function Prototypes ****************************************************/

/** Creating an NSMapTable **/

NSMapTable *NSCreateMapTable (NSMapTableKeyCallBacks keyCallBacks,
                              NSMapTableValueCallBacks valueCallBacks,
                              unsigned int capacity);

NSMapTable *NSCreateMapTableWithZone (NSMapTableKeyCallBacks keyCallBacks,
                                      NSMapTableValueCallBacks valueCallbacks,
                                      unsigned int capacity,
                                      NSZone *zone);

NSMapTable *NSCopyMapTableWithZone (NSMapTable *table,
                                    NSZone *zone);

/** Freeing an NSMapTable **/

void NSFreeMapTable (NSMapTable *table);

void NSResetMapTable (NSMapTable *table);

/** Comparing two NSMapTables **/

BOOL NSCompareMapTables (NSMapTable *table1, NSMapTable *table2);

/** Getting the number of items in an NSMapTable **/

unsigned int NSCountMapTable (NSMapTable *table);

/** Retrieving items from an NSMapTable **/

BOOL NSMapMember (NSMapTable *table, const void *key,
                  void **originalKey, void **value);

void *NSMapGet (NSMapTable *table, const void *key);

NSMapEnumerator NSEnumerateMapTable (NSMapTable *table);

BOOL NSNextMapEnumeratorPair (NSMapEnumerator *enumerator,
                              void **key,
                              void **value);

NSArray *NSAllMapTableKeys (NSMapTable *table);

NSArray *NSAllMapTableValues (NSMapTable *table);

/** Adding an item to an NSMapTable **/

void NSMapInsert (NSMapTable *table, const void *key, const void *value);

void *NSMapInsertIfAbsent (NSMapTable *table,
                           const void *key,
                           const void *value);

void NSMapInsertKnownAbsent (NSMapTable *table,
                             const void *key,
                             const void *value);

/** Removing an item from an NSMapTable **/

void NSMapRemove (NSMapTable *table, const void *key);

/** Getting an NSString representation of an NSMapTable **/

NSString *NSStringFromMapTable (NSMapTable *table);

#endif /* __NSMapTable_h_OBJECTS_INCLUDE */

