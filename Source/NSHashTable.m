/* NSHashTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:54:09 EST 1994
 * Updated: Sat Feb 10 15:59:11 EST 1996
 * Serial: 96.02.10.01
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
#include <Foundation/atoz.h>
#include <objects/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* These are to increase readabilty locally. */
typedef unsigned int (*NSHT_hash_func_t)(NSHashTable *, const void *);
typedef BOOL (*NSHT_isEqual_func_t)(NSHashTable *,
                                    const void *,
                                    const void *);
typedef void (*NSHT_retain_func_t)(NSHashTable *, const void *);
typedef void (*NSHT_release_func_t)(NSHashTable *, void *);
typedef NSString *(*NSHT_describe_func_t)(NSHashTable *, const void *);

/** Standard NSHashTable callbacks **/
     
const NSHashTableCallBacks NSIntHashCallBacks =
{
  (NSHT_hash_func_t) _NSLF_int_hash,
  (NSHT_isEqual_func_t) _NSLF_int_is_equal,
  (NSHT_retain_func_t) fn_null_function,
  (NSHT_release_func_t) fn_null_function,
  (NSHT_describe_Func_t) _NSLF_int_describe
};

const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NSLF_void_p_hash,
  (NSHT_isEqual_func_t) _NSLF_void_p_is_equal,
  (NSHT_retain_func_t) fn_null_function,
  (NSHT_release_func_t) fn_null_function,
  (NSHT_describe_func_t) _NSLF_void_p_describe
};

const NSHashTableCallBacks NSNonRetainedObjectsHashCallBacks = 
{
  (NSHT_hash_func_t) _NSLF_id_hash,
  (NSHT_isEqual_func_t) _NSLF_id_is_equal,
  (NSHT_retain_func_t) fn_null_function,
  (NSHT_release_func_t) fn_null_function,
  (NSHT_describe_func_t) _NSLF_id_describe
};

const NSHashTableCallBacks NSObjectsHashCallBacks = 
{
  (NSHT_hash_func_t) _NSLF_id_hash,
  (NSHT_isEqual_func_t) _NSLF_id_is_equal,
  (NSHT_retain_func_t) _NSLF_id_retain,
  (NSHT_release_func_t) _NSLF_id_object,
  (NSHT_describe_func_t) _NSLF_id_describe
};

const NSHashTableCallBacks NSOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NSLF_void_p_hash,
  (NSHT_isEqual_func_t) _NSLF_void_p_is_equal,
  (NSHT_retain_func_t) fn_null_function,
  (NSHT_release_func_t) _NSLF_void_p_release,
  (NSHT_describe_func_t) _NSLF_void_p_describe
};

const NSHashTableCallBacks NSPointerToStructHashCallBacks = 
{
  (NSHT_hash_func_t) _NSLF_int_p_hash,
  (NSHT_isEqual_func_t) _NSLF_int_p_is_equal,
  (NSHT_retain_func_t) fn_null_function,
  (NSHT_release_func_t) fn_null_function,
  (NSHT_describe_func_t) _NSLF_int_p_describe
};

/** Macros **/

#define NSHT_ZONE(T) \
  ((NSZone *)((fn_hash_allocs((fn_hash_t *)(T))).user_data))

#define NSHT_CALLBACKS(T) \
  (*((NSHashTableCallBacks *)(__void_p__(fn_hash_extra((fn_hash_t *)(T))))))

#define NSHT_DESCRIBE(T, P) \
  NSHT_CALLBACKS((T)).describe((T), (P))

/** Dummy callbacks **/

size_t
_NSHT_hash(fn_generic_t element, void *table)
{
  return NSHT_CALLBACKS(table).hash((NSHashTable *)table,
                                    __void_p__(element));
}

int
_NSHT_compare(fn_generic_t element1,
                 fn_generic_t element2,
                 void *table)
{
  return !(NSHT_CALLBACKS(table).isEqual((NSHashTable *)table,
                                         __void_p__(element1),
                                         __void_p__(element2)));
}

int
_NSHT_is_equal(fn_generic_t element1,
                  fn_generic_t element2,
                  void *table)
{
  return NSHT_CALLBACKS(table).isEqual((NSHashTable *) table,
                                       __void_p__(element1),
                                       __void_p__(element2));
}

fn_generic_t
_NSHT_retain(fn_generic_t element, void *table)
{
  NSHT_CALLBACKS(table).retain((NSHashTable *)table,
                               __void_p__(element));
  return element;
}

void
_NSHT_release(fn_generic_t element, void *table)
{
  NSHT_CALLBACKS(table).release(table, __void_p__(element));
  return;
}

/* These are wrappers for getting at the real callbacks. */
const fn_callbacks_t _NSHT_callbacks = 
{
  _NSHT_hash,
  _NSHT_compare,
  _NSHT_is_equal,
  _NSHT_retain,
  _NSHT_release,
  (fn_describe_func_t)fn_null_function,
  0 
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
fn_generic_t
_NSHT_extra_retain(fn_generic_t extra, void *table)
{
  /* Pick out the callbacks in EXTRA. */
  NSHashTableCallBacks *callBacks = (NSHashTableCallBacks *)__void_p__(extra);

  /* Find our zone. */
  NSZone *zone = NSHT_ZONE(table);

  /* A pointer to some new callbacks. */
  NSHashTableCallbacks *newCallBacks;

  /* Set aside space for our new callbacks in the right zone. */
  newCallBacks = (NSHashTableCallBacks *)NSZoneMalloc(zone,
                                                      sizeof(NSHashTableCallBacks));

  /* Copy CALLBACKS into NEWCALLBACKS. */
  *newCallBacks = *callBacks;

  /* Stuff NEWCALLBACKS into EXTRA. */
  __void_p__(extra) = newCallBacks;

  /* Return our new EXTRA. */
  return extra;
}

void
_NSHT_extra_release(fn_generic_t extra, void *table)
{
  void *ptr = __void_p__(extra);
  NSZone *zone = NSHT_ZONE(table);

  if (ptr != NULL)
    NSZoneFree(zone, ptr);

  return;
}

/* The idea here is that these callbacks ensure that the
 * NSHashTableCallbacks which are associated with a given NSHashTable
 * remain so throughout the life of the table and its copies. */
fn_callbacks_t _NSHT_extra_callbacks = 
{
  (fn_hash_func_t) fn_generic_hash,
  (fn_is_equal_func_t) fn_generic_is_equal,
  (fn_compare_func_t) fn_generic_compare,
  _NSHT_extra_retain,
  _NSHT_extra_release,
  (fn_describe_func_t) fn_null_function,
  0
};

/**** Function Implementations ***********************************************/

/** Creating NSHashTables **/

NSHashTable *
NSCreateHashTableWithZone(NSHashTableCallBacks callBacks,
                          unsigned int capacity,
                          NSZone *zone)
{
  NSHashTable *table;
  fn_callbacks_t callbacks;
  fn_allocs_t allocs;

  /* These callbacks just look in the TABLE's extra and uses the
   * callbacks there.  See above for precise definitions. */
  callbacks = _NSHT_callbacks;
  allocs = fn_allocs_for_zone(zone);

  /* Then we build the table. */
  table = fn_hash_with_allocs_with_callbacks(allocs, callbacks);

  if (table != NULL)
  {
    fn_generic_t extra;

    /* Resize TABLE to CAPACITY. */
    fn_hash_resize(table, capacity);

    /* Set aside space for the NSHashTableExtra. */
    __void_p__(extra) = &callBacks;

    /* Add EXTRA to TABLE.  This takes care of everything for us. */
    fn_hash_set_extra_callbacks(table, _NSHT_extra_callbacks);
    fn_hash_set_extra(table, extra);
  }

  /* Wah-hoo! */
  return table;
}

NSHashTable *
NSCreateHashTable(NSHashTableCallBacks callBacks,
                  unsigned int capacity)
{
  return NSCreateHashTableWithZone(callBacks, capacity, NULL);
}

/** Copying **/

NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone)
{
  fn_allocs_t allocs;
  NSHashTable *new_table;

  /* Due to the wonders of modern Libfn technology, everything we care
   * about is automagically transferred. */
  allocs = fn_allocs_for_zone(zone);
  new_table = fn_hash_copy_with_allocs(table, allocs);

  return new_table;
}

/** Destroying **/

void
NSFreeHashTable(NSHashTable *table)
{
  /* Due to the wonders of modern Libfn technology, everything we care
   * about is automagically and safely destroyed. */
  fn_hash_dealloc(table);
  return;
}

/** Resetting **/

void
NSResetHashTable(NSHashTable *table)
{
  fn_hash_empty(table);
  return;
}

/** Comparing **/

BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2)
{
  return (fn_hash_is_equal_to_hash(table1, table2) ? YES : NO);
}

/** Counting **/

unsigned int
NSCountHashTable(NSHashTable *table)
{
  return (unsigned int) fn_hash_count(table);
}

/** Retrieving **/

void *
NSHashGet(NSHashTable *table, const void *pointer)
{
  fn_generic_t element;
  fn_generic_t member;

  /* Stuff POINTER into (the `void *' facet of) ELEMENT. */
  __void_p__(element) = pointer;

  /* Look up ELEMENT in TABLE. */
  member = fn_hash_element(table, element);

  /* Return the `void *' facet of MEMBER. */
  return __void_p__(member);
}

NSArray *
NSAllHashTableObjects(NSHashTable *table)
{
  NSArray *array;
  fn_generic_t *elements;
  id *objects;
  unsigned int count;

  /* FIXME: We should really be locking TABLE somehow, to insure
   * the thread-safeness of this method. */

  /* Get an array of the (generically-typed) elements of TABLE. */
  elements = fn_hash_all_elements(table);

  /* How many thing are in TABLE? */
  count = NSCountHashTable(table);

  /* Make enough room for our array of `id's together with a
   * terminating `nil' that we add below. */
  objects = fn_calloc(fn_hash_allocs(table), count + 1, sizeof(id));

  /* Step through the generic array and copy the `id' facet of each
   * into the corresponding member of the objects array.  Remember
   * that this function is only suppossed to be called when TABLE
   * contains objects.  Otherwise, everything goes to hell remarkably
   * quickly. */
  for (i = 0; i < count; ++i)
    objects[i] = __id__(elements[i]);

  /* `nil' terminate OBJECTS. */
  objects[i] = nil;

  /* Build the NSArray to return. */
  array = [[NSArray alloc] initWithObjects:objects count:count];

  /* Free up all the space we allocated here. */
  fn_free(fn_hash_allocs(table), elements);
  fn_free(fn_hash_allocs(table), objects);

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [array autorelease];
}

/** Enumerating **/

NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table)
{
  return fn_hash_enumerator(table);
}

void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator)
{
  fn_generic_t element;

  /* Grab the next element. */
  fn_hash_enumerator_next_element(enumerator, &element);

  /* Return ELEMENT's `void *' facet. */
  return __void_p__(element);
}

/** Adding **/

void
NSHashInsert(NSHashTable *table, const void *pointer)
{
  fn_generic_t element;

  /* Stuff POINTER into ELEMENT. */
  __void_p__(element) = (void *)pointer;

  /* Place ELEMENT in TABLE. */
  fn_hash_add_element(table, element);

  return;
}

void
NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer)
{
  fn_generic_t element;

  __void_p__(element) = pointer;

  if (fn_hash_contains_element(table, element))
  {
    /* FIXME: I should make this give the user/programmer more
     * information.  Not difficult to do, just something for a later
     * date. */
    [NSException raise:NSInvalidArgumentException
                 format:@"Attempted reinsertion of \"%@\" into a hash table.",
                 NSHT_DESCRIBE(table, pointer)];
  }
  else
  {
    fn_hash_add_element_known_absent(table, element);
  }

  return;
}

void *
NSHashInsertIfAbsent(NSHashTable *table, const void *pointer)
{
  fn_generic_t element;

  /* Stuff POINTER into ELEMENT. */
  __void_p__(element) = (void *)pointer;

  /* Place ELEMENT in TABLE. */
  element = fn_hash_add_element_if_absent(table, element);

  /* Return the `void *' facet of ELEMENT. */
  return __void_p__(element);
}

/** Removing **/

void
NSHashRemove(NSHashTable *table, const void *pointer)
{
  fn_generic_t element;

  /* Stuff POINTER into ELEMENT. */
  __void_p__(element) = pointer;

  /* Remove ELEMENT from TABLE. */
  fn_hash_remove_element(table, element);

  return;
}

/** Describing **/

/* FIXME: Make this nicer.  I don't know what is desired here, though.
 * If somebody has a clear idea of what this string should look like,
 * please tell me, and I'll make it happen. */
NSString *
NSStringFromHashTable(NSHashTable *table)
{
  NSString *string;
  NSHashEnumerator enumerator;
  void *pointer;

  /* This will be our string. */
  string = [NSMutableString string];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  /* Iterate over the elements of TABLE, appending the description of
   * each to the mutable string STRING. */
  while ((pointer = NSNextHashEnumeratorItem(&enumerator)) != NULL)
    [string appendFormat:@"%@;", NSHT_DESCRIBE(table, pointer)];

  /* Note that this string'll need to be `retain'ed. */
  /* FIXME: Should I `autorelease' STRING?  I think so. */
  return [string autorelease];
}

