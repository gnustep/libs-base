/* A (pretty good) list implementation.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Tue Sep  5 17:23:50 EDT 1995
 * Updated: Wed Mar 20 20:48:39 EST 1996
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <gnustep/base/o_cbs.h>
#include <gnustep/base/o_list.h>
#include <gnustep/base/o_hash.h>

/**** Function Implementations ***********************************************/

/** Background functions **/

static inline void
_o_list_remove_node_from_its_list (o_list_node_t * node)
{
  if (node->list->first_node == node)
    node->list->first_node = node->next_in_list;
  if (node->list->last_node == node)
    node->list->last_node = node->prev_in_list;
  if (node->next_in_list != 0)
    node->next_in_list->prev_in_list = node->prev_in_list;
  if (node->prev_in_list != 0)
    node->prev_in_list->next_in_list = node->next_in_list;

  node->list->node_count -= 1;
  node->list->element_count -= 1;

  return;
}

static inline o_list_node_t *
_o_list_new_node (o_list_t *list, const void *element)
{
  o_list_node_t *node;

  node = NSZoneMalloc(o_list_zone(list), sizeof(o_list_node_t));

  if (node != 0)
    {
      node->list = list;
      node->next_in_list = 0;
      node->prev_in_list = 0;
      o_retain (o_list_element_callbacks (list), element, list);
      node->element = element;
    }

  return node;
}

void
_o_list_free_node (o_list_t *list, o_list_node_t * node)
{
  o_release (o_list_element_callbacks (node->list), 
		   (void*)node->element, 
		   node->list);
  NSZoneFree(o_list_zone(list), node);
  return;
}

static inline o_list_node_t *
_o_list_nth_node (o_list_t *list, long int n)
{
  o_list_node_t *node;

  if (n < 0)
    {
      node = list->last_node;
      ++n;

      while (node != 0 && n != 0)
	{
	  node = node->prev_in_list;
	  ++n;
	}
    }
  else
    /* (n >= 0) */
    {
      node = list->first_node;

      while (node != 0 && n != 0)
	{
	  node = node->next_in_list;
	  --n;
	}
    }

  return node;
}

static inline o_list_node_t *
_o_list_nth_node_for_element (o_list_t *list,
				    long int n,
				    const void *element)
{
  o_list_node_t *node;

  if (n < 0)
    {
      node = list->last_node;

      ++n;

      while (node != 0 && n != 0)
	{
	  if (o_is_equal (o_list_element_callbacks (list), element, node->element, list))
	    ++n;
	  if (n != 0)
	    node = node->prev_in_list;
	}
    }
  else
    {
      node = list->first_node;

      while (node != 0 && n != 0)
	{
	  if (o_is_equal (o_list_element_callbacks (list), element, node->element, list))
	    --n;
	  if (n != 0)
	    node = node->next_in_list;
	}
    }

  return node;
}

static inline o_list_node_t *
_o_list_enumerator_next_node (o_list_enumerator_t *enumerator)
{
  o_list_node_t *node;

  /* Remember ENUMERATOR's current node. */
  node = enumerator->node;

  /* If NODE is a real node, then we need to increment ENUMERATOR's
   * current node to the next node in ENUMERATOR's list. */
  if (node != 0)
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
o_list_count (o_list_t *list)
{
  return list->element_count;
}

size_t
o_list_capacity (o_list_t *list)
{
  return list->element_count;
}

int
o_list_check (o_list_t *list)
{
  return 0;
}

int
o_list_contains_element (o_list_t *list, const void *element)
{
  o_list_enumerator_t enumerator;
  const void *member;

  o_list_enumerator (list);

  while (o_list_enumerator_next_element (&enumerator, &member))
    if (o_compare (o_list_element_callbacks (list), element, member, list))
      return 1;

  return 0;
}

int
o_list_is_empty (o_list_t *list)
{
  return o_list_count (list) == 0;
}

/** Enumerating **/

o_list_enumerator_t
o_list_enumerator (o_list_t *list)
{
  return o_list_forward_enumerator (list);
}

o_list_enumerator_t
o_list_forward_enumerator (o_list_t *list)
{
  o_list_enumerator_t enumerator;

  /* Make sure ENUMERATOR knows its list. */
  enumerator.list = list;

  /* Start ENUMERATOR at LIST's first node. */
  enumerator.node = list->first_node;

  /* ENUMERATOR walks forward. */
  enumerator.forward = 1;

  return enumerator;
}

o_list_enumerator_t
o_list_reverse_enumerator (o_list_t *list)
{
  o_list_enumerator_t enumerator;

  /* Make sure ENUMERATOR knows its list. */
  enumerator.list = list;

  /* Start ENUMERATOR at LIST's first node. */
  enumerator.node = list->last_node;

  /* ENUMERATOR walks backward. */
  enumerator.forward = 0;

  return enumerator;
}

int
o_list_enumerator_next_element (o_list_enumerator_t *enumerator,
				      const void **element)
{
  o_list_node_t *node;

  /* Try and get the next node in the enumeration represented by
   * ENUMERATOR. */
  node = _o_list_enumerator_next_node (enumerator);

  if (node != 0)
    {
      /* If NODE is real, then return the element it contains. */
      if (element != 0)
	*element = node->element;

      /* Indicate that the enumeration continues. */
      return 1;
    }
  else
    {
      /* If NODE isn't real, then we return the ``bogus'' indicator. */
      if (element != 0)
	*element = o_list_not_an_element_marker (enumerator->list);

      /* Indicate that the enumeration is over. */
      return 0;
    }
}

/** Searching **/

const void *
o_list_element (o_list_t *list, const void *element)
{
  o_list_node_t *node;

  node = _o_list_nth_node_for_element (list, 0, element);

  if (node != 0)
    return node->element;
  else
    return o_list_not_an_element_marker (list);
}

const void *
o_list_nth_element (o_list_t *list, long int n)
{
  o_list_node_t *node;

  node = _o_list_nth_node (list, n);

  if (node != 0)
    return node->element;
  else
    return o_list_not_an_element_marker (list);
}

const void *
o_list_first_element (o_list_t *list)
{
  if (list->first_node != 0)
    return list->first_node->element;
  else
    return o_list_not_an_element_marker (list);
}

const void *
o_list_last_element (o_list_t *list)
{
  if (list->last_node != 0)
    return list->last_node->element;
  else
    return o_list_not_an_element_marker (list);
}

/** Obtaining elements **/

const void **
o_list_all_elements (o_list_t *list)
{
  o_list_enumerator_t enumerator;
  const void **array;
  size_t i;

  array = NSZoneCalloc(o_list_zone(list),
			  o_list_count(list) + 1,
			  sizeof(const void *));

  for (i = 0; o_list_enumerator_next_element (&enumerator, array + i); ++i);

  return array;
}

/** Adding elements **/

const void *
o_list_append_element (o_list_t *list, const void *element)
{
  return o_list_at_index_insert_element (list, -1, element);
}

const void *
o_list_append_element_if_absent (o_list_t *list, const void *element)
{
  return o_list_at_index_insert_element_if_absent (list, -1, element);
}

const void *
o_list_prepend_element (o_list_t *list, const void *element)
{
  return o_list_at_index_insert_element (list, 0, element);
}

const void *
o_list_prepend_element_if_absent (o_list_t *list, const void *element)
{
  return o_list_at_index_insert_element_if_absent (list, 0, element);
}

const void *
o_list_at_index_insert_element(o_list_t *list,
				     long int n,
				     const void *element)
{
  o_list_node_t *anode, *bnode, *new_node, *node;

  node = _o_list_nth_node (list, n);
  new_node = _o_list_new_node (list, element);

  if (new_node == 0)
    /* FIXME: Make this a *little* more graceful, for goodness' sake! */
    abort();

  if (n < 0)
    {
      if (node == 0)
	{
	  anode = 0;
	  bnode = list->first_node;
	}
      else
	/* (node != 0) */
	{
	  anode = node;
	  bnode = node->next_in_list;
	}
    }
  else
    /* (n >= 0) */
    {
      if (node == 0)
	{
	  anode = list->last_node;
	  bnode = 0;
	}
      else
	/* (node != 0) */
	{
	  anode = node->prev_in_list;
	  bnode = node;
	}
    }

  new_node->prev_in_list = anode;
  new_node->next_in_list = bnode;

  if (anode != 0)
    anode->next_in_list = new_node;
  if (bnode != 0)
    bnode->prev_in_list = new_node;

  if (list->last_node == anode)
    list->last_node = new_node;
  if (list->first_node == bnode)
    list->first_node = new_node;

  list->node_count += 1;
  list->element_count += 1;

  return new_node->element;
}

const void *
o_list_at_index_insert_element_if_absent (o_list_t *list,
						long int n,
						const void *element)
{
  if (!o_list_contains_element (list, element))
    return o_list_at_index_insert_element (list, n, element);
  else
    return o_list_element (list, element);
}

/** Removing elements **/

void
o_list_remove_nth_occurrance_of_element (o_list_t *list,
					       long int n,
					       const void *element)
{
  o_list_node_t *node;

  node = _o_list_nth_node_for_element (list, n, element);

  if (node != 0)
    {
      _o_list_remove_node_from_its_list (node);
      _o_list_free_node (list, node);
    }

  return;
}

void
o_list_remove_element (o_list_t *list, const void *element)
{
  o_list_remove_nth_occurrance_of_element (list, 0, element);
  return;
}

void
o_list_remove_nth_element (o_list_t *list, long int n)
{
  o_list_node_t *node;

  node = _o_list_nth_node (list, n);

  if (node != 0)
    {
      _o_list_remove_node_from_its_list (node);
      _o_list_free_node (list, node);
    }

  return;
}

void
o_list_remove_first_element (o_list_t *list)
{
  o_list_remove_nth_element (list, 0);
  return;
}

void
o_list_remove_last_element (o_list_t *list)
{
  o_list_remove_nth_element (list, -1);
  return;
}

/** Emptying **/

void
o_list_empty (o_list_t *list)
{
  o_list_enumerator_t enumerator;
  o_list_node_t *node;

  enumerator = o_list_enumerator (list);

  while ((node = _o_list_enumerator_next_node (&enumerator)) != 0)
    {
      _o_list_remove_node_from_its_list (node);
      _o_list_free_node (list, node);
    }

  return;
}

/** Replacing **/

void
o_list_replace_nth_occurrance_of_element (o_list_t *list,
						long int n,
						const void *old_element,
						const void *new_element)
{
  o_list_node_t *node;

  node = _o_list_nth_node_for_element (list, n, old_element);

  if (node != 0)
    {
      o_retain (o_list_element_callbacks (list), new_element, list);
      o_release (o_list_element_callbacks (list), 
		       (void*)node->element, 
		       list);
      node->element = new_element;
    }

  return;
}

void
o_list_replace_element (o_list_t *list,
			      const void *old_element,
			      const void *new_element)
{
  o_list_replace_nth_occurrance_of_element (list, 0, old_element, new_element);
  return;
}

void
o_list_replace_nth_element (o_list_t *list,
				  long int n,
				  const void *new_element)
{
  o_list_node_t *node;

  node = _o_list_nth_node (list, n);

  if (node != 0)
    {
      o_retain (o_list_element_callbacks (list), new_element, list);
      o_release (o_list_element_callbacks (list), 
		       (void*)node->element, 
		       list);
      node->element = new_element;
    }

  return;
}

void
o_list_replace_first_element (o_list_t *list,
				    const void *new_element)
{
  o_list_replace_nth_element (list, 0, new_element);
  return;
}

void
o_list_replace_last_element (o_list_t *list,
				   const void *new_element)
{
  o_list_replace_nth_element (list, -1, new_element);
  return;
}

/** Creating **/

o_list_t *
o_list_alloc_with_zone (NSZone *zone)
{
  o_list_t *list;

  list = _o_list_alloc_with_zone(zone);

  return list;
}

o_list_t *
o_list_alloc (void)
{
  return o_list_alloc_with_zone (0);
}

o_list_t *
o_list (void)
{
  return o_list_init (o_list_alloc ());
}

o_list_t *
o_list_with_zone (NSZone *zone)
{
  return o_list_init (o_list_alloc_with_zone(zone));
}

o_list_t *
o_list_with_zone_with_callbacks (NSZone *zone,
					 o_callbacks_t callbacks)
{
  return o_list_init_with_callbacks(o_list_alloc_with_zone(zone),
					  callbacks);
}

o_list_t *
o_list_with_callbacks (o_callbacks_t callbacks)
{
  return o_list_init_with_callbacks (o_list_alloc (), callbacks);
}

o_list_t *
o_list_of_char_p (void)
{
  return o_list_with_callbacks (o_callbacks_for_char_p);
}

o_list_t *
o_list_of_int (void)
{
  return o_list_with_callbacks (o_callbacks_for_int);
}

o_list_t *
o_list_of_non_owned_void_p (void)
{
  return o_list_with_callbacks (o_callbacks_for_non_owned_void_p);
}

o_list_t *
o_list_of_owned_void_p (void)
{
  return o_list_with_callbacks (o_callbacks_for_owned_void_p);
}

o_list_t *
o_list_of_id (void)
{
  return o_list_with_callbacks (o_callbacks_for_id);
}

/** Initializing **/

o_list_t *
o_list_init (o_list_t *list)
{
  return o_list_init_with_callbacks (list, o_callbacks_standard());
}

o_list_t *
o_list_init_with_callbacks (o_list_t *list, o_callbacks_t callbacks)
{
  if (list != 0)
    {
      list->callbacks = callbacks;
      list->element_count = 0;
      list->node_count = 0;
      list->first_node = 0;
      list->last_node = 0;
    }

  return list;
}

o_list_t *
o_list_init_from_list (o_list_t *list, o_list_t *old_list)
{
  o_list_enumerator_t enumerator;
  const void *element;

  if (list != 0)
    {
      list->callbacks = o_list_element_callbacks (old_list);
      list->element_count = 0;
      list->node_count = 0;
      list->first_node = 0;
      list->last_node = 0;

      if (old_list != 0)
	{
	  /* Get a forward enumerator for OLD_LIST. */
	  enumerator = o_list_forward_enumerator (old_list);

	  /* Walk from the beginning to the end of OLD_LIST, and add each
	   * element to the end of LIST. */
	  while (o_list_enumerator_next_element (&enumerator, &element))
	    o_list_at_index_insert_element (list, -1, element);
	}
    }

  return list;
}

/** Destroying **/

void
o_list_dealloc (o_list_t *list)
{
  /* Empty LIST out. */
  o_list_empty (list);

  /* Get rid of LIST. */
  _o_list_dealloc (list);

  return;
}

/** Comparing **/

int
o_list_is_equal_to_list(o_list_t *list, o_list_t *other_list)
{
  /* FIXME: Code this. */
  return 0;
}

/** Concatenating **/

o_list_t *
o_list_append_list (o_list_t *base_list, o_list_t *suffix_list)
{
  return o_list_at_index_insert_list (base_list, -1, suffix_list);
}

o_list_t *
o_list_prepend_list (o_list_t *base_list, o_list_t *prefix_list)
{
  return o_list_at_index_insert_list (base_list, 0, prefix_list);
}

/* FIXME: I was lazy when I wrote this next one.  It can easily be
 * sped up.  Do it. */
o_list_t *
o_list_at_index_insert_list(o_list_t *base_list,
				  long int n,
				  o_list_t *infix_list)
{
  o_list_enumerator_t enumerator;
  const void *element;

  if (n < 0)
    enumerator = o_list_forward_enumerator(infix_list);
  else				/* (n >= 0) */
    enumerator = o_list_reverse_enumerator(infix_list);

  while (o_list_enumerator_next_element(&enumerator, &element))
    o_list_at_index_insert_element(base_list, n, element);

  return base_list;
}

/** Copying **/

o_list_t *
o_list_copy (o_list_t *old_list)
{
  return o_list_copy_with_zone (old_list, 0);
}

o_list_t *
o_list_copy_with_zone (o_list_t *old_list, NSZone *zone)
{
  o_list_t *list;

  /* Allocate a new (low-level) copy of OLD_LIST. */
  list = _o_list_copy_with_zone(old_list, zone);

  /* Fill it in. */
  return o_list_init_from_list (list, old_list);
}

/** Mapping **/

o_list_t *
o_list_map_elements(o_list_t *list,
			  const void *(*fcn)(const void *, void *),
			  void *user_data)
{
  o_list_enumerator_t enumerator;
  o_list_node_t *node;
  o_callbacks_t callbacks;

  callbacks = o_list_element_callbacks(list);
  enumerator = o_list_enumerator (list);

  while ((node = _o_list_enumerator_next_node (&enumerator)) != 0)
    {
      const void *element;
      
      element = (*fcn)(node->element, user_data);

      o_retain (callbacks, element, list);
      o_release (callbacks, (void *)(node->element), list);

      node->element = element;
    }

  return list;
}

/** Creating other collections from lists **/

o_hash_t *
o_hash_init_from_list (o_hash_t * hash, o_list_t *list)
{
  if (hash != 0)
    {
      o_list_enumerator_t enumerator;
      const void *element;

      /* Make a note of the callbacks for HASH. */
      hash->callbacks = o_list_element_callbacks (list);

      /* Zero out the various counts. */
      hash->node_count = 0;
      hash->bucket_count = 0;
      hash->element_count = 0;

      /* Zero out the pointers. */
      hash->first_node = 0;
      hash->buckets = 0;

      /* Resize HASH to the given CAPACITY. */
      o_hash_resize (hash, o_list_capacity (list));

      /* Get an element enumerator for LIST. */
      enumerator = o_list_enumerator (list);

      /* Add LIST's elements to HASH, one at a time.  Note that if LIST
       * contains multiple elements from the same equivalence class, it
       * is indeterminate which will end up in HASH.  But this shouldn't
       * be a problem. */
      while (o_list_enumerator_next_element (&enumerator, &element))
	o_hash_add_element (hash, element);
    }

  /* Return the newly initialized HASH. */
  return hash;
}

// o_chash_t *
// o_chash_init_from_list (o_chash_t * chash, o_list_t *list)
// {
//   if (chash != 0)
//     {
//       o_list_enumerator_t enumerator;
//       const void *element;
// 
//       /* Make a note of the callbacks for CHASH. */
//       chash->callbacks = o_list_element_callbacks (list);
// 
//       /* Zero out the various counts. */
//       chash->node_count = 0;
//       chash->bucket_count = 0;
//       chash->element_count = 0;
// 
//       /* Zero out the pointers. */
//       chash->first_node = 0;
//       chash->buckets = 0;
// 
//       /* Resize CHASH to the given CAPACITY. */
//       o_chash_resize (chash, o_list_capacity (list));
// 
//       /* Get an element enumerator for LIST. */
//       enumerator = o_list_enumerator (list);
// 
//       /* Add LIST's elements to CHASH, one at a time.  Note that if LIST
//        * contains multiple elements from the same equivalence class, it
//        * is indeterminate which will end up in CHASH.  But this shouldn't
//        * be a problem. */
//       while (o_list_enumerator_next_element (&enumerator, &element))
// 	o_chash_add_element (chash, element);
//     }
// 
//   /* Return the newly initialized CHASH. */
//   return chash;
// }

