/** Implementation of NSNotificationCenter for GNUstep
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSNotificationCenter class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>

typedef struct {
  @defs(NSNotification)
} NotificationStruct;

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

struct	NCTbl;		/* Notification Center Table structure	*/

/*
 * Observation structure - One of these objects is created for
 * each -addObserver... request.  It holds the requested selector,
 * name and object.  Each struct is placed in one LinkedList,
 * as keyed by the NAME/OBJECT parameters.
 */

typedef	struct	Obs {
  id		observer;	/* Object to receive message.	*/
  SEL		selector;	/* Method selector.		*/
  IMP		method;		/* Method implementation.	*/
  struct Obs	*next;		/* Next item in linked list.	*/
  int		retained;	/* Retain count for structure.	*/
  struct NCTbl	*link;		/* Pointer back to chunk table	*/
} Observation;

#define	ENDOBS	((Observation*)-1)

static inline unsigned doHash(NSString* key)
{
  if (key == nil)
    {
      return 0;
    }
  else if (((gsaddr)key) & 1)
    {
      return (unsigned)(gsaddr)key;
    }
  else
    {
      return [key hash];
    }
}

static inline BOOL doEqual(NSString* key1, NSString* key2)
{
  if (key1 == key2)
    {
      return YES;
    }
  else if ((((gsaddr)key1) & 1) || key1 == nil)
    {
      return NO;
    }
  else
    {
      return [key1 isEqualToString: key2];
    }
}

/*
 * Setup for inline operation on arrays of Observers.
 */
static void listFree(Observation *list);
static void obsRetain(Observation *o);
static void obsFree(Observation *o);

#define GSI_ARRAY_TYPES       0
#define GSI_ARRAY_EXTRA       Observation*

#define GSI_ARRAY_RELEASE(X)   obsFree(X.ext)
#define GSI_ARRAY_RETAIN(X)    obsRetain(X.ext)

#include <base/GSIArray.h>

#ifdef	GSI_NEW
#define GSI_MAP_RETAIN_KEY(M, X)  
#define GSI_MAP_RELEASE_KEY(M, X) ({if ((((gsaddr)X.obj) & 1) == 0) \
  RELEASE(X.obj);})
#define GSI_MAP_HASH(M, X)        doHash(X.obj)
#define GSI_MAP_EQUAL(M, X,Y)     doEqual(X.obj, Y.obj)
#define GSI_MAP_RETAIN_VAL(M, X)  
#define GSI_MAP_RELEASE_VAL(M, X)
#else
#define GSI_MAP_RETAIN_KEY(X)  
#define GSI_MAP_RELEASE_KEY(X) ({if ((((gsaddr)X.obj) & 1) == 0) \
  RELEASE(X.obj);})
#define GSI_MAP_HASH(X)        doHash(X.obj)
#define GSI_MAP_EQUAL(X,Y)     doEqual(X.obj, Y.obj)
#define GSI_MAP_RETAIN_VAL(X)  
#define GSI_MAP_RELEASE_VAL(X)
#endif

#define GSI_MAP_KTYPES GSUNION_OBJ|GSUNION_INT
#define GSI_MAP_VTYPES GSUNION_PTR
#define GSI_MAP_VEXTRA Observation*
#define	GSI_MAP_EXTRA	void*

#include <base/GSIMap.h>

/*
 * An NC table is used to keep track of memory allocated to store
 * Observation structures. When an Observation is removed from the
 * notification center, it's memory is returned to the free list of
 * the chunk table, rather than being released to the general
 * memory allocation system.  This means that, once a large numbner
 * of observers have been registered, memory usage will never shrink
 * even if the observers are removed.  On the other hand, the process
 * of adding and removing observers is speeded up.
 *
 * As another minor aid to performance, we also maintain a cache of
 * the map tables used to keep mappings of notification objects to
 * lists of Observations.  This lets us avoid the overhead of creating
 * and destroying map tables when we are frequently adding and removing
 * notification observations.
 *
 * Performance is however, not the primary reason for using this
 * structure - it provides a neat way to ensure that observers pointed
 * to by the Observation structures are not seen as being in use by
 * the garbage collection mechanism.
 */
#define	CHUNKSIZE	128
#define	CACHESIZE	16
typedef struct NCTbl {
  Observation		*wildcard;	/* Get ALL messages.		*/
  GSIMapTable		nameless;	/* Get messages for any name.	*/
  GSIMapTable		named;		/* Getting named messages only.	*/
  GSIArray		array;		/* Temp store during posting.	*/
  unsigned		lockCount;	/* Count recursive operations.	*/
  NSRecursiveLock	*_lock;		/* Lock out other threads.	*/
  IMP			lImp;
  IMP			uImp;
  BOOL			lockingDisabled;
  BOOL			immutableInPost;

  Observation	*freeList;
  Observation	**chunks;
  unsigned	numChunks;
  GSIMapTable	cache[CACHESIZE];
  short		chunkIndex;
  short		cacheIndex;
} NCTable;

#define	TABLE		((NCTable*)_table)
#define	WILDCARD	(TABLE->wildcard)
#define	NAMELESS	(TABLE->nameless)
#define	NAMED		(TABLE->named)
#define	ARRAY		(TABLE->array)
#define	LOCKCOUNT	(TABLE->lockCount)

static Observation *obsNew(NCTable* t)
{
  Observation	*obs;

  if (t->freeList == 0)
    {
      Observation	*block;

      if (t->chunkIndex == CHUNKSIZE)
	{
	  unsigned	size;

	  t->numChunks++;
	  size = t->numChunks * sizeof(Observation*);
	  t->chunks = (Observation**)NSZoneRealloc(NSDefaultMallocZone(),
	    t->chunks, size);
	  size = CHUNKSIZE * sizeof(Observation);
#if	GS_WITH_GC
	  t->chunks[t->numChunks - 1]
	    = (Observation*)NSZoneMallocAtomic(NSDefaultMallocZone(), size);
#else
	  t->chunks[t->numChunks - 1]
	    = (Observation*)NSZoneMalloc(NSDefaultMallocZone(), size);
#endif
	  t->chunkIndex = 0;
	}
      block = t->chunks[t->numChunks - 1];
      t->freeList = &block[t->chunkIndex];
      t->chunkIndex++;
      t->freeList->link = 0;
    }
  obs = t->freeList;
  t->freeList = (Observation*)obs->link;
  obs->link = (void*)t;
  return obs;
}

static GSIMapTable	mapNew(NCTable *t)
{
  if (t->cacheIndex > 0)
    return t->cache[--t->cacheIndex];
  else
    {
      GSIMapTable	m;

      m = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIMapTable_t));
      GSIMapInitWithZoneAndCapacity(m, NSDefaultMallocZone(), 2);
      return m;
    }
}

static void	mapFree(NCTable *t, GSIMapTable m)
{
  if (t->cacheIndex < CACHESIZE)
    t->cache[t->cacheIndex++] = m;
  else
    {
      GSIMapEmptyMap(m);
      NSZoneFree(NSDefaultMallocZone(), (void*)m);
    }
}

static void endNCTable(NCTable *t)
{
  unsigned		i;
  GSIMapEnumerator_t	e0;
  GSIMapNode		n0;
  Observation		*l;

  /*
   * free the temporary storage area for observations about to receive msgs.
   */
  GSIArrayEmpty(t->array);
  NSZoneFree(NSDefaultMallocZone(), (void*)t->array);

  /*
   * Free observations without notification names or numbers.
   */
  listFree(t->wildcard);

  /*
   * Free lists of observations without notification names.
   */
  e0 = GSIMapEnumeratorForMap(t->nameless);
  n0 = GSIMapEnumeratorNextNode(&e0);
  while (n0 != 0)
    {
      l = (Observation*)n0->value.ptr;
      n0 = GSIMapEnumeratorNextNode(&e0);
      listFree(l);
    }
  GSIMapEmptyMap(t->nameless);
  NSZoneFree(NSDefaultMallocZone(), (void*)t->nameless);

  /*
   * Free lists of observations keyed by name and observer.
   */
  e0 = GSIMapEnumeratorForMap(t->named);
  n0 = GSIMapEnumeratorNextNode(&e0);
  while (n0 != 0)
    {
      GSIMapTable		m = (GSIMapTable)n0->value.ptr;
      GSIMapEnumerator_t	e1 = GSIMapEnumeratorForMap(m);
      GSIMapNode		n1 = GSIMapEnumeratorNextNode(&e1);

      n0 = GSIMapEnumeratorNextNode(&e0);

      while (n1 != 0)
	{
	  l = (Observation*)n1->value.ptr;
	  n1 = GSIMapEnumeratorNextNode(&e1);
	  listFree(l);
	}
      GSIMapEmptyMap(m);
      NSZoneFree(NSDefaultMallocZone(), (void*)m);
    }
  GSIMapEmptyMap(t->named);
  NSZoneFree(NSDefaultMallocZone(), (void*)t->named);

  for (i = 0; i < t->numChunks; i++)
    {
      NSZoneFree(NSDefaultMallocZone(), t->chunks[i]);
    }
  for (i = 0; i < t->cacheIndex; i++)
    {
      GSIMapEmptyMap(t->cache[i]);
      NSZoneFree(NSDefaultMallocZone(), (void*)t->cache[i]);
    }
  NSZoneFree(NSDefaultMallocZone(), t->chunks);
  NSZoneFree(NSDefaultMallocZone(), t);

  TEST_RELEASE(t->_lock);
}

static NCTable *newNCTable()
{
  NCTable	*t;

  t = (NCTable*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(NCTable));
  memset((void*)t, '\0', sizeof(NCTable));
  t->chunkIndex = CHUNKSIZE;
  t->wildcard = ENDOBS;

  t->nameless = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(t->nameless, NSDefaultMallocZone(), 16);

  t->named = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(t->named, NSDefaultMallocZone(), 128);

  t->array = NSZoneMalloc(NSDefaultMallocZone(), sizeof(GSIArray_t));
  GSIArrayInitWithZoneAndCapacity(t->array, NSDefaultMallocZone(), 16);

  return t;
}

static inline void lockNCTable(NCTable* t)
{
  if (t->_lock != nil && t->lockingDisabled == NO)
    (*t->lImp)(t->_lock, @selector(lock));
  t->lockCount++;
}

static inline void unlockNCTable(NCTable* t)
{
  t->lockCount--;
  if (t->_lock != nil && t->lockingDisabled == NO)
    (*t->uImp)(t->_lock, @selector(unlock));
}

static void obsFree(Observation *o)
{
  NSCAssert(o->retained >= 0, NSInternalInconsistencyException);
  if (o->retained-- == 0)
    {
      NCTable	*t = o->link;

      o->link = (NCTable*)t->freeList;
      t->freeList = o;
    }
}

static void listFree(Observation *list)
{
  while (list != ENDOBS)
    {
      Observation	*o = list;

      list = o->next;
      o->next = 0;
      obsFree(o);
    }
}

/*
 *	NB. We need to explicitly set the 'next' field of any observation
 *	we remove to be zero so that, if it currently exists in an array
 *	of observations being posted, the posting code can notice that it
 *	has been removed from its linked list.
 */
static Observation *listPurge(Observation *list, id observer)
{
  Observation	*tmp;

  while (list != ENDOBS && list->observer == observer)
    {
      tmp = list->next;
      list->next = 0;
      obsFree(list);
      list = tmp;
    }
  if (list != ENDOBS)
    {
      tmp = list;
      while (tmp->next != ENDOBS)
	{
	  if (tmp->next->observer == observer)
	    {
	      Observation	*next = tmp->next;

	      tmp->next = next->next;
	      next->next = 0;
	      obsFree(next);
	    }
	  else
	    {
	      tmp = tmp->next;
	    }
	}
    }
  return list;
}

static void obsRetain(Observation *o)
{
  o->retained++;
}

/*
 * Utility function to remove all the observations from a particular
 * map table node that match the specified observer.  If the observer
 * is nil, then all observations are removed.
 * If the list of observations in the map node is emptied, the node is
 * removed from the map.
 */
static inline void
purgeMapNode(GSIMapTable map, GSIMapNode node, id observer)
{
  Observation	*list = node->value.ext;

  if (observer == 0)
    {
      listFree(list);
      GSIMapRemoveKey(map, node->key);
    }
  else
    {
      Observation	*start = list;

      list = listPurge(list, observer);
      if (list == ENDOBS)
	{
	  /*
	   * The list is empty so remove from map.
	   */
	  GSIMapRemoveKey(map, node->key);
	}
      else if (list != start)
	{
	  /*
	   * The list is not empty, but we have changed its
	   * start, so we must place the new head in the map.
	   */
	  node->value.ext = list;
	}
    }
}

/*
 * In order to hide pointers from garbage collection, we OR in an
 * extra bit.  This should be ok for the objects we deal with
 * which are all aligned on 4 or 8 byte boundaries on all the machines
 * I know of.
 *
 * We also use this trick to differentiate between map table keys that
 * should be treated as objects (notification names) and thise that
 * should be treated as pointers (notification objects)
 */
#define	CHEATGC(X)	(id)(((gsaddr)X) | 1)



@implementation NSNotificationCenter

/* The default instance, most often the only one created.
   It is accessed by the class methods at the end of this file.
   There is no need to mutex locking of this variable. */

static NSNotificationCenter *default_center = nil;

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
    }
}

+ (NSNotificationCenter*) defaultCenter
{
  return default_center;
}


/* Initializing. */

- (void) _becomeThreaded: (NSNotification*)notification
{
  unsigned	count;

  TABLE->_lock = [NSRecursiveLock new];
  TABLE->lImp = [TABLE->_lock methodForSelector: @selector(lock)];
  TABLE->uImp = [TABLE->_lock methodForSelector: @selector(unlock)];
  count = LOCKCOUNT;
  /*
   * If we start locking inside a method that would normally have been
   * locked, we must lock the lock enough times so that when we leave
   * the method the number of unlocks will match.
   */
  while (count-- > 0)
    {
      (*TABLE->lImp)(TABLE->_lock, @selector(lock));
    }
}

- (id) init
{
  [super init];
  TABLE = newNCTable();
  if ([NSThread isMultiThreaded])
    {
      [self _becomeThreaded: nil];
    }
  else
    {
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	   selector: @selector(_becomeThreaded:)
	       name: NSWillBecomeMultiThreadedNotification
	     object: nil];
    }

  return self;
}

- (void) dealloc
{
  [self gcFinalize];

  [super dealloc];
}

- (void) gcFinalize
{
  /*
   * Release all memory used to store Observations etc.
   */
  endNCTable(TABLE);
}


/* Adding new observers. */

- (void) addObserver: (id)observer
	    selector: (SEL)selector
                name: (NSString*)name
	      object: (id)object
{
  IMP		method;
  Observation	*list;
  Observation	*o;
  GSIMapTable	m;
  GSIMapNode	n;

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

  method = [observer methodForSelector: selector];
  if (method == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"Observer can not handle specified selector"];

  lockNCTable(TABLE);

  if (TABLE->immutableInPost == YES && LOCKCOUNT > 1)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to add to immutable center."];
    }

  o = obsNew(TABLE);
  o->selector = selector;
  o->method = method;
  o->observer = observer;
  o->retained = 0;
  o->next = 0;

  if (object != nil)
    object = CHEATGC(object);

  /*
   * Record the Observation in one of the linked lists.
   *
   * NB. It is possible to register an observr for a notification more than
   * once - in which case, the observer will receive multiple messages when
   * the notification is posted... odd, but the MacOS-X docs specify this.
   */

  if (name)
    {
      /*
       * Locate the map table for this name - create it if not present.
       */
      n = GSIMapNodeForKey(NAMED, (GSIMapKey)name);
      if (n == 0)
	{
	  m = mapNew(TABLE);
	  /*
	   * As this is the first observation for the given name, we take a
	   * copy of the name so it cannot be mutated while in the map.
	   */
	  name = [name copyWithZone: NSDefaultMallocZone()];
	  GSIMapAddPair(NAMED, (GSIMapKey)name, (GSIMapVal)(void*)m);
	}
      else
	{
	  m = (GSIMapTable)n->value.ptr;
	}

      /*
       * Add the observation to the list for the correct object.
       */
      n = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
      if (n == 0)
	{
	  o->next = ENDOBS;
	  GSIMapAddPair(m, (GSIMapKey)object, (GSIMapVal)o);
	}
      else
	{
	  list = (Observation*)n->value.ptr;
	  o->next = list->next;
	  list->next = o;
	}
    }
  else if (object)
    {
      n = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)object);
      if (n == 0)
	{
	  o->next = ENDOBS;
	  GSIMapAddPair(NAMELESS, (GSIMapKey)object, (GSIMapVal)o);
	}
      else
	{
	  list = (Observation*)n->value.ptr;
	  o->next = list->next;
	  list->next = o;
	}
    }
  else
    {
      o->next = WILDCARD;
      WILDCARD = o;
    }

  unlockNCTable(TABLE);
}

- (void) removeObserver: (id)observer
		   name: (NSString*)name
                 object: (id)object
{
  if (name == nil && object == nil && observer == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Attempt to remove nil observer/name/object"];

  /*
   *	NB. The removal algorithm depends on an implementation characteristic
   *	of our map tables - while enumerating a table, it is safe to remove
   *	the entry returned by the enumerator.
   */

  lockNCTable(TABLE);

  if (TABLE->immutableInPost == YES && LOCKCOUNT > 1)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to remove from immutable center."];
    }

  if (object != nil)
    {
      object = CHEATGC(object);
    }

  if (name == nil && object == nil)
    {
      WILDCARD = listPurge(WILDCARD, observer);
    }

  if (name == nil)
    {
      GSIMapEnumerator_t	e0;
      GSIMapNode		n0;

      /*
       * First try removing all named items set for this object.
       */
      e0 = GSIMapEnumeratorForMap(NAMED);
      n0 = GSIMapEnumeratorNextNode(&e0);
      while (n0 != 0)
	{
	  GSIMapTable		m = (GSIMapTable)n0->value.ptr;
	  NSString		*thisName = (NSString*)n0->key.obj;

	  n0 = GSIMapEnumeratorNextNode(&e0);
	  if (object == nil)
	    {
	      GSIMapEnumerator_t	e1 = GSIMapEnumeratorForMap(m);
	      GSIMapNode		n1 = GSIMapEnumeratorNextNode(&e1);

	      /*
	       * Nil object and nil name, so we step through all the maps
	       * keyed under the current name and remove all the objects
	       * that match the observer.
	       */
	      while (n1 != 0)
		{
		  GSIMapNode	next = GSIMapEnumeratorNextNode(&e1);

		  purgeMapNode(m, n1, observer);
		  n1 = next;
		}
	    }
	  else
	    {
	      GSIMapNode	n1;

	      /*
	       * Nil name, but non-nil object - we locate the map for the
	       * specified object, and remove all the items that match
	       * the observer.
	       */
	      n1 = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
	      if (n1 != 0)
		{
		  purgeMapNode(m, n1, observer);
		}
	    }
	  /*
	   * If we removed all the observations keyed under this name, we
	   * must remove the map table too.
	   */
	  if (m->nodeCount == 0)
	    {
	      mapFree(TABLE, m);
	      GSIMapRemoveKey(NAMED, (GSIMapKey)thisName);
	    }
	}

      /*
       * Now remove unnamed items
       */
      if (object == nil)
	{
	  e0 = GSIMapEnumeratorForMap(NAMELESS);
	  n0 = GSIMapEnumeratorNextNode(&e0);
	  while (n0 != 0)
	    {
	      GSIMapNode	next = GSIMapEnumeratorNextNode(&e0);

	      purgeMapNode(NAMELESS, n0, observer);
	      n0 = next;
	    }
	}
      else
	{
	  n0 = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)object);
	  if (n0 != 0)
	    {
	      purgeMapNode(NAMELESS, n0, observer);
	    }
	}
    }
  else
    {
      GSIMapTable		m;
      GSIMapEnumerator_t	e0;
      GSIMapNode		n0;

      /*
       * Locate the map table for this name.
       */
      n0 = GSIMapNodeForKey(NAMED, (GSIMapKey)name);
      if (n0 == 0)
	{
	  unlockNCTable(TABLE);
	  return;		/* Nothing to do.	*/
	}
      m = (GSIMapTable)n0->value.ptr;

      if (object == nil)
	{
	  e0 = GSIMapEnumeratorForMap(m);
	  n0 = GSIMapEnumeratorNextNode(&e0);

	  while (n0 != 0)
	    {
	      GSIMapNode	next = GSIMapEnumeratorNextNode(&e0);

	      purgeMapNode(m, n0, observer);
	      n0 = next;
	    }
	}
      else
	{
	  n0 = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
	  if (n0 != 0)
	    {
	      purgeMapNode(m, n0, observer);
	    }
	}
      if (m->nodeCount == 0)
	{
	  mapFree(TABLE, m);
	  GSIMapRemoveKey(NAMED, (GSIMapKey)name);
	}
    }
  unlockNCTable(TABLE);
}

/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: (id)observer
{
  if (observer == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Nil observer passed to removeObserver:"];

  [self removeObserver: observer name: nil object: nil];
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
  unsigned	count;
  volatile GSIArray	a;
  unsigned	arrayBase;

  if (notification == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Tried to post a nil notification."];

  n_name = ((NotificationStruct*)notification)->_name;
  n_object = ((NotificationStruct*)notification)->_object;
  if (n_object != nil)
    n_object = CHEATGC(n_object);

  if (n_name == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Tried to post a notification with no name."];

  lockNCTable(TABLE);

  a = ARRAY;
  /*
   * If this is a recursive posting of a notification, the array will already
   * be in use, so we restrict our operation to array indices beyond the end
   * of those used by the posting that caused this one.
   */
  arrayBase = GSIArrayCount(a);

#if 0
  NS_DURING
#endif
    {
      GSIMapNode	n;
      GSIMapTable	m;

      /*
       * If the notification center guarantees that it will be immutable
       * while a notification is being posted, we can simply send the
       * message to each matching Observation.  Otherwise, we put the
       * Observations in a temporary array before starting sending the
       * messages, so any changes to the tables don't mess us up.
       */
      if (TABLE->immutableInPost)
	{
	  /*
	   * Post the notification to all the observers that specified neither
	   * NAME nor OBJECT.
	   */
	  for (o = WILDCARD; o != ENDOBS; o = o->next)
	    {
	      (*o->method)(o->observer, o->selector, notification);
	    }

	  /*
	   * Post the notification to all the observers that specified OBJECT,
	   * but didn't specify NAME.
	   */
	  if (n_object)
	    {
	      n = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)n_object);
	      if (n != 0)
		{
		  o = n->value.ext;
		  while (o != ENDOBS)
		    {
		      (*o->method)(o->observer, o->selector, notification);
		      o = o->next;
		    }
		}
	    }

	  /*
	   * Post the notification to all the observers of NAME, except those
	   * observers with a non-nil OBJECT that doesn't match the
	   * notification's OBJECT).
	   */
	  if (n_name)
	    {
	      n = GSIMapNodeForKey(NAMED, (GSIMapKey)n_name);
	      if (n)
		m = (GSIMapTable)n->value.ptr;
	      else
		m = 0;
	      if (m != 0)
		{
		  /*
		   * First, observers with a matching object.
		   */
		  n = GSIMapNodeForSimpleKey(m, (GSIMapKey)n_object);
		  if (n != 0)
		    {
		      o = n->value.ext;
		      while (o != ENDOBS)
			{
			  (*o->method)(o->observer, o->selector,
			    notification);
			  o = o->next;
			}
		    }

		  if (n_object != nil)
		    {
		      /*
		       * Now observers with a nil object.
		       */
		      n = GSIMapNodeForSimpleKey(m, (GSIMapKey)nil);
		      if (n != 0)
			{
			  o = n->value.ext;
			  while (o != ENDOBS)
			    {
			      (*o->method)(o->observer, o->selector,
				notification);
			      o = o->next;
			    }
			}
		    }
		}
	    }
	}
      else
	{
	  /*
	   * Post the notification to all the observers that specified neither
	   * NAME nor OBJECT.
	   */
	  for (o = WILDCARD; o != ENDOBS; o = o->next)
	    {
	      GSIArrayAddItem(a, (GSIArrayItem)o);
	    }
	  count = GSIArrayCount(a);
	  while (count-- > arrayBase)
	    {
	      o = GSIArrayItemAtIndex(a, count).ext;
	      if (o->next != 0) 
		(*o->method)(o->observer, o->selector, notification);
	    }
	  GSIArrayRemoveItemsFromIndex(a, arrayBase);

	  /*
	   * Post the notification to all the observers that specified OBJECT,
	   * but didn't specify NAME.
	   */
	  if (n_object)
	    {
	      n = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)n_object);
	      if (n != 0)
		{
		  o = n->value.ext;
		  while (o != ENDOBS)
		    {
		      GSIArrayAddItem(a, (GSIArrayItem)o);
		      o = o->next;
		    }
		  count = GSIArrayCount(a);
		  while (count-- > arrayBase)
		    {
		      o = GSIArrayItemAtIndex(a, count).ext;
		      if (o->next != 0) 
			(*o->method)(o->observer, o->selector, notification);
		    }
		  GSIArrayRemoveItemsFromIndex(a, arrayBase);
		}
	    }

	  /*
	   * Post the notification to all the observers of NAME, except those
	   * observers with a non-nil OBJECT that doesn't match the
	   * notification's OBJECT).
	   */
	  if (n_name)
	    {
	      n = GSIMapNodeForKey(NAMED, (GSIMapKey)n_name);
	      if (n)
		m = (GSIMapTable)n->value.ptr;
	      else
		m = 0;
	      if (m != 0)
		{
		  /*
		   * First, observers with a matching object.
		   */
		  n = GSIMapNodeForSimpleKey(m, (GSIMapKey)n_object);
		  if (n != 0)
		    {
		      o = n->value.ext;
		      while (o != ENDOBS)
			{
			  GSIArrayAddItem(a, (GSIArrayItem)o);
			  o = o->next;
			}
		    }

		  if (n_object != nil)
		    {
		      /*
		       * Now observers with a nil object.
		       */
		      n = GSIMapNodeForSimpleKey(m, (GSIMapKey)nil);
		      if (n != 0)
			{
			  o = n->value.ext;
			  while (o != ENDOBS)
			    {
			      GSIArrayAddItem(a, (GSIArrayItem)o);
			      o = o->next;
			    }
			}
		    }

		  count = GSIArrayCount(a);
		  while (count-- > arrayBase)
		    {
		      o = GSIArrayItemAtIndex(a, count).ext;
		      if (o->next != 0)
			(*o->method)(o->observer, o->selector,
			  notification);
		    }
		  GSIArrayRemoveItemsFromIndex(a, arrayBase);
		}
	    }
	}
    }
#if 0
  NS_HANDLER
    {
      /*
       *    If we had a problem - release memory and unlock before going on.
       */
      GSIArrayRemoveItemsFromIndex(ARRAY, arrayBase);
      unlockNCTable(TABLE);

      [localException raise];
    }
  NS_ENDHANDLER
#endif

  unlockNCTable(TABLE);
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

@implementation	NSNotificationCenter (GNUstep)

- (BOOL) setImmutableInPost: (BOOL)flag
{
  BOOL	old;

  lockNCTable(TABLE);

  if (self == default_center)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		  format: @"Can't change behavior of default center."];
    }
  if (LOCKCOUNT > 1)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		format: @"Can't change behavior during post."];
    }

  old = TABLE->immutableInPost;
  TABLE->immutableInPost = flag;
  unlockNCTable(TABLE);
  
  return old;
}

- (BOOL) setLockingDisabled: (BOOL)flag
{
  BOOL	old;

  lockNCTable(TABLE);
  if (self == default_center)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		  format: @"Can't change locking of default center."];
    }
  if (LOCKCOUNT > 1)
    {
      unlockNCTable(TABLE);
      [NSException raise: NSInvalidArgumentException
		  format: @"Can't change locking during post."];
    }

  old = TABLE->lockingDisabled;
  TABLE->lockingDisabled = flag;
  unlockNCTable(TABLE);
  return old;
}

@end

