/* A sparse array structure.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Mar  2 02:30:02 EST 1994
 * Updated: Tue Mar 12 02:42:54 EST 1996
 * Serial: 96.03.12.13
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

#ifndef __array_h_GNUSTEP_BASE_INCLUDE
#define __array_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSZone.h>
#include <base/o_cbs.h>
#include <base/o_hash.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _o_array o_array_t;
typedef struct _o_array_bucket o_array_bucket_t;
typedef o_array_bucket_t *o_array_slot_t;
typedef struct _o_array_enumerator o_array_enumerator_t;

struct _o_array_bucket
{
  /* The bucket's real (or external) index */
  size_t index;

  /* The bucket's cargo */
  const void *element;
};

struct _o_array
{
  /* Identifying information. */
  int magic_number;
  size_t serial_number;
  NSString *name;
  const void *extra;
  o_callbacks_t extra_callbacks;

  /* Callbacks for the items in the array. */
  o_callbacks_t callbacks;

  /* Internal counters */
  size_t slot_count;
  size_t element_count;

  /* Databanks */
  o_array_slot_t *slots;
  o_array_slot_t *sorted_slots;
};

struct _o_array_enumerator
{
  o_array_t *array;
  size_t index;
  int is_sorted;
  int is_ascending;
};

/**** Function Prototypes ****************************************************/

/** Basics **/

#include <base/o_array_bas.h>
#include <base/o_array_cbs.h>

/** Creating **/

o_array_t *
o_array_alloc(void);

o_array_t *
o_array_alloc_with_zone(NSZone *zone);

o_array_t *
o_array(void);

o_array_t *
o_array_with_zone(NSZone *zone);

o_array_t *
o_array_with_zone_with_callbacks(NSZone *zone,
                                       o_callbacks_t callbacks);

o_array_t *
o_array_with_callbacks(o_callbacks_t callbacks);

o_array_t *
o_array_of_char_p(void);

o_array_t *
o_array_of_non_owned_void_p(void);

o_array_t *
o_array_of_owned_void_p(void);

o_array_t *
o_array_of_int(void);

o_array_t *
o_array_of_id(void);

/** Initializing **/

o_array_t *
o_array_init(o_array_t *array);

o_array_t *
o_array_init_with_callbacks(o_array_t *array,
                                  o_callbacks_t callbacks);

o_array_t *
o_array_init_with_array(o_array_t *array,
                              o_array_t *other_array);

/** Copying **/

o_array_t *
o_array_copy(o_array_t *array);

o_array_t *
o_array_copy_with_zone(o_array_t *array, NSZone *zone);

/** Destroying **/

void
o_array_dealloc(o_array_t *array);

/** Comparing **/

int
o_array_is_equal_to_array(o_array_t *array,
                                o_array_t *other_array);

/** Adding **/

const void *
o_array_at_index_put_element(o_array_t *array,
                                   size_t index,
                                   const void *element);

/** Replacing **/

/** Removing **/

void
o_array_remove_element_at_index(o_array_t *array, size_t index);

void
o_array_remove_element(o_array_t *array, const void *element);

void
o_array_remove_element_known_present(o_array_t *array,
                                           const void *element);

/** Emptying **/

void
o_array_empty(o_array_t *array);

/** Searching **/

int
o_array_contains_element(o_array_t *array, const void *element);

const void *
o_array_element(o_array_t *array, const void *element);

size_t
o_array_index_of_element(o_array_t *array, const void *element);

const void *
o_array_element_at_index(o_array_t *array, size_t index);

const void **
o_array_all_elements(o_array_t *array);

const void **
o_array_all_elements_ascending(o_array_t *array);

const void **
o_array_all_element_descending(o_array_t *array);

/** Enumerating **/

o_array_enumerator_t
o_array_enumerator(o_array_t *array);

o_array_enumerator_t
o_array_ascending_enumerator(o_array_t *array);

o_array_enumerator_t
o_array_descending_enumerator(o_array_t *array);

int
o_array_enumerator_next_index_and_element(o_array_enumerator_t *enumerator,
                                                size_t *index,
                                                const void **element);

int
o_array_enumerator_next_element(o_array_enumerator_t *enumerator,
                                      const void **element);

int
o_array_enumerator_next_index(o_array_enumerator_t *enumerator,
                                    size_t *element);

/** Statistics **/

int
o_array_is_empty(o_array_t *array);

size_t
o_array_count(o_array_t *array);

size_t
o_array_capacity(o_array_t *array);

int
o_array_check(o_array_t *array);

/** Miscellaneous **/

o_hash_t *
o_hash_init_from_array(o_hash_t *hash, o_array_t *array);

#endif /* __array_h_GNUSTEP_BASE_INCLUDE */
