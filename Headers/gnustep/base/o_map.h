/* A map table for use with Libobjects.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Sat Feb 10 13:36:59 EST 1996
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

#ifndef __map_h_OBJECTS_INCLUDE
#define __map_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <objects/allocs.h>
#include <objects/callbacks.h>
#include <objects/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _objects_map objects_map_t;
typedef struct _objects_map_bucket objects_map_bucket_t;
typedef struct _objects_map_node objects_map_node_t;
typedef struct _objects_map_enumerator objects_map_enumerator_t;

/* Important structures... */

struct _objects_map_node
{
  const void *key;
  const void *value;

  objects_map_bucket_t *bucket;
  objects_map_t *map;

  objects_map_node_t *next_in_bucket;
  objects_map_node_t *prev_in_bucket;
  objects_map_node_t *next_in_map;
  objects_map_node_t *prev_in_map;
};

struct _objects_map_bucket
{
  size_t node_count;
  size_t element_count;

  objects_map_node_t *first_node;
};

struct _objects_map
{
  /* Container identifiers */
  int magic;
  size_t number;
  char *name;
  const void *extra;
  objects_callbacks_t extra_callbacks;
  objects_allocs_t allocs;
  objects_callbacks_t key_callbacks;

    /* Management information */
  objects_callbacks_t value_callbacks;

  /* Internal counters */
  size_t bucket_count;
  size_t node_count;
  size_t element_count;

  /* Databanks */
  objects_map_bucket_t *buckets;
  objects_map_node_t *first_node;
};

struct _objects_map_enumerator
{
  objects_map_t *map;
  objects_map_node_t *node;
};

/**** Function Prototypes ****************************************************/

/** Basics **/

#include <objects/map-basics.h>
#include <objects/map-callbacks.h>

/** Altering capacity **/

size_t
objects_map_resize (objects_map_t * map, size_t new_capacity);

size_t
objects_map_rightsize (objects_map_t * map);

/** Creating **/

objects_map_t *
objects_map_alloc (void);

objects_map_t *
objects_map_alloc_with_allocs (objects_allocs_t allocs);

objects_map_t *
objects_map (void);

objects_map_t *
objects_map_with_allocs (objects_allocs_t allocs);

objects_map_t *
objects_map_with_allocs_with_callbacks (objects_allocs_t allocs,
					objects_callbacks_t key_callbacks,
					objects_callbacks_t value_callbacks);

objects_map_t *
objects_map_with_callbacks (objects_callbacks_t key_callbacks,
			    objects_callbacks_t value_callbacks);

objects_map_t *
objects_map_of_int (void);

objects_map_t *
objects_map_of_int_to_char_p (void);

objects_map_t *
objects_map_of_int_to_void_p (void);

objects_map_t *
objects_map_of_int_to_float (void);

objects_map_t *
objects_map_of_char_p (void);

objects_map_t *
objects_map_of_char_p_to_int (void);

objects_map_t *
objects_map_of_char_p_to_void_p (void);

objects_map_t *
objects_map_of_char_p_to_float (void);

objects_map_t *
objects_map_of_void_p (void);

objects_map_t *
objects_map_of_void_p_to_int (void);

objects_map_t *
objects_map_of_void_p_to_char_p (void);

objects_map_t *
objects_map_of_void_p_to_float (void);

objects_map_t *
objects_map_of_float (void);

objects_map_t *
objects_map_of_double (void);

/** Initializing **/

objects_map_t *
objects_map_init (objects_map_t * map);

objects_map_t *
objects_map_init_with_callbacks (objects_map_t * map,
				 objects_callbacks_t key_callbacks,
				 objects_callbacks_t value_callbacks);

/** Destroying **/

void
objects_map_dealloc (objects_map_t * map);

/** Gathering statistics on a mapionary **/

size_t
objects_map_pair_count (objects_map_t * map);

size_t
objects_map_capacity (objects_map_t * map);

int
objects_map_check_map (objects_map_t * map);

/** Finding elements in a mapionary **/

int
objects_map_contains_key (objects_map_t * map, const void *key);

int
objects_map_key_and_value (objects_map_t * map,
			   const void *key,
			   void **old_key,
			   void **value);

const void *
objects_map_key (objects_map_t * map, const void *key);

const void *
objects_map_value_at_key (objects_map_t * map, const void *key);

/** Enumerating the nodes and elements of a mapionary **/

objects_map_enumerator_t
objects_map_enumerator (objects_map_t * map);

int
objects_map_enumerator_next_key_and_value (objects_map_enumerator_t *enumeratr,
					   const void **key,
					   const void **value);

int
objects_map_enumerator_next_key (objects_map_enumerator_t * enumerator,
				 const void **key);

int
objects_map_enumerator_next_value (objects_map_enumerator_t * enumerator,
				   const void **value);

/** Obtaining an array of the elements of a mapionary **/

const void **
objects_map_all_keys_and_values (objects_map_t * map);

const void **
objects_map_all_keys (objects_map_t * map);

const void **
objects_map_all_values (objects_map_t * map);

/** Removing **/

void
objects_map_remove_key (objects_map_t * map, const void *key);

void
objects_map_empty (objects_map_t * map);

/** Adding **/

const void *
objects_map_at_key_put_value_known_absent (objects_map_t * map,
					   const void *key,
					   const void *value);

const void *
objects_map_at_key_put_value (objects_map_t * map,
			      const void *key,
			      const void *value);

const void *
objects_map_at_key_put_value_if_absent (objects_map_t * map,
					const void *key,
					const void *value);

/** Replacing **/

void
objects_map_replace_key (objects_map_t * map, const void *key);

/** Comparing **/

int
objects_map_contains_map (objects_map_t * map1, objects_map_t * map2);

int
objects_map_is_equal_to_map (objects_map_t * map1, objects_map_t * map2);

/** Copying **/

objects_map_t *
objects_map_copy_with_allocs (objects_map_t * old_map, objects_allocs_t new_allocs);

objects_map_t *
objects_map_copy (objects_map_t * old_map);

/** Mapping **/

/* WARNING: The mapping function KFCN must be one-to-one on the keys
 * of MAP.  I.e., `objects_map_map_keys()' makes no provision for the
 * possibility that KFCN maps two unequal keys of MAP to the same (or
 * equal) keys. */
objects_map_t *
objects_map_map_keys (objects_map_t * map,
		      const void *(*kfcn) (const void *, const void *),
		      const void *user_data);

/* NO WARNING: The mapping function VFCN need not be one-to-one on
 * (the equivalence classes of) values. */
objects_map_t *
objects_map_map_values (objects_map_t * map,
			const void *(*vfcn) (const void *, const void *),
			const void *user_data);

/** Miscellaneous **/

objects_map_t *
objects_map_intersect_map (objects_map_t * map, objects_map_t * other_map);

objects_map_t *
objects_map_minus_map (objects_map_t * map, objects_map_t * other_map);

objects_map_t *
objects_map_union_map (objects_map_t * map, objects_map_t * other_map);

objects_hash_t *
objects_hash_init_from_map_keys (objects_hash_t * hash, objects_map_t * map);

objects_hash_t *
objects_hash_init_from_map_values (objects_hash_t * hash, objects_map_t * map);

#endif /* __map_h_OBJECTS_INCLUDE */
