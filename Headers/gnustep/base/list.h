/* A list structure.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Sep  5 17:25:59 EDT 1995
 * Updated: Sun Mar 10 23:24:49 EST 1996
 * Serial: 96.03.10.02
 * 
 * This file is part of the Gnustep Base Library.
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

#ifndef __list_h_GNUSTEP_BASE_INCLUDE
#define __list_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <gnustep/base/callbacks.h>
#include <gnustep/base/hash.h>
#include <gnustep/base/array.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _o_list o_list_t;
typedef struct _o_list_node o_list_node_t;
typedef struct _o_list_enumerator o_list_enumerator_t;

struct _o_list_node
{
  o_list_t *list;

  o_list_node_t *next_in_list;
  o_list_node_t *prev_in_list;

  const void *element;
};

struct _o_list
{
  /* Container identifiers */
  int magic_number;
  size_t serial_number;
  NSZone *zone;
  NSString *name;
  const void *extra;
  o_callbacks_t extra_callbacks;

  /* Element callbacks */
  o_callbacks_t callbacks;

  /* Internal counters */
  size_t node_count;
  size_t element_count;

  /* Databanks */
  o_list_node_t *first_node;
  o_list_node_t *last_node;
};

struct _o_list_enumerator
{
  o_list_t *list;
  o_list_node_t *node;
  size_t forward;
};


/**** Function Prototypes ****************************************************/

/** Basics **/

#include <gnustep/base/list-bas.h>
#include <gnustep/base/list-cbs.h>

/** Creating **/

o_list_t *
o_list_alloc(void);

o_list_t *
o_list_alloc_with_zone(NSZone *zone);

o_list_t *
o_list_with_zone(NSZone *zone);

o_list_t *
o_list_with_callbacks(o_callbacks_t callbacks);

o_list_t *
o_list_with_zone_with_callbacks(NSZone *zone,
                                      o_callbacks_t callbacks);

o_list_t *
o_list_of_char_p(void);

o_list_t *
o_list_of_non_owned_void_p(void);

o_list_t *
o_list_of_owned_void_p(void);

o_list_t *
o_list_of_int(void);

o_list_t *
o_list_of_int_p(void);

o_list_t *
o_list_of_id(void);

/** Initializing **/

o_list_t *
o_list_init(o_list_t *list);

o_list_t *
o_list_init_with_callbacks(o_list_t *list,
                                 o_callbacks_t callbacks);

/** Copying **/

o_list_t *
o_list_copy(o_list_t *old_list);

o_list_t *
o_list_copy_with_zone(o_list_t *old_list,
                            NSZone *zone);

/** Destroying **/

void
o_list_dealloc(o_list_t *list);

/** Comparing **/

int
o_list_is_equal_to_list(o_list_t *list,
                              o_list_t *other_list);

/** Concatenating **/

o_list_t *
o_list_append_list(o_list_t *base_list,
                         o_list_t *suffix_list);

o_list_t *
o_list_prepend_list(o_list_t *base_list,
                          o_list_t *prefix_list);

o_list_t *
o_list_at_index_insert_list(o_list_t *base_list,
                                  long int n,
                                  o_list_t *infix_list);

/** Permuting **/

o_list_t *
o_list_roll_to_nth_element(o_list_t *list, long int n);

o_list_t *
o_list_roll_to_element(o_list_t *list, const void *element);

o_list_t *
o_list_roll_to_nth_occurrance_of_element(o_list_t *list,
                                               long int n,
                                               const void *element);

o_list_t *
o_list_invert(o_list_t *list);

o_list_t *
o_list_swap_elements_at_indices(o_list_t *list,
                                      long int m,
                                      long int n);

/** Adding **/

const void *
o_list_append_element(o_list_t *list, const void *element);

const void *
o_list_append_element_if_absent(o_list_t *list,
                                      const void *element);

const void *
o_list_prepend_element(o_list_t *list, const void *element);

const void *
o_list_prepend_element_if_absent(o_list_t *list,
                                       const void *element);

const void *
o_list_at_index_insert_element(o_list_t *list,
                                     long int n,
                                     const void *element);

const void *
o_list_at_index_insert_element_if_absent(o_list_t *list,
                                               long int n,
                                               const void *element);

const void *
o_list_queue_push_element(o_list_t *list, const void *element);

const void *
o_list_stack_push_element(o_list_t *list, const void *element);

/** Replacing **/

void
o_list_replace_nth_occurrance_of_element(o_list_t *list,
                                               long int n,
                                               const void *old_element,
                                               const void *new_element);

void
o_list_replace_element(o_list_t *list,
                             const void *old_element,
                             const void *new_element);

void
o_list_replace_nth_element(o_list_t *list,
                                 long int n,
                                 const void *new_element);

void
o_list_replace_first_element(o_list_t *list,
                                   const void *new_element);

void
o_list_replace_last_element(o_list_t *list,
                                  const void *new_element);

/** Removing **/

void
o_list_remove_nth_occurrence_of_element(o_list_t *list,
                                              long int n,
                                              const void *element);

void
o_list_remove_element(o_list_t *list, const void *element);

void
o_list_remove_nth_element(o_list_t *list, long int n);

void
o_list_remove_first_element(o_list_t *list);

void
o_list_remove_last_element(o_list_t *list);

void
o_list_queue_pop_element(o_list_t *list);

void
o_list_queue_pop_nth_element(o_list_t *list, long int n);

void
o_list_stack_pop_element(o_list_t *list);

void
o_list_stack_pop_nth_element(o_list_t *list, long int n);

/** Emptying **/

void
o_list_empty(o_list_t *list);

/** Searching **/

int
o_list_contains_element(o_list_t *list, const void *element);

const void *
o_list_element(o_list_t *list, const void *element);

const void *
o_list_nth_element(o_list_t *list, long int n);

const void *
o_list_first_element(o_list_t *list);

const void *
o_list_last_element(o_list_t *list);

const void **
o_list_all_elements(o_list_t *list);

/** Enumerating **/

o_list_enumerator_t
o_list_enumerator(o_list_t *list);

o_list_enumerator_t
o_list_forward_enumerator(o_list_t *list);

o_list_enumerator_t
o_list_reverse_enumerator(o_list_t *list);

int
o_list_enumerator_next_element(o_list_enumerator_t *enumerator,
                                     const void **element);

/** Mapping **/

/* NO WARNING: The mapping function FCN need not be one-to-one on the
 * elements of LIST.  In fact, FCN may do whatever it likes. */
o_list_t *
o_list_map_elements(o_list_t *list,
                          const void *(*fcn)(const void *, void *),
                          void *user_data);

/** Statistics **/

int
o_list_is_empty(o_list_t *list);

size_t
o_list_count(o_list_t *list);

size_t
o_list_capacity(o_list_t *list);

int
o_list_check(o_list_t *list);

/** Miscellaneous **/

o_hash_t *
o_hash_init_from_list(o_hash_t *hash, o_list_t *list);

#endif /* __list_h_GNUSTEP_BASE_INCLUDE */
