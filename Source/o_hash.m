/* A hash table.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Tue Mar 19 00:25:18 EST 1996
 * Serial: 96.03.19.33
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

#include <config.h>
#include <Foundation/NSZone.h>
#include <base/o_cbs.h>
#include <base/numbers.h>
#include <base/o_hash.h>

/**** Function Implementations ***********************************************/

/** Behind-the-Scenes functions **/

static inline o_hash_bucket_t *
_o_hash_pick_bucket_for_element(o_hash_t *hash,
				      o_hash_bucket_t *buckets,
				      size_t bucket_count,
				      const void *element)
{
  return buckets + (o_hash(o_hash_element_callbacks(hash),
				 element, hash)
		    % bucket_count);
}

static inline o_hash_bucket_t *
_o_hash_pick_bucket_for_node(o_hash_t *hash,
				   o_hash_bucket_t *buckets,
				   size_t bucket_count,
				   o_hash_node_t *node)
{
  return buckets + (o_hash(o_hash_element_callbacks(hash),
				 node->element, hash)
		    % bucket_count);
}

static inline o_hash_bucket_t *
_o_hash_bucket_for_element(o_hash_t *hash, const void *element)
{
  return _o_hash_pick_bucket_for_element(hash, hash->buckets,
					    hash->bucket_count, element);
}

static inline o_hash_bucket_t *
_o_hash_bucket_for_node(o_hash_t *hash, o_hash_node_t *node)
{
  return _o_hash_pick_bucket_for_node(hash, hash->buckets,
					    hash->bucket_count, node);
}

static inline void
_o_hash_link_node_into_bucket(o_hash_bucket_t *bucket,
				    o_hash_node_t *node)
{
  if (bucket->first_node != 0)
    bucket->first_node->prev_in_bucket = node;

  node->next_in_bucket = bucket->first_node;

  bucket->first_node = node;

  return;
}

static inline void
_o_hash_unlink_node_from_its_bucket(o_hash_node_t *node)
{
  if (node == node->bucket->first_node)
    node->bucket->first_node = node->next_in_bucket;

  if (node->prev_in_bucket != 0)
    node->prev_in_bucket->next_in_bucket = node->next_in_bucket;
  if (node->next_in_bucket != 0)
    node->next_in_bucket->prev_in_bucket = node->prev_in_bucket;

  node->prev_in_bucket = node->next_in_bucket = 0;

  return;
}

static inline void
_o_hash_link_node_into_hash(o_hash_t *hash,
				  o_hash_node_t *node)
{
  if (hash->first_node != 0)
    hash->first_node->prev_in_hash = node;
  node->next_in_hash = hash->first_node;
  hash->first_node = node;

  return;
}

static inline void
_o_hash_unlink_node_from_its_hash(o_hash_node_t *node)
{
  if (node == node->hash->first_node)
    node->hash->first_node = node->next_in_hash;

  if (node->prev_in_hash != 0)
    node->prev_in_hash->next_in_hash = node->next_in_hash;
  if (node->next_in_hash != 0)
    node->next_in_hash->prev_in_hash = node->prev_in_hash;

  node->prev_in_hash = node->next_in_hash = 0;

  return;
}

static inline void
_o_hash_add_node_to_bucket(o_hash_bucket_t *bucket,
				 o_hash_node_t *node)
{
  if (bucket != 0)
  {
    _o_hash_link_node_into_bucket(bucket, node);

    node->bucket = bucket;

    bucket->node_count += 1;
    bucket->element_count += 1;
  }

  return;
}

static inline void
_o_hash_add_node_to_its_bucket(o_hash_t *hash,
				     o_hash_node_t *node)
{
  _o_hash_add_node_to_bucket(_o_hash_bucket_for_node(hash, node),
				   node);
  return;
}

static inline void
_o_hash_add_node_to_hash(o_hash_t *hash, o_hash_node_t *node)
{
  if (hash != 0)
  {
    _o_hash_add_node_to_its_bucket(hash, node);

    _o_hash_link_node_into_hash(hash, node);

    node->hash = hash;

    hash->node_count += 1;
    hash->element_count += 1;
  }

  return;
}

static inline void
_o_hash_remove_node_from_its_bucket(o_hash_node_t *node)
{
  if (node->bucket != 0)
  {
    node->bucket->node_count -= 1;
    node->bucket->element_count -= 1;

    _o_hash_unlink_node_from_its_bucket(node);
  }

  return;
}

static inline void
_o_hash_remove_node_from_its_hash(o_hash_node_t *node)
{
  if (node->hash != 0)
  {
    node->hash->node_count -= 1;
    node->hash->element_count -= 1;

    _o_hash_unlink_node_from_its_hash(node);
  }

  _o_hash_remove_node_from_its_bucket(node);

  return;
}

static inline o_hash_bucket_t *
_o_hash_new_buckets(o_hash_t *hash, size_t bucket_count)
{
  return (o_hash_bucket_t *)NSZoneCalloc(o_hash_zone(hash),
					       bucket_count,
					  sizeof(o_hash_bucket_t));
}

static inline void
_o_hash_free_buckets(o_hash_t *hash, o_hash_bucket_t *buckets)
{
  if (buckets != 0)
    NSZoneFree(o_hash_zone(hash), buckets);
  return;
}

static inline void
_o_hash_remangle_buckets(o_hash_t *hash,
			       o_hash_bucket_t *old_buckets,
			       size_t old_bucket_count,
			       o_hash_bucket_t *new_buckets,
			       size_t new_bucket_count)
{
  size_t i;
  o_hash_node_t *node;
  for (i = 0; i < old_bucket_count; i++)
  {
    while ((node = old_buckets[i].first_node) != 0)
    {
      _o_hash_remove_node_from_its_bucket(node);
      _o_hash_add_node_to_bucket(_o_hash_pick_bucket_for_node(hash,
							     new_buckets,
							new_bucket_count,
								   node),
				       node);
    }
  }

  /* And that's that. */
  return;
}

static inline o_hash_node_t *
_o_hash_new_node(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;
  /* Allocate the space for a new node. */
  node = (o_hash_node_t *)NSZoneMalloc(o_hash_zone(hash),
					     sizeof(o_hash_node_t));

  if (node != 0)
  {
    /* Retain ELEMENT.  (It's released in `_o_hash_free_node()'.) */
    o_retain(o_hash_element_callbacks(hash), element, hash);

    /* Remember ELEMENT. */
    node->element = element;

    /* Associate NODE with HASH. */
    node->hash = hash;

    /* Zero out the various pointers. */
    node->bucket = 0;
    node->next_in_bucket = 0;
    node->next_in_hash = 0;
    node->prev_in_bucket = 0;
    node->prev_in_hash = 0;
  }

  return node;
}

static inline void
_o_hash_free_node(o_hash_node_t *node)
{
  if (node != 0)
  {
    o_hash_t *hash;
    /* Remember NODE's hash. */
    hash = node->hash;

    /* Release ELEMENT.  (It's retained in `_o_hash_new_node()'.) */
    o_release(o_hash_element_callbacks(hash),
		    (void *)node->element,
		    hash);

    /* Actually free the space hash aside for NODE. */
    NSZoneFree(o_hash_zone(hash), node);
  }

  /* And just return. */
  return;
}

static inline o_hash_node_t *
_o_hash_node_for_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node = 0;

  if (element != o_hash_not_an_element_marker(hash))
  {
    o_hash_bucket_t *bucket = 0;

    /* Find the bucket in which the node for ELEMENT would be. */
    bucket = _o_hash_bucket_for_element(hash, element);

    /* Run through the nodes in BUCKET until we find one whose element
     * matches ELEMENT. */
    for (node = bucket->first_node;
         (node != 0) && !o_is_equal(o_hash_element_callbacks(hash),
                                      element,
                                      node->element,
                                      hash);
         node = node->next_in_bucket);
  }

  /* Note that if ELEMENT is bogus or if none of the nodes'
   * elements matches ELEMENT, then we naturally return 0. */
  return node;
}

static inline o_hash_node_t *
_o_hash_enumerator_next_node(o_hash_enumerator_t *enumerator)
{
  o_hash_node_t *node;
  /* Remember ENUMERATOR's current node. */
  node = enumerator->node;

  /* If NODE is a real node, then we need to increment ENUMERATOR's
   * current node to the next node in ENUMERATOR's hash. */
  if (node != 0)
    enumerator->node = enumerator->node->next_in_hash;

  /* Send back NODE. */
  return node;
}

/** Callbacks... **/

/* Return a hash index for HASH.  Needed for the callbacks below. */
size_t
_o_hash_hash(o_hash_t *hash)
{
  /* One might be tempted to do something simple here, but remember:
   * If two hash tables are equal they *must* hash to the same value! */

  /* FIXME: Code this. */
  return 0;
}

/* An (inefficient, but necessary) "retaining" function for hash tables. */
o_hash_t *
_o_hash_retain(o_hash_t *hash, o_hash_t *in_hash)
{
  /* Note that this works only because all the structures (hash, map
   * list, array) look alike at first...so we can get the zone of
   * one just like we can get the zone of any of them. */
  return o_hash_copy_with_zone(hash, o_hash_zone(in_hash));
}

/* Returns a collection of callbacks for use with hash tables. */
o_callbacks_t
o_callbacks_for_hash(void)
{
  o_callbacks_t hash_callbacks =
  {
    (o_hash_func_t) _o_hash_hash,
    (o_compare_func_t) 0,
    (o_is_equal_func_t) o_hash_is_equal_to_hash,
    (o_retain_func_t) _o_hash_retain,
    (o_release_func_t) o_hash_dealloc,
    (o_describe_func_t) o_hash_description,
    0
  };

  return hash_callbacks;
}

/** Resizing **/

size_t
o_hash_resize(o_hash_t *hash, size_t new_capacity)
{
  o_hash_bucket_t *new_buckets;
  /* Round NEW_CAPACITY up to the next power of two. */
  new_capacity = _o_next_power_of_two(new_capacity);

  /* Make a new hash of buckets. */
  new_buckets = _o_hash_new_buckets(hash, new_capacity);

  if (new_buckets != 0)
  {
    _o_hash_remangle_buckets(hash,
				   hash->buckets,
				   hash->bucket_count,
				   new_buckets,
				   new_capacity);

    _o_hash_free_buckets(hash, hash->buckets);

    hash->buckets = new_buckets;
    hash->bucket_count = new_capacity;

  }

  /* Return the new capacity. */
  return hash->bucket_count;
}

size_t
o_hash_rightsize(o_hash_t *hash)
{
  /* FIXME: Now, this is a guess, based solely on my intuition.  If anyone
   * knows of a better ratio (or other test, for that matter) and can
   * provide evidence of its goodness, please get in touch with me, Albin
   * L. Jones <albin.l.jones@dartmouth.edu>. */

  if (3 * hash->node_count > 4 * hash->bucket_count)
  {
    return o_hash_resize(hash, hash->bucket_count + 1);
  }
  else
  {
    return hash->bucket_count;
  }
}
/** Statistics **/

size_t
o_hash_count(o_hash_t *hash)
{
  return hash->element_count;
}

size_t
o_hash_capacity(o_hash_t *hash)
{
  return hash->bucket_count;
}

int
o_hash_check(o_hash_t *hash)
{
  /* FIXME: Code this. */
  return 0;
}
/** Searching **/

int
o_hash_contains_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;
  node = _o_hash_node_for_element(hash, element);

  return node != 0;
}

const void *
o_hash_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;
  /* Try and find the node for ELEMENT. */
  node = _o_hash_node_for_element(hash, element);

  if (node != 0)
    return node->element;
  else
    return o_hash_not_an_element_marker(hash);
}

const void **
o_hash_all_elements(o_hash_t *hash)
{
  size_t j;
  const void **array;
  o_hash_enumerator_t enumerator;

  /* FIXME: It probably shouldn't be the programmer's responsibility to
   * worry about freeing ARRAY.  Maybe we should be returning an NSArray? */

  /* Allocate space for ARRAY.  Remember that it is the programmer's
   * responsibility to free this by calling
   * `NSZoneFree(o_hash_zone(HASH), ARRAY)' */
  array = (const void **)NSZoneCalloc(o_hash_zone(hash),
				      hash->node_count + 1,
				      sizeof(void *));

  /* ENUMERATOR is an enumerator for HASH. */
  enumerator = o_hash_enumerator_for_hash(hash);

  /* Now we enumerate through the elements of HASH, adding them one-by-one
   * to ARRAY.  */
  for (j = 0; j < hash->node_count; j++)
    o_hash_enumerator_next_element(&enumerator, array + j);

  /* We terminate ARRAY with the `not_an_element_marker' for HASH. */
  array[j] = o_hash_not_an_element_marker(hash);

  /* And we're done. */
  return array;
}

int
o_hash_is_empty(o_hash_t *hash)
{
  return o_hash_count(hash) == 0;
}
/** Enumerating **/

/* WARNING: You should not alter a hash while an enumeration is
 * in progress.  The results of doing so are reasonably unpredictable.
 * With that in mind, read the following warnings carefully.  But
 * remember, DON'T MESS WITH A HASH WHILE YOU'RE ENUMERATING IT. */

/* IMPORTANT WARNING: Hash enumerators, as I have hash them up, have a
 * wonderous property.  Namely, that, while enumerating, one may add
 * new elements (i.e., new nodes) to the hash while an enumeration is
 * in progress (i.e., after `o_hash_enumerator_for_hash()' has been called), and
 * the enumeration remains the same. */

/* WARNING: The above warning should not, in any way, be taken as
 * assurance that this property of hash enumerators will be preserved
 * in future editions of the library.  I'm still thinking about
 * this. */

/* IMPORTANT WARNING: Enumerators have yet another wonderous property.
 * Once a node has been returned by
 * `_o_hash_enumerator_next_node()', it may be removed from the hash
 * without effecting the rest of the current enumeration.  For
 * example, to clean all of the nodes out of a hash, the following code
 * would work:
 * 
 * void
 * empty_my_hash(o_hash_t *hash)
 * {
 *   o_hash_enumerator_t enumerator = o_hash_enumerator_for_hash(hash);
 *   o_hash_node_t *node;
 * 
 *   while ((node = _o_hash_enumerator_next_node(&enumerator)) != 0)
 *   {
 *     _o_hash_remove_node_from_its_hash(node);
 *     _o_hash_free_node(node);
 *   }
 * 
 *   return;
 * }
 * 
 * (In fact, this is the code currently being used below in the
 * function `o_hash_empty()'.)  But again, this is not to be taken
 * as an assurance that this behaviour will persist in future versions
 * of the library. */

/* EXTREMELY IMPORTANT WARNING: The purpose of this warning is point
 * out that, at this time, various (i.e., many) functions depend on
 * the behaviours outlined above.  So be prepared for some serious
 * breakage when you go fudging around with these things. */

o_hash_enumerator_t
o_hash_enumerator_for_hash(o_hash_t *hash)
{
  o_hash_enumerator_t enumerator;
  /* Make sure ENUMERATOR knows its hash. */
  enumerator.hash = hash;

  /* Start ENUMERATOR at HASH's first node. */
  enumerator.node = hash->first_node;

  return enumerator;
}

int
o_hash_enumerator_next_element(o_hash_enumerator_t *enumerator,
				     const void **element)
{
  o_hash_node_t *node;
  /* Get the next node in the enumeration represented by ENUMERATOR. */
  node = _o_hash_enumerator_next_node(enumerator);

  if (node != 0)
  {
    /* NODE is real, so we pull the information out of it that we need. 
     * Note that we check to see whether ELEMENT and COUNT are non-`0'. */
    if (element != 0)
      *element = node->element;

    /* Since we weren't at the end of our enumeration, we return ``true''. */
    return 1;
  }
  else /* (node == 0) */
  {
    /* If NODE isn't real, then we return the bogus element indicator and
     * a zero count. */
    if (element != 0)
      *element = o_hash_not_an_element_marker(enumerator->hash);

    /* Since we're at the end of the enumeration, we return ``false''. */
    return 0;
  }
}
/** Adding... **/

inline const void *
o_hash_add_element_known_absent(o_hash_t *hash,
				      const void *element)
{
  /* Note that we *do not* use the callback functions to test for
   * the presence of the bogus element.  Is is perfectly permissible for
   * elements which are "equal" (but not equal) to the "not an
   * element marker" to be added to HASH. */
  if (element == o_hash_not_an_element_marker(hash))
  {
     /* FIXME: We should do something useful here,
      * like raise an exception. */
     abort();
  }
  else if ((_o_hash_node_for_element(hash, element)) != 0)
  {
    /* FIXME: We should do something useful here,
     * like raise an exception. */
    abort();
  }
  else /* (element != bogus && !(element in hash)) */
  {
    o_hash_node_t *node;
    node = _o_hash_new_node(hash, element);

    if (node != 0)
    {
      /* Actually add NODE to HASH. */
      _o_hash_add_node_to_hash(hash, node);

      return node->element;
    }
    else /* (node == 0) */
      return o_hash_not_an_element_marker(hash);
  }
}

const void *
o_hash_add_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;

  /* First, we check for ELEMENT in HASH. */
  node = _o_hash_node_for_element(hash, element);

  if (node == 0)
  {
    /* ELEMENT isn't in HASH, so we can add it with impunity. */
    return o_hash_add_element_known_absent(hash, element);
  }
  else /* (node != 0) */
  {
    /* Remember: First retain, then release. */
    o_retain(o_hash_element_callbacks(hash), element, hash);
    o_release(o_hash_element_callbacks(hash),
		    (void *)(node->element),
		    hash);
    return node->element = element;
  }
}

/* If (any item "equal" to) ELEMENT is in HASH, then that member of HASH is
 * returned.  Otherwise, the "not an element marker" for HASH is returned
 * and ELEMENT is added to HASH. */
const void *
o_hash_add_element_if_absent(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;

  /* First, we check for ELEMENT in HASH. */
  node = _o_hash_node_for_element(hash, element);

  if (node == 0)
  {
    /* ELEMENT isn't in HASH, so we can add it with impunity. */
    o_hash_add_element_known_absent(hash, element);

    /* To indicate that ELEMENT was not in HASH, we return the bogus
     * element indicator. */
    return o_hash_not_an_element_marker(hash);
  }
  else /* (node != 0) */
    return node->element;
}
/** Removing **/

void
o_hash_remove_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;
  node = _o_hash_node_for_element(hash, element);

  if (node != 0)
  {
    /* Pull NODE out of HASH. */
    _o_hash_remove_node_from_its_hash(node);

    /* Free up NODE. */
    _o_hash_free_node(node);
  }

  return;
}
/** Emptying **/

void
o_hash_empty(o_hash_t *hash)
{
  o_hash_enumerator_t enumerator;
  o_hash_node_t *node;
  /* Get an element enumerator for HASH. */
  enumerator = o_hash_enumerator_for_hash(hash);

  /* Just step through the nodes of HASH and wipe them out, one after
   * another.  Don't try this at home, kids!  Note that, under ordinary
   * circumstances, this would be a verboten use of hash enumerators.  See
   * the warnings with the enumerator functions for more details. */
  while ((node = _o_hash_enumerator_next_node(&enumerator)) != 0)
  {
    _o_hash_remove_node_from_its_hash(node);
    _o_hash_free_node(node);
  }

  /* And return. */
  return;
}
/** Creating **/

o_hash_t *
o_hash_alloc_with_zone(NSZone * zone)
{
  o_hash_t *hash;
  /* Get a new hash, using basic methods. */
  hash = _o_hash_alloc_with_zone(zone);

  return hash;
}

o_hash_t *
o_hash_alloc(void)
{
  return o_hash_alloc_with_zone(NSDefaultMallocZone());
}

o_hash_t *
o_hash_with_callbacks(o_callbacks_t callbacks)
{
  return o_hash_init_with_callbacks(o_hash_alloc(), callbacks);
}

o_hash_t *
o_hash_with_zone_with_callbacks(NSZone * zone,
				      o_callbacks_t callbacks)
{
  return o_hash_init_with_callbacks(o_hash_alloc_with_zone(zone),
					  callbacks);
}

o_hash_t *
o_hash_with_zone(NSZone * zone)
{
  return o_hash_init(o_hash_alloc_with_zone(zone));
}

o_hash_t *
o_hash_of_char_p(void)
{
  return o_hash_with_callbacks(o_callbacks_for_char_p);
}

o_hash_t *
o_hash_of_non_owned_void_p(void)
{
  return o_hash_with_callbacks(o_callbacks_for_non_owned_void_p);
}

o_hash_t *
o_hash_of_owned_void_p(void)
{
  return o_hash_with_callbacks(o_callbacks_for_owned_void_p);
}

o_hash_t *
o_hash_of_int(void)
{
  return o_hash_with_callbacks(o_callbacks_for_int);
}

o_hash_t *
o_hash_of_int_p(void)
{
  return o_hash_with_callbacks(o_callbacks_for_int_p);
}

o_hash_t *
o_hash_of_id(void)
{
  return o_hash_with_callbacks(o_callbacks_for_id);
}
/** Initializing **/

o_hash_t *
o_hash_init_with_callbacks(o_hash_t *hash,
				 o_callbacks_t callbacks)
{
  if (hash != 0)
  {
    size_t capacity = 10;
    /* Make a note of the callbacks for HASH. */
    hash->callbacks = o_callbacks_standardize(callbacks);

    /* Zero out the various counts. */
    hash->node_count = 0;
    hash->bucket_count = 0;
    hash->element_count = 0;

    /* Zero out the pointers. */
    hash->first_node = 0;
    hash->buckets = 0;

    /* Resize HASH to the given CAPACITY. */
    o_hash_resize(hash, capacity);
  }

  /* Return the newly initialized HASH. */
  return hash;
}

o_hash_t *
o_hash_init(o_hash_t *hash)
{
  return o_hash_init_with_callbacks(hash, o_callbacks_standard());
}

o_hash_t *
o_hash_init_from_hash(o_hash_t *hash, o_hash_t *old_hash)
{
  if (hash != 0)
  {
    o_hash_enumerator_t enumerator;
    const void *element;
    /* Make a note of the callbacks for HASH. */
    hash->callbacks = o_hash_element_callbacks(hash);

    /* Zero out the various counts. */
    hash->node_count = 0;
    hash->bucket_count = 0;
    hash->element_count = 0;

    /* Zero out the pointers. */
    hash->first_node = 0;
    hash->buckets = 0;

    /* Resize HASH to the given CAPACITY. */
    o_hash_resize(hash, o_hash_capacity(old_hash));

    /* Get an element enumerator for OLD_HASH. */
    enumerator = o_hash_enumerator_for_hash(old_hash);

    /* Add OLD_HASH's elements to HASH, one at a time. */
    while (o_hash_enumerator_next_element(&enumerator, &element))
      o_hash_add_element_known_absent(hash, element);
  }

  /* Return the newly initialized HASH. */
  return hash;
}

/** Destroying... **/

void
o_hash_dealloc(o_hash_t *hash)
{
  /* Remove all of HASH's elements. */
  o_hash_empty(hash);

  /* Free up the bucket array. */
  _o_hash_free_buckets(hash, hash->buckets);

  /* And finally, perform the ultimate sacrifice. */
  _o_hash_dealloc(hash);

  return;
}

/** Replacing... **/

/* If (some item "equal" to) ELEMENT is an element of HASH, then ELEMENT is
 * substituted for it.  (This is rather like the non-existant but perfectly
 * reasonable 'o_hash_add_element_if_present()'.) */
void
o_hash_replace_element(o_hash_t *hash, const void *element)
{
  o_hash_node_t *node;

  /* Lookup the node for ELEMENT. */
  node = _o_hash_node_for_element(hash, element);

  if (node != 0)
  {
    /* Remember: First retain the new element, then release the old
     * element, just in case they're the same. */
    o_retain(o_hash_element_callbacks(hash), element, hash);
    o_release(o_hash_element_callbacks(hash),
		    (void *)(node->element),
		    hash);
    node->element = element;
  }

  return;
}

/** Comparing... **/

/* Returns true if HASH1 is a superset of HASH2. */
int
o_hash_contains_hash(o_hash_t *hash1, o_hash_t *hash2)
{
  o_hash_enumerator_t enumerator;
  const void *element;
  enumerator = o_hash_enumerator_for_hash(hash2);

  while (o_hash_enumerator_next_element(&enumerator, &element))
    if (!o_hash_contains_element(hash1, element))
      return 0;

  return 1;
}

/* Returns true if HASH1 is both a superset and a subset of HASH2.
 * Checks to make sure HASH1 and HASH2 have the same number of
 * elements first. */
int
o_hash_is_equal_to_hash(o_hash_t *hash1, o_hash_t *hash2)
{
  size_t a,
         b;
  /* Count HASH1 and HASH2. */
  a = o_hash_count(hash1);
  b = o_hash_count(hash2);

  /* Check the counts. */
  if (a != b)
    return 0;

  /* If the counts match, then we do an element by element check. */
  if (!o_hash_contains_hash(hash1, hash2)
      || !o_hash_contains_hash(hash2, hash1))
    return 0;

  /* If we made it this far, HASH1 and HASH2 are the same. */
  return 1;
}

/* Returns true if HASH and OTHER_HASH have at least one element in
 * common. */
int
o_hash_intersects_hash(o_hash_t *hash, o_hash_t *other_hash)
{
  o_hash_enumerator_t enumerator;
  const void *element;
  /* Get an element enumerator for OTHER_HASH. */
  enumerator = o_hash_enumerator_for_hash(other_hash);

  while (o_hash_enumerator_next_element(&enumerator, &element))
    if (o_hash_contains_element(hash, element))
      return 1;

  return 0;
}

/** Copying... **/

/* Returns a new copy of OLD_HASH in ZONE. */
o_hash_t *
o_hash_copy_with_zone(o_hash_t *old_hash, NSZone * zone)
{
  o_hash_t *new_hash;
  /* Alloc the NEW_HASH, copying over the low-level stuff. */
  new_hash = _o_hash_copy_with_zone(old_hash, zone);

  /* Initialize the NEW_HASH. */
  o_hash_init_from_hash(new_hash, old_hash);

  /* Return the NEW_HASH. */
  return new_hash;
}

/* Returns a new copy of OLD_HASH, using the default zone. */
o_hash_t *
o_hash_copy(o_hash_t *old_hash)
{
  return o_hash_copy_with_zone(old_hash, NSDefaultMallocZone());
}

/** Mapping... **/

/* WARNING: The mapping function FCN must be one-to-one on elements of
 * HASH.  I.e., for reasons of efficiency, `o_hash_map_elements()'
 * makes no provision for the possibility that FCN maps two unequal
 * elements of HASH to the same (or equal) elements.  The better way
 * to handle functions that aren't one-to-one is to create a new hash
 * and transform the elements of the first to create the elements of
 * the second. */
o_hash_t *
o_hash_map_elements(o_hash_t *hash,
			  const void *(*fcn)(const void *, const void *),
			  const void *user_data)
{
  o_hash_enumerator_t enumerator;
  o_hash_node_t *node;
  enumerator = o_hash_enumerator_for_hash(hash);

  while ((node = _o_hash_enumerator_next_node(&enumerator)) != 0)
  {
    const void *element;
    element = (*fcn)(node->element, user_data);

    /* Remember: First retain the new element, then release the old
     * element. */
    o_retain(o_hash_element_callbacks(hash), element, hash);
    o_release(o_hash_element_callbacks(hash),
		    (void *)(node->element),
		    hash);
    node->element = element;
  }

  return hash;
}

/** Miscellaneous **/

/* Removes the elements of HASH which do not occur in OTHER_HASH. */
o_hash_t *
o_hash_intersect_hash(o_hash_t *hash, o_hash_t *other_hash)
{
  o_hash_enumerator_t enumerator;
  o_hash_node_t *node;
  enumerator = o_hash_enumerator_for_hash(hash);

  while ((node = _o_hash_enumerator_next_node(&enumerator)) != 0)
    if (!o_hash_contains_element(other_hash, node->element))
    {
      _o_hash_remove_node_from_its_hash(node);
      _o_hash_free_node(node);
    }

  return hash;
}

/* Removes the elements of HASH which occur in OTHER_HASH. */
o_hash_t *
o_hash_minus_hash(o_hash_t *hash, o_hash_t *other_hash)
{
  o_hash_enumerator_t enumerator;
  o_hash_node_t *node;
  enumerator = o_hash_enumerator_for_hash(hash);

  /* FIXME: Make this more efficient by enumerating
   * over the smaller of the two hashes only. */
  while ((node = _o_hash_enumerator_next_node(&enumerator)) != 0)
    if (o_hash_contains_element(other_hash, node->element))
    {
      _o_hash_remove_node_from_its_hash(node);
      _o_hash_free_node(node);
    }

  return hash;
}

/* Adds to HASH those elements of OTHER_HASH not occurring in HASH. */
o_hash_t *
o_hash_union_hash(o_hash_t *hash, o_hash_t *other_hash)
{
  o_hash_enumerator_t enumerator;
  const void *element;

  enumerator = o_hash_enumerator_for_hash(other_hash);

  while (o_hash_enumerator_next_element(&enumerator, &element))
    o_hash_add_element_if_absent(hash, element);

  return hash;
}

/** Describing a hash table... **/

NSString *
o_hash_description(o_hash_t *hash)
{
/* FIXME: Fix this. 
  NSMutableString *string;
  NSString *gnirts;
  o_callbacks_t callbacks;
  o_hash_enumerator_t enumerator;
  const void *element;

  callbacks = o_hash_element_callbacks(hash);
  enumerator = o_hash_enumerator_for_hash(hash);
  string = [_o_hash_description(hash) mutableCopy];

  [[string retain] autorelease];

#define DESCRIBE(E) o_describe(callbacks, (E), hash)

  [string appendFormat:@"element_count = %d;\n", o_hash_count(hash)];
  [string appendFormat:@"not_an_element_marker = %s;\n",
          [DESCRIBE(o_hash_not_an_element_marker(hash)) cString]];
  [string appendString:@"elements = {\n"];

  while (o_hash_enumerator_next_element(&enumerator, &element))
    [string appendFormat:@"%s,\n", [DESCRIBE(element) cString]];

  [string appendFormat:@"%s};\n",
          [DESCRIBE(o_hash_not_an_element_marker(hash)) cString]];

#undef DESCRIBE

  gnirts = [[[string copy] retain] autorelease];

  [string release];

  return gnirts;
*/
  return nil;
}
