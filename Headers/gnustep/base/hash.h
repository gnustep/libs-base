/* A hash table.
 * Copyright (C) 1993, 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: ??? ??? ?? ??:??:?? ??? 1993
 * Updated: Tue Mar 19 00:25:34 EST 1996
 * Serial: 96.03.19.05
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

#ifndef __hash_h_GNUSTEP_BASE_INCLUDE
#define __hash_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <Foundation/NSZone.h>
#include <Foundation/NSString.h>
#include <gnustep/base/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

/* Need these up here because of their interdependence. */
typedef struct _o_hash o_hash_t;
typedef struct _o_hash_enumerator o_hash_enumerator_t;
typedef struct _o_hash_node o_hash_node_t;
typedef struct _o_hash_bucket o_hash_bucket_t;

/* Private type for elemental holding. */
struct _o_hash_node
{
  /* The hash table with which the node is associated. */
  o_hash_t *hash;

  /* The bucket in HASH in which the node sits. */
  o_hash_bucket_t *bucket;

  /* These hold the BUCKET linked list together. */
  o_hash_node_t *next_in_bucket;
  o_hash_node_t *prev_in_bucket;

  /* For enumerating over the whole hash table.  These make
   * enumerating much quicker.  They also make it safer. */
  o_hash_node_t *next_in_hash;
  o_hash_node_t *prev_in_hash;

  /* What the node is holding for us.  Its raison d'etre. */
  const void *element;
};

/* Private type for holding chains of nodes. */
struct _o_hash_bucket
{
  /* The number of nodes in this bucket.  For internal consistency checks. */
  size_t node_count;

  /* The number of elements in this bucket.  (This had *better* be
   * the same as NODE_COUNT, or something's wrong.) */
  size_t element_count;

  /* The head of this bucket's linked list of nodes. */
  o_hash_node_t *first_node;
};

/* The hash table type. */
struct _o_hash
{
  /* All structures have these... 
   * And all structures have them in the same order. */
  int magic_number;
  size_t serial_number;
  NSZone *zone;
  NSString *name;
  const void *extra;
  o_callbacks_t extra_callbacks;

  /* Callbacks for the elements of the hash. */
  o_callbacks_t callbacks;

  /* Internal counters.  Mainly for consistency's sake. */
  size_t bucket_count;   /* How many types of items? */
  size_t node_count;     /* How many items? */
  size_t element_count;  /* How many elements? */

  /* Places to start looking for elements. */
  o_hash_bucket_t *buckets;   /* Organized as a hash. */
  o_hash_node_t *first_node;  /* Organized as a linked list.
                                     * (For enumerating...) */
};

/* Type for enumerating the elements of a hash table. */
struct _o_hash_enumerator
{
  o_hash_t *hash;       /* To which hash do I belong? */
  o_hash_node_t *node;  /* Which node is next? */
};

/**** Function Prototypes ****************************************************/

/** Basics... **/

/* All the structures (hashes, maps, lists, and arrays) have
 * the same basic ideas behind them. */

#include <gnustep/base/hash-bas.h>
#include <gnustep/base/hash-cbs.h>

/** Callbacks... **/

/* Returns a collection of callbacks for use with hash tables. */
o_callbacks_t
o_callbacks_for_hash(void);

/** Creating... **/

/* Allocate a hash table in the default zone. */
o_hash_t *
o_hash_alloc(void);

/* Allocate a hash table in the memory block ZONE. */
o_hash_t *
o_hash_alloc_with_zone(NSZone *zone);

/* Create an empty hash table in the memory block ZONE.  The returned
 * hash table has a "reasonable" default capacity, but will need to
 * be resized to suit your specific needs if more than a couple of
 * dozen elements will be placed within it. */
o_hash_t *
o_hash_with_zone_with_callbacks(NSZone *zone,
                                      o_callbacks_t callbacks);

/* Like calling 'o_hash_with_zone_with_callbacks(zone,
 * o_callbacks_standard())'. */
o_hash_t *
o_hash_with_zone(NSZone *zone);

/* Like calling 'o_hash_with_zone_with_callbacks(0, callbacks)'. */
o_hash_t *
o_hash_with_callbacks(o_callbacks_t callbacks);

/* These are just shortcuts for ease of use. */
o_hash_t *o_hash_of_char_p(void);
o_hash_t *o_hash_of_non_owned_void_p(void);
o_hash_t *o_hash_of_owned_void_p(void);
o_hash_t *o_hash_of_int(void);
o_hash_t *o_hash_of_int_p(void);
o_hash_t *o_hash_of_id(void);

/** Initializing... **/

/* Initializes HASH with a "reasonable" capacity, with the
 * callbacks obtained from 'o_callbacks_standard()'. */
o_hash_t *
o_hash_init(o_hash_t *hash);

/* Initializes HASH with a "reasonable" capacity and
 * with element callbacks CALLBACKS. */
o_hash_t *
o_hash_init_with_callbacks(o_hash_t *hash,
                                 o_callbacks_t callbacks);

/* Initializes HASH with the capacity, callbacks, and contents
 * of OTHER_HASH.  NOTE: This is (as it must be) a "shallow" copying.
 * See 'o_hash_copy_with_zone()', below. */
o_hash_t *
o_hash_init_with_hash(o_hash_t *hash,
                            o_hash_t *other_hash);

/** Copying... **/

/* Creates a (shallow) copy of HASH in the memory block ZONE.  WARNING:
 * If the elements of HASH are pointers to mutable items, it is the
 * programmer's responsibility to deepen the copy returned by this
 * function call (using, for example, `o_hash_map_elements()'). */
o_hash_t *
o_hash_copy_with_zone(o_hash_t *hash, NSZone *zone);

/* Create a (shallow) copy of HASH in the default zone.  WARNING: See the 
 * above function for an important caveat about copying. */ 
o_hash_t *
o_hash_copy(o_hash_t *old_hash);

/** Mapping... **/

/* WARNING: The mapping function FCN must be one-to-one on elements of
 * HASH.  I.e., for reasons of efficiency, `o_hash_map_elements()'
 * makes no provision for the possibility that FCN maps two unequal
 * elements of HASH to the same (or "equal") elements.  The better way
 * to handle functions that aren't one-to-one is to create a new hash
 * and transform the elements of the first to create the elements of
 * the second (by manual enumeration). */
o_hash_t *
o_hash_map_elements(o_hash_t *hash, 
			  const void *(*fcn)(const void *, const void *), 
			  const void *user_data);

/** Destroying... **/

/* Releases all the elements of HASH, and then frees up the space
 * HASH used.  HASH is no longer a (pointer to a) valid hash
 * table structure after this call. */
void
o_hash_dealloc(o_hash_t *hash);

/** Comparing... **/

/* Returns 'true' if every element of OTHER_HASH is also
 * a member of HASH.  Otherwise, returns 'false'. */
int
o_hash_contains_hash(o_hash_t *hash,
                           o_hash_t *other_hash);

/* Returns 'true' if some element of HASH is also
 * a member of OTHER_HASH.  Otherwise, returns 'false'. */
int
o_hash_intersects_hash(o_hash_t *hash,
                             o_hash_t *other_hash);

/* Returns 'true' if HASH and OTHER_HASH have the same number of elements,
 * HASH contains OTHER_HASH, and OTHER_HASH contains HASH.  Otheraise, returns 'false'. */
int
o_hash_is_equal_to_hash(o_hash_t *hash,
                              o_hash_t *other_hash);

/** Adding... **/

/* Adds ELEMENT to HASH.  If ELEMENT is "equal" to an item already in HASH,
 * then we abort.  If ELEMENT is the "not an element marker" for HASH,
 * then we abort.  [NOTE: This abortive behaviour will be changed in a
 * future revision.] */
const void *
o_hash_add_element_known_absent(o_hash_t *hash,
                                      const void *element);

/* Adds ELEMENT to HASH.  If ELEMENT is "equal" to an item already in HASH,
 * then that older item is released using the 'release()' callback function
 * that was specified when HASH was created.  (If ELEMENT is the "not an
 * element marker" for HASH, then all bets are off, and we abort.
 * [NOTE: This abortive behaviour will be changed in a future revision.]) */
const void *
o_hash_add_element(o_hash_t *hash, const void *element);

/* If (any item "equal" to) ELEMENT is in HASH, then that member of HASH is
 * returned.  Otherwise, the "not an element marker" for HASH is returned
 * and ELEMENT is added to HASH.  If ELEMENT is the "not an element marker"
 * for HASH, then we abort.  [NOTE: This abortive behaviour will be changed
 * in a future revision.] */
const void *
o_hash_add_element_if_absent(o_hash_t *hash, const void *element);

/** Replacing... **/

/* If (some item "equal" to) ELEMENT is an element of HASH, then ELEMENT is
 * substituted for it.  The old element is released.  (This is rather
 * like the non-existant but perfectly reasonable function
 * 'o_hash_add_element_if_present()'.) */
void
o_hash_replace_element(o_hash_t *hash,
                             const void *element);

/** Removing... **/

/* Removes the element (if any) of HASH which is "equal" to ELEMENT,
 * according to HASH's element callbacks.  It is not an error to
 * remove ELEMENT from HASH, if no element of HASH is "equal" to ELEMENT. */
void
o_hash_remove_element(o_hash_t *hash, const void *element);

/** Emptying... **/

/* Empties HASH, releasing all of its elements while retaining
 * its current "capacity". */
void
o_hash_empty(o_hash_t *hash);

/** Searching... **/

/* Returns a "random" element of HASH, for your viewing enjoyment. */
void *
o_hash_any_element(o_hash_t *hash);

/* Returns `true' if some element of HASH is "equal" to ELEMENT,
 * according to HASH's element callbacks. */
int
o_hash_contains_element(o_hash_t *hash, const void *element);

/* Returns the element of HASH (or the appropriate `not an element
 * marker' if there is none) which is "equal" to ELEMENT. */
const void *
o_hash_element(o_hash_t *hash, const void *element);

/* Returns an array with all the elements of HASH, terminated
 * by HASH's "not an element marker".  It is your responsibility
 * to free the returned array.  [NOTE: this responsibility may
 * shift from your shoulders in a later revision.] */
const void **
o_hash_all_elements(o_hash_t *hash);

/** Enumerating... **/

/* Returns an enumerator for HASH's elements.  WARNING: DO NOT ALTER
 * A HASH DURING AN ENUMERATION.  DOING SO WILL PROBABLY LEAVE YOUR ENUMERATION
 * IN AN INDETERMINATE STATE.  If you are hell-bent on ignoring the above
 * warning, please check out the source code for some more specific
 * information about when and how one can get away with it. */
o_hash_enumerator_t
o_hash_enumerator_for_hash(o_hash_t *hash);

/* Returns `false' if the enumeration is complete, `true' otherwise.
 * If ELEMENT is non-zero, the next element of ENUMERATOR's hash table
 * is returned by reference. */
int
o_hash_enumerator_next_element(o_hash_enumerator_t *enumerator,
                                     const void **element);

/** Statistics... **/

/* Returns `true' if HASH contains no elements. */
int
o_hash_is_empty(o_hash_t *hash);

/* Returns the number of elements HASH is currently holding.  So long as no
 * additions or removals occur, you may take this number to be accurate. */
size_t
o_hash_count(o_hash_t *hash);

/* Returns a number which represents (to some degree) HASH's current ability
 * to hold stuff.  Do not, however, rely on this for precision.  Treat as
 * a (reasonable) estimate. */
size_t
o_hash_capacity(o_hash_t *hash);

/* Performs an internal consistency check on HASH.  Useful only
 * for debugging. */
int
o_hash_check(o_hash_t *hash);

/** Resizing... **/

/* Resizes HASH to be ready to contain (at least) NEW_CAPACITY many elements.
 * However, as far as you are concerned, it is indeterminate what exactly
 * this means.  After receiving and successfully processing this call,
 * you are *not* guaranteed that HASH has actually set aside space for
 * NEW_CAPACITY elements, for example.  All that you are guaranteed is that,
 * to the best of its ability, HASH will incur no loss in efficiency so long
 * as it contains no more than NEW_CAPACITY elements. */
size_t
o_hash_resize(o_hash_t *hash, size_t new_capacity);

/* Shrinks (or grows) HASH to be comfortable with the number of elements
 * it contains.  In all likelyhood, after this call, HASH is more efficient
 * in terms of its speed of search vs. use of space balance. */
size_t
o_hash_rightsize(o_hash_t *hash);

/** Describing... **/

/* Returns a string describing (the contents of) HASH. */
NSString *
o_hash_description(o_hash_t *hash);

/** Set theoretic operations... **/

/* Removes from HASH all of its elements which are not also
 * elements of OTHER_HASH.  Returns HASH as a courtesy. */
o_hash_t *
o_hash_intersect_hash(o_hash_t *hash, o_hash_t *other_hash);

/* Removes from HASH all of its elements which are also
 * elements of OTHER_HASH.  Returns HASH as a courtesy. */
o_hash_t *
o_hash_minus_hash(o_hash_t *hash, o_hash_t *other_hash);

/* Adds to HASH all elements of OTHER_HASH which are not
 * already members of HASH.  Returns HASH as a courtesy. */
o_hash_t *
o_hash_union_hash(o_hash_t *hash, o_hash_t *other_hash);

#endif /* __hash_h_GNUSTEP_BASE_INCLUDE */

