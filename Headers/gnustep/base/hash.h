/* A hash table for use with Libobjects.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Sat Feb 10 15:35:37 EST 1996
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

#ifndef __hash_h_OBJECTS_INCLUDE
#define __hash_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <objects/allocs.h>
#include <objects/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _objects_hash objects_hash_t;
typedef struct _objects_hash_bucket objects_hash_bucket_t;
typedef struct _objects_hash_node objects_hash_node_t;
typedef struct _objects_hash_enumerator objects_hash_enumerator_t;

struct _objects_hash_node
  {
    objects_hash_t *hash;
    objects_hash_bucket_t *bucket;

    objects_hash_node_t *next_in_bucket;
    objects_hash_node_t *prev_in_bucket;
    objects_hash_node_t *next_in_hash;
    objects_hash_node_t *prev_in_hash;

    void *element;
  };

struct _objects_hash_bucket
  {
    size_t node_count;
    size_t element_count;

    objects_hash_node_t *first_node;
  };

struct _objects_hash
  {
    int magic;
    size_t number;
    char *name;
    void *extra;
    objects_callbacks_t extra_callbacks;
    objects_allocs_t allocs;

    /* Callbacks for the items in the hash. */
    objects_callbacks_t callbacks;

    /* Internal hash counters. */
    size_t bucket_count;	/* How many types of items? */
    size_t node_count;		/* How many items? */
    size_t element_count;	/* How many elements? */

    /* Places to start looking for elements. */
      objects_hash_bucket_t *buckets;
      objects_hash_node_t *first_node;
  };

struct _objects_hash_enumerator
  {
    objects_hash_t *hash;
    objects_hash_node_t *node;
  };

/**** Function Prototypes ****************************************************/

/** Basics **/

#include <objects/hash-basics.h>
#include <objects/hash-callbacks.h>

/** Hashing **/

size_t objects_hash_hash (objects_hash_t * hash);

/** Creating **/

objects_hash_t * objects_hash_alloc (void);

objects_hash_t * objects_hash_alloc_with_allocs (objects_allocs_t alloc);

objects_hash_t * objects_hash_with_callbacks (objects_callbacks_t callbacks);

objects_hash_t * objects_hash_with_allocs (objects_allocs_t allocs);

objects_hash_t * objects_hash_with_allocs_with_callbacks (objects_allocs_t allocs, objects_callbacks_t callbacks);

objects_hash_t * objects_hash_of_char_p (void);

objects_hash_t * objects_hash_of_void_p (void);

objects_hash_t * objects_hash_of_owned_void_p (void);

objects_hash_t * objects_hash_of_int (void);

objects_hash_t * objects_hash_of_id (void);

/** Initializing **/

objects_hash_t * objects_hash_init (objects_hash_t * hash);

objects_hash_t * objects_hash_init_with_callbacks (objects_hash_t * hash, objects_callbacks_t callbacks);

objects_hash_t * objects_hash_init_with_hash (objects_hash_t * hash, objects_hash_t * other_hash);

/** Copying **/

objects_hash_t * objects_hash_copy (objects_hash_t * old_hash);

objects_hash_t * objects_hash_copy_with_allocs (objects_hash_t * hash, objects_allocs_t new_allocs);

/** Mapping **/

/* WARNING: The mapping function FCN must be one-to-one on elements of
 * HASH.  I.e., for reasons of efficiency, `objects_hash_map_elements()'
 * makes no provision for the possibility that FCN maps two unequal
 * elements of HASH to the same (or equal) elements.  The better way
 * to handle functions that aren't one-to-one is to create a new hash
 * and transform the elements of the first to create the elements of
 * the second. */
objects_hash_t * objects_hash_map_elements (objects_hash_t * hash, void *(*fcn) (void *, void *), void *user_data);

/** Destroying **/

void objects_hash_dealloc (objects_hash_t * hash);

/** Comparing **/

int objects_hash_contains_hash (objects_hash_t * hash, objects_hash_t * other_hash);

int objects_hash_intersects_hash (objects_hash_t * hash, objects_hash_t * other_hash);

int objects_hash_is_equal_to_hash (objects_hash_t * hash, objects_hash_t * other_hash);

/** Adding **/

void *objects_hash_add_element_known_absent (objects_hash_t * hash, void *element);

void *objects_hash_add_element (objects_hash_t * hash, void *element);

void *objects_hash_add_element_if_absent (objects_hash_t * hash, void *element);

/** Replacing **/

void objects_hash_replace_element (objects_hash_t * hash, void *element);

/** Removing **/

void objects_hash_remove_element (objects_hash_t * hash, void *element);

/** Emptying **/

void objects_hash_empty (objects_hash_t * hash);

/** Searching **/

void *objects_hash_any_element (objects_hash_t * hash);

int objects_hash_contains_element (objects_hash_t * hash, void *element);

void *objects_hash_element (objects_hash_t * hash, void *element);

void **objects_hash_all_elements (objects_hash_t * hash);

/** Enumerating **/

objects_hash_enumerator_t objects_hash_enumerator (objects_hash_t * hash);

int objects_hash_enumerator_next_element (objects_hash_enumerator_t *enumerator, void **element);

/** Statistics **/

int objects_hash_is_empty (objects_hash_t * hash);

size_t objects_hash_count (objects_hash_t * hash);

size_t objects_hash_capacity (objects_hash_t * hash);

int objects_hash_check (objects_hash_t * hash);

/** Miscellaneous **/

size_t objects_hash_resize (objects_hash_t * hash, size_t new_capacity);

size_t objects_hash_rightsize (objects_hash_t * hash);

objects_hash_t * objects_hash_intersect_hash (objects_hash_t * hash, objects_hash_t * other_hash);

objects_hash_t * objects_hash_minus_hash (objects_hash_t * hash, objects_hash_t * other_hash);

objects_hash_t * objects_hash_union_hash (objects_hash_t * hash, objects_hash_t * other_hash);

#endif /* __hash_h_OBJECTS_INCLUDE */

