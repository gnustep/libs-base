/* A (pretty good) list implementation.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Sep  5 17:23:50 EDT 1995
 * Updated: Sat Feb 10 14:50:36 EST 1996
 * Serial: 96.02.10.03
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

#include <objects/allocs.h>
#include <objects/callbacks.h>
#include <objects/list.h>
#include <objects/hash.h>

/**** Function Implementations ***********************************************/

/** Background functions **/

inline void
_objects_list_remove_node_from_its_list (objects_list_node_t * node)
{
  if (node->list->first_node == node)
    node->list->first_node = node->next_in_list;
  if (node->list->last_node == node)
    node->list->last_node = node->prev_in_list;
  if (node->next_in_list != NULL)
    node->next_in_list->prev_in_list = node->prev_in_list;
  if (node->prev_in_list != NULL)
    node->prev_in_list->next_in_list = node->next_in_list;

  node->list->node_count -= 1;
  node->list->element_count -= 1;

  return;
}

objects_list_node_t *
_objects_list_new_node (objects_list_t * list, void *element)
{
  objects_list_node_t *node;

  node = objects_malloc (objects_list_allocs (list), sizeof (objects_list_node_t));

  if (node != NULL)
    {
      node->list = list;
      node->next_in_list = NULL;
      node->prev_in_list = NULL;
      objects_retain (objects_list_element_callbacks (list), element, list);
      node->element = element;
    }

  return node;
}

void
_objects_list_free_node (objects_list_t * list, objects_list_node_t * node)
{
  objects_release (objects_list_element_callbacks (node->list), node->element, node->list);
  objects_free (objects_list_allocs (list), node);
  return;
}

inline objects_list_node_t *
_objects_list_nth_node (objects_list_t * list, long int n)
{
  objects_list_node_t *node;

  if (n < 0)
    {
      node = list->last_node;
      ++n;

      while (node != NULL && n != 0)
	{
	  node = node->prev_in_list;
	  ++n;
	}
    }
  else
    /* (n >= 0) */
    {
      node = list->first_node;

      while (node != NULL && n != 0)
	{
	  node = node->next_in_list;
	  --n;
	}
    }

  return node;
}

inline objects_list_node_t *
_objects_list_nth_node_for_element (objects_list_t * list,
				    long int n,
				    void *element)
{
  objects_list_node_t *node;

  if (n < 0)
    {
      node = list->last_node;

      ++n;

      while (node != NULL && n != 0)
	{
	  if (objects_is_equal (objects_list_element_callbacks (list), element, node->element, list))
	    ++n;
	  if (n != 0)
	    node = node->prev_in_list;
	}
    }
  else
    {
      node = list->first_node;

      while (node != NULL && n != 0)
	{
	  if (objects_is_equal (objects_list_element_callbacks (list), element, node->element, list))
	    --n;
	  if (n != 0)
	    node = node->next_in_list;
	}
    }

  return node;
}

inline objects_list_node_t *
_objects_list_enumerator_next_node (objects_list_enumerator_t * enumerator)
{
  objects_list_node_t *node;

  /* Remember ENUMERATOR's current node. */
  node = enumerator->node;

  /* If NODE is a real node, then we need to increment ENUMERATOR's
   * current node to the next node in ENUMERATOR's list. */
  if (node != NULL)
    {
      if (enumerator->forward)
	enumerator->node = enumerator->node->next_in_list;
      else			/* (!enumerator->forward) */
	enumerator->node = enumerator->node->prev_in_list;
    }

  /* Send back NODE. */
  return node;
}

/** Gathering statistics **/

size_t
objects_list_count (objects_list_t * list)
{
  return list->element_count;
}

size_t
objects_list_capacity (objects_list_t * list)
{
  return list->element_count;
}

int
objects_list_check (objects_list_t * list)
{
  return 0;
}

int
objects_list_contains_element (objects_list_t * list, void *element)
{
  objects_list_enumerator_t enumerator;
  void *member;

  objects_list_enumerator (list);

  while (objects_list_enumerator_next_element (&enumerator, &member))
    if (objects_compare (objects_list_element_callbacks (list), element, member, list))
      return 1;

  return 0;
}

int
objects_list_is_empty (objects_list_t * list)
{
  return objects_list_count (list) == 0;
}

/** Enumerating **/

objects_list_enumerator_t
objects_list_enumerator (objects_list_t * list)
{
  return objects_list_forward_enumerator (list);
}

objects_list_enumerator_t
objects_list_forward_enumerator (objects_list_t * list)
{
  objects_list_enumerator_t enumerator;

  /* Update the access time. */
  _objects_list_set_access_time (list);

  /* Make sure ENUMERATOR knows its list. */
  enumerator.list = list;

  /* Start ENUMERATOR at LIST's first node. */
  enumerator.node = list->first_node;

  /* ENUMERATOR walks forward. */
  enumerator.forward = 1;

  return enumerator;
}

objects_list_enumerator_t
objects_list_reverse_enumerator (objects_list_t * list)
{
  objects_list_enumerator_t enumerator;

  /* Make sure ENUMERATOR knows its list. */
  enumerator.list = list;

  /* Start ENUMERATOR at LIST's first node. */
  enumerator.node = list->last_node;

  /* ENUMERATOR walks backward. */
  enumerator.forward = 0;

  return enumerator;
}

int
objects_list_enumerator_next_element (objects_list_enumerator_t * enumerator,
				      void **element)
{
  objects_list_node_t *node;

  /* Try and get the next node in the enumeration represented by
   * ENUMERATOR. */
  node = _objects_list_enumerator_next_node (enumerator);

  if (node != NULL)
    {
      /* If NODE is real, then return the element it contains. */
      if (element != NULL)
	*element = node->element;

      /* Indicate that the enumeration continues. */
      return 1;
    }
  else
    {
      /* If NODE isn't real, then we return the ``bogus'' indicator. */
      if (element != NULL)
	*element = objects_list_not_an_element_marker (enumerator->list);

      /* Indicate that the enumeration is over. */
      return 0;
    }
}

/** Searching **/

void *
objects_list_element (objects_list_t * list, void *element)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node_for_element (list, 0, element);

  if (node != NULL)
    return node->element;
  else
    return objects_list_not_an_element_marker (list);
}

void *
objects_list_nth_element (objects_list_t * list, long int n)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node (list, n);

  if (node != NULL)
    return node->element;
  else
    return objects_list_not_an_element_marker (list);
}

void *
objects_list_first_element (objects_list_t * list)
{
  if (list->first_node != NULL)
    return list->first_node->element;
  else
    return objects_list_not_an_element_marker (list);
}

void *
objects_list_last_element (objects_list_t * list)
{
  if (list->last_node != NULL)
    return list->last_node->element;
  else
    return objects_list_not_an_element_marker (list);
}

/** Obtaining elements **/

void **
objects_list_all_elements (objects_list_t * list)
{
  objects_list_enumerator_t enumerator;
  void **array;
  size_t i;

  array = objects_calloc (objects_list_allocs (list),
			  objects_list_count (list) + 1,
			  sizeof (void *));

  for (i = 0; objects_list_enumerator_next_element (&enumerator, array + i); ++i);

  return array;
}

/** Adding elements **/

void *
objects_list_append_element (objects_list_t * list, void *element)
{
  return objects_list_at_index_insert_element (list, -1, element);
}

void *
objects_list_append_element_if_absent (objects_list_t * list, void *element)
{
  return objects_list_at_index_insert_element_if_absent (list, -1, element);
}

void *
objects_list_prepend_element (objects_list_t * list, void *element)
{
  return objects_list_at_index_insert_element (list, 0, element);
}

void *
objects_list_prepend_element_if_absent (objects_list_t * list, void *element)
{
  return objects_list_at_index_insert_element_if_absent (list, 0, element);
}

void *
objects_list_at_index_insert_element (objects_list_t * list,
				      long int n,
				      void *element)
{
  objects_list_node_t *anode, *bnode, *new_node, *node;

  node = _objects_list_nth_node (list, n);
  new_node = _objects_list_new_node (list, element);

  if (new_node == NULL)
    objects_abort ();

  if (n < 0)
    {
      if (node == NULL)
	{
	  anode = NULL;
	  bnode = list->first_node;
	}
      else
	/* (node != NULL) */
	{
	  anode = node;
	  bnode = node->next_in_list;
	}
    }
  else
    /* (n >= 0) */
    {
      if (node == NULL)
	{
	  anode = list->last_node;
	  bnode = NULL;
	}
      else
	/* (node != NULL) */
	{
	  anode = node->prev_in_list;
	  bnode = node;
	}
    }

  new_node->prev_in_list = anode;
  new_node->next_in_list = bnode;

  if (anode != NULL)
    anode->next_in_list = new_node;
  if (bnode != NULL)
    bnode->prev_in_list = new_node;

  if (list->last_node == anode)
    list->last_node = new_node;
  if (list->first_node == bnode)
    list->first_node = new_node;

  list->node_count += 1;
  list->element_count += 1;

  return new_node->element;
}

void *
objects_list_at_index_insert_element_if_absent (objects_list_t * list,
						long int n,
						void *element)
{
  if (!objects_list_contains_element (list, element))
    return objects_list_at_index_insert_element (list, n, element);
  else
    return objects_list_element (list, element);
}

/** Removing elements **/

void
objects_list_remove_nth_occurrance_of_element (objects_list_t * list,
					       long int n,
					       void *element)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node_for_element (list, n, element);

  if (node != NULL)
    {
      _objects_list_remove_node_from_its_list (node);
      _objects_list_free_node (list, node);
    }

  return;
}

void
objects_list_remove_element (objects_list_t * list, void *element)
{
  objects_list_remove_nth_occurrance_of_element (list, 0, element);
  return;
}

inline void
objects_list_remove_nth_element (objects_list_t * list, long int n)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node (list, n);

  if (node != NULL)
    {
      _objects_list_remove_node_from_its_list (node);
      _objects_list_free_node (list, node);
    }

  return;
}

void
objects_list_remove_first_element (objects_list_t * list)
{
  objects_list_remove_nth_element (list, 0);
  return;
}

void
objects_list_remove_last_element (objects_list_t * list)
{
  objects_list_remove_nth_element (list, -1);
  return;
}

/** Emptying **/

void
objects_list_empty (objects_list_t * list)
{
  objects_list_enumerator_t enumerator;
  objects_list_node_t *node;

  enumerator = objects_list_enumerator (list);

  while ((node = _objects_list_enumerator_next_node (&enumerator)) != NULL)
    {
      _objects_list_remove_node_from_its_list (node);
      _objects_list_free_node (list, node);
    }

  return;
}

/** Replacing **/

void
objects_list_replace_nth_occurrance_of_element (objects_list_t * list,
						long int n,
						void *old_element,
						void *new_element)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node_for_element (list, n, old_element);

  if (node != NULL)
    {
      objects_retain (objects_list_element_callbacks (list), new_element, list);
      objects_release (objects_list_element_callbacks (list), node->element, list);
      node->element = new_element;
    }

  return;
}

void
objects_list_replace_element (objects_list_t * list,
			      void *old_element,
			      void *new_element)
{
  objects_list_replace_nth_occurrance_of_element (list, 0, old_element, new_element);
  return;
}

void
objects_list_replace_nth_element (objects_list_t * list,
				  long int n,
				  void *new_element)
{
  objects_list_node_t *node;

  node = _objects_list_nth_node (list, n);

  if (node != NULL)
    {
      objects_retain (objects_list_element_callbacks (list), new_element, list);
      objects_release (objects_list_element_callbacks (list), node->element, list);
      node->element = new_element;
    }

  return;
}

void
objects_list_replace_first_element (objects_list_t * list,
				    void *new_element)
{
  objects_list_replace_nth_element (list, 0, new_element);
  return;
}

void
objects_list_replace_last_element (objects_list_t * list,
				   void *new_element)
{
  objects_list_replace_nth_element (list, -1, new_element);
  return;
}

/** Creating **/

objects_list_t *
objects_list_alloc_with_allocs (objects_allocs_t allocs)
{
  objects_list_t *list;

  list = _objects_list_alloc_with_allocs (allocs);

  return list;
}

objects_list_t *
objects_list_alloc (void)
{
  return objects_list_alloc_with_allocs (objects_allocs_standard ());
}

objects_list_t *
objects_list (void)
{
  return objects_list_init (objects_list_alloc ());
}

objects_list_t *
objects_list_with_allocs (objects_allocs_t allocs)
{
  return objects_list_init (objects_list_alloc_with_allocs (allocs));
}

objects_list_t *
objects_list_with_allocs_with_callbacks (objects_allocs_t allocs,
					 objects_callbacks_t callbacks)
{
  return objects_list_init_with_callbacks (objects_list_alloc_with_allocs (allocs),
					   callbacks);
}

objects_list_t *
objects_list_with_callbacks (objects_callbacks_t callbacks)
{
  return objects_list_init_with_callbacks (objects_list_alloc (), callbacks);
}

objects_list_t *
objects_list_of_char_p (void)
{
  return objects_list_with_callbacks (objects_callbacks_for_char_p);
}

objects_list_t *
objects_list_of_int (void)
{
  return objects_list_with_callbacks (objects_callbacks_for_int);
}

objects_list_t *
objects_list_of_void_p (void)
{
  return objects_list_with_callbacks (objects_callbacks_for_void_p);
}

objects_list_t *
objects_list_of_owned_void_p (void)
{
  return objects_list_with_callbacks (objects_callbacks_for_owned_void_p);
}

objects_list_t *
objects_list_of_id (void)
{
  return objects_list_with_callbacks (objects_callbacks_for_id);
}

/** Initializing **/

objects_list_t *
objects_list_init (objects_list_t * list)
{
  return objects_list_init_with_callbacks (list, objects_callbacks_standard());
}

objects_list_t *
objects_list_init_with_callbacks (objects_list_t * list, objects_callbacks_t callbacks)
{
  if (list != NULL)
    {
      list->callbacks = callbacks;
      list->element_count = 0;
      list->node_count = 0;
      list->first_node = NULL;
      list->last_node = NULL;
    }

  return list;
}

objects_list_t *
objects_list_init_from_list (objects_list_t * list, objects_list_t * old_list)
{
  objects_list_enumerator_t enumerator;
  void *element;

  if (list != NULL)
    {
      list->callbacks = objects_list_element_callbacks (old_list);
      list->element_count = 0;
      list->node_count = 0;
      list->first_node = NULL;
      list->last_node = NULL;

      if (old_list != NULL)
	{
	  /* Get a forward enumerator for OLD_LIST. */
	  enumerator = objects_list_forward_enumerator (old_list);

	  /* Walk from the beginning to the end of OLD_LIST, and add each
	   * element to the end of LIST. */
	  while (objects_list_enumerator_next_element (&enumerator, &element))
	    objects_list_at_index_insert_element (list, -1, element);
	}
    }

  return list;
}

/** Destroying **/

void
objects_list_dealloc (objects_list_t * list)
{
  /* Empty LIST out. */
  objects_list_empty (list);

  /* Get rid of LIST. */
  _objects_list_dealloc (list);

  return;
}

/** Comparing **/

int
objects_list_is_equal_to_list (objects_list_t * list, objects_list_t * other_list)
{
  /* FIXME: Code this. */
  return 0;
}

/** Concatenating **/

objects_list_t *
objects_list_append_list (objects_list_t * base_list, objects_list_t * suffix_list)
{
  return objects_list_at_index_insert_list (base_list, -1, suffix_list);
}

objects_list_t *
objects_list_prepend_list (objects_list_t * base_list, objects_list_t * prefix_list)
{
  return objects_list_at_index_insert_list (base_list, 0, prefix_list);
}

/* FIXME: I was lazy when I wrote this next one.  It can easily be
 * sped up.  Do it. */
objects_list_t *
objects_list_at_index_insert_list (objects_list_t * base_list,
				   long int n,
				   objects_list_t * infix_list)
{
  objects_list_enumerator_t enumerator;
  void *element;

  if (n < 0)
    enumerator = objects_list_forward_enumerator (infix_list);
  else				/* (n >= 0) */
    enumerator = objects_list_reverse_enumerator (infix_list);

  while (objects_list_enumerator_next_element (&enumerator, &element))
    objects_list_at_index_insert_element (base_list, n, element);

  return base_list;
}

/** Copying **/

objects_list_t *
objects_list_copy (objects_list_t * old_list)
{
  /* FIXME: Should I be using `objects_allocs_standard()' or
   * `objects_list_allocs(old_list)'? */
  return objects_list_copy_with_allocs (old_list, objects_list_allocs (old_list));
}

objects_list_t *
objects_list_copy_with_allocs (objects_list_t * old_list, objects_allocs_t allocs)
{
  objects_list_t *list;

  /* Allocate a new (low-level) copy of OLD_LIST. */
  list = _objects_list_copy_with_allocs (old_list, allocs);

  /* Fill it in. */
  return objects_list_init_from_list (list, old_list);
}

/** Mapping **/

objects_list_t *
objects_list_map_elements (objects_list_t * list,
			   void *(*fcn) (void *, void *),
			   void *user_data)
{
  objects_list_enumerator_t enumerator;
  objects_list_node_t *node;

  enumerator = objects_list_enumerator (list);

  while ((node = _objects_list_enumerator_next_node (&enumerator)) != NULL)
    {
      void *element;

      element = (*fcn) (node->element, user_data);

      /* NOTE: I'm accessing the callbacks directly for a little
       * efficiency. */
      objects_retain (list->callbacks, element, list);
      objects_release (list->callbacks, node->element, list);

      node->element = element;
    }

  return list;
}

/** Creating other collections from lists **/

objects_hash_t *
objects_hash_init_from_list (objects_hash_t * hash, objects_list_t * list)
{
  if (hash != NULL)
    {
      objects_list_enumerator_t enumerator;
      void *element;

      /* Make a note of the callbacks for HASH. */
      hash->callbacks = objects_list_element_callbacks (list);

      /* Zero out the various counts. */
      hash->node_count = 0;
      hash->bucket_count = 0;
      hash->element_count = 0;

      /* Zero out the pointers. */
      hash->first_node = NULL;
      hash->buckets = NULL;

      /* Resize HASH to the given CAPACITY. */
      objects_hash_resize (hash, objects_list_capacity (list));

      /* Get an element enumerator for LIST. */
      enumerator = objects_list_enumerator (list);

      /* Add LIST's elements to HASH, one at a time.  Note that if LIST
       * contains multiple elements from the same equivalence class, it
       * is indeterminate which will end up in HASH.  But this shouldn't
       * be a problem. */
      while (objects_list_enumerator_next_element (&enumerator, &element))
	objects_hash_add_element (hash, element);
    }

  /* Return the newly initialized HASH. */
  return hash;
}

// objects_chash_t *
// objects_chash_init_from_list (objects_chash_t * chash, objects_list_t * list)
// {
//   if (chash != NULL)
//     {
//       objects_list_enumerator_t enumerator;
//       void *element;
// 
//       /* Make a note of the callbacks for CHASH. */
//       chash->callbacks = objects_list_element_callbacks (list);
// 
//       /* Zero out the various counts. */
//       chash->node_count = 0;
//       chash->bucket_count = 0;
//       chash->element_count = 0;
// 
//       /* Zero out the pointers. */
//       chash->first_node = NULL;
//       chash->buckets = NULL;
// 
//       /* Resize CHASH to the given CAPACITY. */
//       objects_chash_resize (chash, objects_list_capacity (list));
// 
//       /* Get an element enumerator for LIST. */
//       enumerator = objects_list_enumerator (list);
// 
//       /* Add LIST's elements to CHASH, one at a time.  Note that if LIST
//        * contains multiple elements from the same equivalence class, it
//        * is indeterminate which will end up in CHASH.  But this shouldn't
//        * be a problem. */
//       while (objects_list_enumerator_next_element (&enumerator, &element))
// 	objects_chash_add_element (chash, element);
//     }
// 
//   /* Return the newly initialized CHASH. */
//   return chash;
// }

