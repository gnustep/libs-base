/* A map table implementation.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Tue Mar 12 02:12:37 EST 1996
 * Serial: 96.03.12.25
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

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <objects/callbacks.h>
#include <objects/hash.h>
#include <objects/map.h>

/**** Function Implementations ***********************************************/

/** Background functions **/

static inline objects_map_bucket_t *
_objects_map_pick_bucket_for_key(objects_map_t *map,
				 objects_map_bucket_t *buckets,
				 size_t bucket_count,
				 const void *key)
{
  return buckets + (objects_hash(objects_map_key_callbacks(map),
				 key, map)
		    % bucket_count);
}

static inline objects_map_bucket_t *
_objects_map_pick_bucket_for_node(objects_map_t *map,
				  objects_map_bucket_t *buckets,
				  size_t bucket_count,
				  objects_map_node_t *node)
{
  return buckets + (objects_hash(objects_map_key_callbacks(map),
				 node->key, map)
		    % bucket_count);
}

static inline objects_map_bucket_t *
_objects_map_bucket_for_key(objects_map_t *map, const void *key)
{
  return _objects_map_pick_bucket_for_key(map, map->buckets,
					  map->bucket_count, key);
}

static inline objects_map_bucket_t *
_objects_map_bucket_for_node(objects_map_t *map, objects_map_node_t *node)
{
  return _objects_map_pick_bucket_for_node(map, map->buckets,
					   map->bucket_count, node);
}

static inline void
_objects_map_link_node_into_bucket(objects_map_bucket_t *bucket,
				   objects_map_node_t *node)
{
  if (bucket->first_node != 0)
    bucket->first_node->prev_in_bucket = node;

  node->next_in_bucket = bucket->first_node;

  bucket->first_node = node;

  return;
}

static inline void
_objects_map_unlink_node_from_its_bucket(objects_map_node_t *node)
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
_objects_map_link_node_into_map(objects_map_t *map,
				objects_map_node_t *node)
{
  if (map->first_node != 0)
    map->first_node->prev_in_map = node;

  node->next_in_map = map->first_node;

  map->first_node = node;

  return;
}

static inline void
_objects_map_unlink_node_from_its_map(objects_map_node_t *node)
{
  if (node == node->map->first_node)
    node->map->first_node = node->next_in_map;

  if (node->prev_in_map != 0)
    node->prev_in_map->next_in_map = node->next_in_map;
  if (node->next_in_map != 0)
    node->next_in_map->prev_in_map = node->prev_in_map;

  node->prev_in_map = node->next_in_map = 0;

  return;
}

static inline void
_objects_map_add_node_to_bucket(objects_map_bucket_t *bucket,
				objects_map_node_t *node)
{
  if (bucket != 0)
  {
    _objects_map_link_node_into_bucket(bucket, node);

    node->bucket = bucket;

    bucket->node_count += 1;
    bucket->element_count += 1;
  }

  return;
}

static inline void
_objects_map_add_node_to_its_bucket(objects_map_t *map,
				    objects_map_node_t *node)
{
  _objects_map_add_node_to_bucket(_objects_map_bucket_for_node(map, node),
				  node);
  return;
}

static inline void
_objects_map_add_node_to_map(objects_map_t *map, objects_map_node_t *node)
{
  if (map != 0)
  {
    _objects_map_add_node_to_its_bucket(map, node);

    _objects_map_link_node_into_map(map, node);

    node->map = map;

    map->node_count += 1;
    map->element_count += 1;
  }

  return;
}

static inline void
_objects_map_remove_node_from_its_bucket(objects_map_node_t *node)
{
  if (node->bucket != 0)
  {
    node->bucket->node_count -= 1;
    node->bucket->element_count -= 1;

    _objects_map_unlink_node_from_its_bucket(node);
  }

  return;
}

static inline void
_objects_map_remove_node_from_its_map(objects_map_node_t *node)
{
  if (node->map != 0)
  {
    node->map->node_count -= 1;
    node->map->element_count -= 1;

    _objects_map_unlink_node_from_its_map(node);
  }

  _objects_map_remove_node_from_its_bucket(node);

  return;
}

static inline objects_map_bucket_t *
_objects_map_new_buckets(objects_map_t *map, size_t bucket_count)
{
  return (objects_map_bucket_t *)NSZoneCalloc(objects_map_zone(map),
					      bucket_count,
					   sizeof(objects_map_bucket_t));
}

static inline void
_objects_map_free_buckets(objects_map_t *map, objects_map_bucket_t *buckets)
{
  if (buckets != 0)
    NSZoneFree(objects_map_zone(map), buckets);
  return;
}

static inline void
_objects_map_remangle_buckets(objects_map_t *map,
			      objects_map_bucket_t *old_buckets,
			      size_t old_bucket_count,
			      objects_map_bucket_t *new_buckets,
			      size_t new_bucket_count)
{
  size_t i;
  objects_map_node_t *node;
  for (i = 0; i < old_bucket_count; i++)
  {
    while ((node = old_buckets[i].first_node) != 0)
    {
      _objects_map_remove_node_from_its_bucket(node);
      _objects_map_add_node_to_bucket(_objects_map_pick_bucket_for_node(map,
							     new_buckets,
							new_bucket_count,
								   node),
				      node);
    }
  }

  /* And that's that. */
  return;
}

static inline objects_map_node_t *
_objects_map_new_node(objects_map_t *map, const void *key, const void *value)
{
  objects_map_node_t *node;
  /* Allocate the space for a new node. */
  node = (objects_map_node_t *)NSZoneMalloc(objects_map_zone(map),
					    sizeof(objects_map_node_t));

  if (node != 0)
  {
    /* Retain KEY and VALUE.  (They're released below in
     * `_objects_map_free_node()'.) */
    objects_retain(objects_map_key_callbacks(map), key, map);
    objects_retain(objects_map_value_callbacks(map), value, map);

    /* Remember KEY and VALUE. */
    node->key = key;
    node->value = value;

    /* Zero out the various pointers. */
    node->map = 0;
    node->bucket = 0;
    node->next_in_bucket = 0;
    node->next_in_map = 0;
    node->prev_in_bucket = 0;
    node->prev_in_map = 0;
  }

  return node;
}

static inline void
_objects_map_free_node(objects_map_node_t *node)
{
  if (node != 0)
  {
    objects_map_t *map;
    /* Remember NODE's map. */
    map = node->map;

    /* Release KEY and VALUE.  (They're retained above in
     * `_objects_map_new_node()'.) */
    objects_release(objects_map_key_callbacks(map),
		    (void *)node->key, map);
    objects_release(objects_map_value_callbacks(map),
		    (void *)node->value, map);

    /* Actually free the space map aside for NODE. */
    NSZoneFree(objects_map_zone(map), node);
  }

  /* And just return. */
  return;
}

static inline objects_map_node_t *
_objects_map_node_for_key(objects_map_t *map, const void *key)
{
  objects_map_bucket_t *bucket;
  objects_map_node_t *node;
  /* Find the bucket in which the node for KEY would be. */
  bucket = _objects_map_bucket_for_key(map, key);

  /* Run through the nodes in BUCKET until we find one whose element
   * matches ELEMENT. */
  for (node = bucket->first_node;
       (node != 0) && !objects_is_equal(objects_map_key_callbacks(map),
					   key,
					   node->key,
					   map);
       node = node->next_in_bucket);

  /* Note that if none of the nodes' elements matches ELEMENT, then we
   * naturally return `0'. */
  return node;
}

/** Callbacks... **/

/* Return a hash index for MAP.  Needed for the callbacks below. */
size_t
_objects_map_hash(objects_map_t *map)
{
  /* One might be tempted to do something simple here, but remember:
   * If two map tables are equal they *must* hash to the same value! */

  /* FIXME: Code this. */
  return 0;
}

/* An (inefficient, but necessary) "retaining" function for map tables. */
objects_map_t *
_objects_map_retain(objects_map_t *map, objects_map_t *in_map)
{
  /* Note that this works only because all the structures (hash, map
   * list, array) look alike at first...so we can get the zone of
   * one just like we can get the zone of any of them. */
  return objects_map_copy_with_zone(map, objects_map_zone(in_map));
}

/* Returns a collection of callbacks for use with map tables. */
objects_callbacks_t
objects_callbacks_for_map(void)
{
  objects_callbacks_t map_callbacks =
  {
    (objects_hash_func_t) _objects_map_hash,
    (objects_compare_func_t) 0,
    (objects_is_equal_func_t) objects_map_is_equal_to_map,
    (objects_retain_func_t) _objects_map_retain,
    (objects_release_func_t) objects_map_dealloc,
    (objects_describe_func_t) objects_map_description,
    0
  };

  return map_callbacks;
}

/** Resizing **/

size_t
objects_map_resize(objects_map_t *map, size_t new_capacity)
{
  objects_map_bucket_t *new_buckets;
  /* Round NEW_CAPACITY up to the next power of two. */
  new_capacity = _objects_next_power_of_two(new_capacity);

  /* Make a new map of buckets. */
  new_buckets = _objects_map_new_buckets(map, new_capacity);

  if (new_buckets != 0)
  {
    _objects_map_remangle_buckets(map,
				  map->buckets,
				  map->bucket_count,
				  new_buckets,
				  new_capacity);

    _objects_map_free_buckets(map, map->buckets);

    map->buckets = new_buckets;
    map->bucket_count = new_capacity;
  }

  /* Return the new capacity. */
  return map->bucket_count;
}

size_t
objects_map_rightsize(objects_map_t *map)
{
  /* FIXME: Now, this is a guess, based solely on my intuition.  If anyone
   * knows of a better ratio (or other test, for that matter) and can
   * provide evidence of its goodness, please get in touch with me, Albin
   * L. Jones <Albin.L.Jones@Dartmouth.EDU>. */

  if (3 * map->node_count > 4 * map->bucket_count)
  {
    return objects_map_resize(map, map->bucket_count + 1);
  }
  else
  {
    return map->bucket_count;
  }
}

/** Statistics... **/

/* Returns the number of key/value pairs in MAP. */
size_t
objects_map_count(objects_map_t *map)
{
  return map->element_count;
}

/* Returns some (inexact) measure of how many key/value pairs
 * MAP can comfortably hold without resizing. */
size_t
objects_map_capacity(objects_map_t *map)
{
  return map->bucket_count;
}

/* Performs an internal consistency check, returns 'true' if
 * everything is OK, 'false' otherwise.  Really useful only
 * for debugging. */
int
objects_map_check(objects_map_t *map)
{
  /* FIXME: Code this. */
  return 1;
}

int
objects_map_is_empty(objects_map_t *map)
{
  return objects_map_count(map) == 0;
}

/** Searching **/

/* Returns 'true' if and only if some key in MAP is equal
 * (in the sense of the key callbacks of MAP) to KEY. */
int
objects_map_contains_key(objects_map_t *map, const void *key)
{
  if (_objects_map_node_for_key(map, key) != 0)
    return 1;
  else
    return 0;
}

/* Returns 'true' if and only if some value in MAP is equal
 * (in the sense of the value callbacks of MAP) to VALUE. */
/* WARNING: This is rather inefficient.  Not to be used lightly. */
int
objects_map_contains_value(objects_map_t *map, const void *value)
{
  objects_map_enumerator_t me;
  const void *v = 0;

  /* ME is an enumerator for MAP. */
  me = objects_map_enumerator_for_map(map);

  /* Enumerate, and check. */
  while (objects_map_enumerator_next_value(&me, &v))
    if (objects_is_equal(objects_map_value_callbacks(map), value, v, map))
      return 1;

  /* If we made it this far, then VALUE isn't in MAP. */
  return 0;
}

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
inline int
objects_map_key_and_value_at_key(objects_map_t *map,
				 const void **old_key,
				 const void **value,
				 const void *key)
{
  objects_map_node_t *node;

  /* Try and find the node for KEY. */
  node = _objects_map_node_for_key(map, key);

  if (node != 0)
  {
    if (old_key != 0)
      *old_key = node->key;
    if (value != 0)
      *value = node->value;
    return 1;
  }
  else /* (node == 0) */
  {
    if (old_key != 0)
      *old_key = objects_map_not_a_key_marker(map);
    if (value != 0)
      *value = objects_map_not_a_value_marker(map);
    return 0;
  }
}

/* If KEY is in MAP, then the key of MAP which is equal to KEY
 * is returned.  Otherwise, the "not a key marker" for MAP is returned. */
const void *
objects_map_key_at_key(objects_map_t *map, const void *key)
{
  const void *old_key;

  /* Use the grandfather function above... */
  objects_map_key_and_value_at_key(map, &old_key, 0, key);

  return old_key;
}

/* If KEY is in MAP, then the value of MAP which to which KEY maps
 * is returned.  Otherwise, the "not a value marker" for MAP is returned. */
const void *
objects_map_value_at_key(objects_map_t *map, const void *key)
{
  const void *value;

  /* Use the grandfather function above... */
  objects_map_key_and_value_at_key(map, 0, &value, key);

  return value;
}

const void **
objects_map_all_keys_and_values(objects_map_t *map)
{
  size_t j;
  const void **array;
  objects_map_enumerator_t enumerator;
  /* Allocate space for ARRAY.  Remember that it is the programmer's
   * responsibility to free this by calling
   * `NSZoneFree(objects_map_zone(MAP), ARRAY)' */
  array = (const void **)NSZoneCalloc(objects_map_zone(map),
				      2 * (objects_map_count(map) + 1),
				      sizeof(void *));

  /* ENUMERATOR is an enumerator for MAP. */
  enumerator = objects_map_enumerator_for_map(map);

  /* Now we enumerate through the elements of MAP, adding them one-by-one
   * to ARRAY.  Note that this automagically puts the ``not a key/value
   * markers'' at the end of ARRAY.  */
  for (j = 0;
       objects_map_enumerator_next_key_and_value(&enumerator,
						 array + j,
						 array + j + 1);
       j += 2);

  /* And we're done. */
  return array;
}

const void **
objects_map_all_keys(objects_map_t *map)
{
  size_t j;
  const void **array;
  objects_map_enumerator_t enumerator;

  /* FIXME: Morally, deallocating this space shouldn't be the
   * programmer's responsibility.  Maybe we should be returning
   * an NSArray? */

  /* Allocate space for ARRAY.  Remember that it is the programmer's
   * responsibility to free this by calling
   * `NSZoneFree(objects_map_zone(MAP), ARRAY)' */
  array = (const void **)NSZoneCalloc(objects_map_zone(map),
				      objects_map_count(map) + 1,
				      sizeof(void *));

  /* ENUMERATOR is an enumerator for MAP. */
  enumerator = objects_map_enumerator_for_map(map);

  /* Now we enumerate through the elements of MAP, adding them one-by-one
   * to ARRAY.  Note that this automagically puts the ``not a key marker''
   * at the end of ARRAY.  */
  for (j = 0; objects_map_enumerator_next_key(&enumerator, array + j); j++);

  /* And we're done. */
  return array;
}

const void **
objects_map_all_values(objects_map_t *map)
{
  size_t j;
  const void **array;
  objects_map_enumerator_t enumerator;

  /* FIXME: Morally, deallocating this space shouldn't be the
   * programmer's responsibility.  Maybe we should be returning
   * an NSArray? */

  /* Allocate space for ARRAY.  Remember that it is the programmer's
   * responsibility to free this by calling
   * `NSZoneFree(objects_map_zone(MAP), ARRAY)' */
  array = (const void **)NSZoneCalloc(objects_map_zone(map),
				      objects_map_count(map) + 1,
				      sizeof(void *));

  /* ENUMERATOR is an enumerator for MAP. */
  enumerator = objects_map_enumerator_for_map(map);

  /* Now we enumerate through the elements of MAP, adding them one-by-one
   * to ARRAY.  Note that this automagically puts the ``not a value
   * marker'' at the end of ARRAY.  */
  for (j = 0; objects_map_enumerator_next_value(&enumerator, array + j); j++);

  /* And we're done. */
  return array;
}
/** Enumerating **/

/* WARNING: You should not alter a map while an enumeration is
 * in progress.  The results of doing so are reasonably unpremapable.
 * With that in mind, read the following warnings carefully.  But
 * remember, DON'T MESS WITH A MAP WHILE YOU'RE ENUMERATING IT. */

/* IMPORTANT WARNING: Map enumerators, as I have map them up, have a
 * wonderous property.  Namely, that, while enumerating, one may add
 * new elements (i.e., new nodes) to the map while an enumeration is
 * in progress (i.e., after `objects_map_enumerator_for_map()' has been
 * called), and the enumeration remains the same. */

/* WARNING: The above warning should not, in any way, be taken as
 * assurance that this property of map enumerators will be preserved
 * in future editions of the library.  I'm still thinking about
 * this. */

/* IMPORTANT WARNING: Enumerators have yet another wonderous property.
 * Once a node has been returned by `_map_next_node()', it may be
 * removed from the map without effecting the rest of the current
 * enumeration.  For example, to clean all of the nodes out of a map,
 * the following code would work:
 * 
 * void
 * empty_my_map(objects_map_t *map)
 * {
 *   objects_map_enuemrator_t enumerator = objects_map_enumerator_for_map(map);
 *   objects_map_node_t *node;
 * 
 *   while ((node = _objects_map_next_node(&enumerator)) != 0)
 *   {
 *     _objects_map_remove_node_from_its_map(node);
 *     _objects_map_free_node(node);
 *   }
 * 
 *   return;
 * }
 * 
 * (In fact, this is the code currently being used below in the
 * function `map_delete_all_elements()'.)  But again, this is not to be
 * taken as an assurance that this behaviour will persist in future
 * versions of the library. */

/* EXTREMELY IMPORTANT WARNING: The purpose of this warning is point
 * out that, at this time, various (i.e., many) functions depend on
 * the behaviours outlined above.  So be prepared for some serious
 * breakage when you go fudging around with these things. */

objects_map_enumerator_t
objects_map_enumerator_for_map(objects_map_t *map)
{
  objects_map_enumerator_t enumerator;
  /* Make sure ENUMERATOR knows its mapionary. */
  enumerator.map = map;

  /* Start ENUMERATOR at MAP's first node. */
  enumerator.node = map->first_node;

  return enumerator;
}

objects_map_node_t *
_objects_map_enumerator_next_node(objects_map_enumerator_t *enumerator)
{
  objects_map_node_t *node;
  /* Remember ENUMERATOR's current node. */
  node = enumerator->node;

  /* If NODE is a real node, then we need to increment ENUMERATOR's
   * current node to the next node in ENUMERATOR's map. */
  if (node != 0)
    enumerator->node = enumerator->node->next_in_map;

  /* Send back NODE. */
  return node;
}

int
objects_map_enumerator_next_key_and_value(objects_map_enumerator_t *enumerator,
					  const void **key,
					  const void **value)
{
  objects_map_node_t *node;
  /* Try and get the next node in the enumeration represented by
   * ENUMERATOR. */
  node = _objects_map_enumerator_next_node(enumerator);

  if (node != 0)
  {
    /* If NODE is real, then return the key and value it contains. */
    if (key != 0)
      *key = node->key;
    if (value != 0)
      *value = node->value;

    /* Indicate that the enumeration continues. */
    return 1;
  }
  else
  {
    /* If NODE isn't real, then we return the ``bogus'' indicators. */
    if (key != 0)
      *key = objects_map_not_a_key_marker(enumerator->map);
    if (value != 0)
      *value = objects_map_not_a_value_marker(enumerator->map);

    /* Indicate that the enumeration is over. */
    return 0;
  }
}

int
objects_map_enumerator_next_key(objects_map_enumerator_t *enumerator,
				const void **key)
{
  return objects_map_enumerator_next_key_and_value(enumerator, key, 0);
}

int
objects_map_enumerator_next_value(objects_map_enumerator_t *enumerator,
				  const void **value)
{
  return objects_map_enumerator_next_key_and_value(enumerator, 0, value);
}
/** Adding **/

/* FIXME: Make this check for invalidity and abort or raise an exception! */

const void *
objects_map_at_key_put_value_known_absent(objects_map_t *map,
					  const void *key,
					  const void *value)
{
  objects_map_node_t *node;
  /* Resize MAP if needed. */
  objects_map_rightsize(map);

  /* Make NODE a node which holds KEY and VALUE. */
  node = _objects_map_new_node(map, key, value);

  if (node != 0)
  {
    /* NODE is real, so stick it in MAP. */
    _objects_map_add_node_to_map(map, node);

    /* Return ELEMENT, just in case someone wants to look at it. */
    return key;
  }
  else
  {
    /* NODE would be `0' only if an allocation failed, but it's worth
     * checking and returning an error if appropriate, I guess. It just
     * seems like the kind thing to do. */
    return objects_map_not_a_key_marker(map);
  }
}

const void *
objects_map_at_key_put_value(objects_map_t *map,
			     const void *key,
			     const void *value)
{
  objects_map_node_t *node;
  /* First, we check for KEY in MAP. */
  node = _objects_map_node_for_key(map, key);

  if (node != 0)
  {
    objects_retain(objects_map_value_callbacks(map), value, map);
    objects_release(objects_map_value_callbacks(map),
		    (void *)node->value, map);
    node->value = value;
    return node->key;
  }
  else
  {
    /* KEY isn't in MAP, so we can add it with impunity. */
    return objects_map_at_key_put_value_known_absent(map, key, value);
  }
}

const void *
objects_map_at_key_put_value_if_absent(objects_map_t *map,
				       const void *key,
				       const void *value)
{
  objects_map_node_t *node;
  /* Look for a node with KEY in it. */
  node = _objects_map_node_for_key(map, key);

  if (node != 0)
  {
    /* If NODE is real, then KEY is already in MAP.  So we return the
     * member key of MAP which is ``equal to'' KEY. */
    return node->key;
  }
  else
  {
    /* If NODE isn't real, then we may add KEY (and VALUE) to MAP without
     * worrying too much. */
    return objects_map_at_key_put_value_known_absent(map, key, value);
  }
}
/** Removing **/

void
objects_map_remove_key(objects_map_t *map, const void *key)
{
  objects_map_node_t *node;
  /* Look for a node with KEY in it. */
  node = _objects_map_node_for_key(map, key);

  if (node != 0)
  {
    /* If NODE is real, then we've got something to remove. */
    _objects_map_remove_node_from_its_map(node);
    _objects_map_free_node(node);
  }

  return;
}
/** Emptying **/

void
objects_map_empty(objects_map_t *map)
{
  objects_map_enumerator_t enumerator;
  objects_map_node_t *node;

  /* Get an element enumerator for MAP. */
  enumerator = objects_map_enumerator_for_map(map);

  /* Just step through the nodes of MAP and wipe them out, one after
   * another.  Don't try this at home, kids! */
  while ((node = _objects_map_enumerator_next_node(&enumerator)) != 0)
  {
    _objects_map_remove_node_from_its_map(node);
    _objects_map_free_node(node);
  }

  /* And return. */
  return;
}
/** Creating **/

objects_map_t *
objects_map_alloc_with_zone(NSZone * zone)
{
  objects_map_t *map;
  map = _objects_map_alloc_with_zone(zone);

  return map;
}

objects_map_t *
objects_map_alloc(void)
{
  return objects_map_alloc_with_zone(0);
}

objects_map_t *
objects_map_with_zone(NSZone * zone)
{
  return objects_map_init(objects_map_alloc_with_zone(zone));
}

objects_map_t *
objects_map_with_zone_with_callbacks(NSZone * zone,
				     objects_callbacks_t key_callbacks,
				     objects_callbacks_t value_callbacks)
{
  return objects_map_init_with_callbacks(objects_map_alloc_with_zone(zone),
					 key_callbacks,
					 value_callbacks);
}

objects_map_t *
objects_map_with_callbacks(objects_callbacks_t key_callbacks,
			   objects_callbacks_t value_callbacks)
{
  return objects_map_init_with_callbacks(objects_map_alloc(),
					 key_callbacks,
					 value_callbacks);
}

objects_map_t *
objects_map_of_char_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_char_p,
				    objects_callbacks_for_char_p);
}

objects_map_t *
objects_map_of_char_p_to_int(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_char_p,
				    objects_callbacks_for_int);
}

objects_map_t *
objects_map_of_char_p_to_non_owned_void_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_char_p,
				    objects_callbacks_for_non_owned_void_p);
}

objects_map_t *
objects_map_of_char_p_to_id(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_char_p,
				    objects_callbacks_for_id);
}

objects_map_t *
objects_map_of_non_owned_void_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_non_owned_void_p,
				    objects_callbacks_for_non_owned_void_p);
}

objects_map_t *
objects_map_of_int(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_int,
				    objects_callbacks_for_int);
}

objects_map_t *
objects_map_of_int_to_char_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_int,
				    objects_callbacks_for_char_p);
}

objects_map_t *
objects_map_of_int_to_non_owned_void_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_int,
				    objects_callbacks_for_non_owned_void_p);
}

objects_map_t *
objects_map_of_int_to_id(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_int,
				    objects_callbacks_for_id);
}

objects_map_t *
objects_map_of_id(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_id,
				    objects_callbacks_for_id);
}

objects_map_t *
objects_map_of_id_to_int(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_id,
				    objects_callbacks_for_int);
}

objects_map_t *
objects_map_of_id_to_char_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_id,
				    objects_callbacks_for_char_p);
}

objects_map_t *
objects_map_of_id_to_non_owned_void_p(void)
{
  return objects_map_with_callbacks(objects_callbacks_for_id,
				    objects_callbacks_for_non_owned_void_p);
}
/** Initializing **/

objects_map_t *
objects_map_init_with_callbacks(objects_map_t *map,
				objects_callbacks_t key_callbacks,
				objects_callbacks_t value_callbacks)
{
  if (map != 0)
  {
    size_t capacity = 10;

    /* Make a note of the callbacks for MAP. */
    map->key_callbacks = objects_callbacks_standardize(key_callbacks);
    map->value_callbacks = objects_callbacks_standardize(value_callbacks);

    /* Zero out the various counts. */
    map->node_count = 0;
    map->bucket_count = 0;
    map->element_count = 0;

    /* Zero out the pointers. */
    map->first_node = 0;
    map->buckets = 0;

    /* Resize MAP to the given CAPACITY. */
    objects_map_resize(map, capacity);
  }

  /* Return the newly initialized MAP. */
  return map;
}

objects_map_t *
objects_map_init(objects_map_t *map)
{
  return objects_map_init_with_callbacks(map,
					 objects_callbacks_standard(),
					 objects_callbacks_standard());
}

objects_map_t *
objects_map_init_from_map(objects_map_t *map, objects_map_t *old_map)
{
  objects_map_enumerator_t enumerator;
  const void *key;
  const void *value;

  /* Initialize MAP. */
  objects_map_init_with_callbacks(map,
				  objects_map_key_callbacks(old_map),
				  objects_map_value_callbacks(old_map));

  objects_map_resize(map, objects_map_capacity(old_map));

  /* Get an enumerator for OLD_MAP. */
  enumerator = objects_map_enumerator_for_map(old_map);

  /* Step through the pairs of OLD_MAP, adding each in turn to MAP. */
  while (objects_map_enumerator_next_key_and_value(&enumerator, &key, &value))
    objects_map_at_key_put_value(map, key, value);

  /* Return the newly initialized MAP. */
  return map;
}
/** Destroying... **/

/* Releases all the keys and values of MAP, and then
 * deallocates MAP itself. */
void
objects_map_dealloc(objects_map_t *map)
{
  if (map != 0)
  {
    /* Remove all of MAP's elements. */
    objects_map_empty(map);

    /* Free up the bucket array. */
    _objects_map_free_buckets(map, map->buckets);

    /* And finally, free up the space that MAP itself takes up. */
    _objects_map_dealloc(map);
  }

  return;
}
/** Replacing **/

void
objects_map_replace_key(objects_map_t *map,
			const void *key)
{
  objects_map_node_t *node;

  /* Look up the node (if any) for KEY in MAP. */
  node = _objects_map_node_for_key(map, key);

  if (node != 0)
  {
    /* Remember: First retain, then release;
     * just in case they're the same. */
    objects_retain(objects_map_key_callbacks(map), key, map);
    objects_release(objects_map_key_callbacks(map),
		    (void *)(node->key), map);

    /* Because "equality" is suppossedly transitive, we needn't
     * worry about having duplicate keys in MAP after this. */
    node->key = key;
  }

  return;
}
/** Comparing **/

/* Returns 'true' if every key/value pair of MAP2 is also a key/value pair
 * of MAP1.  Otherwise, returns 'false'. */
int
objects_map_contains_map(objects_map_t *map1, objects_map_t *map2)
{
  objects_map_enumerator_t enumerator;
  const void *key = 0;
  const void *value = 0;

  /* ENUMERATOR is a key/value enumerator for MAP2. */
  enumerator = objects_map_enumerator_for_map(map2);

  while (objects_map_enumerator_next_key_and_value(&enumerator, &key, &value))
  {
    objects_map_node_t *node;

    /* Try an get MAP1's node for KEY. */
    node = _objects_map_node_for_key(map1, key);

    /* If MAP1 doesn't even have KEY as a key, then we're done. */
    if (node == 0)
      return 0;

    /* If MAP1 has K as a key, but doesn't map
     * KEY to VALUE, then we're done. */
    if (objects_compare(objects_map_value_callbacks(map1), node->value,
                        value, map1))
      return 0;
  }

  return 1;
}

/* Returns 'true' iff some key/value pair of MAP1 if also
 * a key/value pair of MAP2. */
int
objects_map_intersects_map(objects_map_t *map1, objects_map_t *map2)
{
  objects_map_enumerator_t enumerator;
  const void *key = 0;
  const void *value = 0;

  /* ENUMERATOR is a key/value enumerator for MAP2. */
  enumerator = objects_map_enumerator_for_map(map2);

  while (objects_map_enumerator_next_key_and_value(&enumerator, &key, &value))
  {
    objects_map_node_t *node;

    /* Try an get MAP1's node for KEY. */
    node = _objects_map_node_for_key(map1, key);

    /* If MAP1 doesn't even have KEY as a key, then we're done. */
    if (node != 0)
      /* If MAP1 has KEY as a key, and maps KEY
       * to VALUE, then we're done.  Yippee! */
      if (objects_is_equal(objects_map_value_callbacks(map1),
                           node->value, value, map1))
        return 1;
  }

  return 0;
}

int
objects_map_is_equal_to_map(objects_map_t *map1, objects_map_t *map2)
{
  /* Check the counts. */
  if (objects_map_count(map1) != objects_map_count(map2))
    return 0;

  /* If the counts match, then we do an pair by pair check. */
  if (!objects_map_contains_map(map1, map2)
      || !objects_map_contains_map(map2, map1))
    return 0;

  /* If we made it this far, MAP1 and MAP2 are the same. */
  return 1;
}

/* Returns 'true' iff every key of MAP2 is a key of MAP1. */
int
objects_map_keys_contain_keys_of_map(objects_map_t *map1, objects_map_t *map2)
{
  objects_map_enumerator_t enumerator;
  const void *key;

  enumerator = objects_map_enumerator_for_map(map2);

  if (objects_map_count(map1) < objects_map_count(map2))
    return 0;

  while (objects_map_enumerator_next_key(&enumerator, &key))
    if (!objects_map_contains_key(map1, key))
      return 0;

  return 1;
}

/* Returns 'true' iff some key of MAP1 if also a key of MAP2. */
int
objects_map_keys_intersect_keys_of_map(objects_map_t *map1,
                                       objects_map_t *map2)
{
  objects_map_enumerator_t enumerator;
  const void *key;

  enumerator = objects_map_enumerator_for_map(map1);

  while (objects_map_enumerator_next_key(&enumerator, &key))
    if (objects_map_contains_key(map2, key))
      return 1;

  return 0;
}

/* Returns 'true' if MAP1 and MAP2 have the same number of key/value pairs,
 * MAP1 contains every key of MAP2, and MAP2 contains every key of MAP1.
 * Otherwise, returns 'false'. */
int
objects_map_keys_are_equal_to_keys_of_map(objects_map_t *map1,
                                          objects_map_t *map2);

/** Copying **/

objects_map_t *
objects_map_copy_with_zone(objects_map_t *old_map, NSZone * zone)
{
  objects_map_t *new_map;
  /* Alloc the NEW_MAP. */
  new_map = _objects_map_copy_with_zone(old_map, zone);

  /* Initialize the NEW_MAP. */
  objects_map_init_from_map(new_map, old_map);

  /* And return the copy. */
  return new_map;
}

objects_map_t *
objects_map_copy(objects_map_t *old_map)
{
  return objects_map_copy_with_zone(old_map, 0);
}

/** Describing... **/

/* Returns a string describing (the contents of) MAP. */
NSString *
objects_map_description(objects_map_t *map)
{
  /* FIXME: Code this. */
  return nil;
}

/** Mapping **/

objects_map_t *
objects_map_map_keys(objects_map_t *map,
		     const void *(*fcn)(const void *, void *),
		     void *user_data)
{
  objects_map_enumerator_t enumerator;
  objects_map_node_t *node;

  enumerator = objects_map_enumerator_for_map(map);

  while ((node = _objects_map_enumerator_next_node(&enumerator)) != 0)
  {
    const void *key;

    key = (*fcn)(node->key, user_data);

    objects_retain(objects_map_key_callbacks(map), key, map);
    objects_release(objects_map_key_callbacks(map),
		    (void *)(node->key), map);
    node->key = key;
  }

  return map;
}

objects_map_t *
objects_map_map_values(objects_map_t *map,
		       const void *(*fcn) (const void *, void *),
		       void *user_data)
{
  objects_map_enumerator_t enumerator;
  objects_map_node_t *node;

  enumerator = objects_map_enumerator_for_map(map);

  while ((node = _objects_map_enumerator_next_node(&enumerator)) != 0)
  {
    const void *value;

    value = (*fcn)(node->value, user_data);

    objects_retain(objects_map_value_callbacks(map), value, map);
    objects_release(objects_map_value_callbacks(map),
		    (void *)(node->value), map);
    node->value = value;
  }

  return map;
}
/** Miscellaneous **/

objects_map_t *
objects_map_intersect_map(objects_map_t *map, objects_map_t *other_map)
{
  objects_map_enumerator_t enumerator;
  const void *key;

  enumerator = objects_map_enumerator_for_map(map);

  while (objects_map_enumerator_next_key(&enumerator, &key))
    if (!objects_map_contains_key(other_map, key))
      objects_map_remove_key(map, key);

  return map;
}

objects_map_t *
objects_map_minus_map(objects_map_t *map, objects_map_t *other_map)
{
  objects_map_enumerator_t enumerator;
  const void *key;

  enumerator = objects_map_enumerator_for_map(other_map);

  while (objects_map_enumerator_next_key(&enumerator, &key))
  {
    objects_map_remove_key(map, key);
  }

  return map;
}

objects_map_t *
objects_map_union_map(objects_map_t *map, objects_map_t *other_map)
{
  objects_map_enumerator_t enumerator;
  const void *key;
  const void *value;

  enumerator = objects_map_enumerator_for_map(other_map);

  while (objects_map_enumerator_next_key_and_value(&enumerator, &key, &value))
  {
    objects_map_at_key_put_value_if_absent(map, key, value);
  }

  return map;
}
