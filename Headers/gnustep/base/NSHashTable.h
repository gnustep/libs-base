/* NSHashTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996, 1997  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:56:03 EST 1994
 * Updated: Thu Mar 21 15:13:46 EST 1996
 * Serial: 96.03.21.06
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

#ifndef __NSHashTable_h_GNUSTEP_BASE_INCLUDE
#define __NSHashTable_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <base/o_hash.h>

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
GS_EXPORT const NSHashTableCallBacks NSIntHashCallBacks;

/* For sets of pointers hashed by address. */
GS_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;

/* For sets of objects without retaining and releasing. */
GS_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks;

/* For sets of objects; similar to NSSet. */
GS_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks;

/* For sets of pointers with transfer of ownership upon insertion. */
GS_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks;

/* For sets of pointers to structs when the first field of the
 * struct is the size of an int. */
GS_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks;

/* These are to increase readabilty locally. */
typedef unsigned int (*NSHT_hash_func_t)(NSHashTable *, const void *);
typedef BOOL (*NSHT_isEqual_func_t)(NSHashTable *, const void *, const void *);
typedef void (*NSHT_retain_func_t)(NSHashTable *, const void *);
typedef void (*NSHT_release_func_t)(NSHashTable *, void *);
typedef NSString *(*NSHT_describe_func_t)(NSHashTable *, const void *);

/**** Function Prototypes ****************************************************/

/** Creating an NSHashTable... **/

/* Returns a (pointer to) an NSHashTable space for which is allocated
 * in the default zone.  If CAPACITY is small or 0, then the returned
 * table has a reasonable (but still small) capacity. */
GS_EXPORT NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
                  unsigned int capacity);

/* Just like 'NSCreateHashTable()', but the returned hash table is created
 * in the memory zone ZONE, rather than in the default zone.  (Of course,
 * if you send 0 for ZONE, then the hash table will be created in the
 * default zone.) */
GS_EXPORT NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          unsigned int capacity,
                          NSZone *zone);

/* Returns a hash table, space for which is allocated in ZONE, which
 * has (newly retained) copies of TABLE's keys and values.  As always,
 * if ZONE is 0, then the returned hash table is allocated in the
 * default zone. */
GS_EXPORT NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone);

/** Freeing an NSHashTable... **/

/* Releases all the keys and values of TABLE (using the callbacks
 * specified at the time of TABLE's creation), and then proceeds
 * to deallocate the space allocated for TABLE itself. */
GS_EXPORT void
NSFreeHashTable(NSHashTable *table);

/* Releases every element of TABLE, while preserving
 * TABLE's "capacity". */
GS_EXPORT void
NSResetHashTable(NSHashTable *table);

/** Comparing two NSHashTables... **/

/* Returns 'YES' if and only if every element of TABLE1 is an element
 * of TABLE2, and vice versa. */
GS_EXPORT BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);

/** Getting the number of items in an NSHashTable... **/

/* Returns the total number of elements in TABLE. */
GS_EXPORT unsigned int
NSCountHashTable(NSHashTable *table);

/** Retrieving items from an NSHashTable... **/

/* Returns the element of TABLE equal to POINTER, if POINTER is a
 * member of TABLE.  If not, then 0 (the only completely
 * forbidden element) is returned. */
GS_EXPORT void *
NSHashGet(NSHashTable *table, const void *pointer);

/* Returns an NSArray which contains all of the elements of TABLE.
 * WARNING: Call this function only when the elements of TABLE
 * are objects. */
GS_EXPORT NSArray *
NSAllHashTableObjects(NSHashTable *table);

/* Returns an NSHashEnumerator structure (a pointer to) which
 * can be passed repeatedly to the function 'NSNextHashEnumeratorItem()'
 * to enumerate the elements of TABLE. */
GS_EXPORT NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table);

/* Return 0 if ENUMERATOR has completed its enumeration of
 * its hash table's elements.  If not, then the next element is
 * returned. */
GS_EXPORT void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);

/** Adding an item to an NSHashTable... **/

/* Inserts the item POINTER into the hash table TABLE.
 * If POINTER is already an element of TABLE, then its previously
 * incarnation is released from TABLE, and POINTER is put in its place.
 * Raises an NSInvalidArgumentException if POINTER is 0. */
GS_EXPORT void
NSHashInsert(NSHashTable *table, const void *pointer);

/* Just like 'NSHashInsert()', with one exception: If POINTER is already
 * in TABLE, then an NSInvalidArgumentException is raised. */
GS_EXPORT void
NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer);

/* If POINTER is already in TABLE, the pre-existing item is returned.
 * Otherwise, 0 is returned, and this is just like 'NSHashInsert()'. */
GS_EXPORT void *
NSHashInsertIfAbsent(NSHashTable *table, const void *pointer);

/** Removing an item from an NSHashTable... **/

/* Releases POINTER from TABLE.  It is not
 * an error if POINTER is not already in TABLE. */
GS_EXPORT void
NSHashRemove(NSHashTable *table, const void *pointer);

/** Getting an NSString representation of an NSHashTable... **/

/* Returns an NSString which describes TABLE.  The returned string
 * is produced by iterating over the elements of TABLE,
 * appending the string "X;\n", where X is the description of
 * the element (obtained from the callbacks, of course). */
GS_EXPORT NSString *
NSStringFromHashTable(NSHashTable *table);

#endif /* __NSHashTable_h_GNUSTEP_BASE_INCLUDE */
