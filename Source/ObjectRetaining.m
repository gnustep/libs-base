/* Implementation of retaining/releasing for object disposal and ref counting
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <objects/ObjectRetaining.h>
#include <objects/collhash.h>
#include <objects/eltfuncs.h>
#include <objects/objc-malloc.h>
#include <limits.h>

/* Doesn't handle multi-threaded stuff.
   Doesn't handle exceptions. */

/* We should add this to the runtime:
   We should use cache_ptr's instead, (adding the necessary code)
   Put the stuff from initialize into a runtime init function. 
   This class should be made more efficient, especially:
     [[Autorelease alloc] init]
     [current_pool addObject:o] (REALLOC-case)
   */

/* The initial size of the released_objects array */
#define DEFAULT_SIZE 64

/* The hashtable of retain counts on objects */
static coll_cache_ptr retain_counts = NULL;

/* Array of objects to be released later */
static unsigned released_capacity = 0;
static unsigned released_index = 0;
static id *released_objects = NULL;
static void **released_stack_pointers = NULL;

static int
init_object_retaining_if_necessary()
{
  static init_done = 0;

  /* Initialize if we haven't done it yet */
  if (!init_done)
    {
      init_done = 1;
      
      released_capacity = DEFAULT_SIZE;
      OBJC_MALLOC(released_objects, id, released_capacity);
      OBJC_MALLOC(released_stack_pointers, void*, released_capacity);
      
      retain_counts = coll_hash_new(64,
				    (coll_hash_func_type)
				    elt_hash_void_ptr,
				    (coll_compare_func_type)
				    elt_compare_void_ptrs);
    }
  return 1;
}

static int object_retaining_initialized = init_object_retaining_if_necessary();

void
objc_retain_object (id anObj)
{
  coll_node_ptr n;

  init_object_retaining_if_necessary();
  n = coll_hash_node_for_key(retain_counts, anObj);
  if (n)
    (n->value.unsigned_int_u)++;
  else
    coll_hash_add(&retain_counts, anObj, (unsigned)1);
}

void
objc_release_object (id anObj)
{
  coll_node_ptr n;

  init_object_retaining_if_necessary();
  n = coll_hash_node_for_key(retain_counts, anObj);
  if (n)
    {
      (n->value.unsigned_int_u)--;
      if (n->value.unsigned_int_u)
	return;
      coll_hash_remove(retain_counts, anObj);
    }
  [anObj dealloc];
}

/* Careful, this doesn't include autoreleases */
unsigned
objc_retain_count (id anObj)
{
  coll_node_ptr n;

  init_object_retaining_if_necessary();
  n = coll_hash_node_for_key(retain_counts, anObj);
  if (n)
    return n->value.unsigned_int_u;
  else
    return 0;
}

static void*
get_stack()
{
  int i;
  return &i;
}

static inline void
grow_released_arrays()
{
  if (index == released_capacity)
    {
      released_capacity *= 2;
      OBJC_REALLOC(released_objects, id, released_capacity);
      OBJC_REALLOC(released_stack_pointers, void*, released_capacity);
    }
}

void
objc_release_stack_objects_to_frame_address(void *frame_address)
{
  /* xxx This assumes stack grows up */
  while ((released_frame_pointers[released_index] 
	  > frame_address))
	 && released_index)
    {
      [released_objects[released_index] release];
      released_index--;
    }
}

void
objc_release_stack_objects_this_frame()
{
  objc_release_stack_objects_to_frame_address(__builtin_frame_address(1));
}

void
objc_release_stack_objects()
{
  /* Note that the argument may be a bit conservative here. */
  objc_release_stack_objects_to_frame_address(__builtin_frame_address(0));
}

void
objc_stack_release_object(id anObj, unsigned frames_up)
{
  /* Do the pending releases of other objects */
  objc_release_stack_objects_to_frame_address
    (__builtin_frame_address(frames_up+1));

  /* Queue this object for later release */
  released_index++;
  grow_released_arrays();
  released_objects[released_index] = self;
  released_stack_pointers[released_index] = __builtin_frame_address(1);
}


@implementation Object (RetainingObject)

- retain
{
  objc_retain_object(self);
  return self;
}

- stackRelease
{
  objc_stack_release_object(self,1);
  return self;
}

- (oneway void) release
{
  objc_release_object(self);
}

- (void) dealloc
{
  object_dispose(self);
}

- (unsigned) retainCount
{
  return objc_retain_count(self);
}

@end
