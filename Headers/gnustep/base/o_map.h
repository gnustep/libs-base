/* A map table.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Thu Mar 21 00:05:43 EST 1996
 * Serial: 96.03.20.04
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

#ifndef __map_h_OBJECTS_INCLUDE
#define __map_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <gnustep/base/callbacks.h>
#include <gnustep/base/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Need these up here because of their interdependence. */
typedef struct _objects_map objects_map_t;
typedef struct _objects_map_bucket objects_map_bucket_t;
typedef struct _objects_map_node objects_map_node_t;
typedef struct _objects_map_enumerator objects_map_enumerator_t;

/* Important structures... */

/* Private type for elemental holding. */
struct _objects_map_node
{
  /* The map table with which the node is associated. */
  objects_map_t *map;

  /* The bucket in MAP in which the node sits. */
  objects_map_bucket_t *bucket;

  /* These hold the BUCKET linked list together. */
  objects_map_node_t *next_in_bucket;
  objects_map_node_t *prev_in_bucket;

  /* For enumerating over the whole map table.  These make
   * enumerating much quicker.  They also make it safer. */
  objects_map_node_t *next_in_map;
  objects_map_node_t *prev_in_map;

  const void *key;
  const void *value;
};

/* Private type for holding chains of nodes. */
struct _objects_map_bucket
{
  /* The number of nodes in this bucket.  For internal consistency checks. */
  size_t node_count;

  /* The number of elements in this bucket.  (This had *better* be
   * the same as NODE_COUNT, or something's wrong.) */
  size_t element_count;

  /* The head of this bucket's linked list of nodes. */
  objects_map_node_t *first_node;
};

/* The map table type. */
struct _objects_map
{
  /* All structures have these... 
   * And all structures have them in the same order. */
  int magic_number;
  size_t serial_number;
  NSZone *zone;
  NSString *name;
  const void *extra;
  objects_callbacks_t extra_callbacks;

  /* For keys...And Values. */
  objects_callbacks_t key_callbacks;
  objects_callbacks_t value_callbacks;

  /* Internal counters */
  size_t bucket_count;
  size_t node_count;
  size_t element_count;

  /* Places to start looking for elements. */
  objects_map_bucket_t *buckets;   /* Organized as a hash. */
  objects_map_node_t *first_node;  /* Organized as a linked list.
                                     * (For enumerating...) */
};

/* Type for enumerating the elements of a map table. */
struct _objects_map_enumerator
{
  objects_map_t *map;        /* To which hash do I belong? */
  objects_map_node_t *node;  /* Which node is next? */
};

/**** Function Prototypes ****************************************************/

/** Basics... **/

/* All the structures (hashes, maps, lists, and arrays) have
 * the same basic ideas behind them. */

#include <gnustep/base/map-bas.h>
#include <gnustep/base/map-cbs.h>

/** Callbacks... **/

/* Returns a collection of callbacks for use with hash tables. */
objects_callbacks_t
objects_callbacks_for_map(void);

/** Creating... **/

/* Allocate a hash table in the default zone. */
objects_map_t *
objects_map_alloc(void);

/* Allocate a hash table in the memory block ZONE. */
objects_map_t *
objects_map_alloc_with_zone(NSZone *zone);

/* Create an empty map table in the memory block ZONE.  The returned
 * hash table has a "reasonable" default capacity, but will need to
 * be resized to suit your specific needs if more than a couple of
 * dozen key/value pairs will be placed within it. */
objects_map_t *
objects_map_with_zone_with_callbacks(NSZone *zone,
                                     objects_callbacks_t key_callbacks,
                                     objects_callbacks_t value_callbacks);

/* Like calling 'objects_map_with_zone_with_callbacks(0, key_callbacks,
 * value_callbacks)'. */
objects_map_t *
objects_map_with_callbacks(objects_callbacks_t key_callbacks,
                           objects_callbacks_t value_callbacks);

/* Like calling 'objects_map_with_zone_with_callbacks(0,
 * objects_callbacks_standard(), objects_callbacks_standard())'. */
objects_map_t *
objects_map_with_zone(NSZone *zone);

/* Shortcuts... */
objects_map_t *objects_map_of_int(void);
objects_map_t *objects_map_of_int_to_char_p(void);
objects_map_t *objects_map_of_int_to_non_owned_void_p(void);
objects_map_t *objects_map_of_int_to_id(void);
objects_map_t *objects_map_of_char_p(void);
objects_map_t *objects_map_of_char_p_to_int(void);
objects_map_t *objects_map_of_char_p_to_non_owned_void_p(void);
objects_map_t *objects_map_of_char_p_to_id(void);
objects_map_t *objects_map_of_non_owned_void_p(void);
objects_map_t *objects_map_of_non_owned_void_p_to_int(void);
objects_map_t *objects_map_of_non_owned_void_p_to_char_p(void);
objects_map_t *objects_map_of_non_owned_void_p_to_id(void);
objects_map_t *objects_map_of_id(void);

/** Initializing... **/

objects_map_t *
objects_map_init(objects_map_t *map);

objects_map_t *
objects_map_init_with_callbacks(objects_map_t *map,
                                objects_callbacks_t key_callbacks,
                                objects_callbacks_t value_callbacks);

objects_map_t *
object_map_init_from_map(objects_map_t *map, objects_map_t *old_map);

/** Destroying... **/

/* Releases all the keys and values of MAP, and then
 * deallocates MAP itself. */
void
objects_map_dealloc(objects_map_t *map);

/** Gathering statistics on a map... **/

/* Returns the number of key/value pairs in MAP. */
size_t
objects_map_count(objects_map_t *map);

/* Returns some (inexact) measure of how many key/value pairs
 * MAP can comfortably hold without resizing. */
size_t
objects_map_capacity(objects_map_t *map);

/* Performs an internal consistency check, returns 'true' if
 * everything is OK, 'false' otherwise.  Really useful only
 * for debugging. */
int
objects_map_check(objects_map_t *map);

/** Finding elements in a map... **/

/* Returns 'true' if and only if some key in MAP is equal
 * (in the sense of the key callbacks of MAP) to KEY. */
int
objects_map_contains_key(objects_map_t *map, const void *key);

/* Returns 'true' if and only if some value in MAP is equal
 * (in the sense of the value callbacks of MAP) to VALUE. */
/* WARNING: This is rather inefficient.  Not to be used lightly. */
int
objects_map_contains_value(objects_map_t *map, const void *value);

/* If KEY is in MAP, then the following three things happen:
 *   (1) 'true' is returned;
 *   (2) if OLD_KEY is non-zero, then the key in MAP
 *       equal to KEY is placed there;
 *   (3) if VALUE is non-zero, then the value in MAP
 *       mapped to by KEY is placed there. 
 * If KEY is not in MAP, then the following three things happen:
 *   (1) 'false' is returned;
 *   (2) if OLD_KEY is non-zero, then the "not a key marker"
 *       for MAP is placed there;
 *   (3) if VALUE is non-zero, then the the "not a value marker"
 *       for MAP is placed there. */
int
objects_map_key_and_value_at_key(objects_map_t *map,
                                 const void **old_key,
                                 const void **value,
                                 const void *key);

/* If KEY is in MAP, then the key of MAP which is equal to KEY
 * is returned.  Otherwise, the "not a key marker" for MAP is returned. */
const void *
objects_map_key_at_key(objects_map_t *map, const void *key);

/* If KEY is in MAP, then the value of MAP which to which KEY maps
 * is returned.  Otherwise, the "not a value marker" for MAP is returned. */
const void *
objects_map_value_at_key(objects_map_t *map, const void *key);

/** Enumerating the nodes and elements of a map... **/

objects_map_enumerator_t
objects_map_enumerator_for_map(objects_map_t *map);

int
objects_map_enumerator_next_key_and_value(objects_map_enumerator_t *enumerator,
                                          const void **key,
                                          const void **value);

int
objects_map_enumerator_next_key(objects_map_enumerator_t *enumerator,
                                const void **key);

int
objects_map_enumerator_next_value(objects_map_enumerator_t *enumerator,
                                  const void **value);

/** Obtaining an array of the elements of a map... **/

const void **
objects_map_all_keys_and_values(objects_map_t *map);

const void **
objects_map_all_keys(objects_map_t *map);

const void **
objects_map_all_values(objects_map_t *map);

/** Removing... **/

/* Removes the key/value pair (if any) from MAP whose key is KEY. */
void
objects_map_remove_key(objects_map_t *map, const void *key);

/* Releases all of the keys and values of MAP without
 * altering MAP's capacity. */
void
objects_map_empty(objects_map_t *map);

/** Adding... **/

const void *
objects_map_at_key_put_value_known_absent(objects_map_t *map,
                                          const void *key,
                                          const void *value);

const void *
objects_map_at_key_put_value(objects_map_t *map,
                             const void *key,
                             const void *value);

const void *
objects_map_at_key_put_value_if_absent(objects_map_t *map,
                                       const void *key,
                                       const void *value);

/** Replacing... **/

void
objects_map_replace_key(objects_map_t *map, const void *key);

/** Comparing... **/

/* Returns 'true' if every key/value pair of MAP2 is also a key/value pair
 * of MAP1.  Otherwise, returns 'false'. */
int
objects_map_contains_map(objects_map_t *map1, objects_map_t *map2);

/* Returns 'true' if MAP1 and MAP2 have the same number of key/value pairs,
 * MAP1 contains MAP2, and MAP2 contains MAP1.  Otherwise, returns 'false'. */
int
objects_map_is_equal_to_map(objects_map_t *map1, objects_map_t *map2);

/* Returns 'true' iff every key of MAP2 is a key of MAP1. */
int
objects_map_keys_contain_keys_of_map(objects_map_t *map1, objects_map_t *map2);

/* Returns 'true' if MAP1 and MAP2 have the same number of key/value pairs,
 * MAP1 contains every key of MAP2, and MAP2 contains every key of MAP1.
 * Otherwise, returns 'false'. */
int
objects_map_keys_are_equal_to_keys_of_map(objects_map_t *map1,
                                          objects_map_t *map2);

/* Returns 'true' iff some key/value pair of MAP1 if also
 * a key/value pair of MAP2. */
int
objects_map_intersects_map(objects_map_t *map1, objects_map_t *map2);

/* Returns 'true' iff some key of MAP1 if also a key of MAP2. */
int
objects_map_keys_intersect_keys_of_map(objects_map_t *map1,
                                       objects_map_t *map2);
/** Copying... **/

/* Returns a copy of OLD_MAP in ZONE.  Remember that, as far as what
 * (if anything) OLD_MAP's keys and values point to, this copy is
 * shallow.  If, for example, OLD_MAP is a map from int to int, then
 * you've got nothing more to worry about.  If, however, OLD_MAP is a
 * map from id to id, and you want the copy of OLD_MAP to be "deep",
 * you'll need to use the mapping functions below to make copies of
 * all of the returned map's elements. */
objects_map_t *
objects_map_copy_with_zone(objects_map_t *old_map, NSZone *zone);

/* Just like 'objects_map_copy_with_zone()', but returns a copy of
 * OLD_MAP in the default zone. */
objects_map_t *
objects_map_copy(objects_map_t *old_map);

/** Mapping... **/

/* Iterates through MAP, replacing each key with the result of
 * '(*kfcn)(key, user_data)'.  Useful for deepening copied maps
 * and other uniform (and one-to-one) transformations of map keys. */
/* WARNING: The mapping function KFCN *must* be one-to-one on the
 * (equivalence classes of) keys of MAP.  I.e., for efficiency's sake,
 * `objects_map_map_keys()' makes no provision for the possibility
 * that KFCN maps two unequal keys of MAP to the same (or equal) keys. */
objects_map_t *
objects_map_map_keys(objects_map_t *map,
                     const void *(*kfcn)(const void *, void *),
                     void *user_data);

/* Iterates through MAP, replacing each value with the result of
 * '(*vfcn)(value, user_data)'.  Useful for deepening copied maps
 * and other uniform transformations of map keys. */
/* NO WARNING: The mapping function VFCN need not be one-to-one on
 * (the equivalence classes of) values. */
objects_map_t *
objects_map_map_values(objects_map_t *map,
                       const void *(*vfcn)(const void *, void *),
                       void *user_data);

/** Resizing... **/

/* Resizes MAP to be ready to contain (at least) NEW_CAPACITY many elements.
 * However, as far as you are concerned, it is indeterminate what exactly
 * this means.  After receiving and successfully processing this call,
 * you are *not* guaranteed that MAP has actually set aside space for
 * NEW_CAPACITY elements, for example.  All that you are guaranteed is that,
 * to the best of its ability, MAP will incur no loss in efficiency so long
 * as it contains no more than NEW_CAPACITY elements. */
size_t
objects_map_resize(objects_map_t *map, size_t new_capacity);

/* Shrinks (or grows) MAP to be comfortable with the number of elements
 * it contains.  In all likelyhood, after this call, MAP is more efficient
 * in terms of its speed of search vs. use of space balance. */
size_t
objects_map_rightsize(objects_map_t *map);

/** Describing... **/

/* Returns a string describing (the contents of) MAP. */
NSString *
objects_map_description(objects_map_t *map);

/** Set theoretic operations... **/

objects_map_t *
objects_map_intersect_map(objects_map_t *map, objects_map_t *other_map);

objects_map_t *
objects_map_minus_map(objects_map_t *map, objects_map_t *other_map);

objects_map_t *
objects_map_union_map(objects_map_t *map, objects_map_t *other_map);

objects_hash_t *
objects_hash_init_from_map_keys(objects_hash_t *hash, objects_map_t *map);

objects_hash_t *
objects_hash_init_from_map_values(objects_hash_t *hash, objects_map_t *map);

#endif /* __map_h_OBJECTS_INCLUDE */
