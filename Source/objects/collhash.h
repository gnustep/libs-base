/* Hash tables for Objective C method dispatch, modified for libcoll.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

This file is part of GNU CC.

GNU CC is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU CC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU CC; see the file COPYING.  If not, write to
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */

/* As a special exception, if you link this library with files
   compiled with GCC to produce an executable, this does not cause
   the resulting executable to be covered by the GNU General Public License.
   This exception does not however invalidate any other reasons why
   the executable file might be covered by the GNU General Public License.  */


#ifndef __collhash_INCLUDE_GNU
#define __collhash_INCLUDE_GNU

#ifdef IN_GCC
#include "gstddef.h"
#else
#include "stddef.h"
#endif

#include <objects/elt.h>

/* This returns an unsigned int that is the closest power of two greater 
   than the argument. */
/* If we can rely on having ffs() we could do this better */
#define POWER_OF_TWO(n) \
({ \
  unsigned _MASK = 1; \
  while (n > _MASK) \
    _MASK <<= 1; \
  _MASK; \
})


/*
 * This data structure is used to hold items
 *  stored in a hash table.  Each node holds 
 *  a key/value pair.
 *
 * Items in the cache are really of type void *.
 */
typedef struct coll_cache_node
{
  struct coll_cache_node *next;	/* Pointer to next entry on the list.
				   NULL indicates end of list. */
  elt key;			/* Key used to locate the value.  Used
				   to locate value when more than one
				   key computes the same hash
				   value. */
  elt value;			/* Value stored for the key. */
} *coll_node_ptr;


/*
 * This data type is the function that computes a hash code given a key.
 * Therefore, the key can be a pointer to anything and the function specific
 * to the key type. 
 *
 * Unfortunately there is a mutual data structure reference problem with this
 * typedef.  Therefore, to remove compiler warnings the functions passed to
 * hash_new will have to be casted to this type. 
 */
typedef unsigned int (*coll_hash_func_type)(elt);

/*
 * This data type is the function that compares two hash keys and returns an
 * integer greater than, equal to, or less than 0, according as the first
 * parameter is lexico-graphically greater than, equal to, or less than the
 * second. 
 */

typedef int (*coll_compare_func_type)(elt, elt);


/*
 * This data structure is the cache.
 *
 * It must be passed to all of the hashing routines
 *   (except for new).
 */
typedef struct coll_cache
{
  /* Variables used to implement the hash itself.  */
  coll_node_ptr *node_table; /* Pointer to an array of hash nodes.  */
  /* Variables used to track the size of the hash table so to determine
    when to resize it.  */
  unsigned int size; /* Number of buckets allocated for the hash table
			(number of array entries allocated for
			"node_table").  Must be a power of two.  */
  unsigned int used; /* Current number of entries in the hash table.  */
  unsigned int mask; /* Precomputed mask.  */

  /* Variables used to implement indexing through the hash table.  */

  /* commented out by mccallum */
  /* unsigned int last_bucket; Tracks which entry in the array where
			       the last value was returned.  */
  /* Function used to compute a hash code given a key. 
     This function is specified when the hash table is created.  */
  coll_hash_func_type    hash_func;
  /* Function used to compare two hash keys to see if they are equal.  */
  coll_compare_func_type compare_func;
} *coll_cache_ptr;


/* Two important hash tables.  */
/* This should be removed
extern coll_cache_ptr module_hash_table, class_hash_table;
*/

/* Allocate and initialize a hash table.  */ 

coll_cache_ptr coll_hash_new (unsigned int size,
		    coll_hash_func_type hash_func,
		    coll_compare_func_type compare_func);
                       
/* Deallocate all of the hash nodes and the cache itself.  */

void coll_hash_delete (coll_cache_ptr cache);

/* Deallocate all of the hash nodes.  */

void coll_hash_empty (coll_cache_ptr cache);

/* Add the key/value pair to the hash table.  If the
   hash table reaches a level of fullnes then it will be resized. 
                                                   
   assert if the key is already in the hash.  */

void coll_hash_add (coll_cache_ptr *cachep, elt key, elt value);
     
/* Remove the key/value pair from the hash table.  
   assert if the key isn't in the table.  */

void coll_hash_remove (coll_cache_ptr cache, elt key);

/* Used to index through the hash table.  Start with NULL
   to get the first entry.
                                                  
   Successive calls pass the value returned previously.
   ** Don't modify the hash during this operation *** 
                                                  
   Cache nodes are returned such that key or value can
   be extracted.  */

coll_node_ptr coll_hash_next (coll_cache_ptr cache, void** state);

/* Used to return a value from a hash table using a given key.  */

elt coll_hash_value_for_key (coll_cache_ptr cache, elt key);


extern coll_node_ptr coll_hash_node_for_key (coll_cache_ptr cache, elt key);

#endif /* not __hash_INCLUDE_GNU */
