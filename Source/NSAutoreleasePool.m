/* Implementation of auto release pool for delayed disposal
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995
   
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

#include <gnustep/base/preface.h>
#include <Foundation/NSAutoreleasePool.h>
#include <gnustep/base/objc-malloc.h>
#include <gnustep/base/Array.h>
#include <Foundation/NSException.h>
#include <limits.h>

/* TODO:
   Doesn't work multi-threaded.
   */

/* The current, default NSAutoreleasePool; the one that will hold
   objects that are arguments to [NSAutoreleasePool +addObject:]. */
static NSAutoreleasePool *current_pool = nil;

/* When this is `NO', autoreleased objects are never actually recorded
   in an NSAutoreleasePool, and are not sent a `release' message.
   Thus memory for objects use grows, and grows, and... */
static BOOL autorelease_enabled = YES;

/* When the _released_count of the current pool gets over this value,
   we raise an exception.  This can be adjusted with -setPoolCountThreshhold */
static unsigned pool_count_warning_threshhold = UINT_MAX;

/* The total number of objects autoreleased since the program was
   started, or since -resetTotalAutoreleasedObjects was called. */
static unsigned total_autoreleased_objects_count = 0;

/* The size of the first _released array. */
#define BEGINNING_POOL_SIZE 32


@interface NSAutoreleasePool (Private)
- _parentAutoreleasePool;
- (unsigned) autoreleaseCount;
- (unsigned) autoreleaseCountForObject: anObject;
+ (unsigned) autoreleaseCountForObject: anObject;
+ currentPool;
- (void) _setChildPool: pool;
@end

/* A cache of NSAutoreleasePool's already alloc'ed.  Caching old pools
   instead of deallocating and re-allocating them will save time. */
static id *autorelease_pool_cache;
static int autorelease_pool_cache_size = 32;
static int autorelease_pool_cache_count = 0;

static void
push_pool_to_cache (id p)
{
  if (autorelease_pool_cache_count == autorelease_pool_cache_size)
    {
      autorelease_pool_cache_size *= 2;
      OBJC_REALLOC (autorelease_pool_cache, id, autorelease_pool_cache_size);
    }
  autorelease_pool_cache[autorelease_pool_cache_count++] = p;
}

static id
pop_pool_from_cache ()
{
  assert (autorelease_pool_cache_count);
  return autorelease_pool_cache[--autorelease_pool_cache_count];
}


@implementation NSAutoreleasePool

+ (void) initialize
{
  if (self == [NSAutoreleasePool class])
    OBJC_MALLOC (autorelease_pool_cache, id, autorelease_pool_cache_size);
}

+ allocWithZone: (NSZone*)z
{
  /* If there is an already-allocated NSAutoreleasePool available,
     save time by just returning that, rather than allocating a new one. */
  if (autorelease_pool_cache_count)
    return pop_pool_from_cache ();

  return NSAllocateObject (self, 0, z);
}

- init
{
  if (!_released_head)
    {
      /* Allocate the array that will be the new head of the list of arrays. */
      _released = (struct autorelease_array_list*)
	(*objc_malloc) (sizeof(struct autorelease_array_list) + 
			(BEGINNING_POOL_SIZE * sizeof(id)));
      /* Currently no NEXT array in the list, so NEXT == NULL. */
      _released->next = NULL;
      _released->size = BEGINNING_POOL_SIZE;
      _released->count = 0;
      _released_head = _released;
    }
  else
    /* Already initialized; (it came from autorelease_pool_cache);
       we don't have to allocate new array list memory. */
    {
      _released = _released_head;
      _released->count = 0;
    }

  /* This NSAutoreleasePool contains no objects yet. */
  _released_count = 0;

  /* Install ourselves as the current pool. */
  _parent = current_pool;
  _child = nil;
  [current_pool _setChildPool: self];
  current_pool = self;

  return self;
}

- (void) _setChildPool: pool
{
  assert (!_child);
  _child = pool;
}

/* This method not in OpenStep */
- _parentAutoreleasePool
{
  return _parent;
}

/* This method not in OpenStep */
- (unsigned) autoreleaseCount
{
  unsigned count = 0;
  struct autorelease_array_list *released = _released_head;
  while (released && released->count)
    {
      count += released->count;
      released = released->next;
    }
  return count;
}

/* This method not in OpenStep */
- (unsigned) autoreleaseCountForObject: anObject
{
  unsigned count = 0;
  struct autorelease_array_list *released = _released_head;
  int i;

  while (released && released->count)
    {
      for (i = 0; i < released->count; i++)
	if (released->objects[i] == anObject)
	  count++;
      released = released->next;
    }
  return count;
}

/* This method not in OpenStep */
+ (unsigned) autoreleaseCountForObject: anObject
{
  unsigned count = 0;
  id pool = current_pool;
  while (pool)
    {
      count += [pool autoreleaseCountForObject: anObject];
      pool = [pool _parentAutoreleasePool];
    }
  return count;
}

+ currentPool
{
  return current_pool;
}

+ (void) addObject: anObj
{
  [current_pool addObject: anObj];
}

- (void) addObject: anObj
{
  /* If the global, static variable AUTORELEASE_ENABLED is not set,
     do nothing, just return. */
  if (!autorelease_enabled)
    return;

  if (_released_count >= pool_count_warning_threshhold)
    [NSException raise: NSGenericException
		 format: @"AutoreleasePool count threshhold exceeded."];

  /* Get a new array for the list, if the current one is full. */
  if (_released->count == _released->size)
    {
      if (_released->next)
	{
	  /* There is an already-allocated one in the chain; use it. */
	  _released = _released->next;
	  _released->count = 0;
	}
      else
	{
	  /* We are at the end of the chain, and need to allocate a new one. */
	  struct autorelease_array_list *new_released;
	  unsigned new_size = _released->size * 2;
	  
	  new_released = (struct autorelease_array_list*)
	    (*objc_malloc) (sizeof(struct autorelease_array_list) + 
			    (new_size * sizeof(id)));
	  new_released->next = NULL;
	  new_released->size = new_size;
	  new_released->count = 0;
	  _released->next = new_released;
	  _released = new_released;
	}
    }

  /* Put the object at the end of the list. */
  _released->objects[_released->count] = anObj;
  (_released->count)++;

  /* Keep track of the total number of objects autoreleased across all
     pools. */
  total_autoreleased_objects_count++;

  /* Keep track of the total number of objects autoreleased in this pool */
  _released_count++;
}

- (id) retain
{
  [NSException raise: NSGenericException
	       format: @"Don't call `-retain' on a NSAutoreleasePool"];
  return self;
}

- (oneway void) release
{
  [self dealloc];
}

- (void) dealloc
{
  /* If there are NSAutoreleasePool below us in the stack of
     NSAutoreleasePools, then deallocate them also.  The (only) way we
     could get in this situation (in correctly written programs, that
     don't release NSAutoreleasePools in weird ways), is if an
     exception threw us up the stack. */
  if (_child)
    [_child dealloc];

  /* Make debugging easier by checking to see if the user already
     dealloced the object before trying to release it.  Also, take the
     object out of the released list just before releasing it, so if
     we are doing "double_release_check"ing, then
     autoreleaseCountForObject: won't find the object we are currently
     releasing. */
  {
    struct autorelease_array_list *released = _released_head;
    int i;

    while (released)
      {
	for (i = 0; i < released->count; i++)
	  {
	    id anObject = released->objects[i];
	    if (object_get_class(anObject) == (void*) 0xdeadface)
	      [NSException 
		raise: NSGenericException
		format: @"Autoreleasing deallocated object.\n"
		@"Suggest you debug after setting [NSObject "
		@"enableDoubleReleaseCheck:YES]\n"
		@"to check for release errors."];
	    released->objects[i] = nil;
	    [anObject release];
	  }
	released = released->next;
      }
  }

  /* Uninstall ourselves as the current pool; install our parent pool. */
  current_pool = _parent;
  if (current_pool)
    current_pool->_child = nil;

  /* Don't deallocate ourself, just save us for later use. */
  push_pool_to_cache (self);
}

- autorelease
{
  [NSException raise: NSGenericException
	       format: @"Don't call `-autorelease' on a NSAutoreleasePool"];
  return self;
}

+ (void) resetTotalAutoreleasedObjects
{
  total_autoreleased_objects_count = 0;
}

+ (unsigned) totalAutoreleasedObjects
{
  return total_autoreleased_objects_count;
}

+ (void) enableRelease: (BOOL)enable
{
  autorelease_enabled = enable;
}

+ (void) setPoolCountThreshhold: (unsigned)c
{
  pool_count_warning_threshhold = c;
}

@end
