/* NSMapTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:59:57 EST 1994
 * Updated: Sat Feb 10 16:00:25 EST 1996
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
#include <Foundation/_NSLibfn.h>
#include <Foundation/NSMapTable.h>
#include <fn/map.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* This is for keeping track of information... */     
typedef struct _NSMT_extra NSMT_extra_t;

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

const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_int_hash,
  (NSMT_is_equal_func_t) _NS_int_is_equal,
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_int_describe,
  (const void *) 0
};

const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_void_p_hash,
  (NSMT_is_equal_func_t) _NS_void_p_is_equal,
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_void_p_describe,
  (const void *) NULL
};

const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_void_p_hash,
  (NSMT_is_equal_func_t) _NS_void_p_is_equal,
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_void_p_describe,
  /* FIXME: Oh my.  Is this really ok?  I did it in a moment of
   * weakness.  A fit of madness, I say!  And if this is wrong, what
   * *should* it be?!? */
  (const void *) -1
};

const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_id_hash,
  (NSMT_is_equal_func_t) _NS_id_is_equal,
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_id_describe,
  (const void *) NULL
};

const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_id_hash,
  (NSMT_is_equal_func_t) _NS_id_is_equal,
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe,
  (const void *) NULL
};

const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_void_p_hash,
  (NSMT_is_equal_func_t) _NS_void_p_is_equal,
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) _NS_void_p_release,
  (NSMT_describe_func_t) _NS_void_p_describe,
  (const void *) NULL
};

const NSMapTableValueCallBacks NSIntMapValueCallBacks = 
{
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_int_describe
};

const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) fn_null_function,
  (NSMT_describe_func_t) _NS_void_p_describe
};

const NSMapTableValueCallBacks NSObjectMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe
};

const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) fn_null_function,
  (NSMT_release_func_t) _NS_void_p_release,
  (NSMT_describe_func_t) _NS_void_p_describe
};

/** Macros **/

#define NSMT_ZONE(T) \
  ((NSZone *)((fn_map_allocs((fn_map_t *)(T))).user_data))

#define NSMT_EXTRA(T) \
  ((NSMT_extra_t *)(__void_p__(fn_map_extra((fn_map_t *)(T)))))

#define NSMT_KEY_CALLBACKS(T) \
  ((NSMT_EXTRA((T)))->keyCallBacks)

#define NSMT_VALUE_CALLBACKS(T) \
  ((NSMT_EXTRA((T)))->valueCallBacks)

#define NSMT_DESCRIBE_KEY(T, P) \
  NSMT_KEY_CALLBACKS((T)).describe((T), (P))

#define NSMT_DESCRIBE_VALUE(T, P) \
  NSMT_VALUE_CALLBACKS((T)).describe((T), (P))

/** Dummy callbacks **/

size_t
_NSMT_key_hash(fn_generic_t element, void *table)
{
  return NSMT_KEY_CALLBACKS(table).hash((NSMapTable *)table,
                                        __void_p__(element));
}

int
_NSMT_key_compare(fn_generic_t element1,
                  fn_generic_t element2,
                  void *table)
{
  return !(NSMT_KEY_CALLBACKS(table).isEqual((NSMapTable *)table,
                                             __void_p__(element1),
                                             __void_p__(element2)));
}

int
_NSMT_key_is_equal(fn_generic_t element1,
                   fn_generic_t element2,
                   void *table)
{
  return NSMT_KEY_CALLBACKS(table).isEqual((NSMapTable *) table,
                                           __void_p__(element1),
                                           __void_p__(element2));
}

fn_generic_t
_NSMT_key_retain(fn_generic_t element, void *table)
{
  NSMT_KEY_CALLBACKS(table).retain((NSMapTable *)table,
                                   __void_p__(element));
  return element;
}

void
_NSMT_key_release(fn_generic_t element, void *table)
{
  NSMT_KEY_CALLBACKS(table).release(table, __void_p__(element));
  return;
}

fn_generic_t
_NSMT_value_retain(fn_generic_t element, void *table)
{
  NSMT_VALUE_CALLBACKS(table).retain((NSMapTable *)table,
                                     __void_p__(element));
  return element;
}

void
_NSMT_value_release(fn_generic_t element, void *table)
{
  NSMT_VALUE_CALLBACKS(table).release(table, __void_p__(element));
  return;
}

/* These are wrappers for getting at the real callbacks. */
fn_callbacks_t _NSMT_key_callbacks = 
{
  _NSMT_key_hash,
  _NSMT_key_compare,
  _NSMT_key_is_equal,
  _NSMT_key_retain,
  _NSMT_key_release,
  (fn_describe_func_t)fn_null_function,
  0 
};

fn_callbacks_t
_NSMT_callbacks_for_key_callbacks(NSMapTableKeyCallBacks keyCallBacks)
{
  fn_callbacks_t cb = _NSMT_key_callbacks;

  __void_p__(cb.not_an_item_marker) = (void *)(keyCallBacks.notAKeyMarker);

  return callbacks;
}

fn_callbacks_t _NSMT_value_callbacks = 
{
  (fn_hash_func_t) fn_generic_hash,
  (fn_compare_func_t) fn_generic_compare,
  (fn_is_equal_func_t) fn_generic_is_equal,
  _NSMT_value_retain,
  _NSMT_value_release,
  (fn_describe_func_t)fn_null_function,
  0
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
fn_generic_t
_NSMT_extra_retain(fn_generic_t g, void *table)
{
  /* A pointer to some space for new callbacks. */
  NSMT_extra_t *new_extra;

  /* Set aside space for our new callbacks in the right zone. */
  new_extra = (NSMT_extra_t *)NSZoneMalloc(NSMT_ZONE(table),
                                           sizeof(NSMT_extra_t));

  /* Copy the old callbacks into NEW_EXTRA. */
  *new_extra = *((NSMT_extra_t *)(__void_p__(g)))

  /* Stuff NEW_EXTRA into G. */
  __void_p__(g) = new_extra;

  /* Return our new EXTRA. */
  return g;
}

void
_NSMT_extra_release(fn_generic_t extra, void *table)
{
  void *ptr = __void_p__(extra);
  NSZone *zone = NSMT_ZONE(table);

  if (ptr != NULL)
    NSZoneFree(zone, ptr);

  return;
}

/* The idea here is that these callbacks ensure that the
 * NSMapTableCallbacks which are associated with a given NSMapTable
 * remain so throughout the life of the table and its copies. */
fn_callbacks_t _NSMT_extra_callbacks = 
{
  (fn_hash_func_t) fn_generic_hash,
  (fn_is_equal_func_t) fn_generic_is_equal,
  (fn_compare_func_t) fn_generic_compare,
  _NSMT_extra_retain,
  _NSMT_extra_release,
  (fn_describe_func_t) fn_null_function,
  0
};

/**** Function Implementations ****/

/** Creating an NSMapTable **/

NSMapTable *
NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks,
			 NSMapTableValueCallBacks valueCallBacks,
			 unsigned capacity,
                         NSZone *zone)
{
  NSMapTable *table;
  fn_callbacks_t key_callbacks, value_callbacks;
  fn_allocs_t alloc;

  /* Transform the callbacks we were given. */
  key_callbacks = _NSMT_callbacks_for_key_callbacks(keyCallBacks);
  value_callbacks = _NSMT_value_callbacks;
  
  /* Get some useful allocs. */
  alloc = fn_allocs_for_zone(zone);

  /* Create a map table. */
  table = fn_map_with_allocs_with_callbacks(allocs, key_callbacks,
                                            value_callbacks);

  /* Adjust the capacity of TABLE. */
  fn_map_resize(table, capacity);

  if (table != NULL)
  {
    NSMapTableExtras *extras;

    /* Set aside space for the NSMapTableExtras. */
    extras = _NSNewMapTableExtrasWithZone(zone);
    extras->keyCallBacks = keyCallBacks;
    extras->valueCallBacks = valueCallBacks;

    table->extras = extras;
  }

  return table;
}

NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
		 NSMapTableValueCallBacks valueCallBacks,
		 unsigned int capacity)
{
  return NSCreateMapTableWithZone(keyCallBacks,
                                  valueCallBacks,
				  capacity,
                                  NULL);
}

/* FIXME: CODE THIS! */
NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
  fn_allocs_t allocs;
  NSMapTable *new_table;

  allocs = fn_allocs_for_zone(zone);
  new_table = fn_map_copy_with_allocs(table, alloc);

  return new_table;
}

/** Freeing an NSMapTable **/

void
NSFreeMapTable(NSMapTable *table)
{
  fn_map_dealloc(table);
  return;
}

void
NSResetMapTable(NSMapTable *table)
{
  fn_map_empty(table);
  return;
}

/** Comparing two NSMapTables **/

BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
  return fn_map_is_equal_map(table1, table2) ? YES : NO;
}

/** Getting the number of items in an NSMapTable **/

unsigned int
NSCountMapTable(NSMapTable *table)
{
  return (unsigned int) fn_map_count(table);
}

/** Retrieving items from an NSMapTable **/

BOOL
NSMapMember(NSMapTable *table, const void *key,
	    void **originalKey, void **value)
{
  fn_generic_t k, ok, v;
  int i;

  /* Stuff KEY into K. */
  __void_p__(k) = key;

  /* Check for K in TABLE. */
  i = fn_map_key_and_value(table, k, &ok, &v);

  /* Put the `void *' facet of OK and V into ORIGINALKEY and VALUE. */
  if (originalKey != NULL)
    *originalKey = __void_p__(ok);
  if (value != NULL)
    *value = __void_p__(v);

  /* Indicate our state of success. */
  return i ? YES : NO;
}

void *
NSMapGet(NSMapTable *table, const void *key)
{
  return fn_map_value(table, key);
}

NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table)
{
  return fn_map_enumerator(table);
}

BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
			void **key, void **value)
{
  fn_generic_t k, v;
  int i;

  /* Get the next pair. */
  i = fn_map_enumerator_next_key_and_value(enumerator, &k, &v);

  /* Put the `void *' facet of K and V into KEY and VALUE. */
  *key = __void_p__(k);
  *value = __void_p__(v);

  /* Indicate our success or failure. */
  return i ? YES : NO;
}

NSArray *
NSAllMapTableKeys(NSMapTable *table)
{
  NSArray *array;
  fn_generic_t *keys;
  id *objects;
  unsigned int count;

  count = fn_map_count(table);
  keys = fn_map_all_keys(table);
  objects = fn_calloc(fn_set_allocs(table), count + 1, sizeof(id));

  for (i = 0; i < count; ++i)
    objects[i] = __id__(keys[i]);

  objects[i] = nil;

  array = [[NSArray alloc] initWithObjects:objects count:count];
  
  fn_free(fn_map_allocs(table), keys);
  fn_free(fn_map_allocs(table), objects);

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [array autorelease];
}

NSArray *
NSAllMapTableValues(NSMapTable *table)
{
  NSArray *array;
  fn_generic_t *values;
  id *objects;
  unsigned int count;

  count = fn_map_count(table);
  values = fn_map_all_values(table);
  objects = fn_calloc(fn_set_allocs(table), count + 1, sizeof(id));

  for (i = 0; i < count; ++i)
    objects[i] = __id__(values[i]);

  objects[i] = nil;

  array = [[NSArray alloc] initWithObjects:objects count:count];
  
  fn_free(fn_map_allocs(table), keys);
  fn_free(fn_map_allocs(table), objects);

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [array autorelease];
}

/** Adding items to an NSMapTable **/

void
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
  fn_generic_t k, v;

  /* Stuff KEY and VALUE into K and V. */
  __void_p__(k) = key;
  __void_p__(v) = value;

  /* Put K -> V into TABLE. */
  fn_map_at_key_put_value(table, k, v);

  return;
}

void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value)
{
  fn_generic_t k, v, m;

  /* Stuff KEY and VALUE into K and V. */
  __void_p__(k) = key;
  __void_p__(v) = value;

  /* Put K -> V into TABLE. */
  m = fn_map_at_key_put_value_if_absent(table, k, v);

  /* Return the `void *' facet of M. */
  return __void_p__(m);
}

void
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
  fn_generic_t k, v;

  /* Stuff KEY and VALUE into K and V. */
  __void_p__(k) = key;
  __void_p__(v) = value;

  /* Is the key already in the table? */
  if (fn_map_contains_key(table, k))
  {
    /* Ooh.  Bad.  The docs say to raise an exception! */
    /* FIXME: I should make this much more informative.  */
    [NSException raise:NSInvalidArgumentException
                 format:@"That key's already in the table."];
  }
  else
  {
    /* Well, we know it's not there, so... */
    fn_map_at_key_put_value_known_absent(table, k, v);
  }

  /* Yah-hoo! */
  return;
}

/** Removing items from an NSMapTable **/

void
NSMapRemove(NSMapTable *table, const void *key)
{
  fn_map_remove_key(table, key);
  return;
}

/** Getting an NSString representation of an NSMapTable **/

NSString *
NSStringFromMapTable(NSMapTable *table)
{
  NSString *string;
  NSMapEnumerator enumerator;
  NSMapTableKeyCallBacks keyCallBacks;
  NSMapTableValueCallBacks valueCallBacks;
  void *key, *value;

  /* Get an empty mutable string. */
  string = [NSMutableString string];

  /* Pull the NSMapTable...CallBacks out of the mess. */
  keyCallBacks = NSMT_KEY_CALLBACKS(table);
  valueCallBacks = NSMT_VALUE_CALLBACKS(table);

  /* Get an enumerator for our table. */
  enumerator = NSEnumerateMapTable(table);

  /* Now, just step through the elements of the table, and add their
   * descriptions to the string. */
  while (NSNextMapEnumeratorPair(&enumerator, &key, &value))
    [string appendFormat:@"%@ = %@;", (keyCallBacks.describe)(table, key),
     (valueCallBacks.describe)(table, value)];

  /* Note that this string'll need to be `retain'ed. */
  /* FIXME: Should I be `autorelease'ing it? */
  return [string autorelease];
}
