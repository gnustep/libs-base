/* NSMapTable interface for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Dec 13 00:05:02 EST 1994
 * Updated: Thu Mar 21 15:12:42 EST 1996
 * Serial: 96.03.21.05
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.  */ 

#ifndef __NSMapTable_h_GNUSTEP_BASE_INCLUDE
#define __NSMapTable_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <base/o_map.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Map table type. */
typedef o_map_t NSMapTable;

/* Private type for enumerating. */
typedef o_map_enumerator_t NSMapEnumerator;

/* Callback functions for a key. */
typedef struct _NSMapTableKeyCallBacks NSMapTableKeyCallBacks;
struct _NSMapTableKeyCallBacks
{
  /* Hashing function.  NOTE: Elements with equal values must
   * have equal hash function values. */
  unsigned (*hash)(NSMapTable *, const void *);

  /* Comparison function. */
  BOOL (*isEqual)(NSMapTable *, const void *, const void *);

  /* Retaining function called when adding elements to table. */
  void (*retain)(NSMapTable *, const void *);

  /* Releasing function called when a data element is
   * removed from the table. */
  void (*release)(NSMapTable *, void *);

  /* Description function. */
  NSString *(*describe)(NSMapTable *, const void *);

  /* Quantity that is not a key to the map table. */
  const void *notAKeyMarker;
};

/* Callback functions for a value. */
typedef struct _NSMapTableValueCallBacks NSMapTableValueCallBacks;
struct _NSMapTableValueCallBacks
{
  /* Retaining function called when adding elements to table. */
  void (*retain)(NSMapTable *, const void *);

  /* Releasing function called when a data element is
   * removed from the table. */
  void (*release)(NSMapTable *, void *);

  /* Description function. */
  NSString *(*describe)(NSMapTable *, const void *);
};

/* Quantities that are never map keys. */
#define NSNotAnIntMapKey     o_not_an_int_marker
#define NSNotAPointerMapKey  o_not_a_void_p_marker

/* For keys that are pointer-sized or smaller quantities. */
extern const NSMapTableKeyCallBacks NSIntMapKeyCallBacks;

/* For keys that are pointers not freed. */
extern const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks;

/* For keys that are pointers not freed, or 0. */
extern const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks;

/* For sets of objects without retaining and releasing. */
extern const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks;

/* For keys that are objects. */
extern const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks;

/* For keys that are pointers with transfer of ownership upon insertion. */
extern const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks;

/* For values that are pointer-sized quantities. */
extern const NSMapTableValueCallBacks NSIntMapValueCallBacks;

/* For values that are pointers not freed. */
extern const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;

/* For values that are objects. */
extern const NSMapTableValueCallBacks NSObjectMapValueCallBacks;

/* For values that are pointers with transfer of ownership upon insertion. */
extern const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;

/* This is for keeping track of information... */     
typedef struct _NSMT_extra _NSMT_extra_t;

struct _NSMT_extra
{
  NSMapTableKeyCallBacks keyCallBacks;
  NSMapTableValueCallBacks valueCallBacks;
};

/* These are to increase readabilty locally. */
typedef unsigned int (*NSMT_hash_func_t)(NSMapTable *, const void *);
typedef BOOL (*NSMT_is_equal_func_t)(NSMapTable *, const void *,
                                          const void *);
typedef void (*NSMT_retain_func_t)(NSMapTable *, const void *);
typedef void (*NSMT_release_func_t)(NSMapTable *, void *);
typedef NSString *(*NSMT_describe_func_t)(NSMapTable *, const void *);

/** Macros... **/

#define NSMT_EXTRA(T) \
  ((_NSMT_extra_t *)(o_map_extra((o_map_t *)(T))))

#define NSMT_KEY_CALLBACKS(T) \
  ((NSMT_EXTRA((T)))->keyCallBacks)

#define NSMT_VALUE_CALLBACKS(T) \
  ((NSMT_EXTRA((T)))->valueCallBacks)

#define NSMT_DESCRIBE_KEY(T, P) \
  NSMT_KEY_CALLBACKS((T)).describe((T), (P))

#define NSMT_DESCRIBE_VALUE(T, P) \
  NSMT_VALUE_CALLBACKS((T)).describe((T), (P))

/**** Function Prototypes ****************************************************/

/** Creating an NSMapTable... **/

/* Returns a (pointer to) an NSMapTable space for which is allocated
 * in the default zone.  If CAPACITY is small or 0, then the returned
 * table has a reasonable capacity. */
NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
                 NSMapTableValueCallBacks valueCallBacks,
                 unsigned int capacity);

/* Just like 'NSCreateMapTable()', but the returned map table is created
 * in the memory zone ZONE, rather than in the default zone.  (Of course,
 * if you send 0 for ZONE, then the map table will be created in the
 * default zone.) */
NSMapTable *
NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks,
                         NSMapTableValueCallBacks valueCallbacks,
                         unsigned int capacity,
                         NSZone *zone);

/* Returns a map table, space for which is allocated in ZONE, which
 * has (newly retained) copies of TABLE's keys and values.  As always,
 * if ZONE is 0, then the returned map table is allocated in the
 * default zone. */
NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone);

/** Freeing an NSMapTable... **/

/* Releases all the keys and values of TABLE (using the key and
 * value callbacks specified at the time of TABLE's creation),
 * and then proceeds to deallocate the space allocated for TABLE itself. */
void
NSFreeMapTable(NSMapTable *table);

/* Releases every key and value of TABLE, while preserving
 * TABLE's "capacity". */
void
NSResetMapTable(NSMapTable *table);

/** Comparing two NSMapTables... **/

/* Returns 'YES' if and only if every key of TABLE1 is a key
 * of TABLE2, and vice versa.  NOTE: This function only cares
 * about keys, never values. */
BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2);

/** Getting the number of items in an NSMapTable... **/

/* Returns the total number of key/value pairs in TABLE. */
unsigned int
NSCountMapTable(NSMapTable *table);

/** Retrieving items from an NSMapTable... **/

/* Returns 'YES' iff TABLE contains a key that is "equal" to KEY.
 * If so, then ORIGINALKEY is set to that key of TABLE, while
 * VALUE is set to the value to which it maps in TABLE. */
BOOL
NSMapMember(NSMapTable *table,
            const void *key,
            void **originalKey,
            void **value);

/* Returns the value to which TABLE maps KEY, if KEY is a
 * member of TABLE.  If not, then 0 (the only completely
 * forbidden value) is returned. */
void *
NSMapGet(NSMapTable *table, const void *key);

/* Returns an NSMapEnumerator structure (a pointer to) which
 * can be passed repeatedly to the function 'NSNextMapEnumeratorPair()'
 * to enumerate the key/value pairs of TABLE. */
NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table);

/* Return 'NO' if ENUMERATOR has completed its enumeration of
 * its map table's key/value pairs.  If not, then 'YES' is
 * returned and KEY and VALUE are set to the next key and
 * value (respectively) in ENUMERATOR's table. */
BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
                        void **key,
                        void **value);

/* Returns an NSArray which contains all of the keys of TABLE.
 * WARNING: Call this function only when the keys of TABLE
 * are objects. */
NSArray *
NSAllMapTableKeys(NSMapTable *table);

/* Returns an NSArray which contains all of the values of TABLE.
 * WARNING: Call this function only when the values of TABLE
 * are objects. */
NSArray *
NSAllMapTableValues(NSMapTable *table);

/** Adding an item to an NSMapTable... **/

/* Inserts the association KEY -> VALUE into the map table TABLE.
 * If KEY is already a key of TABLE, then its previously associated
 * value is released from TABLE, and VALUE is put in its place.
 * Raises an NSInvalidArgumentException if KEY is the "not a key
 * marker" for TABLE (as specified in its key callbacks). */
void
NSMapInsert(NSMapTable *table, const void *key, const void *value);

/* If KEY is already in TABLE, the pre-existing key is returned.
 * Otherwise, 0 is returned, and this is just like 'NSMapInsert()'. */
void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value);

/* Just like 'NSMapInsert()', with one exception: If KEY is already
 * in TABLE, then an NSInvalidArgumentException is raised. */
void
NSMapInsertKnownAbsent(NSMapTable *table,
                       const void *key,
                       const void *value);

/** Removing an item from an NSMapTable... **/

/* Releases KEY (and its associated value) from TABLE.  It is not
 * an error if KEY is not already in TABLE. */
void
NSMapRemove(NSMapTable *table, const void *key);

/** Getting an NSString representation of an NSMapTable **/

/* Returns an NSString which describes TABLE.  The returned string
 * is produced by iterating over the key/value pairs of TABLE,
 * appending the string "X = Y;\n", where X is the description of
 * the key, and Y is the description of the value (each obtained
 * from the respective callbacks, of course). */
NSString *NSStringFromMapTable (NSMapTable *table);

#endif /* __NSMapTable_h_GNUSTEP_BASE_INCLUDE */
