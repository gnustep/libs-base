/* A list for use with Libobjects.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Sep  5 17:25:59 EDT 1995
 * Updated: Sat Feb 10 15:37:41 EST 1996
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

#ifndef __list_h_OBJECTS_INCLUDE
#define __list_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <objects/allocs.h>
#include <objects/callbacks.h>
#include <objects/hash.h>
#include <objects/array.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef struct _objects_list objects_list_t;
typedef struct _objects_list_node objects_list_node_t;
typedef struct _objects_list_enumerator objects_list_enumerator_t;

struct _objects_list_node
  {
    objects_list_t * list;

    objects_list_node_t *next_in_list;
    objects_list_node_t *prev_in_list;

    void *element;
  };

struct _objects_list
  {
    /* Container identifiers */
    int magic;
    size_t number;
    char *name;
    void *extra;
    objects_callbacks_t extra_callbacks;
    objects_allocs_t allocs;

    /* Element callbacks */
    objects_callbacks_t callbacks;

    /* Internal counters */
    size_t node_count;
    size_t element_count;

    /* Databanks */
    objects_list_node_t *first_node;
    objects_list_node_t *last_node;
  };

struct _objects_list_enumerator
  {
    objects_list_t *list;
    objects_list_node_t *node;
    size_t forward;
  };


/**** Function Prototypes ****************************************************/

/** Basics **/

#include <objects/list-basics.h>
#include <objects/list-callbacks.h>

/** Creating **/

objects_list_t * objects_list_alloc (void);

objects_list_t * objects_list_alloc_with_allocs (objects_allocs_t allocs);

objects_list_t * objects_list_with_allocs (objects_allocs_t allocs);

objects_list_t * objects_list_with_callbacks (objects_callbacks_t callbacks);

objects_list_t * objects_list_with_allocs_with_callbacks (objects_allocs_t allocs, objects_callbacks_t callbacks);

objects_list_t * objects_list_of_char_p (void);

objects_list_t * objects_list_of_void_p (void);

objects_list_t * objects_list_of_owned_void_p (void);

objects_list_t * objects_list_of_int (void);

objects_list_t * objects_list_of_int_p (void);

objects_list_t * objects_list_of_id (void);

/** Initializing **/

objects_list_t * objects_list_init (objects_list_t * list);

objects_list_t * objects_list_init_with_callbacks (objects_list_t * list, objects_callbacks_t callbacks);

/** Copying **/

objects_list_t * objects_list_copy (objects_list_t * old_list);

objects_list_t * objects_list_copy_with_allocs (objects_list_t * old_list, objects_allocs_t allocs);

/** Destroying **/

void objects_list_dealloc (objects_list_t * list);

/** Comparing **/

int objects_list_is_equal_to_list (objects_list_t * list, objects_list_t * other_list);

/** Concatenating **/

objects_list_t * objects_list_append_list (objects_list_t * base_list, objects_list_t * suffix_list);

objects_list_t * objects_list_prepend_list (objects_list_t * base_list, objects_list_t * prefix_list);

objects_list_t * objects_list_at_index_insert_list (objects_list_t * base_list, long int n, objects_list_t * infix_list);

/** Permuting **/

objects_list_t * objects_list_roll_to_nth_element (objects_list_t * list, long int n);

objects_list_t * objects_list_roll_to_element (objects_list_t * list, void *element);

objects_list_t * objects_list_roll_to_nth_occurrance_of_element (objects_list_t * list, long int n, void *element);

objects_list_t * objects_list_invert (objects_list_t * list);

objects_list_t * objects_list_swap_elements_at_indices (objects_list_t * list, long int m, long int n);

/** Adding **/

void *objects_list_append_element (objects_list_t * list, void *element);

void *objects_list_append_element_if_absent (objects_list_t * list, void *element);

void *objects_list_prepend_element (objects_list_t * list, void *element);

void *objects_list_prepend_element_if_absent (objects_list_t * list, void *element);

void *objects_list_at_index_insert_element (objects_list_t * list, long int n, void *element);

void *objects_list_at_index_insert_element_if_absent (objects_list_t * list, long int n, void *element);

void *objects_list_queue_push_element (objects_list_t * list, void *element);

void *objects_list_stack_push_element (objects_list_t * list, void *element);

/** Replacing **/

void objects_list_replace_nth_occurrance_of_element (objects_list_t * list, long int n, void *old_element, void *new_element);

void objects_list_replace_element (objects_list_t * list, void *old_element, void *new_element);

void objects_list_replace_nth_element (objects_list_t * list, long int n, void *new_element);

void objects_list_replace_first_element (objects_list_t * list, void *new_element);

void objects_list_replace_last_element (objects_list_t * list, void *new_element);

/** Removing **/

void objects_list_remove_nth_occurrence_of_element (objects_list_t * list, long int n, void *element);

void objects_list_remove_element (objects_list_t * list, void *element);

void objects_list_remove_nth_element (objects_list_t * list, long int n);

void objects_list_remove_first_element (objects_list_t * list);

void objects_list_remove_last_element (objects_list_t * list);

void objects_list_queue_pop_element (objects_list_t * list);

void objects_list_queue_pop_nth_element (objects_list_t * list, long int n);

void objects_list_stack_pop_element (objects_list_t * list);

void objects_list_stack_pop_nth_element (objects_list_t * list, long int n);

/** Emptying **/

void objects_list_empty (objects_list_t * list);

/** Searching **/

int objects_list_contains_element (objects_list_t * list, void *element);

void *objects_list_element (objects_list_t * list, void *element);

void *objects_list_nth_element (objects_list_t * list, long int n);

void *objects_list_first_element (objects_list_t * list);

void *objects_list_last_element (objects_list_t * list);

void **objects_list_all_elements (objects_list_t * list);

/** Enumerating **/

objects_list_enumerator_t objects_list_enumerator (objects_list_t * list);

objects_list_enumerator_t objects_list_forward_enumerator (objects_list_t * list);

objects_list_enumerator_t objects_list_reverse_enumerator (objects_list_t * list);

int objects_list_enumerator_next_element (objects_list_enumerator_t *enumerator, void **element);

/** Mapping **/

/* NO WARNING: The mapping function FCN need not be one-to-one on the
 * elements of LIST.  In fact, FCN may do whatever it likes. */
objects_list_t * objects_list_map_elements (objects_list_t * list, void *(*fcn) (void *, void *), void *user_data);

/** Statistics **/

int objects_list_is_empty (objects_list_t * list);

size_t objects_list_count (objects_list_t * list);

size_t objects_list_capacity (objects_list_t * list);

int objects_list_check (objects_list_t * list);

/** Miscellaneous **/

objects_hash_t *objects_hash_init_from_list (objects_hash_t *hash, objects_list_t * list);

#endif /* __list_h_OBJECTS_INCLUDE */
