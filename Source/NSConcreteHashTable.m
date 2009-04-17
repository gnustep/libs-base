/** Implementation of NSHashTable for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: April 2009

   Based on original o_hash code by Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>

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

   $Date: 2008-06-08 11:38:33 +0100 (Sun, 08 Jun 2008) $ $Revision: 26606 $
   */

#include "config.h"

#import "Foundation/NSArray.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSGarbageCollector.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSString.h"
#import "Foundation/NSZone.h"

#import "NSConcretePointerFunctions.h"
#import "NSCallBacks.h"

static Class	concreteClass = 0;

/* Here is the interface for the concrete class as used by the functions.
 */

typedef struct _GSIMapBucket GSIMapBucket_t;
typedef struct _GSIMapNode GSIMapNode_t;
typedef GSIMapBucket_t *GSIMapBucket;
typedef GSIMapNode_t *GSIMapNode;

@interface	NSConcreteHashTable : NSHashTable
{
@public
  NSZone	*zone;
  size_t	nodeCount;	/* Number of used nodes in hash.	*/
  size_t	bucketCount;	/* Number of buckets in hash.	*/
  GSIMapBucket	buckets;	/* Array of buckets.		*/
  GSIMapNode	freeNodes;	/* List of unused nodes.	*/
  GSIMapNode	*nodeChunks;	/* Chunks of allocated memory.	*/
  size_t	chunkCount;	/* Number of chunks in array.	*/
  size_t	increment;	/* Amount to grow by.		*/
  BOOL		legacy;		/* old style callbacks?		*/
  union {
    PFInfo	pf;
    NSHashTableCallBacks old;
  }cb;
}
@end

#define	GSI_MAP_HAS_VALUE	0
#define	GSI_MAP_TABLE_T	NSConcreteHashTable

#define GSI_MAP_HASH(M, X)\
 (M->legacy ? M->cb.old.hash(M, X.ptr) \
 : pointerFunctionsHash(&M->cb.pf, X.ptr))
#define GSI_MAP_EQUAL(M, X, Y)\
 (M->legacy ? M->cb.old.isEqual(M, X.ptr, Y.ptr) \
 : pointerFunctionsEqual(&M->cb.pf, X.ptr, Y.ptr))
#define GSI_MAP_RELEASE_KEY(M, X)\
 (M->legacy ? M->cb.old.release(M, X.ptr) \
 : pointerFunctionsRelinquish(&M->cb.pf, &X.ptr))
#define GSI_MAP_RETAIN_KEY(M, X)\
 (M->legacy ? M->cb.old.retain(M, X.ptr) \
 : pointerFunctionsAcquire(&M->cb.pf, &X.ptr, X.ptr))

#define	GSI_MAP_ENUMERATOR	NSHashEnumerator

#if	GS_WITH_GC
#include	<gc_typed.h>
static GC_descr	nodeS = 0;
static GC_descr	nodeW = 0;
#define	GSI_MAP_NODES(M, X) \
(GSIMapNode)GC_calloc_explicitly_typed(X, sizeof(GSIMapNode_t), (GC_descr)M->zone)
#endif

#include "GNUstepBase/GSIMap.h"

/**** Function Implementations ****/

/**
 * Returns an array of all the objects in the table.
 * NB. The table <em>must</em> contain objects for its keys.
 */
NSArray *
NSAllHashTableObjects(NSHashTable *table)
{
  NSMutableArray	*array;
  NSHashEnumerator	enumerator;
  id			element;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return nil;
    }

  /* Create our mutable key array. */
  array = [NSMutableArray arrayWithCapacity: NSCountHashTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  /* Step through TABLE... */
  while ((element = NSNextHashEnumeratorItem(&enumerator)) != nil)
    {
      [array addObject: element];
    }
  NSEndHashTableEnumeration(&enumerator);
  return array;
}

/**
 * Compares the two hash tables for equality.
 * If the tables are different sizes, returns NO.
 * Otherwise, compares the values in the two tables
 * and returns NO if they differ.<br />
 * The GNUstep implementation enumerates the values in table1
 * and uses the hash and isEqual functions of table2 for comparison.
 */
BOOL
NSCompareHashTables(NSHashTable *table1, NSHashTable *table2)
{
  if (table1 == table2)
    {
      return YES;
    }
  if (table1 == nil)
    {
      NSWarnFLog(@"Nul first argument supplied");
      return NO;
    }
  if (table2 == nil)
    {
      NSWarnFLog(@"Nul second argument supplied");
      return NO;
    }
  if ([table1 count] != [table2 count])
    {
      return NO;
    }
  if (GSObjCClass(table1) != concreteClass
    && GSObjCClass(table2) == concreteClass)
    {
      id	t = table1;

      table1 = table2;
      table2 = t;
    }
  if (GSObjCClass(table1) == concreteClass)
    {
      BOOL		result = YES;
      NSHashEnumerator	enumerator;
      GSIMapNode	n1;

      enumerator = NSEnumerateHashTable(table1);
      if (GSObjCClass(table2) == concreteClass)
	{
          GSIMapTable	t2 = (GSIMapTable)table2;

	  while ((n1 = GSIMapEnumeratorNextNode(&enumerator)) != 0)
	    {
	      if (GSIMapNodeForKey(t2, n1->key) == 0)
		{
		  result = NO;
		  break;
		}
	    }
	}
      else
	{
	  while ((n1 = GSIMapEnumeratorNextNode(&enumerator)) != 0)
	    {
	      void	*v1 = n1->key.ptr;
	      void	*v2;

	      v2 = NSHashGet(table2, v1);
	      if (v2 == 0 && v2 != v1)
		{
		  result = NO;
		  break;
		}
	    }
	}
      NSEndHashTableEnumeration(&enumerator);
      return result;
    }
  else
    {
      BOOL		result = YES;
      NSHashEnumerator	enumerator;
      void		*v1;

      enumerator = NSEnumerateHashTable(table1);
      while ((v1 = NSNextHashEnumeratorItem(&enumerator)) != 0)
	{
	  void	*v2;

	  v2 = NSHashGet(table2, v1);
	  if (v2 == 0 && v2 != v1)
	    {
	      result = NO;
	      break;
	    }
	}
      NSEndHashTableEnumeration(&enumerator);
      return result;
    }
}

/**
 * Copy the supplied hash table.<br />
 * Returns a hash table, space for which is allocated in zone, which
 * has (newly retained) copies of table's contents.  As always,
 * if zone is 0, then NSDefaultMallocZone() is used.
 */
NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone)
{
  GSIMapTable	o = (GSIMapTable)table;
  GSIMapTable	t;
  GSIMapNode	n;
  NSHashEnumerator enumerator;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  t = (GSIMapTable)[concreteClass allocWithZone: zone];
  t->legacy = o->legacy;
  if (t->legacy == YES)
    {
      t->cb.old = o->cb.old;
    }
  else
    {
      t->cb.pf = o->cb.pf;
    }
#if	GS_WITH_GC
  zone = ((GSIMapTable)table)->zone;
#endif
  GSIMapInitWithZoneAndCapacity(t, zone, ((GSIMapTable)table)->nodeCount);

  enumerator = GSIMapEnumeratorForMap((GSIMapTable)table);
  while ((n = GSIMapEnumeratorNextNode(&enumerator)) != 0)
    {
      GSIMapAddKey(t, n->key);
    }
  GSIMapEndEnumerator((GSIMapEnumerator)&enumerator);

  return (NSHashTable*)t;
}

/**
 * Returns the number of items in the table.
 */
unsigned int
NSCountHashTable(NSHashTable *table)
{
  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  return ((GSIMapTable)table)->nodeCount;
}

/**
 * Create a new hash table by calling NSCreateHashTableWithZone() using
 * NSDefaultMallocZone().<br />
 * Returns a (pointer to) an NSHashTable space for which is allocated
 * in the default zone.  If capacity is small or 0, then the returned
 * table has a reasonable capacity.
 */
NSHashTable *
NSCreateHashTable(
  NSHashTableCallBacks callBacks,
  unsigned int capacity)
{
  return NSCreateHashTableWithZone(callBacks, capacity, NSDefaultMallocZone());
}

/**
 * Create a new hash table using the supplied callbacks structures.
 * If any functions in the callback structures are null the default
 * values are used ... as for non-owned pointers.<br />
 * Of course, if you send 0 for zone, then the hash table will be
 * created in NSDefaultMallocZone().<br />
 * The table will be created with the specified capacity ... ie ready
 * to hold at least that many items.
 */
NSHashTable *
NSCreateHashTableWithZone(
  NSHashTableCallBacks k,
  unsigned int capacity,
  NSZone *zone)
{
  GSIMapTable	table;

  if (concreteClass == 0)
    {
      [NSConcreteHashTable class];
    }
  table = (GSIMapTable)[concreteClass allocWithZone: zone];

  if (k.hash == 0)
    k.hash = NSNonOwnedPointerHashCallBacks.hash;
  if (k.isEqual == 0)
    k.isEqual = NSNonOwnedPointerHashCallBacks.isEqual;
  if (k.retain == 0)
    k.retain = NSNonOwnedPointerHashCallBacks.retain;
  if (k.release == 0)
    k.release = NSNonOwnedPointerHashCallBacks.release;
  if (k.describe == 0)
    k.describe = NSNonOwnedPointerHashCallBacks.describe;

  table->legacy = YES;
  table->cb.old = k;

#if	GS_WITH_GC
  GSIMapInitWithZoneAndCapacity(table, (NSZone*)nodeS, capacity);
#else
  GSIMapInitWithZoneAndCapacity(table, zone, capacity);
#endif

  return (NSHashTable*)table;
}

/**
 * Function to be called when finished with the enumerator.
 * This permits memory used by the enumerator to be released!
 */
void
NSEndHashTableEnumeration(NSHashEnumerator *enumerator)
{
  if (enumerator == 0)
    {
      NSWarnFLog(@"Null enumerator argument supplied");
      return;
    }
  GSIMapEndEnumerator((GSIMapEnumerator)enumerator);
}

/**
 * Return an enumerator for stepping through a hash table using the
 * NSNextHashEnumeratorPair() function.
 */
NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table)
{
  if (table == nil)
    {
      NSHashEnumerator	v = {0, 0, 0};

      NSWarnFLog(@"Null table argument supplied");
      return v;
    }
  return GSIMapEnumeratorForMap((GSIMapTable)table);
}

/**
 * Destroy the hash table and release its contents.<br />
 * Releases all the keys and values of table (using the key and
 * value callbacks specified at the time of table's creation),
 * and then proceeds to deallocate the space allocated for table itself.
 */
void
NSFreeHashTable(NSHashTable *table)
{
  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
    }
  else
    {
      [table release];
    }
}

/**
 * Returns the value for the specified item, or a null pointer if the
 * item is not found in the table.
 */
void *
NSHashGet(NSHashTable *table, const void *element)
{
  GSIMapNode	n;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  n = GSIMapNodeForKey((GSIMapTable)table, (GSIMapKey)element);
  if (n == 0)
    {
      return 0;
    }
  else
    {
      return n->key.ptr;
    }
}

/**
 * Adds the element to table.<br />
 * If an equal element is already in table, replaces it with the new one.<br />
 * If element is null raises an NSInvalidArgumentException.
 */
void
NSHashInsert(NSHashTable *table, const void *element)
{
  GSIMapTable   t = (GSIMapTable)table;
  GSIMapNode    n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place value in null hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place null in hash table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)element);
  if (n == 0)
    {
      GSIMapAddKey(t, (GSIMapKey)element);
    }
  else
    {
      GSI_MAP_RELEASE_KEY(t, n->key);
      n->key = (GSIMapKey)element;
      GSI_MAP_RETAIN_KEY(t, n->key);
    }
}

/**
 * Adds the element to table and returns nul.<br />
 * If an equal element is already in table, returns the old element
 * instead of adding the new one.<br />
 * If element is nul, raises an NSInvalidArgumentException.
 */
void *
NSHashInsertIfAbsent(NSHashTable *table, const void *element)
{
  GSIMapTable   t = (GSIMapTable)table;
  GSIMapNode    n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place value in null hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place null in hash table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)element);
  if (n == 0)
    {
      GSIMapAddKey(t, (GSIMapKey)element);
      return 0;
    }
  else
    {
      return n->key.ptr;
    }
}

/**
 * Adds the element to table and returns nul.<br />
 * If an equal element is already present, raises NSInvalidArgumentException.
 * <br />If element is null raises an NSInvalidArgumentException.
 */
void
NSHashInsertKnownAbsent(NSHashTable *table, const void *element)
{
  GSIMapTable   t = (GSIMapTable)table;
  GSIMapNode    n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place value in null hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place null in hash table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)element);
  if (n == 0)
    {
      GSIMapAddKey(t, (GSIMapKey)element);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSHashInsertKnownAbsent ... element not absent"];
    }
}

/**
 * Remove the specified element from the table.
 */
void
NSHashRemove(NSHashTable *table, const void *element)
{
  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
    }
  else
    {
      GSIMapRemoveKey((GSIMapTable)table, (GSIMapKey)element);
    }
}

/**
 * Step through the hash table ... return the next item or
 * return nul if we hit the of the table.
 */
void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator)
{
  GSIMapNode    n;

  if (enumerator == 0)
    {
      NSWarnFLog(@"Nul enumerator argument supplied");
      return 0;
    }
  n = GSIMapEnumeratorNextNode((GSIMapEnumerator)enumerator);
  if (n == 0)
    {
      return 0;
    }
  else
    {
      return n->key.ptr;
    }
}

/**
 * Empty the hash table (releasing all elements), but preserve its capacity.
 */
void
NSResetHashTable(NSHashTable *table)
{
  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
    }
  else
    {
      GSIMapCleanMap((GSIMapTable)table);
    }
}

/**
 * Returns a string describing the table contents.<br />
 * For each item, a string of the form "value;\n"
 * is appended.  The appropriate describe function is used to generate
 * the strings for each item.
 */
NSString *
NSStringFromHashTable(NSHashTable *table)
{
  GSIMapTable		t = (GSIMapTable)table;
  NSMutableString	*string;
  NSHashEnumerator	enumerator;
  const void		*element;

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
      return nil;
    }

  /* This will be our string. */
  string = [NSMutableString stringWithCapacity: 0];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  /* Iterate over the elements of TABLE, appending the description of
   * each to the mutable string STRING. */
  if (t->legacy)
    {
      while ((element = NSNextHashEnumeratorItem(&enumerator)) != nil)
	{
	  [string appendFormat: @"%@;\n",
	    (t->cb.old.describe)(table, element)];
	}
    }
  else
    {
      while ((element = NSNextHashEnumeratorItem(&enumerator)) != nil)
	{
	  [string appendFormat: @"%@;\n",
	    (t->cb.pf.descriptionFunction)(element)];
	}
    }
  NSEndHashTableEnumeration(&enumerator);
  return string;
}




/* These are to increase readabilty locally. */
typedef unsigned int (*NSHT_hash_func_t)(NSHashTable *, const void *);
typedef BOOL (*NSHT_isEqual_func_t)(NSHashTable *, const void *, const void *);
typedef void (*NSHT_retain_func_t)(NSHashTable *, const void *);
typedef void (*NSHT_release_func_t)(NSHashTable *, void *);
typedef NSString *(*NSHT_describe_func_t)(NSHashTable *, const void *);

/** For sets of pointer-sized or smaller quantities. */
const NSHashTableCallBacks NSIntHashCallBacks =
{
  (NSHT_hash_func_t) _NS_int_hash,
  (NSHT_isEqual_func_t) _NS_int_is_equal,
  (NSHT_retain_func_t) _NS_int_retain,
  (NSHT_release_func_t) _NS_int_release,
  (NSHT_describe_func_t) _NS_int_describe
};

/** For sets of pointers hashed by address. */
const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks =
{
  (NSHT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_non_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSHT_release_func_t) _NS_non_owned_void_p_release,
  (NSHT_describe_func_t) _NS_non_owned_void_p_describe
};

/** For sets of objects without retaining and releasing. */
const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks =
{
  (NSHT_hash_func_t) _NS_non_retained_id_hash,
  (NSHT_isEqual_func_t) _NS_non_retained_id_is_equal,
  (NSHT_retain_func_t) _NS_non_retained_id_retain,
  (NSHT_release_func_t) _NS_non_retained_id_release,
  (NSHT_describe_func_t) _NS_non_retained_id_describe
};

/** For sets of objects; similar to [NSSet]. */
const NSHashTableCallBacks NSObjectHashCallBacks =
{
  (NSHT_hash_func_t) _NS_id_hash,
  (NSHT_isEqual_func_t) _NS_id_is_equal,
  (NSHT_retain_func_t) _NS_id_retain,
  (NSHT_release_func_t) _NS_id_release,
  (NSHT_describe_func_t) _NS_id_describe
};

/** For sets of pointers with transfer of ownership upon insertion. */
const NSHashTableCallBacks NSOwnedPointerHashCallBacks =
{
  (NSHT_hash_func_t) _NS_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_owned_void_p_retain,
  (NSHT_release_func_t) _NS_owned_void_p_release,
  (NSHT_describe_func_t) _NS_owned_void_p_describe
};

/** For sets of pointers to structs when the first field of the
 * struct is the size of an int. */
const NSHashTableCallBacks NSPointerToStructHashCallBacks =
{
  (NSHT_hash_func_t) _NS_int_p_hash,
  (NSHT_isEqual_func_t) _NS_int_p_is_equal,
  (NSHT_retain_func_t) _NS_int_p_retain,
  (NSHT_release_func_t) _NS_int_p_release,
  (NSHT_describe_func_t) _NS_int_p_describe
};



@implementation	NSConcreteHashTable

+ (void) initialize
{
  if (concreteClass == nil)
    {
      concreteClass = [NSConcreteHashTable class];
    }
#if	GS_WITH_GC
  /* We create a typed memory descriptor for hash nodes.
   */
  if (nodeS == 0)
    {
      GC_word	w[GC_BITMAP_SIZE(GSIMapNode_t)] = {0};

      nodeW = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
      GC_set_bit(w, GC_WORD_OFFSET(GSIMapNode_t, key));
      nodeS = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
    }
#endif
}

- (void) addObject: (id)anObject
{
  GSIMapTable   t = (GSIMapTable)self;
  GSIMapNode	n;

  n = GSIMapNodeForKey(t, (GSIMapKey)anObject);
  if (n == 0)
    {
      GSIMapAddKey(t, (GSIMapKey)anObject);
    }
  else if (n->key.obj != anObject)
    {
      GSI_MAP_RELEASE_KEY(t, n->key);
      n->key = (GSIMapKey)anObject;
      GSI_MAP_RETAIN_KEY(t, n->key);
    }
}

- (id) copyWithZone: (NSZone*)aZone
{
  return NSCopyHashTableWithZone(self, aZone);
}

- (NSUInteger) count
{
  return (NSUInteger)nodeCount;
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (NSUInteger)len
{
  return (NSUInteger)[self subclassResponsibility: _cmd];
}

- (void) dealloc
{
  GSIMapEmptyMap(self);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (void) finalize
{
  GSIMapEmptyMap(self);
}

- (NSUInteger) hash
{
  return (NSUInteger)nodeCount;
}

- (id) init
{
  return [self initWithPointerFunctions: nil capacity: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  return [self subclassResponsibility: _cmd];
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
		       capacity: (NSUInteger)initialCapacity
{
  legacy = NO;
  if (![functions isKindOfClass: [NSConcretePointerFunctions class]])
    {
      static NSConcretePointerFunctions	*defaultFunctions = nil;

      if (defaultFunctions == nil)
	{
          defaultFunctions
	    = [[NSConcretePointerFunctions alloc] initWithOptions: 0];
	}
      functions = defaultFunctions;
    }
  memcpy(&self->cb.pf, &((NSConcretePointerFunctions*)functions)->_x,
    sizeof(self->cb.pf));

#if	GC_WITH_GC
  if (self->cb.pf.usesWeakReadAndWriteBarriers)
    {
      zone = (NSZone*)nodeW;
    }
  else
    {
      zone = (NSZone*)nodeS;
    }
#endif
  GSIMapInitWithZoneAndCapacity(self, zone, initialCapacity);
  return self;
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility: _cmd];
}

- (id) member: (id)aKey
{
  if (aKey != nil)
    {
      GSIMapNode	node  = GSIMapNodeForKey(self, (GSIMapKey)aKey);

      if (node)
	{
	  return node->key.obj;
	}
    }
  return nil;
}

- (NSPointerFunctions*) pointerFunctions
{
  NSConcretePointerFunctions	*p = [NSConcretePointerFunctions new];

  p->_x = self->cb.pf;
  return [p autorelease];
}

- (void) removeAllObjects
{
  GSIMapEmptyMap(self);
}

- (NSSet*) setRepresentation
{
  return [self subclassResponsibility: _cmd];
}

@end

