/* A sparse array structure.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Mar  2 02:30:02 EST 1994
 * Updated: Tue Mar 12 02:42:54 EST 1996
 * Serial: 96.03.12.13
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

#ifndef __array_h_OBJECTS_INCLUDE
#define __array_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSZone.h>
#include <objects/callbacks.h>
#include <objects/hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _objects_array objects_array_t;
typedef struct _objects_array_bucket objects_array_bucket_t;
typedef objects_array_bucket_t *objects_array_slot_t;
typedef struct _objects_array_enumerator objects_array_enumerator_t;

struct _objects_array_bucket
{
  /* The bucket's real (or external) index */
  size_t index;

  /* The bucket's cargo */
  const void *element;
};

struct _objects_array
{
  /* Identifying information. */
  int magic_number;
  size_t serial_number;
  NSZone *zone;
  NSString *name;
  const void *extra;
  objects_callbacks_t extra_callbacks;

  /* Callbacks for the items in the array. */
  objects_callbacks_t callbacks;

  /* Internal counters */
  size_t slot_count;
  size_t element_count;

  /* Databanks */
  objects_array_slot_t *slots;
  objects_array_slot_t *sorted_slots;
};

struct _objects_array_enumerator
{
  objects_array_t *array;
  size_t index;
  int is_sorted;
  int is_ascending;
};

/**** Function Prototypes ****************************************************/

/** Basics **/

#include <objects/array-bas.h>
#include <objects/array-cbs.h>

/** Creating **/

objects_array_t *
objects_array_alloc(void);

objects_array_t *
objects_array_alloc_with_zone(NSZone *zone);

objects_array_t *
objects_array(void);

objects_array_t *
objects_array_with_zone(NSZone *zone);

objects_array_t *
objects_array_with_zone_with_callbacks(NSZone *zone,
                                       objects_callbacks_t callbacks);

objects_array_t *
objects_array_with_callbacks(objects_callbacks_t callbacks);

objects_array_t *
objects_array_of_char_p(void);

objects_array_t *
objects_array_of_non_owned_void_p(void);

objects_array_t *
objects_array_of_owned_void_p(void);

objects_array_t *
objects_array_of_int(void);

objects_array_t *
objects_array_of_id(void);

/** Initializing **/

objects_array_t *
objects_array_init(objects_array_t *array);

objects_array_t *
objects_array_init_with_callbacks(objects_array_t *array,
                                  objects_callbacks_t callbacks);

objects_array_t *
objects_array_init_with_array(objects_array_t *array,
                              objects_array_t *other_array);

/** Copying **/

objects_array_t *
objects_array_copy(objects_array_t *array);

objects_array_t *
objects_array_copy_with_zone(objects_array_t *array, NSZone *zone);

/** Destroying **/

void
objects_array_dealloc(objects_array_t *array);

/** Comparing **/

int
objects_array_is_equal_to_array(objects_array_t *array,
                                objects_array_t *other_array);

/** Adding **/

const void *
objects_array_at_index_put_element(objects_array_t *array,
                                   size_t index,
                                   const void *element);

/** Replacing **/

/** Removing **/

void
objects_array_remove_element_at_index(objects_array_t *array, size_t index);

void
objects_array_remove_element(objects_array_t *array, const void *element);

void
objects_array_remove_element_known_present(objects_array_t *array,
                                           const void *element);

/** Emptying **/

void
objects_array_empty(objects_array_t *array);

/** Searching **/

int
objects_array_contains_element(objects_array_t *array, const void *element);

const void *
objects_array_element(objects_array_t *array, const void *element);

size_t
objects_array_index_of_element(objects_array_t *array, const void *element);

const void *
objects_array_element_at_index(objects_array_t *array, size_t index);

const void **
objects_array_all_elements(objects_array_t *array);

const void **
objects_array_all_elements_ascending(objects_array_t *array);

const void **
objects_array_all_element_descending(objects_array_t *array);

/** Enumerating **/

objects_array_enumerator_t
objects_array_enumerator(objects_array_t *array);

objects_array_enumerator_t
objects_array_ascending_enumerator(objects_array_t *array);

objects_array_enumerator_t
objects_array_descending_enumerator(objects_array_t *array);

int
objects_array_enumerator_next_index_and_element(objects_array_enumerator_t *enumerator,
                                                size_t *index,
                                                const void **element);

int
objects_array_enumerator_next_element(objects_array_enumerator_t *enumerator,
                                      const void **element);

int
objects_array_enumerator_next_index(objects_array_enumerator_t *enumerator,
                                    size_t *element);

/** Statistics **/

int
objects_array_is_empty(objects_array_t *array);

size_t
objects_array_count(objects_array_t *array);

size_t
objects_array_capacity(objects_array_t *array);

int
objects_array_check(objects_array_t *array);

/** Miscellaneous **/

objects_hash_t *
objects_hash_init_from_array(objects_hash_t *hash, objects_array_t *array);

#endif /* __array_h_OBJECTS_INCLUDE */
