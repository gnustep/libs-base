/* Implementation of retaining/releasing for object disposal and ref counting
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
   This file is part of the Gnustep Base Library.

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

#include <gnustep/base/ObjectRetaining.h>
#include <gnustep/base/collhash.h>
#include <gnustep/base/eltfuncs.h>
#include <gnustep/base/objc-malloc.h>
#include <gnustep/base/AutoreleasePool.h>
#include <limits.h>

/* Doesn't handle multi-threaded stuff.
   Doesn't handle exceptions. */

/* The hashtable of retain counts on objects */
static coll_cache_ptr retain_counts = NULL;

/* The Class responsible for handling autorelease's */
id autorelease_class = nil;

static void
init_retain_counts_if_necessary()
{
  /* Initialize if we haven't done it yet */
  if (!retain_counts)
    {
      retain_counts = coll_hash_new(64,
				    (coll_hash_func_type)
				    elt_hash_void_ptr,
				    (coll_compare_func_type)
				    elt_compare_void_ptrs);
    }
}

void
objc_retain_object (id anObj)
{
  coll_node_ptr n;

  init_retain_counts_if_necessary();
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

  init_retain_counts_if_necessary();
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

  init_retain_counts_if_necessary();
  n = coll_hash_node_for_key(retain_counts, anObj);
  if (n)
    return n->value.unsigned_int_u;
  else
    return 0;
}

@implementation Object (RetainingObject)

- retain
{
  objc_retain_object(self);
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

- autorelease
{
  [autorelease_class autoreleaseObject:self];
  return self;
}

@end
