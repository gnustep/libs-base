/* NSHashTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:56:03 EST 1994
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

#ifndef __NSHashTable_h_OBJECTS_INCLUDE
#define __NSHashTable_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <objects/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef objects_hash_t NSHashTable;
typedef objects_hash_enumerator_t NSHashEnumerator;
typedef struct _NSHashTableCallBacks NSHashTableCallBacks;

struct _NSHashTableCallBacks
{
  unsigned int (*hash) (NSHashTable *, const void *);
  BOOL (*isEqual) (NSHashTable *, const void *, const void *);
  void (*retain) (NSHashTable *, const void *);
  void (*release) (NSHashTable *, void *);
  NSString *(*describe) (NSHashTable *, const void *);
};

extern const NSHashTableCallBacks NSIntHashCallBacks;
extern const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;
extern const NSHashTableCallBacks NSNonRetainedObjectsHashCallBacks;
extern const NSHashTableCallBacks NSObjectsHashCallBacks;
extern const NSHashTableCallBacks NSOwnedPointerHashCallBacks;
extern const NSHashTableCallBacks NSPointerToStructHashCallBacks;

/**** Function Prototypes ****************************************************/

/** Creating an NSHashTable **/

NSHashTable *NSCreateHashTable (NSHashTableCallBacks callBacks,
                                unsigned int capacity);

NSHashTable *NSCreateHashTableWithZone (NSHashTableCallBacks callBacks,
                                        unsigned int capacity,
                                        NSZone *zone);

NSHashTable *NSCopyHashTableWithZone (NSHashTable *table, NSZone *zone);

/** Freeing an NSHashTable **/

void NSFreeHashTable (NSHashTable * table);

void NSResetHashTable (NSHashTable * table);

/** Comparing two NSHashTables **/

BOOL NSCompareHashTables (NSHashTable *table1, NSHashTable *table2);

/** Getting the number of items in an NSHashTable **/

unsigned int NSCountHashTable (NSHashTable *table);

/** Retrieving items from an NSHashTable **/

void *NSHashGet (NSHashTable *table, const void *pointer);

NSArray *NSAllHashTableObjects (NSHashTable *table);

NSHashEnumerator NSEnumerateHashTable (NSHashTable *table);

void *NSNextHashEnumeratorItem (NSHashEnumerator *enumerator);

/** Adding an item to an NSHashTable **/

void NSHashInsert (NSHashTable *table, const void *pointer);

void NSHashInsertKnownAbsent (NSHashTable *table, const void *pointer);

void *NSHashInsertIfAbsent (NSHashTable *table, const void *pointer);

/** Removing an item from an NSHashTable **/

void NSHashRemove (NSHashTable *table, const void *pointer);

/** Getting an NSString representation of an NSHashTable **/

NSString *NSStringFromHashTable (NSHashTable *table);

#endif /* __NSHashTable_h_OBJECTS_INCLUDE */
