/* NSHashTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:54:09 EST 1994
 * Updated: Mon Mar 11 01:48:31 EST 1996
 * Serial: 96.03.11.06
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHashTable.h>
#include <gnustep/base/o_hash.h>
#include "NSCallBacks.h"

/**** Type, Constant, and Macro Definitions **********************************/

/* These are to increase readabilty locally. */
typedef unsigned int (*NSHT_hash_func_t)(NSHashTable *, const void *);
typedef BOOL (*NSHT_isEqual_func_t)(NSHashTable *, const void *, const void *);
typedef void (*NSHT_retain_func_t)(NSHashTable *, const void *);
typedef void (*NSHT_release_func_t)(NSHashTable *, void *);
typedef NSString *(*NSHT_describe_func_t)(NSHashTable *, const void *);

/** Standard NSHashTable callbacks... **/
     
const NSHashTableCallBacks NSIntHashCallBacks =
{
  (NSHT_hash_func_t) _NS_int_hash,
  (NSHT_isEqual_func_t) _NS_int_is_equal,
  (NSHT_retain_func_t) _NS_int_retain,
  (NSHT_release_func_t) _NS_int_release,
  (NSHT_describe_func_t) _NS_int_describe
};

const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_owned_void_p_retain,
  (NSHT_release_func_t) _NS_owned_void_p_release,
  (NSHT_describe_func_t) _NS_owned_void_p_describe
};

const NSHashTableCallBacks NSNonRetainedObjectsHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_non_retained_id_hash,
  (NSHT_isEqual_func_t) _NS_non_retained_id_is_equal,
  (NSHT_retain_func_t) _NS_non_retained_id_retain,
  (NSHT_release_func_t) _NS_non_retained_id_release,
  (NSHT_describe_func_t) _NS_non_retained_id_describe
};

const NSHashTableCallBacks NSObjectsHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_id_hash,
  (NSHT_isEqual_func_t) _NS_id_is_equal,
  (NSHT_retain_func_t) _NS_id_retain,
  (NSHT_release_func_t) _NS_id_release,
  (NSHT_describe_func_t) _NS_id_describe
};

const NSHashTableCallBacks NSOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_owned_void_p_retain,
  (NSHT_release_func_t) _NS_owned_void_p_release,
  (NSHT_describe_func_t) _NS_owned_void_p_describe
};

const NSHashTableCallBacks NSPointerToStructHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_int_p_hash,
  (NSHT_isEqual_func_t) _NS_int_p_is_equal,
  (NSHT_retain_func_t) _NS_int_p_retain,
  (NSHT_release_func_t) _NS_int_p_release,
  (NSHT_describe_func_t) _NS_int_p_describe
};

/** Macros... **/

#define NSHT_CALLBACKS(T) \
  (*((NSHashTableCallBacks *)(o_hash_extra((o_hash_t *)(T)))))

#define NSHT_DESCRIBE(T, P) \
  (NSHT_CALLBACKS((T))).describe((T), (P))

/** Dummy callbacks... **/

size_t
_NSHT_hash(const void *element, NSHashTable *table)
{
  return (NSHT_CALLBACKS(table)).hash((NSHashTable *)table, element);
}

int
_NSHT_compare(const void *element1, const void *element2, NSHashTable *table)
{
  return !((NSHT_CALLBACKS(table)).isEqual(table, element1, element2));
}

int
_NSHT_is_equal(const void *element1, const void *element2, NSHashTable *table)
{
  return (NSHT_CALLBACKS(table)).isEqual(table, element1, element2);
}

const void *
_NSHT_retain(const void *element, NSHashTable *table)
{
  /* OpenStep (unlike we) does not allow for the possibility of
   * substitution upon retaining. */
  (NSHT_CALLBACKS(table)).retain(table, element);
  return element;
}

void
_NSHT_release(void *element, NSHashTable *table)
{
  (NSHT_CALLBACKS(table)).release(table, element);
  return;
}

NSString *
_NSHT_describe(const void *element, const void *table)
{
  return ((NSHT_CALLBACKS(table)).describe((NSHashTable *)table, element));
}

/* These are wrappers for getting at the real callbacks. */
o_callbacks_t _NSHT_callbacks = 
{
  (o_hash_func_t) _NSHT_hash,
  (o_compare_func_t) _NSHT_compare,
  (o_is_equal_func_t) _NSHT_is_equal,
  (o_retain_func_t) _NSHT_retain,
  (o_release_func_t) _NSHT_release,
  (o_describe_func_t) _NSHT_describe,
  0 /* Note that OpenStep decrees that '0' is the (only) forbidden value. */
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
const void *
_NSHT_extra_retain (const NSHashTableCallBacks *callBacks, NSHashTable *table)
{
  /* A pointer to some new callbacks. */
  NSHashTableCallBacks *newCallBacks;

  /* Set aside space for our new callbacks in the right zone. */
  newCallBacks = (NSHashTableCallBacks *)NSZoneMalloc(o_hash_zone(table),
                                                 sizeof(NSHashTableCallBacks));

  /* FIXME: Check for an invalid pointer? */

  /* Copy CALLBACKS into NEWCALLBACKS. */
  *newCallBacks = *callBacks;

  /* Return our new callbacks. */
  return (const void *) newCallBacks;
}

void
_NSHT_extra_release(NSHashTableCallBacks *callBacks, NSHashTable *table)
{
  if (callBacks != 0)
    NSZoneFree(o_hash_zone(table), callBacks);

  return;
}

NSString *
_NSHT_extra_describe(NSHashTableCallBacks *callBacks, NSHashTable *table)
{
  /* FIXME: Code this. */
  return nil;
}

/* The idea here is that these callbacks ensure that the
 * NSHashTableCallbacks which are associated with a given NSHashTable
 * remain so associated throughout the life of the table and its copies. */
o_callbacks_t _NSHT_extra_callbacks = 
{
  (o_hash_func_t) o_non_owned_void_p_hash,
  (o_compare_func_t) o_non_owned_void_p_compare,
  (o_is_equal_func_t) o_non_owned_void_p_is_equal,
  (o_retain_func_t) _NSHT_extra_retain,
  (o_release_func_t) _NSHT_extra_release,
  (o_describe_func_t) _NSHT_extra_describe,
  0
};

/**** Function Implementations ***********************************************/

/** Creating NSHashTables **/

inline NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          unsigned int capacity,
                          NSZone *zone)
{
  NSHashTable *table;

  /* Build the core table.  See the above for the definitions of
   * the funny callbacks. */
  table = o_hash_with_zone_with_callbacks(zone, _NSHT_callbacks);

  /* Check to make sure our allocation has succeeded. */
  if (table != 0)
  {
    /* Resize TABLE to CAPACITY. */
    o_hash_resize(table, capacity);

    /* Add CALLBACKS to TABLE.  This takes care of everything for us. */
    o_hash_set_extra_callbacks(table, _NSHT_extra_callbacks);
    o_hash_set_extra(table, &callBacks);
  }

  /* Yah-hoo, kid! */
  return table;
}

NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
		  unsigned int capacity)
{
  return NSCreateHashTableWithZone(callBacks, capacity, 0);
}

/** Copying **/

NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone)
{
  /* Due to the wonders of modern structure technology,
   * everything we care about is automagically and safely destroyed. */
  return o_hash_copy_with_zone(table, zone);
}

/** Destroying **/

void
NSFreeHashTable(NSHashTable *table)
{
  /* Due to the wonders of modern technology,
   * everything we care about is automagically and safely destroyed. */
  o_hash_dealloc(table);
  return;
}

/** Resetting **/

void
NSResetHashTable(NSHashTable *table)
{
  o_hash_empty(table);
  return;
}

/** Comparing **/

BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2)
{
  return (o_hash_is_equal_to_hash(table1, table2) ? YES : NO);
}

/** Counting **/

unsigned int
NSCountHashTable(NSHashTable *table)
{
  return (unsigned int) o_hash_count(table);
}

/** Retrieving **/

void *
NSHashGet(NSHashTable *table, const void *pointer)
{
  /* Just make the call.  You know the number. */
  return (void *) o_hash_element(table, pointer);
}

NSArray *
NSAllHashTableObjects (NSHashTable *table)
{
  NSMutableArray *array;
  NSHashEnumerator enumerator;
  id element;

  /* FIXME: We should really be locking TABLE somehow, to insure
   * the thread-safeness of this method. */

  /* Get us a mutable array with plenty of space. */
  array = [NSMutableArray arrayWithCapacity:NSCountHashTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  while ((element = NSNextHashEnumeratorItem(&enumerator)) != 0)
    [array addObject:element];

  /* ARRAY is already autoreleased. */
  return (NSArray *) array;
}

/** Enumerating **/

NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table)
{
  return o_hash_enumerator_for_hash(table);
}

void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator)
{
  const void *element;

  /* Grab the next element. */
  o_hash_enumerator_next_element(enumerator, &element);

  /* Return ELEMENT. */
  return (void *) element;
}

/** Adding **/

void
NSHashInsert(NSHashTable *table, const void *pointer)
{
  /* Place POINTER in TABLE. */
  o_hash_add_element(table, pointer);

  /* OpenStep doesn't care for any return value, so... */
  return;
}

void
NSHashInsertKnownAbsent(NSHashTable *table, const void *element)
{
  if (o_hash_contains_element(table, element))
  {
    /* FIXME: I should make this give the user/programmer more
     * information.  Not difficult to do, just something for a later
     * date. */
    [NSException raise:NSInvalidArgumentException
                 format:@"NSHashTable: illegal reinsertion of: %s",
                 [NSHT_DESCRIBE(table, element) cStringNoCopy]];
  }
  else
  {
    o_hash_add_element_known_absent(table, element);
  }

  /* OpenStep doesn't care for any return value, so... */
  return;
}

void *
NSHashInsertIfAbsent(NSHashTable *table, const void *element)
{
  const void *old_element;

  /* Place ELEMENT in TABLE. */
  old_element = o_hash_add_element_if_absent(table, element);

  /* Return the version of ELEMENT in TABLE now. */
  return (void *) old_element;
}

/** Removing **/

void
NSHashRemove(NSHashTable *table, const void *element)
{
  /* Remove ELEMENT from TABLE. */
  o_hash_remove_element(table, element);

  /* OpenStep doesn't care about return values here, so... */
  return;
}

/** Describing **/

NSString *
NSStringFromHashTable(NSHashTable *table)
{
  NSMutableString *string;
  NSHashEnumerator enumerator;
  const void *pointer;

  /* This will be our string. */
  string = [NSMutableString stringWithCapacity:0];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  /* Iterate over the elements of TABLE, appending the description of
   * each to the mutable string STRING. */
  while ((pointer = NSNextHashEnumeratorItem(&enumerator)) != 0)
    [string appendFormat:@"%s;\n", 
	    [NSHT_DESCRIBE(table, pointer) cStringNoCopy]];

  /* STRING is already autoreleased. */
  return (NSString *) string;
}
