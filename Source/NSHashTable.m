/* NSHashTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:54:09 EST 1994
 * Updated: Mon Feb 12 22:55:15 EST 1996
 * Serial: 96.02.12.01
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

/**** Included Headers *******************************************************/

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHashTable.h>
#include <NSCallBacks.h>
#include <Foundation/atoz.h>
#include <objects/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* These are to increase readabilty locally. */
typedef unsigned int (*NSHT_hash_func_t)(NSHashTable *, const void *);
typedef BOOL (*NSHT_isEqual_func_t)(NSHashTable *, const void *, const void *);
typedef void (*NSHT_retain_func_t)(NSHashTable *, const void *);
typedef void (*NSHT_release_func_t)(NSHashTable *, void *);
typedef NSString *(*NSHT_describe_func_t)(NSHashTable *, const void *);

/** Standard NSHashTable callbacks **/
     
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

/** Macros **/

#define NSHT_ZONE(T) \
  ((NSZone *)((objects_hash_allocs((objects_hash_t *)(T))).user_data))

#define NSHT_CALLBACKS(T) \
  (*((NSHashTableCallBacks *)(objects_hash_extra((objects_hash_t *)(T)))))

#define NSHT_DESCRIBE(T, P) \
  NSHT_CALLBACKS((T)).describe((T), (P))

/** Dummy callbacks **/

size_t
_NSHT_hash (const void *element, const void *table)
{
  return (NSHT_CALLBACKS(table)).hash ((NSHashTable *)table, element);
}

int
_NSHT_compare (const void *element1, const void *element2, const void *table)
{
  return !((NSHT_CALLBACKS(table)).isEqual ((NSHashTable *)table,
					    element1,
					    element2));
}

int
_NSHT_is_equal (const void *element1, const void *element2, const void *table)
{
  return (NSHT_CALLBACKS(table)).isEqual ((NSHashTable *) table,
					  element1,
					  element2);
}

void *
_NSHT_retain (const void *element, const void *table)
{
  (NSHT_CALLBACKS(table)).retain ((NSHashTable *)table, element);
  return (void*) element;
}

void
_NSHT_release (void *element, const void *table)
{
  (NSHT_CALLBACKS(table)).release ((NSHashTable*)table, (void*)element);
  return;
}

/* These are wrappers for getting at the real callbacks. */
const objects_callbacks_t _NSHT_callbacks = 
{
  _NSHT_hash,
  _NSHT_compare,
  _NSHT_is_equal,
  _NSHT_retain,
  _NSHT_release,
  0,
  0 
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
void *
_NSHT_extra_retain (const void *extra, const void *table)
{
  /* Pick out the callbacks in EXTRA. */
  NSHashTableCallBacks *callBacks = (NSHashTableCallBacks *)(extra);

  /* Find our zone. */
  NSZone *zone = NSHT_ZONE(table);

  /* A pointer to some new callbacks. */
  NSHashTableCallBacks *newCallBacks;

  /* Set aside space for our new callbacks in the right zone. */
  newCallBacks = (NSHashTableCallBacks *)
    NSZoneMalloc(zone,
		 sizeof(NSHashTableCallBacks));

  /* Copy CALLBACKS into NEWCALLBACKS. */
  *newCallBacks = *callBacks;

  /* Return our new EXTRA. */
  return (void*) extra;
}

void
_NSHT_extra_release (void *extra, const void *table)
{
  NSZone *zone = NSHT_ZONE(table);

  if (extra != NULL)
    NSZoneFree(zone, (void*)extra);

  return;
}

/* The idea here is that these callbacks ensure that the
 * NSHashTableCallbacks which are associated with a given NSHashTable
 * remain so associated throughout the life of the table and its copies. */
objects_callbacks_t _NSHT_extra_callbacks = 
{
  (objects_hash_func_t) objects_void_p_hash,
  (objects_compare_func_t) objects_void_p_compare,
  (objects_is_equal_func_t) objects_void_p_is_equal,
  _NSHT_extra_retain,
  _NSHT_extra_release,
  0,
  0
};

/**** Function Implementations ***********************************************/

/** Creating NSHashTables **/

NSHashTable *
NSCreateHashTableWithZone (NSHashTableCallBacks callBacks,
			   unsigned int capacity,
			   NSZone *zone)
{
  NSHashTable *table;
  objects_callbacks_t callbacks;
  objects_allocs_t allocs;

  /* These callbacks just look in the TABLE's extra and uses the
   * callbacks there.  See above for precise definitions. */
  callbacks = _NSHT_callbacks;
  allocs = objects_allocs_for_zone(zone);

  /* Then we build the table. */
  table = objects_hash_with_allocs_with_callbacks(allocs, callbacks);

  if (table != NULL)
  {
    const void *extra;

    /* Resize TABLE to CAPACITY. */
    objects_hash_resize(table, capacity);

    /* Set aside space for the NSHashTableExtra. */
    extra = &callBacks;

    /* Add EXTRA to TABLE.  This takes care of everything for us. */
    objects_hash_set_extra_callbacks(table, _NSHT_extra_callbacks);
    objects_hash_set_extra(table, extra);
  }

  /* Wah-hoo! */
  return table;
}

NSHashTable *
NSCreateHashTable (NSHashTableCallBacks callBacks,
		   unsigned int capacity)
{
  return NSCreateHashTableWithZone(callBacks, capacity, NULL);
}

/** Copying **/

NSHashTable *
NSCopyHashTableWithZone (NSHashTable *table, NSZone *zone)
{
  objects_allocs_t allocs;
  NSHashTable *new_table;

  /* Due to the wonders of modern Libfn technology, everything we care
   * about is automagically transferred. */
  allocs = objects_allocs_for_zone(zone);
  new_table = objects_hash_copy_with_allocs(table, allocs);

  return new_table;
}

/** Destroying **/

void
NSFreeHashTable (NSHashTable *table)
{
  /* Due to the wonders of modern Libobjects structure technology,
   * everything we care about is automagically and safely destroyed. */
  objects_hash_dealloc(table);
  return;
}

/** Resetting **/

void
NSResetHashTable (NSHashTable *table)
{
  objects_hash_empty(table);
  return;
}

/** Comparing **/

BOOL
NSCompareHashTables (NSHashTable *table1, NSHashTable *table2)
{
  return (objects_hash_is_equal_to_hash(table1, table2) ? YES : NO);
}

/** Counting **/

unsigned int
NSCountHashTable (NSHashTable *table)
{
  return (unsigned int) objects_hash_count(table);
}

/** Retrieving **/

void *
NSHashGet (NSHashTable *table, const void *pointer)
{
  /* Just make the call.  You know the number. */
  return (void*) objects_hash_element (table, pointer);
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

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [array autorelease];
}

/** Enumerating **/

NSHashEnumerator
NSEnumerateHashTable (NSHashTable *table)
{
  return objects_hash_enumerator (table);
}

void *
NSNextHashEnumeratorItem (NSHashEnumerator *enumerator)
{
  const void *element;

  /* Grab the next element. */
  objects_hash_enumerator_next_element (enumerator, &element);

  /* Return ELEMENT. */
  return (void*) element;
}

/** Adding **/

void
NSHashInsert (NSHashTable *table, const void *pointer)
{
  /* Place POINTER in TABLE. */
  objects_hash_add_element (table, pointer);

  /* OpenStep doesn't care for any return value, so... */
  return;
}

void
NSHashInsertKnownAbsent (NSHashTable *table, const void *element)
{
  if (objects_hash_contains_element(table, element))
  {
    /* FIXME: I should make this give the user/programmer more
     * information.  Not difficult to do, just something for a later
     * date. */
    [NSException raise:NSInvalidArgumentException
                 format:@"Attempted reinsertion of \"%@\" into a hash table.",
                 NSHT_DESCRIBE(table, element)];
  }
  else
  {
    objects_hash_add_element_known_absent(table, element);
  }

  return;
}

void *
NSHashInsertIfAbsent (NSHashTable *table, const void *element)
{
  const void *old_element;

  /* Place ELEMENT in TABLE. */
  old_element = objects_hash_add_element_if_absent(table, element);

  /* Return the version of ELEMENT in TABLE now. */
  return (void*) old_element;
}

/** Removing **/

void
NSHashRemove (NSHashTable *table, const void *element)
{
  /* Remove ELEMENT from TABLE. */
  objects_hash_remove_element(table, element);

  /* OpenStep doesn't care about return values here, so... */
  return;
}

/** Describing **/

/* FIXME: Make this nicer.  I don't know what is desired here, though.
 * If somebody has a clear idea of what this string should look like,
 * please tell me, and I'll make it happen. */
NSString *
NSStringFromHashTable (NSHashTable *table)
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
    [string appendFormat:@"%@;", NSHT_DESCRIBE(table, pointer)];

  /* Note that this string'll need to be `retain'ed. */
  /* FIXME: Should I `autorelease' STRING?  I think so. */
  return (NSString *)[string autorelease];
}
