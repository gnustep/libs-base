/* A map table.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Thu Mar 21 00:05:43 EST 1996
 * Serial: 96.03.20.04
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA. */ 

#ifndef __map_h_GNUSTEP_BASE_INCLUDE
#define __map_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <base/o_cbs.h>
#include <base/o_hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Need these up here because of their interdependence. */
typedef struct _o_map o_map_t;
typedef struct _o_map_bucket o_map_bucket_t;
typedef struct _o_map_node o_map_node_t;
typedef struct _o_map_enumerator o_map_enumerator_t;

/* Important structures... */

/* Private type for elemental holding. */
struct _o_map_node
{
  /* The map table with which the node is associated. */
  o_map_t *map;

  /* The bucket in MAP in which the node sits. */
  o_map_bucket_t *bucket;

  /* These hold the BUCKET linked list together. */
  o_map_node_t *next_in_bucket;
  o_map_node_t *prev_in_bucket;

  /* For enumerating over the whole map table.  These make
   * enumerating much quicker.  They also make it safer. */
  o_map_node_t *next_in_map;
  o_map_node_t *prev_in_map;

  const void *key;
  const void *value;
};

/* Private type for holding chains of nodes. */
struct _o_map_bucket
{
  /* The number of nodes in this bucket.  For internal consistency checks. */
  size_t node_count;

  /* The number of elements in this bucket.  (This had *better* be
   * the same as NODE_COUNT, or something's wrong.) */
  size_t element_count;

  /* The head of this bucket's linked list of nodes. */
  o_map_node_t *first_node;
};

/* The map table type. */
struct _o_map
{
  /* All structures have these... 
   * And all structures have them in the same order. */
  int magic_number;
  size_t serial_number;
  NSString *name;
  const void *extra;
  o_callbacks_t extra_callbacks;

  /* For keys...And Values. */
  o_callbacks_t key_callbacks;
  o_callbacks_t value_callbacks;

  /* Internal counters */
  size_t bucket_count;
  size_t node_count;
  size_t element_count;

  /* Places to start looking for elements. */
  o_map_bucket_t *buckets;   /* Organized as a hash. */
  o_map_node_t *first_node;  /* Organized as a linked list.
                                     * (For enumerating...) */
};

/* Type for enumerating the elements of a map table. */
struct _o_map_enumerator
{
  o_map_t *map;        /* To which hash do I belong? */
  o_map_node_t *node;  /* Which node is next? */
};

/**** Function Prototypes ****************************************************/

/** Basics... **/

/* All the structures (hashes, maps, lists, and arrays) have
 * the same basic ideas behind them. */

#include <base/o_map_bas.h>
#include <base/o_map_cbs.h>

/** Callbacks... **/

/* Returns a collection of callbacks for use with hash tables. */
o_callbacks_t
o_callbacks_for_map(void);

/** Creating... **/

/* Allocate a hash table in the default zone. */
o_map_t *
o_map_alloc(void);

/* Allocate a hash table in the memory block ZONE. */
o_map_t *
o_map_alloc_with_zone(NSZone *zone);

/* Create an empty map table in the memory block ZONE.  The returned
 * hash table has a "reasonable" default capacity, but will need to
 * be resized to suit your specific needs if more than a couple of
 * dozen key/value pairs will be placed within it. */
o_map_t *
o_map_with_zone_with_callbacks(NSZone *zone,
                                     o_callbacks_t key_callbacks,
                                     o_callbacks_t value_callbacks);

/* Like calling 'o_map_with_zone_with_callbacks(0, key_callbacks,
 * value_callbacks)'. */
o_map_t *
o_map_with_callbacks(o_callbacks_t key_callbacks,
                           o_callbacks_t value_callbacks);

/* Like calling 'o_map_with_zone_with_callbacks(0,
 * o_callbacks_standard(), o_callbacks_standard())'. */
o_map_t *
o_map_with_zone(NSZone *zone);

/* Shortcuts... */
o_map_t *o_map_of_int(void);
o_map_t *o_map_of_int_to_char_p(void);
o_map_t *o_map_of_int_to_non_owned_void_p(void);
o_map_t *o_map_of_int_to_id(void);
o_map_t *o_map_of_char_p(void);
o_map_t *o_map_of_char_p_to_int(void);
o_map_t *o_map_of_char_p_to_non_owned_void_p(void);
o_map_t *o_map_of_char_p_to_id(void);
o_map_t *o_map_of_non_owned_void_p(void);
o_map_t *o_map_of_non_owned_void_p_to_int(void);
o_map_t *o_map_of_non_owned_void_p_to_char_p(void);
o_map_t *o_map_of_non_owned_void_p_to_id(void);
o_map_t *o_map_of_id(void);

/** Initializing... **/

o_map_t *
o_map_init(o_map_t *map);

o_map_t *
o_map_init_with_callbacks(o_map_t *map,
                                o_callbacks_t key_callbacks,
                                o_callbacks_t value_callbacks);

o_map_t *
object_map_init_from_map(o_map_t *map, o_map_t *old_map);

/** Destroying... **/

/* Releases all the keys and values of MAP, and then
 * deallocates MAP itself. */
void
o_map_dealloc(o_map_t *map);

/** Gathering statistics on a map... **/

/* Returns the number of key/value pairs in MAP. */
size_t
o_map_count(o_map_t *map);

/* Returns some (inexact) measure of how many key/value pairs
 * MAP can comfortably hold without resizing. */
size_t
o_map_capacity(o_map_t *map);

/* Performs an internal consistency check, returns 'true' if
 * everything is OK, 'false' otherwise.  Really useful only
 * for debugging. */
int
o_map_check(o_map_t *map);

/** Finding elements in a map... **/

/* Returns 'true' if and only if some key in MAP is equal
 * (in the sense of the key callbacks of MAP) to KEY. */
int
o_map_contains_key(o_map_t *map, const void *key);

/* Returns 'true' if and only if some value in MAP is equal
 * (in the sense of the value callbacks of MAP) to VALUE. */
/* WARNING: This is rather inefficient.  Not to be used lightly. */
int
o_map_contains_value(o_map_t *map, const void *value);

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
o_map_key_and_value_at_key(o_map_t *map,
                                 const void **old_key,
                                 const void **value,
                                 const void *key);

/* If KEY is in MAP, then the key of MAP which is equal to KEY
 * is returned.  Otherwise, the "not a key marker" for MAP is returned. */
const void *
o_map_key_at_key(o_map_t *map, const void *key);

/* If KEY is in MAP, then the value of MAP which to which KEY maps
 * is returned.  Otherwise, the "not a value marker" for MAP is returned. */
const void *
o_map_value_at_key(o_map_t *map, const void *key);

/** Enumerating the nodes and elements of a map... **/

o_map_enumerator_t
o_map_enumerator_for_map(o_map_t *map);

int
o_map_enumerator_next_key_and_value(o_map_enumerator_t *enumerator,
                                          const void **key,
                                          const void **value);

int
o_map_enumerator_next_key(o_map_enumerator_t *enumerator,
                                const void **key);

int
o_map_enumerator_next_value(o_map_enumerator_t *enumerator,
                                  const void **value);

/** Obtaining an array of the elements of a map... **/

const void **
o_map_all_keys_and_values(o_map_t *map);

const void **
o_map_all_keys(o_map_t *map);

const void **
o_map_all_values(o_map_t *map);

/** Removing... **/

/* Removes the key/value pair (if any) from MAP whose key is KEY. */
void
o_map_remove_key(o_map_t *map, const void *key);

/* Releases all of the keys and values of MAP without
 * altering MAP's capacity. */
void
o_map_empty(o_map_t *map);

/** Adding... **/

const void *
o_map_at_key_put_value_known_absent(o_map_t *map,
                                          const void *key,
                                          const void *value);

const void *
o_map_at_key_put_value(o_map_t *map,
                             const void *key,
                             const void *value);

const void *
o_map_at_key_put_value_if_absent(o_map_t *map,
                                       const void *key,
                                       const void *value);

/** Replacing... **/

void
o_map_replace_key(o_map_t *map, const void *key);

/** Comparing... **/

/* Returns 'true' if every key/value pair of MAP2 is also a key/value pair
 * of MAP1.  Otherwise, returns 'false'. */
int
o_map_contains_map(o_map_t *map1, o_map_t *map2);

/* Returns 'true' if MAP1 and MAP2 have the same number of key/value pairs,
 * MAP1 contains MAP2, and MAP2 contains MAP1.  Otherwise, returns 'false'. */
int
o_map_is_equal_to_map(o_map_t *map1, o_map_t *map2);

/* Returns 'true' iff every key of MAP2 is a key of MAP1. */
int
o_map_keys_contain_keys_of_map(o_map_t *map1, o_map_t *map2);

/* Returns 'true' if MAP1 and MAP2 have the same number of key/value pairs,
 * MAP1 contains every key of MAP2, and MAP2 contains every key of MAP1.
 * Otherwise, returns 'false'. */
int
o_map_keys_are_equal_to_keys_of_map(o_map_t *map1,
                                          o_map_t *map2);

/* Returns 'true' iff some key/value pair of MAP1 if also
 * a key/value pair of MAP2. */
int
o_map_intersects_map(o_map_t *map1, o_map_t *map2);

/* Returns 'true' iff some key of MAP1 if also a key of MAP2. */
int
o_map_keys_intersect_keys_of_map(o_map_t *map1,
                                       o_map_t *map2);
/** Copying... **/

/* Returns a copy of OLD_MAP in ZONE.  Remember that, as far as what
 * (if anything) OLD_MAP's keys and values point to, this copy is
 * shallow.  If, for example, OLD_MAP is a map from int to int, then
 * you've got nothing more to worry about.  If, however, OLD_MAP is a
 * map from id to id, and you want the copy of OLD_MAP to be "deep",
 * you'll need to use the mapping functions below to make copies of
 * all of the returned map's elements. */
o_map_t *
o_map_copy_with_zone(o_map_t *old_map, NSZone *zone);

/* Just like 'o_map_copy_with_zone()', but returns a copy of
 * OLD_MAP in the default zone. */
o_map_t *
o_map_copy(o_map_t *old_map);

/** Mapping... **/

/* Iterates through MAP, replacing each key with the result of
 * '(*kfcn)(key, user_data)'.  Useful for deepening copied maps
 * and other uniform (and one-to-one) transformations of map keys. */
/* WARNING: The mapping function KFCN *must* be one-to-one on the
 * (equivalence classes of) keys of MAP.  I.e., for efficiency's sake,
 * `o_map_map_keys()' makes no provision for the possibility
 * that KFCN maps two unequal keys of MAP to the same (or equal) keys. */
o_map_t *
o_map_map_keys(o_map_t *map,
                     const void *(*kfcn)(const void *, void *),
                     void *user_data);

/* Iterates through MAP, replacing each value with the result of
 * '(*vfcn)(value, user_data)'.  Useful for deepening copied maps
 * and other uniform transformations of map keys. */
/* NO WARNING: The mapping function VFCN need not be one-to-one on
 * (the equivalence classes of) values. */
o_map_t *
o_map_map_values(o_map_t *map,
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
o_map_resize(o_map_t *map, size_t new_capacity);

/* Shrinks (or grows) MAP to be comfortable with the number of elements
 * it contains.  In all likelyhood, after this call, MAP is more efficient
 * in terms of its speed of search vs. use of space balance. */
size_t
o_map_rightsize(o_map_t *map);

/** Describing... **/

/* Returns a string describing (the contents of) MAP. */
NSString *
o_map_description(o_map_t *map);

/** Set theoretic operations... **/

o_map_t *
o_map_intersect_map(o_map_t *map, o_map_t *other_map);

o_map_t *
o_map_minus_map(o_map_t *map, o_map_t *other_map);

o_map_t *
o_map_union_map(o_map_t *map, o_map_t *other_map);

o_hash_t *
o_hash_init_from_map_keys(o_hash_t *hash, o_map_t *map);

o_hash_t *
o_hash_init_from_map_values(o_hash_t *hash, o_map_t *map);

#endif /* __map_h_GNUSTEP_BASE_INCLUDE */
