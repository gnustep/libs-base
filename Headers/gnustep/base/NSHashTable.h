/* NSHashTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:56:03 EST 1994
 * Updated: Thu Mar 21 15:13:46 EST 1996
 * Serial: 96.03.21.06
 * 
 * This file is part of the Gnustep Base Library.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

#ifndef __NSHashTable_h_GNUSTEP_BASE_INCLUDE
#define __NSHashTable_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <gnustep/base/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Hash table type. */
typedef o_hash_t NSHashTable;

/* Private type for enumerating. */
typedef o_hash_enumerator_t NSHashEnumerator;

/* Callback functions. */
typedef struct _NSHashTableCallBacks NSHashTableCallBacks;
struct _NSHashTableCallBacks
{
  /* Hashing function. NOTE: Elements with equal values must have
   * equal hash function values. */
  unsigned int (*hash)(NSHashTable *, const void *);

  /* Comparison function. */
  BOOL (*isEqual)(NSHashTable *, const void *, const void *);

  /* Retaining function called when adding elements to table. */
  void (*retain)(NSHashTable *, const void *);

  /* Releasing function called when a data element is
   * removed from the table. */
  void (*release)(NSHashTable *, void *);

  /* Description function. */
  NSString *(*describe)(NSHashTable *, const void *);
};

/* For sets of pointer-sized or smaller quantities. */
extern const NSHashTableCallBacks NSIntHashCallBacks;

/* For sets of pointers hashed by address. */
extern const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;

/* For sets of objects without retaining and releasing. */
extern const NSHashTableCallBacks NSNonRetainedObjectsHashCallBacks;

/* For sets of objects; similar to NSSet. */
extern const NSHashTableCallBacks NSObjectsHashCallBacks;

/* For sets of pointers with transfer of ownership upon insertion. */
extern const NSHashTableCallBacks NSOwnedPointerHashCallBacks;

/* For sets of pointers to structs when the first field of the
 * struct is the size of an int. */
extern const NSHashTableCallBacks NSPointerToStructHashCallBacks;

/**** Function Prototypes ****************************************************/

/** Creating an NSHashTable... **/

/* Returns a (pointer to) an NSHashTable space for which is allocated
 * in the default zone.  If CAPACITY is small or 0, then the returned
 * table has a reasonable (but still small) capacity. */
NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
                  unsigned int capacity);

/* Just like 'NSCreateHashTable()', but the returned hash table is created
 * in the memory zone ZONE, rather than in the default zone.  (Of course,
 * if you send 0 for ZONE, then the hash table will be created in the
 * default zone.) */
NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          unsigned int capacity,
                          NSZone *zone);

/* Returns a hash table, space for which is allocated in ZONE, which
 * has (newly retained) copies of TABLE's keys and values.  As always,
 * if ZONE is 0, then the returned hash table is allocated in the
 * default zone. */
NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone);

/** Freeing an NSHashTable... **/

/* Releases all the keys and values of TABLE (using the callbacks
 * specified at the time of TABLE's creation), and then proceeds
 * to deallocate the space allocated for TABLE itself. */
void
NSFreeHashTable(NSHashTable *table);

/* Releases every element of TABLE, while preserving
 * TABLE's "capacity". */
void
NSResetHashTable(NSHashTable *table);

/** Comparing two NSHashTables... **/

/* Returns 'YES' if and only if every element of TABLE1 is an element
 * of TABLE2, and vice versa. */
BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);

/** Getting the number of items in an NSHashTable... **/

/* Returns the total number of elements in TABLE. */
unsigned int
NSCountHashTable(NSHashTable *table);

/** Retrieving items from an NSHashTable... **/

/* Returns the element of TABLE equal to POINTER, if POINTER is a
 * member of TABLE.  If not, then 0 (the only completely
 * forbidden element) is returned. */
void *
NSHashGet(NSHashTable *table, const void *pointer);

/* Returns an NSArray which contains all of the elements of TABLE.
 * WARNING: Call this function only when the elements of TABLE
 * are objects. */
NSArray *
NSAllHashTableObjects(NSHashTable *table);

/* Returns an NSHashEnumerator structure (a pointer to) which
 * can be passed repeatedly to the function 'NSNextHashEnumeratorItem()'
 * to enumerate the elements of TABLE. */
NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table);

/* Return 0 if ENUMERATOR has completed its enumeration of
 * its hash table's elements.  If not, then the next element is
 * returned. */
void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);

/** Adding an item to an NSHashTable... **/

/* Inserts the item POINTER into the hash table TABLE.
 * If POINTER is already an element of TABLE, then its previously
 * incarnation is released from TABLE, and POINTER is put in its place.
 * Raises an NSInvalidArgumentException if POINTER is 0. */
void
NSHashInsert(NSHashTable *table, const void *pointer);

/* Just like 'NSHashInsert()', with one exception: If POINTER is already
 * in TABLE, then an NSInvalidArgumentException is raised. */
void
NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer);

/* If POINTER is already in TABLE, the pre-existing item is returned.
 * Otherwise, 0 is returned, and this is just like 'NSHashInsert()'. */
void *
NSHashInsertIfAbsent(NSHashTable *table, const void *pointer);

/** Removing an item from an NSHashTable... **/

/* Releases POINTER from TABLE.  It is not
 * an error if POINTER is not already in TABLE. */
void
NSHashRemove(NSHashTable *table, const void *pointer);

/** Getting an NSString representation of an NSHashTable... **/

/* Returns an NSString which describes TABLE.  The returned string
 * is produced by iterating over the elements of TABLE,
 * appending the string "X;\n", where X is the description of
 * the element (obtained from the callbacks, of course). */
NSString *
NSStringFromHashTable(NSHashTable *table);

#endif /* __NSHashTable_h_GNUSTEP_BASE_INCLUDE */
