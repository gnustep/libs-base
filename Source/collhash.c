/* Hash tables for Objective C internal structures
   Copyright (C) 1993, 1995 Free Software Foundation, Inc.

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

#include <stdio.h>
#include <assert.h>

#include <objects/collhash.h>
#include <objects/objc-malloc.h>
#include <objc/objc.h>

/* These two macros determine when a hash table is full and
   by how much it should be expanded respectively.

   These equations are percentages.  */
#define FULLNESS(cache) \
   ((((cache)->size * 75) / 100) <= (cache)->used)
#define EXPANSION(cache) \
  ((cache)->size * 2)

coll_cache_ptr
coll_hash_new (unsigned int size, 
	       coll_hash_func_type hash_func,
	       coll_compare_func_type compare_func)
{
  coll_cache_ptr cache;

  /* Pass me a value greater than 0 and a power of 2.  */
  assert (size);
  assert (!(size & (size - 1)));

  /* Allocate the cache structure.  calloc insures
     its initialization for default values.  */
  cache = (coll_cache_ptr)(*objc_calloc)(1, sizeof (struct coll_cache));
  assert (cache);

  /* Allocate the array of buckets for the cache.
     calloc initializes all of the pointers to NULL.  */
  cache->node_table
    = (coll_node_ptr *)(*objc_calloc)(size, sizeof (coll_node_ptr));
  assert (cache->node_table);

  cache->size  = size;

  /* This should work for all processor architectures? */
  cache->mask = (size - 1);
	
  /* Store the hashing function so that codes can be computed.  */
  cache->hash_func = hash_func;

  /* Store the function that compares hash keys to
     determine if they are equal.  */
  cache->compare_func = compare_func;

  return cache;
}


void
coll_hash_delete (coll_cache_ptr cache)
{
  /*
  coll_node_ptr node;
  void *state = 0;
  */

  /* Purge all key/value pairs from the table.  */
  /* was:
  while ((node = coll_hash_next (cache, &state)))
    coll_hash_remove (cache, node->key);
    */
  coll_hash_empty(cache);

  /* Release the array of nodes and the cache itself.  */
  (*objc_free) (cache->node_table);
  (*objc_free) (cache);
}

void
coll_hash_empty(coll_cache_ptr cache)
{
  coll_node_ptr node, nextnode;
  int i;

  for (i = 0; i < cache->size; i++)
    {
      node = cache->node_table[i];
      while (node)
	{
	  nextnode = node->next;
	  (*objc_free)(node);
	  node = nextnode;
	}
      cache->node_table[i] = 0;
    }
  cache->used = 0;
}

void
coll_hash_add (coll_cache_ptr *cachep, elt key, elt value)
{
  size_t indx = ((*(*cachep)->hash_func)(key)) & (*cachep)->mask;
  coll_node_ptr node = 
    (coll_node_ptr)(*objc_calloc)(1, sizeof (struct coll_cache_node));


  assert (node);

  /* Initialize the new node.  */
  node->key    = key;
  node->value  = value;
  node->next  = (*cachep)->node_table[indx];

  /* Debugging.
     Check the list for another key.  */
#if DEBUG
  { coll_node_ptr node1 = (*cachep)->node_table[indx];

    while (node1) {

      assert (node1->key != key);
      node1 = node1->next;
    }
  }
#endif

  /* Install the node as the first element on the list.  */
  (*cachep)->node_table[indx] = node;

  /* Bump the number of entries in the cache.  */
  ++(*cachep)->used;

  /* Check the hash table's fullness.   We're going
     to expand if it is above the fullness level.  */
  if (FULLNESS (*cachep)) {

    /* The hash table has reached its fullness level.  Time to
       expand it.

       I'm using a slow method here but is built on other
       primitive functions thereby increasing its
       correctness.  */
    void *state = 0;
    coll_node_ptr node1;
    coll_cache_ptr new = coll_hash_new (EXPANSION (*cachep),
			      (*cachep)->hash_func,
			      (*cachep)->compare_func);

/*
    DEBUG_PRINTF ("Expanding cache %#x from %d to %d\n",
		  *cachep, (*cachep)->size, new->size);
*/

    /* Copy the nodes from the first hash table to the new one.  */
    while ((node1 = coll_hash_next (*cachep, &state)))
      coll_hash_add (&new, node1->key, node1->value);

    /* Trash the old cache.  */
    coll_hash_delete (*cachep);

    /* Return a pointer to the new hash table.  */
    *cachep = new;
  }
}


void
coll_hash_remove (coll_cache_ptr cache, elt key)
{
  size_t indx = ((*(cache->hash_func))(key)) & cache->mask;
  coll_node_ptr node = cache->node_table[indx];


  /* We assume there is an entry in the table.  Error if it is not.  */
  assert (node);

  /* Special case.  First element is the key/value pair to be removed.  */
  if (!((*cache->compare_func)(node->key, key))) 
    {
      cache->node_table[indx] = node->next;
      (*objc_free) (node);
    } 
  else 
    {
      
      /* Otherwise, find the hash entry.  */
      coll_node_ptr prev = node;
      BOOL removed = NO;
      
      do 
	{
	  
	  if (!((*cache->compare_func)(node->key, key)) )
	    {
	      prev->next = node->next, removed = YES;
	      (*objc_free) (node);
	    }
	  else
	    prev = node, node = node->next;
	} 
      while (!removed && node);
      assert (removed);
    }

  /* Decrement the number of entries in the hash table.  */
  --cache->used;
}

struct coll_hash_state
{
  coll_node_ptr node;
  unsigned int last_bucket;
};

/* Or should I just pass in a coll_hash_state struct? 
   It would be a bit less flexible.  Less amenable to changes
   in structure later... */

/* This scheme is just ASKING for memory leaks.  Programmers could easily 
   start an enumeration and then stop before the enumeration is done.  
   This will leave (struct coll_hash_state) unfree'd! 
   */

coll_node_ptr
coll_hash_next (coll_cache_ptr cache, void** state)
{
#define HS ((struct coll_hash_state *)*state)

  /* If the scan is being started, then reset */
  if (!(*state))
    {
      *state = (void*)(*objc_malloc)(sizeof(struct coll_hash_state));
      HS->node = 0;
      HS->last_bucket = 0;
    }

  /* If there is a node visited last then check for another
     entry in the same bucket;  Otherwise step to the next bucket.  */
  if (HS->node) {
    if (HS->node->next)
      {
	/* There is a node which follows the last node
	   returned.  Step to that node and retun it.  */
	HS->node = HS->node->next;
	return HS->node;
      }
    else
      (HS->last_bucket)++;
  }

  /* If the list isn't exhausted then search the buckets for
     other nodes.  */
  if (HS->last_bucket < cache->size) {
    /*  Scan the remainder of the buckets looking for an entry
	at the head of the list.  Return the first item found.  */
    while (HS->last_bucket < cache->size)
      if (cache->node_table[HS->last_bucket])
	{
	  HS->node = cache->node_table[HS->last_bucket];
	  return cache->node_table[HS->last_bucket];
	}
      else
        (HS->last_bucket)++;

    /* No further nodes were found in the hash table.  */
    (*objc_free)(*state);
    *state = (void*)0;
    return 0;
  } else
    {
      (*objc_free)(*state);
      *state = (void*)0;
      return 0;
    }
}


/* Given KEY, return corresponding value for it in CACHE.
   Return NULL if the KEY is not recorded.  */

elt
coll_hash_value_for_key (coll_cache_ptr cache, elt key)
{
  coll_node_ptr node = cache->node_table[((*cache->hash_func)(key)) & cache->mask];
  elt retval;

  retval = 0;
  if (node)
    do {
      if (!((*cache->compare_func)(node->key, key)))
        retval = node->value;
      else
        node = node->next;
    } while ((retval.void_ptr_u == 0) && node);

  return retval;
}

/* Something like this would be useful in hash.c, I think. */

coll_node_ptr 
coll_hash_node_for_key (coll_cache_ptr cache, elt key)
{
  coll_node_ptr node = 
    cache->node_table[((*cache->hash_func)(key)) & cache->mask];

  if (node)
    do {
      if (!((*cache->compare_func)(node->key, key)))
	return node;
      else
        node = node->next;
    } while (node);

  return 0;
}
