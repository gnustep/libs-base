/* Implementation of release pools for delayed disposal
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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

#include <objects/AutoreleasePool.h>
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

static AutoreleasePool *current_pool = nil;
static coll_cache_ptr retain_counts = NULL;

#define DEFAULT_SIZE 64


void
objc_retain_object (id anObj)
{
  coll_node_ptr n;

  assert(retain_counts);
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

  assert(retain_counts);
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

  assert(retain_counts);
  n = coll_hash_node_for_key(retain_counts, anObj);
  if (n)
    return n->value.unsigned_int_u;
  else
    return 0;
}

@implementation AutoreleasePool

+ initialize
{
  if (self == [AutoreleasePool class])
    {
      retain_counts = coll_hash_new(64,
				    (coll_hash_func_type)
				    elt_hash_void_ptr,
				    (coll_compare_func_type)
				    elt_compare_void_ptrs);
      current_pool = [[AutoreleasePool alloc] init];
    }
  return self;
}

+ currentPool
{
  return current_pool;
}

+ (void) addObject: anObj
{
  [current_pool addObject:anObj];
}

- (void) addObject: anObj
{
  released_count++;
  if (released_count == released_size)
    {
      released_size *= 2;
      OBJC_REALLOC(released, id, released_size);
    }
  released[released_count] = anObj;
}

- init
{
  parent = current_pool;
  current_pool = self;
  OBJC_MALLOC(released, id, DEFAULT_SIZE);
  released_size = DEFAULT_SIZE;
  released_count = 0;
  return self;
}

- (id) retain
{
  [self error:"Don't call `-retain' on a AutoreleasePool"];
  return self;
}

- (oneway void) release
{
  [self dealloc];
}

- (void) dealloc
{
  int i;
  if (parent)
    current_pool = parent;
  else
    current_pool = [[AutoreleasePool alloc] init];
  for (i = 0; i < released_count; i++)
    [released[i] release];
  OBJC_FREE(released);
  object_dispose(self);
}

- autorelease
{
  [self error:"Don't call this"];
  return self;
}

- (unsigned) retainCount
{
  return UINT_MAX;
}

@end


@implementation Object (Retaining)

- retain
{
  objc_retain_object(self);
  return self;
}

- (oneway void) release
{
  objc_release_object(self);
}

- autorelease
{
  [current_pool addObject:self];
  return self;
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
