/* A (pretty good) implementation of a sparse array.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Thu Mar  2 02:28:50 EST 1994
 * Updated: Tue Mar 12 02:42:33 EST 1996
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA. */ 

/**** Included Headers *******************************************************/

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSZone.h>
#include <base/o_cbs.h>
#include <base/o_array.h>
#include <base/o_hash.h>

/**** Function Implementations ***********************************************/

/** Background functions **/

static inline size_t
_o_array_fold_index(size_t index, size_t slot_count)
{
  return (slot_count ? (index % slot_count) : 0);
}

static inline size_t
_o_array_internal_index(o_array_t *array, size_t index)
{
  return _o_array_fold_index (index, array->slot_count);
}

static inline o_array_slot_t *
_o_array_slot_for_index(o_array_t *array, size_t index)
{
  return (array->slots + _o_array_internal_index (array, index));
}

static inline o_array_bucket_t *
_o_array_bucket_for_index (o_array_t *array, size_t index)
{
  o_array_slot_t *slot;
  o_array_bucket_t *bucket;

  /* First, we translate the index into a bucket index to find our
   * candidate for the bucket. */
  slot = _o_array_slot_for_index (array, index);
  bucket = *slot;

  /* But we need to check to see whether this is really the bucket we
   * wanted. */
  if (bucket != 0 && bucket->index == index)
    /* Bucket `index' exists, and we've got it, so... */
    return bucket;
  else
    /* Either no bucket or some other bucket is where bucket `index'
     * would be, if it existed.  So... */
    return 0;
}

static inline o_array_bucket_t *
_o_array_new_bucket (o_array_t *array, size_t index, const void *element)
{
  o_array_bucket_t *bucket;

  bucket = (o_array_bucket_t *) NSZoneMalloc(o_array_zone(array),
					     sizeof(o_array_bucket_t));
  if (bucket != 0)
  {
    o_retain(o_array_element_callbacks(array), element, array);
    bucket->index = index;
    bucket->element = element;
  }
  return bucket;
}

static inline void
_o_array_free_bucket(o_array_t *array,
                           o_array_bucket_t *bucket)
{
  if (bucket != 0)
  {
    o_release(o_array_element_callbacks (array),
                    (void *)(bucket->element),
                    array);
      NSZoneFree(o_array_zone(array), bucket);
  }

  return;
}

static inline o_array_slot_t *
_o_array_new_slots(o_array_t *array, size_t slot_count)
{
  return (o_array_slot_t *) NSZoneCalloc(o_array_zone(array),
                                               slot_count,
                                               sizeof(o_array_slot_t));
}

static inline void
_o_array_free_slots(o_array_t *array,
                          o_array_slot_t *slots)
{
  if (slots != 0)
    NSZoneFree(o_array_zone(array), slots);
  return;
}

static inline void
_o_array_empty_slot (o_array_t *array, o_array_slot_t * slot)
{
  if (*slot != 0)
    {
      /* Get rid of the bucket. */
      _o_array_free_bucket (array, *slot);

      /* Mark the slot as empty. */
      *slot = 0;

      /* Keep the element count accurate */
      --(array->element_count);
    }

  /* And return. */
  return;
}

static inline void
_o_array_insert_bucket(o_array_t *array,
                             o_array_bucket_t * bucket)
{
  o_array_slot_t *slot;

  slot = _o_array_slot_for_index (array, bucket->index);

  /* We're adding a bucket, so the current set of sorted slots is now
   * invalidated. */
  if (array->sorted_slots != 0)
    {
      _o_array_free_slots (array, array->sorted_slots);
      array->sorted_slots = 0;
    }

  if ((*slot) == 0)
    {
      /* There's nothing there, so we can put `bucket' there. */
      *slot = bucket;

      /* Increment the array's bucket counter. */
      ++(array->element_count);
      return;
    }
  if ((*slot)->index == bucket->index)
    {
      /* There's a bucket there, and it has the same index as `bucket'.
       * So we get rid of the old one, and put the new one in its
       * place. */
      _o_array_free_bucket (array, *slot);
      *slot = bucket;
      return;
    }
  else
    {
      /* Now we get to fiddle around with things to make the world a
       * better place... */

      size_t new_slot_count;
      o_array_slot_t *new_slots;	/* This guy holds the buckets while we
					 * muck about with them. */
      size_t d;			/* Just a counter */

      /* FIXME: I *really* wish I had a way of generating
       * statistically better initial values for this variable.  So
       * I'll run a few tests and see...  And is there a better
       * algorithm, e.g., a better collection of sizes in the sense
       * that the likelyhood of fitting everything in earlier is
       * high?  Well, enough mumbling. */
      /* At any rate, we're guaranteed to need at least this many. */
      new_slot_count = array->element_count + 1;

      do
	{
	  /* First we make a new pile of slots for the buckets. */
	  new_slots = _o_array_new_slots (array, new_slot_count);

	  if (new_slots == 0)
            /* FIXME: Make this a *little* more friendly. */
	    abort();

	  /* Then we put the new bucket in the pile. */
	  new_slots[_o_array_fold_index (bucket->index,
					       new_slot_count)] = bucket;

	  /* Now loop and try to place the others.  Upon collision
	   * with a previously inserted bucket, try again with more
	   * `new_slots'. */
	  for (d = 0; d < array->slot_count; ++d)
	    {
	      if (array->slots[d] != 0)
		{
		  size_t i;

		  i = _o_array_fold_index (array->slots[d]->index,
						 new_slot_count);

		  if (new_slots[i] == 0)
		    {
		      new_slots[i] = array->slots[d];
		    }
		  else
		    {
		      /* A collision.  Clean up and try again. */

		      /* Free the current set of new buckets. */
		      _o_array_free_slots (array, new_slots);

		      /* Bump up the number of new buckets. */
		      ++new_slot_count;

		      /* Break out of the `for' loop. */
		      break;
		    }
		}
	    }
	}
      while (d < array->slot_count);

      if (array->slots != 0)
	_o_array_free_slots (array, array->slots);

      array->slots = new_slots;
      array->slot_count = new_slot_count;
      ++(array->element_count);

      return;
    }
}

static inline int
_o_array_compare_slots (const o_array_slot_t *slot1,
			      const o_array_slot_t *slot2)
{
  if (slot1 == slot2)
    return 0;
  if (*slot1 == 0)
    return 1;
  if (*slot2 == 0)
    return -1;

  if ((*slot1)->index < (*slot2)->index)
    return -1;
  else if ((*slot1)->index > (*slot2)->index)
    return 1;
  else
    return 0;
}

typedef int (*qsort_compare_func_t) (const void *, const void *);

static inline void
_o_array_make_sorted_slots (o_array_t *array)
{
  o_array_slot_t *new_slots;

  /* If there're already some sorted slots, then they're valid, and
   * we're done. */
  if (array->sorted_slots != 0)
    return;

  /* Make some new slots. */
  new_slots = _o_array_new_slots (array, array->slot_count);

  /* Copy the pointers to buckets into the new slots. */
  memcpy (new_slots, array->slots, (array->slot_count
				    * sizeof (o_array_slot_t)));

  /* Sort the new slots. */
  qsort (new_slots, array->slot_count, sizeof (o_array_slot_t),
	 (qsort_compare_func_t) _o_array_compare_slots);

  /* Put the newly sorted slots in the `sorted_slots' element of the
   * array structure. */
  array->sorted_slots = new_slots;

  return;
}

static inline o_array_bucket_t *
_o_array_enumerator_next_bucket (o_array_enumerator_t *enumerator)
{
  if (enumerator->is_sorted)
    {
      if (enumerator->is_ascending)
	{
	  if (enumerator->array->sorted_slots == 0)
	    return 0;

	  if (enumerator->index < enumerator->array->element_count)
	    {
	      o_array_bucket_t *bucket;

	      bucket = enumerator->array->sorted_slots[enumerator->index];
	      ++(enumerator->index);
	      return bucket;
	    }
	  else
	    return 0;
	}
      else
	{
	  if (enumerator->array->sorted_slots == 0)
	    return 0;

	  if (enumerator->index > 0)
	    {
	      o_array_bucket_t *bucket;

	      --(enumerator->index);
	      bucket = enumerator->array->sorted_slots[enumerator->index];
	      return bucket;
	    }
	  else
	    return 0;
	}
    }
  else
    {
      o_array_bucket_t *bucket;

      if (enumerator->array->slots == 0)
	return 0;

      for (bucket = 0;
	   (enumerator->index < enumerator->array->slot_count
	    && bucket == 0);
	   ++(enumerator->index))
	{
	  bucket = enumerator->array->slots[enumerator->index];
	}

      return bucket;
    }
}

/** Statistics **/

size_t
o_array_count(o_array_t *array)
{
  return array->element_count;
}

size_t
o_array_capacity (o_array_t *array)
{
  return array->slot_count;
}

int
o_array_check(o_array_t *array)
{
  /* FIXME: Code this. */
  return 0;
}

int
o_array_is_empty(o_array_t *array)
{
  return o_array_count (array) != 0;
}

/** Emptying **/

void
o_array_empty(o_array_t *array)
{
  size_t c;

  /* Just empty each slot out, one by one. */
  for (c = 0; c < array->slot_count; ++c)
    _o_array_empty_slot (array, array->slots + c);

  return;
}

/** Creating **/

o_array_t *
o_array_alloc_with_zone(NSZone *zone)
{
  o_array_t *array;

  /* Get a new array. */
  array = _o_array_alloc_with_zone(zone);

  return array;
}

o_array_t *
o_array_alloc(void)
{
  return o_array_alloc_with_zone(NSDefaultMallocZone());
}

o_array_t *
o_array_with_zone(NSZone *zone)
{
  return o_array_init(o_array_alloc_with_zone(zone));
}

o_array_t *
o_array_with_zone_with_callbacks(NSZone *zone,
                                       o_callbacks_t callbacks)
{
  return o_array_init_with_callbacks(o_array_alloc_with_zone(zone),
					   callbacks);
}

o_array_t *
o_array_with_callbacks(o_callbacks_t callbacks)
{
  return o_array_init_with_callbacks(o_array_alloc(), callbacks);
}

o_array_t *
o_array_of_char_p(void)
{
  return o_array_with_callbacks(o_callbacks_for_char_p);
}

o_array_t *
o_array_of_non_owned_void_p(void)
{
  return o_array_with_callbacks(o_callbacks_for_non_owned_void_p);
}

o_array_t *
o_array_of_owned_void_p(void)
{
  return o_array_with_callbacks(o_callbacks_for_owned_void_p);
}

o_array_t *
o_array_of_int(void)
{
  return o_array_with_callbacks(o_callbacks_for_int);
}

o_array_t *
o_array_of_id(void)
{
  return o_array_with_callbacks(o_callbacks_for_id);
}

/** Initializing **/

o_array_t *
o_array_init_with_callbacks(o_array_t *array,
                                  o_callbacks_t callbacks)
{
  if (array != 0)
    {
      /* The default capacity is 15. */
      size_t capacity = 15;

      /* Record the element callbacks. */
      array->callbacks = o_callbacks_standardize(callbacks);

      /* Initialize ARRAY's information. */
      array->element_count = 0;
      array->slot_count = capacity + 1;

      /* Make some new slots. */
      array->slots = _o_array_new_slots(array, capacity + 1);

      /* Get the sorted slots ready for later use. */
      array->sorted_slots = 0;
    }

  return array;
}

o_array_t *
o_array_init (o_array_t *array)
{
  return o_array_init_with_callbacks (array,
					    o_callbacks_standard());
}

o_array_t *
o_array_init_from_array (o_array_t *array, o_array_t *old_array)
{
  o_array_enumerator_t enumerator;
  size_t index;
  const void *element;

  /* Initialize ARRAY in the usual way. */
  o_array_init_with_callbacks (array,
			       o_array_element_callbacks (old_array));

  /* Get an enumerator for OLD_ARRAY. */
  enumerator = o_array_enumerator (old_array);

  /* Step through OLD_ARRAY's elements, putting them at the proper
   * index in ARRAY. */
  while (o_array_enumerator_next_index_and_element (&enumerator,
							  &index, &element))
    {
      o_array_at_index_put_element (array, index, element);
    }

  return array;
}

/** Destroying **/

void
o_array_dealloc(o_array_t *array)
{
  if (array != 0)
    {
      /* Empty out ARRAY. */
      o_array_empty (array);

      /* Free up its slots. */
      _o_array_free_slots (array, array->slots);

      /* FIXME: What about ARRAY's sorted slots? */

      /* Free up ARRAY itself. */
      _o_array_dealloc (array);
    }

  return;
}

/** Searching **/

const void *
o_array_element_at_index (o_array_t *array, size_t index)
{
  o_array_bucket_t *bucket = _o_array_bucket_for_index (array, index);

  if (bucket != 0)
    return bucket->element;
  else
    /* If `bucket' is 0, then the requested index is unused. */
    /* There's no bucket, so... */
    return o_array_not_an_element_marker (array);
}

size_t
o_array_index_of_element (o_array_t *array, const void *element)
{
  size_t i;

  for (i = 0; i < array->slot_count; ++i)
    {
      o_array_bucket_t *bucket = array->slots[i];

      if (bucket != 0)
	if (o_is_equal (o_array_element_callbacks (array),
			      bucket->element,
			      element,
			      array))
	  return bucket->index;
    }

  return i;
}

int
o_array_contains_element (o_array_t *array, const void *element)
{
  /* Note that this search is quite inefficient. */
  return o_array_index_of_element (array, element) < (array->slot_count);
}

const void **
o_array_all_elements (o_array_t *array)
{
  o_array_enumerator_t enumerator;
  const void **elements;
  size_t count, i;

  count = o_array_count (array);

  /* Set aside space to hold the elements. */
  elements = (const void **)NSZoneCalloc(o_array_zone(array),
				         count + 1,
				         sizeof(const void *));

  enumerator = o_array_enumerator(array);

  for (i = 0; i < count; ++i)
    o_array_enumerator_next_element (&enumerator, elements + i);

  elements[i] = o_array_not_an_element_marker(array);

  /* We're done, so heave it back. */
  return elements;
}

const void **
o_array_all_elements_ascending (o_array_t *array)
{
  o_array_enumerator_t enumerator;
  const void **elements;
  size_t count, i;

  count = o_array_count (array);

  /* Set aside space to hold the elements. */
  elements = (const void **)NSZoneCalloc(o_array_zone(array),
				         count + 1,
				         sizeof(const void *));

  enumerator = o_array_ascending_enumerator (array);

  for (i = 0; i < count; ++i)
    o_array_enumerator_next_element (&enumerator, elements + i);

  elements[i] = o_array_not_an_element_marker (array);

  /* We're done, so heave it back. */
  return elements;
}

const void **
o_array_all_elements_descending (o_array_t *array)
{
  o_array_enumerator_t enumerator;
  const void **elements;
  size_t count, i;

  count = o_array_count (array);

  /* Set aside space to hold the elements. */
  elements = (const void **)NSZoneCalloc(o_array_zone(array),
				         count + 1,
				         sizeof(const void *));

  enumerator = o_array_descending_enumerator (array);

  for (i = 0; i < count; ++i)
    o_array_enumerator_next_element (&enumerator, elements + i);

  elements[i] = o_array_not_an_element_marker (array);

  /* We're done, so heave it back. */
  return elements;
}

/** Removing **/

void
o_array_remove_element_at_index (o_array_t *array, size_t index)
{
  o_array_bucket_t *bucket;

  /* Get the bucket that might be there. */
  bucket = _o_array_bucket_for_index (array, index);

  /* If there's a bucket at the index, then we empty its slot out. */
  if (bucket != 0)
    _o_array_empty_slot (array, _o_array_slot_for_index (array, index));

  /* Finally, we return. */
  return;
}

void
o_array_remove_element_known_present (o_array_t *array,
					    const void *element)
{
  o_array_remove_element_at_index (array,
				      o_array_index_of_element (array,
								  element));
  return;
}

void
o_array_remove_element (o_array_t *array, const void *element)
{
  if (o_array_contains_element (array, element))
    o_array_remove_element_known_present (array, element);

  return;
}

/** Adding **/

const void *
o_array_at_index_put_element (o_array_t *array,
				    size_t index,
				    const void *element)
{
  o_array_bucket_t *bucket;

  /* Clean out anything that's already there. */
  o_array_remove_element_at_index (array, index);

  /* Make a bucket for our information. */
  bucket = _o_array_new_bucket (array, index, element);

  /* Put our bucket in the array. */
  _o_array_insert_bucket (array, bucket);

  return element;
}

/** Enumerating **/

o_array_enumerator_t
o_array_ascending_enumerator (o_array_t *array)
{
  o_array_enumerator_t enumerator;

  enumerator.array = array;
  enumerator.is_sorted = 1;
  enumerator.is_ascending = 1;
  enumerator.index = 0;

  _o_array_make_sorted_slots (array);

  return enumerator;
}

o_array_enumerator_t
o_array_descending_enumerator (o_array_t *array)
{
  o_array_enumerator_t enumerator;

  enumerator.array = array;
  enumerator.is_sorted = 1;
  enumerator.is_ascending = 0;
  /* The `+ 1' is so that we have `0' as a known ending condition.
   * See `_o_array_enumerator_next_bucket()'. */
  enumerator.index = array->element_count + 1;

  _o_array_make_sorted_slots (array);

  return enumerator;
}

o_array_enumerator_t
o_array_enumerator (o_array_t *array)
{
  o_array_enumerator_t enumerator;

  enumerator.array = array;
  enumerator.is_sorted = 0;
  enumerator.is_ascending = 0;
  enumerator.index = 0;

  return enumerator;
}

int
o_array_enumerator_next_index_and_element (o_array_enumerator_t * enumerator,
						 size_t * index,
						 const void **element)
{
  o_array_bucket_t *bucket;

  bucket = _o_array_enumerator_next_bucket (enumerator);

  if (bucket != 0)
    {
      if (element != 0)
	*element = bucket->element;
      if (index != 0)
	*index = bucket->index;
      return 1;
    }
  else
    {
      if (element != 0)
	*element = o_array_not_an_element_marker (enumerator->array);
      if (index != 0)
	*index = 0;
      return 0;
    }
}

int
o_array_enumerator_next_element (o_array_enumerator_t * enumerator,
				       const void **element)
{
  return o_array_enumerator_next_index_and_element (enumerator,
							  0,
							  element);
}

int
o_array_enumerator_next_index (o_array_enumerator_t * enumerator,
				     size_t * index)
{
  return o_array_enumerator_next_index_and_element (enumerator,
							  index,
							  0);
}

/** Comparing **/

int
o_array_is_equal_to_array (o_array_t *array1, o_array_t *array2)
{
  size_t a, b;
  const void *m, *n;
  o_array_enumerator_t e, f;

  a = o_array_count (array1);
  b = o_array_count (array2);

  if (a < b)
    return (b - a);
  if (a > b)
    return (a - b);

  /* Get ascending enumerators for each of the two arrays. */
  e = o_array_ascending_enumerator (array1);
  e = o_array_ascending_enumerator (array1);

  while (o_array_enumerator_next_index_and_element (&e, &a, &m)
	 && o_array_enumerator_next_index_and_element (&f, &b, &n))
    {
      int c, d;

      if (a < b)
	return (b - a);
      if (a > b)
	return (a - b);

      c = o_compare (o_array_element_callbacks (array1), m, n, array1);
      if (c != 0)
	return c;

      d = o_compare (o_array_element_callbacks (array2), n, m, array2);
      if (d != 0)
	return d;
    }

  return 0;
}

/** Mapping **/

o_array_t *
o_array_map_elements(o_array_t *array,
			   const void *(*fcn) (const void *, const void *),
			   const void *user_data)
{
  /* FIXME: Code this. */
  return array;
}

/** Miscellaneous **/

o_hash_t *
o_hash_init_from_array (o_hash_t * hash, o_array_t *array)
{
  o_array_enumerator_t enumerator;
  const void *element;

  /* NOTE: If ARRAY contains multiple elements of the same equivalence
   * class, it is indeterminate which will end up in HASH.  This
   * shouldn't matter, though. */
  enumerator = o_array_enumerator (array);

  /* Just walk through ARRAY's elements and add them to HASH. */
  while (o_array_enumerator_next_element (&enumerator, &element))
    o_hash_add_element (hash, element);

  return hash;
}

// o_chash_t *
// o_chash_init_from_array (o_chash_t * chash, o_array_t *array)
// {
//   o_array_enumerator_t enumerator;
//   const void *element;
// 
//   /* NOTE: If ARRAY contains multiple elements of the same equivalence
//    * class, it is indeterminate which will end up in CHASH.  This
//    * shouldn't matter, though. */
//   enumerator = o_array_enumerator (array);
// 
//   /* Just walk through ARRAY's elements and add them to CHASH. */
//   while (o_array_enumerator_next_element (&enumerator, &element))
//     o_chash_add_element (chash, element);
// 
//   return chash;
// }

