/* NSMapTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:59:57 EST 1994
 * Updated: Sun Mar 17 18:37:12 EST 1996
 * Serial: 96.03.17.31
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

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSMapTable.h>
#include <gnustep/base/o_map.h>
#include "NSCallBacks.h"

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

/** Dummy callbacks... **/

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
_NSMT_key_release (void *element, void *table)
{
  NSMT_KEY_CALLBACKS(table).release ((NSMapTable*)table, element);
  return;
}

NSString *
_NSMT_key_describe(const void *element, void *table)
{
  return nil;
}

void *
_NSMT_value_retain (const void *element, const void *table)
{
  NSMT_VALUE_CALLBACKS(table).retain((NSMapTable *)table, element);
  return (void *) element;
}

void
_NSMT_value_release (void *element, const void *table)
{
  NSMT_VALUE_CALLBACKS(table).release((NSMapTable *)table, element);
  return;
}

NSString *
_NSMT_value_describe(const void *element, const void *table)
{
  /* FIXME: Code this. */
  return nil;
}

/* These are wrappers for getting at the real callbacks. */
o_callbacks_t _NSMT_key_callbacks = 
{
  (o_hash_func_t) _NSMT_key_hash,
  (o_compare_func_t) _NSMT_key_compare,
  (o_is_equal_func_t) _NSMT_key_is_equal,
  (o_retain_func_t) _NSMT_key_retain,
  (o_release_func_t) _NSMT_key_release,
  (o_describe_func_t) _NSMT_key_describe,
  0 /* This gets changed...See just below. */
};

static inline o_callbacks_t
_NSMT_callbacks_for_key_callbacks(NSMapTableKeyCallBacks keyCallBacks)
{
  o_callbacks_t cbs = _NSMT_key_callbacks;

  cbs.not_an_item_marker = keyCallBacks.notAKeyMarker;

  return cbs;
}

o_callbacks_t _NSMT_value_callbacks = 
{
  (o_hash_func_t) o_non_owned_void_p_hash,
  (o_compare_func_t) o_non_owned_void_p_compare,
  (o_is_equal_func_t) o_non_owned_void_p_is_equal,
  (o_retain_func_t) _NSMT_value_retain,
  (o_release_func_t) _NSMT_value_release,
  (o_describe_func_t) _NSMT_value_describe,
  0 /* Not needed, really, for OpenStep...And so, ignored here. */
};

/** Extra, extra **/

/* Make a copy of a hash table's callbacks. */
const void *
_NSMT_extra_retain(_NSMT_extra_t *extra, NSMapTable *table)
{
  /* A pointer to some space for new callbacks. */
  _NSMT_extra_t *new_extra;

  /* Set aside space for our new callbacks in the right zone. */
  new_extra = (_NSMT_extra_t *)NSZoneMalloc(o_map_zone(table),
                                            sizeof(_NSMT_extra_t));

  /* Copy the old callbacks into NEW_EXTRA. */
  *new_extra = *extra;

  /* Return our new EXTRA. */
  return new_extra;
}

void
_NSMT_extra_release(void *extra, NSMapTable *table)
{
  if (extra != 0)
    NSZoneFree(o_map_zone(table), extra);

  return;
}

NSString *
_NSMT_extra_describe(const void *extra, NSMapTable *table)
{
  /* FIXME: Code this. */
  return nil;
}

/* The basic idea here is that these callbacks ensure that the
 * NSMapTable...Callbacks which are associated with a given NSMapTable
 * remain so throughout the life of the table and its copies. */
o_callbacks_t _NSMT_extra_callbacks = 
{
  (o_hash_func_t) o_non_owned_void_p_hash,
  (o_compare_func_t) o_non_owned_void_p_compare,
  (o_is_equal_func_t) o_non_owned_void_p_is_equal,
  (o_retain_func_t) _NSMT_extra_retain,
  (o_release_func_t)_NSMT_extra_release,
  (o_describe_func_t)_NSMT_extra_describe,
  0
};

/**** Function Implementations ****/

/** Creating an NSMapTable **/

inline NSMapTable *
NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks,
			 NSMapTableValueCallBacks valueCallBacks,
			 unsigned capacity,
                         NSZone *zone)
{
  NSMapTable *table;
  o_callbacks_t key_callbacks, value_callbacks;

  /* Transform the callbacks we were given. */
  key_callbacks = _NSMT_callbacks_for_key_callbacks(keyCallBacks);
  value_callbacks = _NSMT_value_callbacks;
  
  /* Create a map table. */
  table = o_map_with_zone_with_callbacks(zone, key_callbacks,
                                               value_callbacks);

  /* Adjust the capacity of TABLE. */
  o_map_resize(table, capacity);

  if (table != 0)
  {
    _NSMT_extra_t extra;

    /* Set aside space for TABLE's extra. */
    extra.keyCallBacks = keyCallBacks;
    extra.valueCallBacks = valueCallBacks;

    /* These callbacks are defined above. */
    o_map_set_extra_callbacks(table, _NSMT_extra_callbacks);

    /* We send a pointer because that's all the room we have.  
     * The callbacks make a copy of these extras, so we needn't
     * worry about the way they disappear real soon now. */
    o_map_set_extra(table, &extra);
  }

  return table;
}

NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
		 NSMapTableValueCallBacks valueCallBacks,
		 unsigned int capacity)
{
  return NSCreateMapTableWithZone(keyCallBacks, valueCallBacks,
				  capacity, NSDefaultMallocZone());
}

NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
  NSMapTable *new_table;

  new_table = o_map_copy_with_zone(table, zone);

  return new_table;
}

/** Freeing an NSMapTable **/

void
NSFreeMapTable(NSMapTable *table)
{
  o_map_dealloc(table);
  return;
}

void
NSResetMapTable(NSMapTable *table)
{
  o_map_empty(table);
  return;
}

/** Comparing two NSMapTables... **/

BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
  return o_map_is_equal_to_map(table1, table2) ? YES : NO;
}

/** Getting the number of items in an NSMapTable **/

unsigned int
NSCountMapTable(NSMapTable *table)
{
  return (unsigned int) o_map_count(table);
}

/** Retrieving items from an NSMapTable **/

BOOL
NSMapMember(NSMapTable *table, const void *key,
	    void **originalKey, void **value)
{
  int i;

  /* Check for K in TABLE. */
  i = o_map_key_and_value_at_key(table, (const void **)originalKey,
                                       (const void **)value, key);

  /* Indicate our state of success. */
  return i ? YES : NO;
}

void *
NSMapGet(NSMapTable *table, const void *key)
{
  return (void *) o_map_value_at_key(table, key);
}

NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table)
{
  return o_map_enumerator_for_map(table);
}

BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
			void **key, void **value)
{
  int i;

  /* Get the next pair. */
  i = o_map_enumerator_next_key_and_value(enumerator, 
						(const void **)key, 
						(const void **)value);

  /* Indicate our success or failure. */
  return i ? YES : NO;
}

NSArray *
NSAllMapTableKeys(NSMapTable *table)
{
  NSMutableArray *keyArray;
  NSMapEnumerator enumerator;
  id key = nil;

  /* Create our mutable key array. */
  keyArray = [NSMutableArray arrayWithCapacity:NSCountMapTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable(table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair(&enumerator, (void **)(&key), 0))
    [keyArray addObject:key];

  return keyArray;
}

NSArray *
NSAllMapTableValues(NSMapTable *table)
{
  NSMapEnumerator enumerator;
  NSMutableArray *valueArray;
  id value = nil;

  /* Create our mutable value array. */
  valueArray = [NSMutableArray arrayWithCapacity:NSCountMapTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable(table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair(&enumerator, 0, (void **)(&value)))
    [valueArray addObject:value];

  return valueArray;
}

/** Adding items to an NSMapTable... **/

void
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
  /* Put KEY -> VALUE into TABLE. */
  o_map_at_key_put_value(table, key, value);

  return;
}

void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value)
{
  if (o_map_contains_key (table, key))
    return (void *) o_map_key_at_key(table, key);
  else
  {
    /* Put KEY -> VALUE into TABLE. */
    o_map_at_key_put_value_known_absent (table, key, value);
    return 0;
  }
}

void
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
  /* Is the key already in the table? */
  if (o_map_contains_key(table, key))
  {
    /* FIXME: I should make this give the user/programmer more
     * information.  Not difficult to do, just something for a later
     * date. */
    [NSException raise:NSInvalidArgumentException
                 format:@"NSMapTable: illegal reinsertion of: %s -> %s",
                 [NSMT_DESCRIBE_KEY(table, key) cStringNoCopy],
                 [NSMT_DESCRIBE_VALUE(table, value) cStringNoCopy]];
  }
  else
  {
    /* Well, we know it's not there, so... */
    o_map_at_key_put_value_known_absent (table, key, value);
  }

  /* Yah-hoo! */
  return;
}

/** Removing items from an NSMapTable **/

void
NSMapRemove(NSMapTable *table, const void *key)
{
  o_map_remove_key (table, key);
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
    [string appendFormat:@"%@ = %@;",
	    [(keyCallBacks.describe)(table, key) cStringNoCopy],
	    [(valueCallBacks.describe)(table, value) cStringNoCopy]];

  /* Note that this string'll need to be `retain'ed. */
  return string;
}
