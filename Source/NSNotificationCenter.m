/* Implementation of NSNotificationCenter for GNUstep
   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: June 1999

   Many thanks for the earlier version, (from which this is loosely
   derived) by  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSLock.h>


/*
 * Garbage collection considerations -
 * The notification center is not supposed to retain any notification
 * observers or notification objects.  To achieve this when using garbage
 * collection, we must hide all references to observers and objects.
 * Within an Observation structure, this is not a problem, we simply
 * allocate the structure using 'atomic' allocation to tell the gc
 * system to ignore pointers inside it.
 * Elsewhere, we store the pointers with a bit added, to hide them from
 * the garbage collector.
 */


/*
 * Observation structure - One of these objects is created for
 * each -addObserver... request.  It holds the requested selector,
 * name and object.  Each struct is placed
 * (1) in one LinkedList, as keyed by the NAME/OBJECT parameters
 * (2) in an array, as keyed by the OBSERVER
 */

typedef	struct	Obs {
  NSString	*name;
  id		object;
  id		observer;
  SEL		selector;
  IMP		method;
  struct Obs	*next;
  unsigned	retained;
} Observation;

#define	ENDOBS	((Observation*)-1)

static void FreeObs(Observation *o)
{
  if (o->retained)
    o->retained--;
  else
    NSZoneFree(NSDefaultMallocZone(), o);
}

static void FreeList(Observation *list)
{
  while (list != ENDOBS)
    {
      Observation	*o = list;

      list = o->next;
      FreeObs(o);
    }
}

static void *RetainObs(Observation *o)
{
  o->retained++;
}

static unsigned oHash(void* t, Observation *o)
{
  unsigned	hash;

  hash = (unsigned)(gsaddr)o->object ^ (unsigned)(gsaddr)o->selector;
  if (o->name != nil)
    hash ^= [o->name hash];
  return hash;
}

static BOOL oIsEqual(void* t, Observation *o1, Observation* o2)
{
  if (o1->object != o2->object)
    return NO;
  if (o1->selector != o2->selector)
    return NO;
  if (o1->name != o2->name)
    return [o1->name isEqual: o2->name];
  return YES;
}

static void* oRetain(void* t, Observation *o)
{
  o->retained++;
}

static void oRelease(void* t, Observation *o)
{
  if (o->retained)
    o->retained--;
  else
    NSZoneFree(NSDefaultMallocZone(), o);
}

const NSHashTableCallBacks ObsCallBacks =
{
  (NSHT_hash_func_t) oHash,
  (NSHT_isEqual_func_t) oIsEqual,
  (NSHT_retain_func_t) oRetain,
  (NSHT_release_func_t) oRelease,
  (NSHT_describe_func_t) 0
};

const NSMapTableValueCallBacks ObsMapCallBacks =
{
  (NSMT_retain_func_t) oRetain,
  (NSMT_release_func_t) oRelease,
  (NSMT_describe_func_t) 0
};

/*
 * Setup for inline operation on arrays of Observers.
 */

#define GSI_ARRAY_TYPES       0
#define GSI_ARRAY_EXTRA       Observation*

#define GSI_ARRAY_RELEASE(X)   FreeObs(((X).ext))
#define GSI_ARRAY_RETAIN(X)    RetainObs(((X).ext))

#include <base/GSIArray.h>

#define GSI_MAP_RETAIN_VAL(X)  X
#define GSI_MAP_RELEASE_VAL(X)
#define GSI_MAP_KTYPES GSUNION_OBJ
#define GSI_MAP_VTYPES GSUNION_PTR

#include <base/GSIMap.h>

#if	GS_WITH_GC
/*
 * In order to hide pointers from garbage collection, we OR in an
 * extra bit.  This should be ok for the objects we deal with
 * which are all aligned on 4 or 8 byte boundaries on all the machines
 * I know of.
 */
#define	CHEATGC(X)	(void*)(gsaddr)((X) | 1)
#else
#define	CHEATGC(X)	(void*)(gsaddr)(X)
#endif



@implementation NSNotificationCenter

/* The default instance, most often the only one created.
   It is accessed by the class methods at the end of this file.
   There is no need to mutex locking of this variable. */

static NSNotificationCenter *default_center = nil;
static SEL	remSel = @selector(_removeObservationFromList:);
static void	(*remImp)(NSNotificationCenter*, SEL, Observation*) = 0;

+ (void) initialize
{
  if (self == [NSNotificationCenter class])
    {
      /*
       * Do alloc and init separately so the default center can refer to
       * the 'default_center' variable during initialisation.
       */
      default_center = [self alloc];
      [default_center init];
      remImp = (void (*)(NSNotificationCenter*, SEL, Observation*))
	[self instanceMethodForSelector: remSel];
    }
}

+ (NSNotificationCenter*) defaultCenter
{
  return default_center;
}


/* Initializing. */

- (id) init
{
  [super init];
  wildcard = ENDOBS;
  nameless = NSCreateMapTable(NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  observers = NSCreateMapTable(NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  named = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity((GSIMapTable)named,NSDefaultMallocZone(),128);

  _lock = [NSRecursiveLock new];

  return self;
}

- (void) dealloc
{
  [self gcFinalize];

  TEST_RELEASE(_lock);
  [super dealloc];
}

- (void) gcFinalize
{
  NSMapEnumerator	enumerator;
  id			o;
  GSIMapTable		f = (GSIMapTable)named;
  GSIMapNode		n;
  Observation		*l;
  NSHashTable		*h;
  NSMapTable		*m;

  /*
   * Free observations without notification names or numbers.
   */
  FreeList(wildcard);

  /*
   * Free lists of observations without notification names.
   */
  enumerator = NSEnumerateMapTable(nameless);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&o, (void**)&l))
    {
      FreeList(l);
    }
  NSFreeMapTable(nameless);

  /*
   * Free lists of observations keyed by name and observer.
   */
  n = f->firstNode;
  while (n != 0)
    {
      NSFreeMapTable((NSMapTable*)n->value.ptr);
      n = n->nextInMap;
    }
  GSIMapEmptyMap(f);
  NSZoneFree(f->zone, named);

  /*
   * Free tables of observations keyed by observer.
   */
  enumerator = NSEnumerateMapTable(observers);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)&o, (void**)&h))
    {
      NSFreeHashTable(h);
    }
  NSFreeMapTable(observers);
}


/* Adding new observers. */

- (void) addObserver: (id)observer
	    selector: (SEL)selector
                name: (NSString*)name
	      object: (id)object
{
  NSHashTable	*h;
  Observation	*o;
  unsigned	i;
  IMP		m;

  if (observer == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Nil observer passed to addObserver ..."];

  if (selector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"Null selector passed to addObserver ..."];

#if	defined(DEBUG)
  if ([observer respondsToSelector: selector] == NO)
    NSLog(@"Observer '%@' does not respond to selector '%@'", observer,
      NSStringFromSelector(selector));
#endif

  m = [observer methodForSelector: selector];
  if (m == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"Observer can not handle specified selector"];

  /*
   * NB. Do Atomic malloc for garbage collection - so objects pointed to by
   * the Observation structure will be garbage collected.
   */
#if	GS_WITH_GC
  o = (Observation*)NSZoneMallocAtomic(NSDefaultMallocZone(),
    sizeof(Observation));
#else
  o = (Observation*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(Observation));
#endif
  o->name = name;
  o->object = object;
  o->selector = selector;
  o->method = m;
  o->observer = observer;
  o->retained = 0;
  o->next = 0;

  [_lock lock];

  /* Record the Observation one of the linked lists */

  if (name)
    {
      NSMapTable	*m;
      Observation	*list;
      GSIMapNode	n;

      /*
       * Locate the map table for this name - create it if not present.
       */
      n = GSIMapNodeForKey((GSIMapTable)named, (GSIMapKey)name);
      if (n == 0)
	{
	  m = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
		      ObsMapCallBacks, 0);
	  /*
	   * If this is the first observation for the given name, we take a
	   * copy of the name so it cannot be mutated while in the map.
	   */
	  name = [name copyWithZone: NSDefaultMallocZone()];
	  o->name = name;
	  GSIMapAddPair((GSIMapTable)named, (GSIMapKey)name,
	    (GSIMapVal)(void*)m);
	  RELEASE(name);
	}
      else
	{
	  m = (NSMapTable*)n->value.ptr;
	  /*
	   * We record the name string that is used as the map key, so we
	   * don't need to retain it in the observation.
	   */
	  o->name = n->key.obj;
	}

      /*
       * Add the observation to the list for the correct object.
       */
      list = (Observation*)NSMapGet(m, CHEATGC(object));
      if (list == 0)
	{
	  o->next = ENDOBS;
	  NSMapInsert(m, CHEATGC(object), (void*)(gsaddr)o);
	}
      else
	{
	  o->next = list->next;
	  list->next = o;
	}
    }
  else if (object)
    {
      Observation	*list;

      list = (Observation*)NSMapGet(nameless, CHEATGC(object));
      if (list == 0)
	{
	  o->next = ENDOBS;
	  NSMapInsert(nameless, CHEATGC(object), (void*)(gsaddr)o);
	}
      else
	{
	  o->next = list->next;
	  list->next = o;
	}
    }
  else
    {
      o->next = wildcard;
      wildcard = o;
    }

  /*
   * Record the notification request in a hash table keyed by OBSERVER.
   * If it already exists, return without doing anything.
   */
  h = (NSHashTable*)NSMapGet(observers, CHEATGC(observer));
  if (h == 0)
    {
      h = NSCreateHashTableWithZone(ObsCallBacks, 4, NSDefaultMallocZone());
      NSMapInsert(observers, CHEATGC(observer), (void*)h);
    }
  if (NSHashGet(h, (void*)o) != 0)
    {
      NSZoneFree(NSDefaultMallocZone(), o);
      [_lock unlock];
      return;
    }
  NSHashInsert(h, (void*)o);

  [_lock unlock];
}

/*
 * Method for internal use only.
 */
- (void) _removeObservationFromList: (Observation*)o
{
  NSAssert(o->next != 0, NSInternalInconsistencyException);

  /* Remove the Observation from its list */

  if (o->name)
    {
      NSMapTable	*m;
      Observation	*list;
      GSIMapNode	n;

      /*
       * Locate the map table for this name.
       */
      n = GSIMapNodeForKey((GSIMapTable)named, (GSIMapKey)o->name);
      NSAssert(n != 0, NSInternalInconsistencyException);
      m = (NSMapTable*)n->value.ptr;

      list = (Observation*)NSMapGet(m, CHEATGC(o->object));
      NSAssert(list != 0, NSInternalInconsistencyException);
      if (list == o)
	{
	  if (list->next == ENDOBS)
	    {
	      NSMapRemove(m, CHEATGC(o->object));
	      if (NSCountMapTable(m) == 0)
		{
		  GSIMapRemoveKey((GSIMapTable)named, (GSIMapKey)o->name);
		}
	    }
	  else
	    {
	      NSMapInsert(m, CHEATGC(o->object), (void*)(gsaddr)o->next);
	    }
	}
      else
	{
	  while (list->next != o)
	    {
	      list = list->next;
	    }
	  list->next = o->next;
	}
    }
  else if (o->object)
    {
      Observation	*list;

      list = (Observation*)NSMapGet(nameless, CHEATGC(o->object));
      NSAssert(list != 0, NSInternalInconsistencyException);
      if (list == o)
	{
	  if (list->next == ENDOBS)
	    {
	      NSMapRemove(nameless, CHEATGC(o->object));
	    }
	  else
	    {
	      NSMapInsert(nameless, CHEATGC(o->object),
		(void*)(gsaddr)o->next);
	    }
	}
      else
	{
	  while (list->next != o)
	    {
	      list = list->next;
	    }
	  list->next = o->next;
	}
    }
  else
    {
      if (wildcard == o)
	{
	  wildcard = o->next;
	}
      else
	{
	  Observation	*list = wildcard;

	  while (list->next != o)
	    {
	      list = list->next;
	    }
	  list->next = o->next;
	}
    }
  /*
   * Mark this observation as not being in a list.
   */
  o->next = 0;
}

/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: (id)observer
{
  NSHashEnumerator	enumerator;
  NSHashTable	*h;
  Observation	*obs;

  if (observer == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Nil observer passed to removeObserver:"];

  [_lock lock];

  h = (NSHashTable*)NSMapGet(observers, CHEATGC(observer));

  if (h == 0)
    return;

  enumerator = NSEnumerateHashTable(h);
  while ((obs = (Observation*)NSNextHashEnumeratorItem(&enumerator)) != 0)
    {
      (*remImp)(self, remSel, obs);
    }

  NSFreeHashTable(h);
  NSMapRemove(observers, CHEATGC(observer));

  [_lock unlock];
}


/* Remove the notification requests for the given parameters.  As with
   adding an observation request, nil NAME or OBJECT act as wildcards. */

- (void) removeObserver: (id)observer
		   name: (NSString*)name
                 object: (id)object
{
  GSIArray	a;

  /*
   * If both NAME and OBJECT are nil, this call is the same as 
   * -removeObserver:, so just call it.
   */
  if (name == nil && object == nil)
    {
      [self removeObserver: observer];
      return;
    }

  /* We are now guaranteed that at least one of NAME and OBJECT is non-nil. */

  [_lock lock];

  a = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIArray_t));
  GSIArrayInitWithZoneAndCapacity(a, NSDefaultMallocZone(), 128);

  if (name)
    {
      NSMapTable	*m;
      GSIMapNode	n;

      /*
       * Locate items with specified name (if any).
       */
      n = GSIMapNodeForKey((GSIMapTable)named, (GSIMapKey)name);
      if (n)
	m = (NSMapTable*)n->value.ptr;
      else
	m = 0;
      if (m != 0)
	{
	  if (object == nil)
	    {
	      Observation	*list;
	      NSMapEnumerator	e;
	      id		o;

	      /*
	       * Make a list of items for ALL objects.
	       */
	      e = NSEnumerateMapTable(m);
	      while (NSNextMapEnumeratorPair(&e, (void**)&o, (void**)&list))
		{
		  while (list != ENDOBS)
		    {
		      if (observer == nil || observer == list->observer)
			{
			  GSIArrayAddItem(a, (GSIArrayItem)list);
			}
		      list = list->next;
		    }
		}
	    }
	  else
	    {
	      Observation	*list;

	      /*
	       * Make a list of items matching specific object.
	       */
	      list = (Observation*)NSMapGet(m, CHEATGC(object));
	      if (list != 0)
		{
		  while (list != ENDOBS)
		    {
		      if (observer == nil || observer == list->observer)
			{
			  GSIArrayAddItem(a, (GSIArrayItem)list);
			}
		      list = list->next;
		    }
		}
	    }
	}
    }
  else
    {
      Observation	*list;
      NSMapTable	*m;
      GSIMapNode	n;

      /*
       * Make a list of items matching specific object with NO names
       */
      list = (Observation*)NSMapGet(nameless, CHEATGC(object));
      if (list != 0)
	{
	  while (list != ENDOBS)
	    {
	      if (observer == nil || observer == list->observer)
		{
		  GSIArrayAddItem(a, (GSIArrayItem)list);
		}
	      list = list->next;
	    }
	}

      /*
       * Add items for ALL names.
       */
      n = ((GSIMapTable)named)->firstNode;
      while (n != 0)
	{
	  m = (NSMapTable*)n->value.ptr;
	  n = n->nextInMap;
	  list = (Observation*)NSMapGet(m, CHEATGC(object));
	  if (list != 0)
	    {
	      while (list != ENDOBS)
		{
		  if (observer == nil || observer == list->observer)
		    {
		      GSIArrayAddItem(a, (GSIArrayItem)list);
		    }
		  list = list->next;
		}
	    }
	}
    }

  if (GSIArrayCount(a) > 0)
    {
      id		lastObs = nil;
      NSHashTable	*h = 0;
      unsigned		count = GSIArrayCount(a);
      unsigned		i;
      Observation	*o;

      for (i = 0; i < count; i++)
	{
	  o = GSIArrayItemAtIndex(a, i).ext;
	  (*remImp)(self, remSel, o);
	  if (h == 0 || lastObs != o->observer)
	    {
	      h = (NSHashTable*)NSMapGet(observers, CHEATGC(o->observer));
	      lastObs = o->observer;
	    }
	  NSHashRemove(h, (void*)o);
	  if (NSCountHashTable(h) == 0)
	    {
	      NSMapRemove(observers, CHEATGC(lastObs));
	    }
	}
    }

  GSIArrayEmpty(a);
  NSZoneFree(a->zone, (void*)a);

  [_lock unlock];
}


/*
 * Post NOTIFICATION to all the observers that match its NAME and OBJECT.
 *
 * For performance reasons, we don't wrap an exception handler round every
 * message sent to an observer.  This means that, if one observer raises
 * an exception, later observers in the lists will not get the notification.
 */
- (void) postNotification: (NSNotification*)notification
{
  NSString	*n_name;
  id		n_object;
  Observation	*o;
  GSIArray	a;
  unsigned	count;
  unsigned	i;

  if (notification == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Tried to post a nil notification."];

  n_name = [notification name];
  n_object = [notification object];

  if (n_name == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Tried to post a notification with no name."];

  [_lock lock];

  a = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIArray_t));
  GSIArrayInitWithZoneAndCapacity(a, NSDefaultMallocZone(), 16);

  NS_DURING
    {
      /*
       * Post the notification to all the observers that specified neither
       * NAME nor OBJECT.
       */
      for (o = wildcard; o != ENDOBS; o = o->next)
	{
	  GSIArrayAddItem(a, (GSIArrayItem)o);
	}
      count = GSIArrayCount(a);
      while (count-- > 0)
	{
	  o = GSIArrayItemAtIndex(a, count).ext;
	  if (o->next != 0) 
	    (*o->method)(o->observer, o->selector, notification);
	  GSIArrayRemoveItemAtIndex(a, count);
	}

      /*
       * Post the notification to all the observers that specified OBJECT,
       * but didn't specify NAME.
       */
      if (n_object)
	{
	  o = (Observation*)NSMapGet(nameless, CHEATGC(n_object));
	  if (o != 0)
	    {
	      while (o != ENDOBS)
		{
		  GSIArrayAddItem(a, (GSIArrayItem)o);
		  o = o->next;
		}
	      count = GSIArrayCount(a);
	      while (count-- > 0)
		{
		  o = GSIArrayItemAtIndex(a, count).ext;
		  if (o->next != 0) 
		    (*o->method)(o->observer, o->selector, notification);
		  GSIArrayRemoveItemAtIndex(a, count);
		}
	    }
	}

      /*
       * Post the notification to all the observers of NAME, except those
       * observers with a non-nill OBJECT that doesn't match the
       * notification's OBJECT).
       */
      if (n_name)
	{
	  NSMapTable	*m;
	  GSIMapNode	n;

	  n = GSIMapNodeForKey((GSIMapTable)named, (GSIMapKey)n_name);
	  if (n)
	    m = (NSMapTable*)n->value.ptr;
	  else
	    m = 0;
	  if (m != 0)
	    {
	      /*
	       * First, observers with a matching object.
	       */
	      o = (Observation*)NSMapGet(m, CHEATGC(n_object));
	      if (o != 0)
		{
		  while (o != ENDOBS)
		    {
		      GSIArrayAddItem(a, (GSIArrayItem)o);
		      o = o->next;
		    }
		  count = GSIArrayCount(a);
		  while (count-- > 0)
		    {
		      o = GSIArrayItemAtIndex(a, count).ext;
		      if (o->next != 0)
			(*o->method)(o->observer, o->selector, notification);
		      GSIArrayRemoveItemAtIndex(a, count);
		    }
		}

	      if (n_object != nil)
		{
		  /*
		   * Now observers with a nil object.
		   */
		  o = (Observation*)NSMapGet(m, CHEATGC(0));
		  if (o != 0)
		    {
		      while (o != ENDOBS)
			{
			  GSIArrayAddItem(a, (GSIArrayItem)o);
			  o = o->next;
			}
		      count = GSIArrayCount(a);
		      while (count-- > 0)
			{
			  o = GSIArrayItemAtIndex(a, count).ext;
			  if (o->next != 0)
			    (*o->method)(o->observer, o->selector,
			      notification);
			  GSIArrayRemoveItemAtIndex(a, count);
			}
		    }
		}
	    }
	}
    }
  NS_HANDLER
    {
      /*
       *    If we had a problem - release memory and unlock before going on.
       */
      GSIArrayEmpty(a);
      NSZoneFree(a->zone, (void*)a);
      [_lock unlock];

      [localException raise];
    }
  NS_ENDHANDLER

  GSIArrayEmpty(a);
  NSZoneFree(a->zone, (void*)a);
  [_lock unlock];
}

- (void) postNotificationName: (NSString*)name 
		       object: (id)object
{
  [self postNotification: [NSNotification notificationWithName: name
							object: object]];
}

- (void) postNotificationName: (NSString*)name 
		       object: (id)object
		     userInfo: (NSDictionary*)info
{
  [self postNotification: [NSNotification notificationWithName: name
							object: object
						      userInfo: info]];
}

@end

