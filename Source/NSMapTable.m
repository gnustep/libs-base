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

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include <NSCallBacks.h>
#include <Foundation/atoz.h>
#include <objects/map.h>

/**** Type, Constant, and Macro Definitions **********************************/

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

const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_int_hash,
  (NSMT_is_equal_func_t) _NS_int_is_equal,
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe,
  0
};

const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  0
};

const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  /* FIXME: Oh my.  Is this really ok?  I did it in a moment of
   * weakness.  A fit of madness, I say!  And if this is wrong, what
   * *should* it be?!? */
  (const void *)-1
};

const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_retained_id_hash,
  (NSMT_is_equal_func_t) _NS_non_retained_id_is_equal,
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe,
  0
};

const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_id_hash,
  (NSMT_is_equal_func_t) _NS_id_is_equal,
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe,
  0
};

const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe,
  0
};

const NSMapTableValueCallBacks NSIntMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe
};

const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe
};

const NSMapTableValueCallBacks NSObjectMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe
};

const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe
};

/** Macros **/

#define NSMT_ZONE(T) \
  ((NSZone *)((objects_map_allocs((objects_map_t *)(T))).user_data))

#define NSMT_EXTRA(T) \
  ((_NSMT_extra_t *)(objects_map_extra((objects_map_t *)(T))))

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
_NSMT_key_hash (const void *element, const void *table)
{
  return NSMT_KEY_CALLBACKS(table).hash((NSMapTable *)table,
                                        element);
}

int
_NSMT_key_compare (const void *element1, const void *element2, 
		   const void *table)
{
  return !(NSMT_KEY_CALLBACKS(table).isEqual((NSMapTable *)table,
                                             element1,
                                             element2));
}

int
_NSMT_key_is_equal (const void *element1, const void *element2, 
		    const void *table)
{
  return NSMT_KEY_CALLBACKS(table).isEqual((NSMapTable *) table,
                                           element1,
                                           element2);
}

void *
_NSMT_key_retain (const void *element, const void *table)
{
  NSMT_KEY_CALLBACKS(table).retain((NSMapTable *)table, element);
  return (void*) element;
}

void
_NSMT_key_release (void *element, const void *table)
{
  NSMT_KEY_CALLBACKS(table).release ((NSMapTable*)table, element);
  return;
}

void *
_NSMT_value_retain (const void *element, const void *table)
{
  NSMT_VALUE_CALLBACKS(table).retain ((NSMapTable *)table, element);
  return (void*) element;
}

void
_NSMT_value_release (void *element, const void *table)
{
  NSMT_VALUE_CALLBACKS(table).release ((NSMapTable*)table, element);
  return;
}

/* These are wrappers for getting at the real callbacks. */
objects_callbacks_t _NSMT_key_callbacks = 
{
  _NSMT_key_hash,
  _NSMT_key_compare,
  _NSMT_key_is_equal,
  _NSMT_key_retain,
  _NSMT_key_release,
  0,
  0 
};

objects_callbacks_t
_NSMT_callbacks_for_key_callbacks (NSMapTableKeyCallBacks keyCallBacks)
{
  objects_callbacks_t cb = _NSMT_key_callbacks;

  cb.not_an_item_marker = keyCallBacks.notAKeyMarker;

  return cb;
}

objects_callbacks_t _NSMT_value_callbacks = 
{
  (objects_hash_func_t) objects_void_p_hash,
  (objects_compare_func_t) objects_void_p_compare,
  (objects_is_equal_func_t) objects_void_p_is_equal,
  _NSMT_value_retain,
  _NSMT_value_release,
  0,
  0
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
void *
_NSMT_extra_retain(const void *extra, const void *table)
{
  /* A pointer to some space for new callbacks. */
  _NSMT_extra_t *new_extra;

  /* Set aside space for our new callbacks in the right zone. */
  new_extra = (_NSMT_extra_t *)NSZoneMalloc(NSMT_ZONE(table),
                                           sizeof(_NSMT_extra_t));

  /* Copy the old callbacks into NEW_EXTRA. */
  *new_extra = *((_NSMT_extra_t *)(extra));

  /* Return our new EXTRA. */
  return new_extra;
}

void
_NSMT_extra_release(void *extra, const void *table)
{
  NSZone *zone = NSMT_ZONE(table);

  if (extra != 0)
    NSZoneFree(zone, extra);

  return;
}

/* The idea here is that these callbacks ensure that the
 * NSMapTableCallbacks which are associated with a given NSMapTable
 * remain so throughout the life of the table and its copies. */
objects_callbacks_t _NSMT_extra_callbacks = 
{
  (objects_hash_func_t) objects_void_p_hash,
  (objects_compare_func_t) objects_void_p_compare,
  (objects_is_equal_func_t) objects_void_p_is_equal,
  _NSMT_extra_retain,
  _NSMT_extra_release,
  0,
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
  objects_callbacks_t key_callbacks, value_callbacks;
  objects_allocs_t allocs;

  /* Transform the callbacks we were given. */
  key_callbacks = _NSMT_callbacks_for_key_callbacks(keyCallBacks);
  value_callbacks = _NSMT_value_callbacks;
  
  /* Get some useful allocs. */
  allocs = objects_allocs_for_zone(zone);

  /* Create a map table. */
  table = objects_map_with_allocs_with_callbacks(allocs, key_callbacks,
                                                 value_callbacks);

  /* Adjust the capacity of TABLE. */
  objects_map_resize(table, capacity);

  if (table != 0)
  {
    _NSMT_extra_t extra;

    /* Set aside space for TABLE's extra. */
    extra.keyCallBacks = keyCallBacks;
    extra.valueCallBacks = valueCallBacks;

    /* These callbacks are defined above. */
    objects_map_set_extra_callbacks(table, _NSMT_extra_callbacks);

    /* We send a pointer because that's all the room we have.  
     * The callbacks make a copy of these extras, so we needn't
     * worry about the way they disappear real soon now. */
    objects_map_set_extra(table, &extra);
  }

  return table;
}

NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
		 NSMapTableValueCallBacks valueCallBacks,
		 unsigned int capacity)
{
  return NSCreateMapTableWithZone(keyCallBacks, valueCallBacks,
				  capacity, 0);
}

NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
  objects_allocs_t allocs;
  NSMapTable *new_table;

  allocs = objects_allocs_for_zone(zone);
  new_table = objects_map_copy_with_allocs(table, allocs);

  return new_table;
}

/** Freeing an NSMapTable **/

void
NSFreeMapTable(NSMapTable *table)
{
  objects_map_dealloc(table);
  return;
}

void
NSResetMapTable(NSMapTable *table)
{
  objects_map_empty(table);
  return;
}

/** Comparing two NSMapTables **/

BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
  return objects_map_is_equal_to_map(table1, table2) ? YES : NO;
}

/** Getting the number of items in an NSMapTable **/

unsigned int
NSCountMapTable(NSMapTable *table)
{
  return (unsigned int) objects_map_count(table);
}

/** Retrieving items from an NSMapTable **/

BOOL
NSMapMember(NSMapTable *table, const void *key,
	    void **originalKey, void **value)
{
  int i;

  /* Check for K in TABLE. */
  i = objects_map_key_and_value_at_key (table, key, originalKey, value);

  /* Indicate our state of success. */
  return i ? YES : NO;
}

void *
NSMapGet(NSMapTable *table, const void *key)
{
  return (void*) objects_map_value_at_key (table, key);
}

NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table)
{
  return objects_map_enumerator(table);
}

BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
			void **key, void **value)
{
  int i;

  /* Get the next pair. */
  i = objects_map_enumerator_next_key_and_value (enumerator, 
						 (const void**)key, 
						 (const void**)value);

  /* Indicate our success or failure. */
  return i ? YES : NO;
}

NSArray *
NSAllMapTableKeys(NSMapTable *table)
{
  NSMutableArray *keyArray;
  NSMapEnumerator enumerator;
  id key;

  /* Create our mutable key array. */
  keyArray = [NSMutableArray arrayWithCapacity: NSCountMapTable (table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable (table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair (&enumerator, (void**)&key, 0))
    [keyArray addObject: key];

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [keyArray autorelease];
}

NSArray *
NSAllMapTableValues(NSMapTable *table)
{
  NSMutableArray *array;
  NSMapEnumerator enumerator;
  id valueArray;
  id value;

  /* Create our mutable value array. */
  valueArray = [NSMutableArray arrayWithCapacity:NSCountMapTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable(table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair (&enumerator, 0, (void**)&value))
    [valueArray addObject:value];

  /* FIXME: Should ARRAY returned be `autorelease'd? */
  return [array autorelease];
}

/** Adding items to an NSMapTable **/

void
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
  /* Put KEY -> VALUE into TABLE. */
  objects_map_at_key_put_value (table, key, value);

  return;
}

void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value)
{
  void *old_key;

  if (objects_map_contains_key (table, key))
    return (void*) objects_map_key (table, key);
  else
  {
    /* Put KEY -> VALUE into TABLE. */
    objects_map_at_key_put_value_known_absent (table, key, value);
    return NULL;
  }
}

void
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
  /* Is the key already in the table? */
  if (objects_map_contains_key(table, key))
  {
    /* Ooh.  Bad.  The docs say to raise an exception! */
    /* FIXME: I should make this much more informative.  */
    [NSException raise:NSInvalidArgumentException
                 format:@"That key's already in the table."];
  }
  else
  {
    /* Well, we know it's not there, so... */
    objects_map_at_key_put_value_known_absent (table, key, value);
  }

  /* Yah-hoo! */
  return;
}

/** Removing items from an NSMapTable **/

void
NSMapRemove(NSMapTable *table, const void *key)
{
  objects_map_remove_key (table, key);
  return;
}

/** Getting an NSString representation of an NSMapTable **/

NSString *
NSStringFromMapTable(NSMapTable *table)
{
  NSMutableString *string;
  NSMapEnumerator enumerator;
  NSMapTableKeyCallBacks keyCallBacks;
  NSMapTableValueCallBacks valueCallBacks;
  void *key, *value;

  /* Get an empty mutable string. */
  string = [NSMutableString stringWithCapacity:0];

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
