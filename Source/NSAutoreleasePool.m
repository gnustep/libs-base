/** Implementation of auto release pool for delayed disposal
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: January 1995
   
   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSAutoreleasePool class reference</title>
   $Date$ $Revision$
   */ 

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSException.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSZone.h"
#include <limits.h>

/*
 * Set to 1 to count all autoreleases
 */
#define	COUNT_ALL	0

/* When this is `NO', autoreleased objects are never actually recorded
   in an NSAutoreleasePool, and are not sent a `release' message.
   Thus memory for objects use grows, and grows, and... */
static BOOL autorelease_enabled = YES;

/* When the _released_count of a pool gets over this value, we raise
   an exception.  This can be adjusted with -setPoolCountThreshhold */
static unsigned pool_count_warning_threshhold = UINT_MAX;

/* The size of the first _released array. */
#define BEGINNING_POOL_SIZE 32

/* Easy access to the thread variables belonging to NSAutoreleasePool. */
#define ARP_THREAD_VARS (&(GSCurrentThread()->_autorelease_vars))


@interface NSAutoreleasePool (Private)
- (id) _parentAutoreleasePool;
- (unsigned) autoreleaseCount;
- (unsigned) autoreleaseCountForObject: (id)anObject;
+ (unsigned) autoreleaseCountForObject: (id)anObject;
+ (id) currentPool;
- (void) _reallyDealloc;
- (void) _setChildPool: (id)pool;
@end


/* Functions for managing a per-thread cache of NSAutoreleasedPool's
   already alloc'ed.  The cache is kept in the autorelease_thread_var 
   structure, which is an ivar of NSThread. */

static id pop_pool_from_cache (struct autorelease_thread_vars *tv);

static inline void
free_pool_cache (struct autorelease_thread_vars *tv)
{
  while (tv->pool_cache_count)
    {
      NSAutoreleasePool	*pool = pop_pool_from_cache(tv);

      [pool _reallyDealloc];
    }

  if (tv->pool_cache)
    {
      NSZoneFree(NSDefaultMallocZone(), tv->pool_cache);
      tv->pool_cache = 0;
    }
}

static inline void
init_pool_cache (struct autorelease_thread_vars *tv)
{
  tv->pool_cache_size = 32;
  tv->pool_cache_count = 0;
  tv->pool_cache = (id*)NSZoneMalloc(NSDefaultMallocZone(),
    sizeof(id) * tv->pool_cache_size);
}

static void
push_pool_to_cache (struct autorelease_thread_vars *tv, id p)
{
  if (!tv->pool_cache)
    {
      init_pool_cache (tv);
    }
  else if (tv->pool_cache_count == tv->pool_cache_size)
    {
      tv->pool_cache_size *= 2;
      tv->pool_cache = (id*)NSZoneRealloc(NSDefaultMallocZone(),
	tv->pool_cache, sizeof(id) * tv->pool_cache_size);
    }
  tv->pool_cache[tv->pool_cache_count++] = p;
}

static id
pop_pool_from_cache (struct autorelease_thread_vars *tv)
{
  return tv->pool_cache[--(tv->pool_cache_count)];
}


/**
 * <p>
 *   The standard OpenStep system of memory management employs retain counts.
 *   When an object is created, it has a retain count of 1.  When an object
 *   is retained, the retain count is incremented.  When it is released the
 *   retain count is decremented, and when the retain count goes to zero the
 *   object gets deallocated.
 * </p>
 * <p>
 *   A simple retain/release mechanism is not very interesting ...
 *   so it's spiced up with autorelease pools.  You can use the
 *   AUTORELEASE() macro to call the [NSObject-autorelease]
 *   method, which adds an object to the current autorelease pool by
 *   calling [NSAutoreleasePool+addObject:].<br />
 *   An autorelease pool simply maintains a reference to each object
 *   added to it, and for each addition, the autorelease pool will
 *   call the [NSObject-release] method of the object when the pool
 *   is released.  So doing an AUTORELEASE() is just the same as
 *   doing a RELEASE(), but deferred until the current autorelease
 *   pool is deallocated.
 * </p>
 * <p>
 *   The NSAutoreleasePool class maintains a separate stack of
 *   autorelease pools objects in each thread.
 * </p>
 * <p>
 *   When an autorelease pool is created, it is automatically
 *   added to the stack of pools in the thread.
 * </p>
 * <p>
 *   When a pool is destroyed, it (and any pool later in
 *   the stack) is removed from the stack.
 * </p>
 * <p>
 *   This mechanism provides a simple but controllable and reasonably
 *   efficient way of managing temporary objects.  An object can be
 *   autoreleased and then passed around and used until the topmost 
 *   pool in the stack is destroyed.
 * </p>   
 * <p>
 *   Most methods return objects which are either owned by autorelease
 *   pools or by the receiver of the method, so the lifetime of the
 *   returned object can be assumed to be the shorter of the lifetime
 *   of the current autorelease pool, or that of the receiver on which
 *   the method was called.<br />
 *   The exceptions to this are those object returned by -
 * </p>
 * <deflist>
 *   <term>[NSObject+alloc], [NSObject+allocWithZone:]</term>
 *   <desc>
 *     Methods whose names begin with alloc return an uninitialised
 *     object, owned by the caller.
 *   </desc>
 *   <term>[NSObject-init]</term>
 *   <desc>
 *     Methods whose names begin with init return an initialised
 *     version of the receiving object, owned by the caller.<br />
 *     NB. The returned object may not actualy be the same as the
 *     receiver ... sometimes an init method releases the original
 *     receiver and returns an alternative.
 *   </desc>
 *   <term>[NSObject+new]</term>
 *   <desc>
 *     Methods whose names begin with new combine the effects of
 *     allocation and initialisation.
 *   </desc>
 *   <term>[NSObject-copy], [(NSCopying)-copyWithZone:]</term>
 *   <desc>
 *     Methods whose names begin with copy create a copy of the receiver
 *     which is owned by the caller.
 *   </desc>
 *   <term>[NSObject-mutableCopy], [(NSMutableCopying)-mutableCopyWithZone:]</term>
 *   <desc>
 *     Methods whose names begin with mutableCopy create a copy of the receiver
 *     which is owned by the caller.
 *   </desc>
 * </deflist>
 */
@implementation NSAutoreleasePool

static IMP	allocImp;
static IMP	initImp;

+ (void) initialize
{
  if (self == [NSAutoreleasePool class])
    {
      allocImp = [self methodForSelector: @selector(allocWithZone:)];
      initImp = [self instanceMethodForSelector: @selector(init)];
    }
}

/**
 * Allocate and return an autorelease pool instance.<br />
 * If there is an already-allocated NSAutoreleasePool available,
 * save time by just returning that, rather than allocating a new one.
 */
+ (id) allocWithZone: (NSZone*)zone
{
  struct autorelease_thread_vars *tv = ARP_THREAD_VARS;
  if (tv->pool_cache_count)
    return pop_pool_from_cache (tv);

  return NSAllocateObject (self, 0, zone);
}

+ (id) new
{
  id arp = (*allocImp)(self, @selector(allocWithZone:), NSDefaultMallocZone());
  return (*initImp)(arp, @selector(init));
}

- (id) init
{
  if (!_released_head)
    {
      _addImp = (void (*)(id, SEL, id))
	[self methodForSelector: @selector(addObject:)];
      /* Allocate the array that will be the new head of the list of arrays. */
      _released = (struct autorelease_array_list*)
	NSZoneMalloc(NSDefaultMallocZone(),
	sizeof(struct autorelease_array_list)
	+ (BEGINNING_POOL_SIZE * sizeof(id)));
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
  {
    struct autorelease_thread_vars *tv = ARP_THREAD_VARS;
    _parent = tv->current_pool;
    _child = nil;
    if (_parent)
      [_parent _setChildPool: self];
    tv->current_pool = self;
  }

  return self;
}

- (void) _setChildPool: (id)pool
{
  _child = pool;
}

/* This method not in OpenStep */
- (id) _parentAutoreleasePool
{
  return _parent;
}

/*
 * Return the number of objects in this pool.
 */
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

/**
 * <p>
 *   Counts the number of times that the specified object occurs
 *   in autorelease pools in the current thread.
 * </p>
 * <p>
 *   This method is <em>slow</em> and should probably only be
 *   used for debugging purposes.
 * </p>
 */
- (unsigned) autoreleaseCountForObject: (id)anObject
{
  unsigned count = 0;
  struct autorelease_array_list *released = _released_head;
  unsigned int i;

  while (released && released->count)
    {
      for (i = 0; i < released->count; i++)
	if (released->objects[i] == anObject)
	  count++;
      released = released->next;
    }
  return count;
}

/**
 * <p>
 *   Counts the number of times that the specified object occurs
 *   in autorelease pools in the current thread.
 * </p>
 * <p>
 *   This method is <em>slow</em> and should probably only be
 *   used for debugging purposes.
 * </p>
 */
+ (unsigned) autoreleaseCountForObject: (id)anObject
{
  unsigned count = 0;
  id pool = ARP_THREAD_VARS->current_pool;
  while (pool)
    {
      count += [pool autoreleaseCountForObject: anObject];
      pool = [pool _parentAutoreleasePool];
    }
  return count;
}

/**
 * Return the currently active autorelease pool.
 */
+ (id) currentPool
{
  return ARP_THREAD_VARS->current_pool;
}

/**
 * Adds the specified object to the current autorelease pool.
 * If there is no autorelease pool in the thread,
 * a warning is logged and the object is leaked (ie it will not be released).
 */
+ (void) addObject: (id)anObj
{
  NSAutoreleasePool	*pool = ARP_THREAD_VARS->current_pool;

  if (pool != nil)
    {
      (*pool->_addImp)(pool, @selector(addObject:), anObj);
    }
  else
    {
      NSAutoreleasePool	*arp = [NSAutoreleasePool new];

      if (anObj != nil)
	{
	  NSLog(@"autorelease called without pool for object (%x) "
	    @"of class %@ in thread %@", anObj,
	    NSStringFromClass([anObj class]), [NSThread currentThread]);
	}
      else
	{
	  NSLog(@"autorelease called without pool for nil object.");
	}
      [arp release];
    }
}

/**
 * Adds the specified object to this autorelease pool.
 */
- (void) addObject: (id)anObj
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
	    NSZoneMalloc(NSDefaultMallocZone(),
	    sizeof(struct autorelease_array_list) + (new_size * sizeof(id)));
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

#if	COUNT_ALL
  /* Keep track of the total number of objects autoreleased across all
     pools. */
  ARP_THREAD_VARS->total_objects_count++;
#endif

  /* Keep track of the total number of objects autoreleased in this pool */
  _released_count++;
}

/**
 * Raises an exception ... pools should not be retained.
 */
- (id) retain
{
  [NSException raise: NSGenericException
	       format: @"Don't call `-retain' on a NSAutoreleasePool"];
  return self;
}

/**
 * Destroys the receiver (calls -dealloc).
 */
- (oneway void) release
{
  [self dealloc];
}

- (void) dealloc
{
  //  fprintf (stderr, "Deallocating an NSAutoreleasePool\n");
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
    unsigned int i;

    while (released)
      {
	for (i = 0; i < released->count; i++)
	  {
	    id anObject = released->objects[i];
#if 0
	    /* There is no general method to find out whether a memory
               chunk has been deallocated or not, especially when
               custom zone functions might be used.  So we #if this
               out. */
	    if (!NSZoneMemInUse(anObject))
              [NSException 
                raise: NSGenericException
                format: @"Autoreleasing deallocated object.\n"
                @"Suggest you debug after setting [NSObject "
		@"enableDoubleReleaseCheck:YES]\n"
		@"to check for release errors."];
#endif
	    released->objects[i] = nil;
	    [anObject release];
	  }
	released->count = 0;
	released = released->next;
      }
  }

  {
    struct autorelease_thread_vars *tv;
    NSAutoreleasePool **cp;

    /* Uninstall ourselves as the current pool; install our parent pool. */
    tv = ARP_THREAD_VARS;
    cp = &(tv->current_pool);
    *cp = _parent;
    if (*cp)
      (*cp)->_child = nil;

    /* Don't deallocate ourself, just save us for later use. */
    push_pool_to_cache (tv, self);
  }
}

- (void) _reallyDealloc
{
  struct autorelease_array_list *a;
  for (a = _released_head; a; )
    {
      void *n = a->next;
      NSZoneFree(NSDefaultMallocZone(), a);
      a = n;
    }
  [super dealloc];
}

/**
 * Raises an exception - pools should not be autoreleased.
 */
- (id) autorelease
{
  [NSException raise: NSGenericException
	       format: @"Don't call `-autorelease' on a NSAutoreleasePool"];
  return self;
}

/**
 * Destroys all the autorelease pools in the thread.
 * You should not call this directly, it's called automatically
 * when a thread exits.
 */
+ (void) _endThread: (NSThread*)thread
{
  struct autorelease_thread_vars *tv;
  id	pool;

  tv = ARP_THREAD_VARS;
  while (tv->current_pool)
    {
      [tv->current_pool release];
      pool = pop_pool_from_cache(tv);
      [pool _reallyDealloc];
    }

  free_pool_cache(tv);
}

/**
 * Resets (to zero) the count of autoreleased objects in the current thread.
 */
+ (void) resetTotalAutoreleasedObjects
{
  ARP_THREAD_VARS->total_objects_count = 0;
}

/**
 * Returns the number of objects which have been autoreleased in the
 * current thread since the last call to +resetTotalAutoreleasedObjects.<br />
 * NB. This is not normally supported ... enable it as a compile time option
 * by editing NSAutoreleasePool.m when building the base library.
 */
+ (unsigned) totalAutoreleasedObjects
{
  return ARP_THREAD_VARS->total_objects_count;
}

/**
 * <p>
 *   Specifies whether objects contained in autorelease pools are to
 *   be released when the pools are deallocated (by default YES).
 * </p>
 * <p>
 *   You can set this to NO for debugging purposes.
 * </p>
 */
+ (void) enableRelease: (BOOL)enable
{
  autorelease_enabled = enable;
}

/**
 * <p>
 *   When autorelease pools are deallocated, the memory they used
 *   is retained in a cache for re-use so that new polls can be
 *   created very quickly.
 * </p>
 * <p>
 *   This method may be used to empty that cache, ensuring that
 *   the minimum memory is used by the application.
 * </p>
 */
+ (void) freeCache
{
  free_pool_cache(ARP_THREAD_VARS);
}

/**
 * <p>
 *   Specifies a limit to the number of objects that may be added to
 *   an autorelease pool.  When this limit is reached an exception is
 *   raised.
 * </p>
 * <p>
 *   You can set this to a smallish value to catch problems with code
 *   that autoreleases too many objects to operate efficiently.
 * </p>
 * <p>
 *   Default value is maxint.
 * </p>
 */
+ (void) setPoolCountThreshhold: (unsigned)c
{
  pool_count_warning_threshhold = c;
}

@end

