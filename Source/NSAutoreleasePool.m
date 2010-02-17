/** Implementation of auto release pool for delayed disposal
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: January 1995

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSAutoreleasePool class reference</title>
   $Date$ $Revision$
   */

#import "config.h"
#define	EXPOSE_NSAutoreleasePool_IVARS	1
#define	EXPOSE_NSThread_IVARS	1
#import "GNUstepBase/preface.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSGarbageCollector.h"
#import "Foundation/NSException.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSZone.h"
#include <limits.h>

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
#define ARP_THREAD_VARS (&((GSCurrentThread())->_autorelease_vars))


@interface NSAutoreleasePool (Private)
+ (unsigned) autoreleaseCountForObject: (id)anObject;
- (void) _reallyDealloc;
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
      tv->pool_cache_size = 0;
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

static SEL	releaseSel = 0;


@implementation NSAutoreleasePool

static IMP	allocImp;
static IMP	initImp;

+ (void) initialize
{
  if (self == [NSAutoreleasePool class])
    {
      releaseSel = @selector(release);
      allocImp = [self methodForSelector: @selector(allocWithZone:)];
      initImp = [self instanceMethodForSelector: @selector(init)];
    }
}

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
      _released_count = 0;
    }
  else
    /* Already initialized; (it came from autorelease_pool_cache);
       we don't have to allocate new array list memory. */
    {
      _released = _released_head;
    }

  /* Install ourselves as the current pool. */
  {
    struct autorelease_thread_vars *tv = ARP_THREAD_VARS;
    _parent = tv->current_pool;
    if (_parent)
      _parent->_child = self;
    tv->current_pool = self;
  }

  return self;
}

- (unsigned) autoreleaseCount
{
  unsigned count = 0;
  struct autorelease_array_list *released = _released_head;
  while (released != 0)
    {
      count += released->count;
      released = released->next;
    }
  return count;
}

- (unsigned) autoreleaseCountForObject: (id)anObject
{
  unsigned count = 0;
  struct autorelease_array_list *released = _released_head;
  unsigned int i;

  while (released != 0)
    {
      for (i = 0; i < released->count; i++)
	if (released->objects[i] == anObject)
	  count++;
      released = released->next;
    }
  return count;
}

+ (unsigned) autoreleaseCountForObject: (id)anObject
{
  unsigned count = 0;
  NSAutoreleasePool *pool = ARP_THREAD_VARS->current_pool;

  while (pool)
    {
      count += [pool autoreleaseCountForObject: anObject];
      pool = pool->_parent;
    }
  return count;
}

+ (id) currentPool
{
  return ARP_THREAD_VARS->current_pool;
}

+ (void) addObject: (id)anObj
{
  NSThread		*t = GSCurrentThread();
  NSAutoreleasePool	*pool;

  pool = t->_autorelease_vars.current_pool;
  if (pool == nil && t->_active == NO)
    {
      [self new];	// Don't leak while exiting thread.
      pool = t->_autorelease_vars.current_pool;
    }
  if (pool != nil)
    {
      (*pool->_addImp)(pool, @selector(addObject:), anObj);
    }
  else
    {
      NSAutoreleasePool	*arp = [NSAutoreleasePool new];

      if (anObj != nil)
	{
	  NSLog(@"autorelease called without pool for object (%p) "
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
  while (_released->count == _released->size)
    {
      if (_released->next)
	{
	  /* There is an already-allocated one in the chain; use it. */
	  _released = _released->next;
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

  /* Keep track of the total number of objects autoreleased in this pool */
  _released_count++;
}

- (void) drain
{
#if	GS_WITH_GC
  static NSGarbageCollector	*collector = nil;
  static SEL			sel;
  static IMP			imp;

  if (collector == nil)
    {
      collector = [NSGarbageCollector defaultCollector];
      sel = @selector(collectIfNeeded);
      imp = [collector methodForSelector: sel];
    }
  (*imp)(collector, sel);
#else
  [self release];
#endif
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
  struct autorelease_thread_vars *tv = ARP_THREAD_VARS;

  [self emptyPool];

  /*
   * Remove self from the linked list of pools in use.
   * We already know that we have deallocated our child (if any),
   * but we may have a parent which needs to know we have gone.
   */
  if (tv->current_pool == self)
    {
      tv->current_pool = _parent;
    }
  if (_parent != nil)
    {
      _parent->_child = nil;
      _parent = nil;
    }
  _child = nil;

  /* Don't deallocate ourself, just save us for later use. */
  push_pool_to_cache (tv, self);
  GSNOSUPERDEALLOC;
}

- (void) emptyPool
{
  unsigned	i;
  Class		classes[16];
  IMP	 	imps[16];

  for (i = 0; i < 16; i++)
    {
      classes[i] = 0;
      imps[i] = 0;
    }

  /*
   * Loop throught the deallocation code repeatedly ... since we deallocate
   * objects in the receiver while the receiver remains set as the current
   * autorelease pool ... so if any object which is being deallocated adds
   * any object to the current autorelease pool, we may need to release it
   * again.
   */
  while (_child != nil || _released_count > 0)
    {
      volatile struct autorelease_array_list *released;

      /* If there are NSAutoreleasePool below us in the stack of
	 NSAutoreleasePools, then deallocate them also.  The (only) way we
	 could get in this situation (in correctly written programs, that
	 don't release NSAutoreleasePools in weird ways), is if an
	 exception threw us up the stack. */
      while (_child != nil)
	{
	  [_child dealloc];
	}

      /* Take the object out of the released list just before releasing it,
       * so if we are doing "double_release_check"ing, then
       * autoreleaseCountForObject: won't find the object we are currently
       * releasing. */
      released = _released_head;
      while (released != 0)
	{
	  id	*objects = (id*)(released->objects);

	  for (i = 0; i < released->count; i++)
	    {
	      id	anObject;
	      Class	c;
	      unsigned	hash;

	      anObject = objects[i];
	      objects[i] = nil;
              if (anObject == nil)
                {
                  fprintf(stderr,
                    "nil object encountered in autorelease pool\n");
                  continue;
                }
	      c = GSObjCClass(anObject);
              if (c == 0)
                {
                  [NSException raise: NSInternalInconsistencyException
                    format: @"nul class for object in autorelease pool"];
                }
	      hash = (((unsigned)(uintptr_t)c) >> 3) & 0x0f;
	      if (classes[hash] != c)
		{
                  /* If anObject was an instance, c is it's class.
                   * If anObject was a class, c is its metaclass.
                   * Either way, get_imp() should get the appropriate pointer.
                   * If anObject is a proxy to something,
                   * the +instanceMethodForSelector: and -methodForSelector:
                   * methods may not exist, but get_imp() will return the
                   * address of the forwarding method if necessary.
                   */
		  imps[hash] = get_imp(c, @selector(release));
		  classes[hash] = c;
		}
	      (imps[hash])(anObject, releaseSel);
	    }
	  _released_count -= released->count;
	  released->count = 0;
	  released = released->next;
	}
    }
}

- (void) _reallyDealloc
{
  struct autorelease_array_list *a;
  for (a = _released_head; a;)
    {
      void *n = a->next;
      NSZoneFree(NSDefaultMallocZone(), a);
      a = n;
    }
  _released = _released_head = 0;
  [super dealloc];
}

- (id) autorelease
{
  [NSException raise: NSGenericException
	       format: @"Don't call `-autorelease' on a NSAutoreleasePool"];
  return self;
}

+ (void) _endThread: (NSThread*)thread
{
  struct autorelease_thread_vars *tv;
  NSAutoreleasePool *pool;

  tv = &((thread)->_autorelease_vars);

  /* First release any objects in the pool... bearing in mind that
   * releasing any object could cause other objects to be added to
   * the pool.
   */
  pool = tv->current_pool;
  while (pool)
    {
      [pool emptyPool];
      pool = pool->_parent;
    }

  /* Now free the memory (we have finished usingthe pool).
   */
  pool = tv->current_pool;
  while (pool)
    {
      NSAutoreleasePool *p = pool->_parent;

      [pool _reallyDealloc];
      pool = p;
    }

  free_pool_cache(tv);
}

+ (void) enableRelease: (BOOL)enable
{
  autorelease_enabled = enable;
}

+ (void) freeCache
{
  free_pool_cache(ARP_THREAD_VARS);
}

+ (void) setPoolCountThreshhold: (unsigned)c
{
  pool_count_warning_threshhold = c;
}

@end

