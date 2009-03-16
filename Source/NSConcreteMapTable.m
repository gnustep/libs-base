/** Implementation of NSMapTable for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: Feb 2009

   Based on original o_map code by Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>

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
#import "Foundation/NSMapTable.h"
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

@interface	NSConcreteMapTable : NSMapTable
{
@public
  NSZone	*zone;
  size_t	nodeCount;	/* Number of used nodes in map.	*/
  size_t	bucketCount;	/* Number of buckets in map.	*/
  GSIMapBucket	buckets;	/* Array of buckets.		*/
  GSIMapNode	freeNodes;	/* List of unused nodes.	*/
  GSIMapNode	*nodeChunks;	/* Chunks of allocated memory.	*/
  size_t	chunkCount;	/* Number of chunks in array.	*/
  size_t	increment;	/* Amount to grow by.		*/
  BOOL		legacy;		/* old style callbacks?		*/
  union {
    struct {
      PFInfo	k;
      PFInfo	v;
    } pf;
    struct {
      NSMapTableKeyCallBacks k;
      NSMapTableValueCallBacks v;
    } old;
  };
}
@end

#define	GSI_MAP_TABLE_T	NSConcreteMapTable

#define GSI_MAP_HASH(M, X)\
 (M->legacy ? M->old.k.hash(M, X.ptr) \
 : pointerFunctionsHash(&M->pf.k, X.ptr))
#define GSI_MAP_EQUAL(M, X, Y)\
 (M->legacy ? M->old.k.isEqual(M, X.ptr, Y.ptr) \
 : pointerFunctionsEqual(&M->pf.k, X.ptr, Y.ptr))
#define GSI_MAP_RELEASE_KEY(M, X)\
 (M->legacy ? M->old.k.release(M, X.ptr) \
 : pointerFunctionsRelinquish(&M->pf.k, &X.ptr))
#define GSI_MAP_RETAIN_KEY(M, X)\
 (M->legacy ? M->old.k.retain(M, X.ptr) \
 : pointerFunctionsAcquire(&M->pf.k, &X.ptr, X.ptr))
#define GSI_MAP_RELEASE_VAL(M, X)\
 (M->legacy ? M->old.v.release(M, X.ptr) \
 : pointerFunctionsRelinquish(&M->pf.v, &X.ptr))
#define GSI_MAP_RETAIN_VAL(M, X)\
 (M->legacy ? M->old.v.retain(M, X.ptr) \
 : pointerFunctionsAcquire(&M->pf.v, &X.ptr, X.ptr))

#define	GSI_MAP_ENUMERATOR	NSMapEnumerator

#if	GS_WITH_GC
#include	<gc_typed.h>
static GC_descr	nodeSS = 0;
static GC_descr	nodeSW = 0;
static GC_descr	nodeWS = 0;
static GC_descr	nodeWW = 0;
#define	GSI_MAP_NODES(M, X) \
(GSIMapNode)GC_calloc_explicitly_typed(X, sizeof(GSIMapNode_t), (GC_descr)M->zone)
#endif

#include "GNUstepBase/GSIMap.h"

/**** Function Implementations ****/

/**
 * Returns an array of all the keys in the table.
 * NB. The table <em>must</em> contain objects for its keys.
 */
NSArray *
NSAllMapTableKeys(NSMapTable *table)
{
  NSMutableArray	*keyArray;
  NSMapEnumerator	enumerator;
  id			key = nil;
  void			*dummy;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return nil;
    }

  /* Create our mutable key array. */
  keyArray = [NSMutableArray arrayWithCapacity: NSCountMapTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable(table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair(&enumerator, (void **)(&key), &dummy))
    {
      [keyArray addObject: key];
    }
  NSEndMapTableEnumeration(&enumerator);
  return keyArray;
}

/**
 * Returns an array of all the values in the table.
 * NB. The table <em>must</em> contain objects for its values.
 */
NSArray *
NSAllMapTableValues(NSMapTable *table)
{
  NSMapEnumerator	enumerator;
  NSMutableArray	*valueArray;
  id			value = nil;
  void			*dummy;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return nil;
    }

  /* Create our mutable value array. */
  valueArray = [NSMutableArray arrayWithCapacity: NSCountMapTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateMapTable(table);

  /* Step through TABLE... */
  while (NSNextMapEnumeratorPair(&enumerator, &dummy, (void **)(&value)))
    {
      [valueArray addObject: value];
    }
  NSEndMapTableEnumeration(&enumerator);
  return valueArray;
}

/**
 * Compares the two map tables for equality.
 * If the tables are different sizes, returns NO.
 * Otherwise, compares the keys <em>(not the values)</em>
 * in the two map tables and returns NO if they differ.<br />
 * The GNUstep implementation enumerates the keys in table1
 * and uses the hash and isEqual functions of table2 for comparison.
 */
BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
  GSIMapTable	t1 = (GSIMapTable)table1;
  GSIMapTable	t2 = (GSIMapTable)table2;

  if (t1 == t2)
    {
      return YES;
    }
  if (t1 == nil)
    {
      NSWarnFLog(@"Null first argument supplied");
      return NO;
    }
  if (t2 == nil)
    {
      NSWarnFLog(@"Null second argument supplied");
      return NO;
    }

  if (t1->nodeCount != t2->nodeCount)
    {
      return NO;
    }
  else
    {
      NSMapEnumerator enumerator = GSIMapEnumeratorForMap((GSIMapTable)t1);
      GSIMapNode n;

      while ((n = GSIMapEnumeratorNextNode(&enumerator)) != 0)
        {
          if (GSIMapNodeForKey(t2, n->key) == 0)
            {
	      GSIMapEndEnumerator((GSIMapEnumerator)&enumerator);
              return NO;
            }
        }
      GSIMapEndEnumerator((GSIMapEnumerator)&enumerator);
      return YES;
    }
}

/**
 * Copy the supplied map table.<br />
 * Returns a map table, space for which is allocated in zone, which
 * has (newly retained) copies of table's keys and values.  As always,
 * if zone is 0, then NSDefaultMallocZone() is used.
 */
NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
  GSIMapTable	o = (GSIMapTable)table;
  GSIMapTable	t;
  GSIMapNode	n;
  NSMapEnumerator enumerator;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  t = (GSIMapTable)[concreteClass allocWithZone: zone];
  t->legacy = o->legacy;
  if (t->legacy == YES)
    {
      t->old.k = o->old.k;
      t->old.v = o->old.v;
    }
  else
    {
      t->pf.k = o->pf.k;
      t->pf.v = o->pf.v;
    }
#if	GS_WITH_GC
  zone = ((GSIMapTable)table)->zone;
#endif
  GSIMapInitWithZoneAndCapacity(t, zone, ((GSIMapTable)table)->nodeCount);

  enumerator = GSIMapEnumeratorForMap((GSIMapTable)table);
  while ((n = GSIMapEnumeratorNextNode(&enumerator)) != 0)
    {
      GSIMapAddPair(t, n->key, n->value);
    }
  GSIMapEndEnumerator((GSIMapEnumerator)&enumerator);

  return (NSMapTable*)t;
}

/**
 * Returns the number of key/value pairs in the table.
 */
unsigned int
NSCountMapTable(NSMapTable *table)
{
  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  return ((GSIMapTable)table)->nodeCount;
}

/**
 * Create a new map table by calling NSCreateMapTableWithZone() using
 * NSDefaultMallocZone().<br />
 * Returns a (pointer to) an NSMapTable space for which is allocated
 * in the default zone.  If capacity is small or 0, then the returned
 * table has a reasonable capacity.
 */
NSMapTable *
NSCreateMapTable(
  NSMapTableKeyCallBacks keyCallBacks,
  NSMapTableValueCallBacks valueCallBacks,
  unsigned int capacity)
{
  return NSCreateMapTableWithZone(keyCallBacks, valueCallBacks,
    capacity, NSDefaultMallocZone());
}

/**
 * Create a new map table using the supplied callbacks structures.
 * If any functions in the callback structures are null the default
 * values are used ... as for non-owned pointers.<br />
 * Of course, if you send 0 for zone, then the map table will be
 * created in NSDefaultMallocZone().<br />
 * The table will be created with the specified capacity ... ie ready
 * to hold at least that many items.
 */
NSMapTable *
NSCreateMapTableWithZone(
  NSMapTableKeyCallBacks k,
  NSMapTableValueCallBacks v,
  unsigned int capacity,
  NSZone *zone)
{
  GSIMapTable	table;

  if (concreteClass == 0)
    {
      [NSConcreteMapTable class];
    }
  table = (GSIMapTable)[concreteClass allocWithZone: zone];

  if (k.hash == 0)
    k.hash = NSNonOwnedPointerMapKeyCallBacks.hash;
  if (k.isEqual == 0)
    k.isEqual = NSNonOwnedPointerMapKeyCallBacks.isEqual;
  if (k.retain == 0)
    k.retain = NSNonOwnedPointerMapKeyCallBacks.retain;
  if (k.release == 0)
    k.release = NSNonOwnedPointerMapKeyCallBacks.release;
  if (k.describe == 0)
    k.describe = NSNonOwnedPointerMapKeyCallBacks.describe;

  if (v.retain == 0)
    v.retain = NSNonOwnedPointerMapValueCallBacks.retain;
  if (v.release == 0)
    v.release = NSNonOwnedPointerMapValueCallBacks.release;
  if (v.describe == 0)
    v.describe = NSNonOwnedPointerMapValueCallBacks.describe;

  table->legacy = YES;
  table->old.k = k;
  table->old.v = v;

#if	GS_WITH_GC
  GSIMapInitWithZoneAndCapacity(table, (NSZone*)nodeSS, capacity);
#else
  GSIMapInitWithZoneAndCapacity(table, zone, capacity);
#endif

  return (NSMapTable*)table;
}

/**
 * Function to be called when finished with the enumerator.
 * This permits memory used by the enumerator to be released!
 */
void
NSEndMapTableEnumeration(NSMapEnumerator *enumerator)
{
  if (enumerator == 0)
    {
      NSWarnFLog(@"Null enumerator argument supplied");
      return;
    }
  GSIMapEndEnumerator((GSIMapEnumerator)enumerator);
}

/**
 * Return an enumerator for stepping through a map table using the
 * NSNextMapEnumeratorPair() function.
 */
NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table)
{
  if (table == nil)
    {
      NSMapEnumerator	v = {0, 0};

      NSWarnFLog(@"Null table argument supplied");
      return v;
    }
  return GSIMapEnumeratorForMap((GSIMapTable)table);
}

/**
 * Destroy the map table and release its contents.<br />
 * Releases all the keys and values of table (using the key and
 * value callbacks specified at the time of table's creation),
 * and then proceeds to deallocate the space allocated for table itself.
 */
void
NSFreeMapTable(NSMapTable *table)
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
 * Returns the value for the specified key, or a null pointer if the
 * key is not found in the table.
 */
void *
NSMapGet(NSMapTable *table, const void *key)
{
  GSIMapNode	n;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return 0;
    }
  n = GSIMapNodeForKey((GSIMapTable)table, (GSIMapKey)key);
  if (n == 0)
    {
      return 0;
    }
  else
    {
      return n->value.ptr;
    }
}

/**
 * Adds the key and value to table.<br />
 * If an equal key is already in table, replaces its mapped value
 * with the new one, without changing the key itself.<br />
 * If key is equal to the notAKeyMarker field of the table's
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in null table"];
    }
  if (key == t->old.k.notAKeyMarker)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place notAKeyMarker in map table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)key);
  if (n == 0)
    {
      GSIMapAddPair(t, (GSIMapKey)key, (GSIMapVal)value);
    }
  else
    {
      GSIMapVal	tmp = n->value;

      n->value = (GSIMapVal)value;
      GSI_MAP_RETAIN_VAL(t, n->value);
      GSI_MAP_RELEASE_VAL(t, tmp);
    }
}

/**
 * Adds the key and value to table and returns nul.<br />
 * If an equal key is already in table, returns the old key
 * instead of adding the new key-value pair.<br />
 * If key is equal to the notAKeyMarker field of the table's
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in null table"];
    }
  if (key == t->old.k.notAKeyMarker)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place notAKeyMarker in map table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)key);
  if (n == 0)
    {
      GSIMapAddPair(t, (GSIMapKey)key, (GSIMapVal)value);
      return 0;
    }
  else
    {
      return n->key.ptr;
    }
}

/**
 * Adds the key and value to table and returns nul.<br />
 * If an equal key is already in table, raises an NSInvalidArgumentException.
 * <br />If key is equal to the notAKeyMarker field of the table's
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in null table"];
    }
  if (key == t->old.k.notAKeyMarker)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place notAKeyMarker in map table"];
    }
  n = GSIMapNodeForKey(t, (GSIMapKey)key);
  if (n == 0)
    {
      GSIMapAddPair(t, (GSIMapKey)key, (GSIMapVal)value);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"NSMapInsertKnownAbsent ... key not absent"];
    }
}

/**
 * Returns a flag to say whether the table contains the specified key.
 * Returns the original key and the value it maps to.<br />
 * The GNUstep implementation checks originalKey and value to see if
 * they are null pointers, and only updates them if non-null.
 */
BOOL
NSMapMember(NSMapTable *table, const void *key,
  void **originalKey, void **value)
{
  GSIMapNode	n;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return NO;
    }
  n = GSIMapNodeForKey((GSIMapTable)table, (GSIMapKey)key);
  if (n == 0)
    {
      return NO;
    }
  else
    {
      if (originalKey != 0)
	{
	  *originalKey = n->key.ptr;
	}
      if (value != 0)
	{
	  *value = n->value.ptr;
	}
      return YES;
    }
}

/**
 * Remove the specified key from the table (if present).<br />
 * Causes the key and its associated value to be released.
 */
void
NSMapRemove(NSMapTable *table, const void *key)
{
  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return;
    }
  GSIMapRemoveKey((GSIMapTable)table, (GSIMapKey)key);
}

/**
 * Step through the map table ... return the next key-value pair and
 * return YES, or hit the end of the table and return NO.<br />
 * The enumerator parameter is a value supplied by NSEnumerateMapTable()
 * and must be destroyed using NSEndMapTableEnumeration().<br />
 * The GNUstep implementation permits either key or value to be a
 * null pointer, and refrains from attempting to return the appropriate
 * result in that case.
 */
BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
			void **key, void **value)
{
  GSIMapNode	n;

  if (enumerator == 0)
    {
      NSWarnFLog(@"Null enumerator argument supplied");
      return NO;
    }
  n = GSIMapEnumeratorNextNode((GSIMapEnumerator)enumerator);
  if (n == 0)
    {
      return NO;
    }
  else
    {
      if (key != 0)
	{
	  *key = n->key.ptr;
	}
      else
	{
	  NSWarnFLog(@"Null key return address");
	}

      if (value != 0)
	{
	  *value = n->value.ptr;
	}
      else
	{
	  NSWarnFLog(@"Null value return address");
	}
      return YES;
    }
}

/**
 * Empty the map table (releasing every key and value),
 * but preserve its capacity.
 */
void
NSResetMapTable(NSMapTable *table)
{
  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
    }
  else
    {
      GSIMapCleanMap((GSIMapTable)table);
    }
}

/**
 * Returns a string describing the table contents.<br />
 * For each key-value pair, a string of the form "key = value;\n"
 * is appended.  The appropriate describe functions are used to generate
 * the strings for each key and value.
 */
NSString *
NSStringFromMapTable(NSMapTable *table)
{
  GSIMapTable		t = (GSIMapTable)table;
  NSMutableString	*string;
  NSMapEnumerator	enumerator;
  void			*key;
  void			*value;

  if (table == nil)
    {
      NSWarnFLog(@"Null table argument supplied");
      return nil;
    }
  string = [NSMutableString stringWithCapacity: 0];
  enumerator = NSEnumerateMapTable(table);

  /*
   * Now, just step through the elements of the table, and add their
   * descriptions to the string.
   */
  if (t->legacy)
    {
      while (NSNextMapEnumeratorPair(&enumerator, &key, &value) == YES)
	{
	  [string appendFormat: @"%@ = %@;\n",
	    (t->old.k.describe)(table, key),
	    (t->old.v.describe)(table, value)];
	}
    }
  else
    {
      while (NSNextMapEnumeratorPair(&enumerator, &key, &value) == YES)
	{
	  [string appendFormat: @"%@ = %@;\n",
	    (t->pf.k.descriptionFunction)(key),
	    (t->pf.v.descriptionFunction)(value)];
	}
    }
  NSEndMapTableEnumeration(&enumerator);
  return string;
}




/* These are to increase readabilty locally. */
typedef unsigned int (*NSMT_hash_func_t)(NSMapTable *, const void *);
typedef BOOL (*NSMT_is_equal_func_t)(NSMapTable *, const void *, const void *);
typedef void (*NSMT_retain_func_t)(NSMapTable *, const void *);
typedef void (*NSMT_release_func_t)(NSMapTable *, void *);
typedef NSString *(*NSMT_describe_func_t)(NSMapTable *, const void *);


/** For keys that are pointer-sized or smaller quantities. */
const NSMapTableKeyCallBacks NSIntMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_int_hash,
  (NSMT_is_equal_func_t) _NS_int_is_equal,
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe,
  NSNotAnIntMapKey
};

/** For keys that are pointers not freed. */
const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  NSNotAPointerMapKey
};

/** For keys that are pointers not freed, or 0. */
const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  NSNotAPointerMapKey
};

/** For sets of objects without retaining and releasing. */
const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_non_retained_id_hash,
  (NSMT_is_equal_func_t) _NS_non_retained_id_is_equal,
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe,
  NSNotAPointerMapKey
};

/** For keys that are objects. */
const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_id_hash,
  (NSMT_is_equal_func_t) _NS_id_is_equal,
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe,
  NSNotAPointerMapKey
};

/** For keys that are pointers with transfer of ownership upon insertion. */
const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks =
{
  (NSMT_hash_func_t) _NS_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe,
  NSNotAPointerMapKey
};

/** For values that are pointer-sized integer quantities. */
const NSMapTableValueCallBacks NSIntMapValueCallBacks =
{
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe
};

/** For values that are pointers not freed. */
const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks =
{
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe
};

/** For sets of objects without retaining and releasing. */
const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks =
{
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe
};

/** For values that are objects. */
const NSMapTableValueCallBacks NSObjectMapValueCallBacks =
{
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe
};

/** For values that are pointers with transfer of ownership upon insertion. */
const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks =
{
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe
};



@implementation	NSConcreteMapTable

+ (void) initialize
{
  if (concreteClass == nil)
    {
      concreteClass = [NSConcreteMapTable class];
    }
#if	GS_WITH_GC
  /* We create a typed memory descriptor for map nodes.
   */
  if (nodeSS == 0)
    {
      GC_word	w[GC_BITMAP_SIZE(GSIMapNode_t)] = {0};

      nodeWW = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
      GC_set_bit(w, GC_WORD_OFFSET(GSIMapNode_t, key));
      nodeSW = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
      GC_set_bit(w, GC_WORD_OFFSET(GSIMapNode_t, value));
      nodeSS = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
      memset(&w[0], '\0', sizeof(w));
      GC_set_bit(w, GC_WORD_OFFSET(GSIMapNode_t, value));
      nodeWS = GC_make_descriptor(w, GC_WORD_LEN(GSIMapNode_t));
    }
#endif
}

- (id) copyWithZone: (NSZone*)aZone
{
  return NSCopyMapTableWithZone(self, aZone);
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

- (NSDictionary*) dictionaryRepresentation
{
  return [self subclassResponsibility: _cmd];
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
  return [self initWithKeyPointerFunctions: nil
		     valuePointerFunctions: nil
				  capacity: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  return [self subclassResponsibility: _cmd];
}

- (id) initWithKeyPointerFunctions: (NSPointerFunctions*)keyFunctions
	     valuePointerFunctions: (NSPointerFunctions*)valueFunctions
			  capacity: (NSUInteger)initialCapacity
{
  if (keyFunctions == nil)
    {
      keyFunctions = [NSPointerFunctions pointerFunctionsWithOptions: 0];
    }
  if (valueFunctions == nil)
    {
      valueFunctions = [NSPointerFunctions pointerFunctionsWithOptions: 0];
    }
  legacy = NO;
  if ([keyFunctions class] == [NSConcretePointerFunctions class])
    {
      memcpy(&self->pf.k, &((NSConcretePointerFunctions*)keyFunctions)->_x,
	sizeof(self->pf.k));
    }
  else
    {
      self->pf.k.acquireFunction = [keyFunctions acquireFunction];
      self->pf.k.descriptionFunction = [keyFunctions descriptionFunction];
      self->pf.k.hashFunction = [keyFunctions hashFunction];
      self->pf.k.isEqualFunction = [keyFunctions isEqualFunction];
      self->pf.k.relinquishFunction = [keyFunctions relinquishFunction];
      self->pf.k.sizeFunction = [keyFunctions sizeFunction];
      self->pf.k.usesStrongWriteBarrier
	= [keyFunctions usesStrongWriteBarrier];
      self->pf.k.usesWeakReadAndWriteBarriers
	= [keyFunctions usesWeakReadAndWriteBarriers];
    }
  if ([valueFunctions class] == [NSConcretePointerFunctions class])
    {
      memcpy(&self->pf.v, &((NSConcretePointerFunctions*)valueFunctions)->_x,
	sizeof(self->pf.v));
    }
  else
    {
      self->pf.v.acquireFunction = [valueFunctions acquireFunction];
      self->pf.v.descriptionFunction = [valueFunctions descriptionFunction];
      self->pf.v.hashFunction = [valueFunctions hashFunction];
      self->pf.v.isEqualFunction = [valueFunctions isEqualFunction];
      self->pf.v.relinquishFunction = [valueFunctions relinquishFunction];
      self->pf.v.sizeFunction = [valueFunctions sizeFunction];
      self->pf.v.usesStrongWriteBarrier
	= [valueFunctions usesStrongWriteBarrier];
      self->pf.v.usesWeakReadAndWriteBarriers
	= [valueFunctions usesWeakReadAndWriteBarriers];
    }

#if	GC_WITH_GC
  if (self->pf.k.usesWeakReadAndWriteBarriers)
    {
      if (self->pf.v.usesWeakReadAndWriteBarriers)
	{
	  zone = (NSZone*)nodeWW;
	}
      else
	{
	  zone = (NSZone*)nodeWS;
	}
    }
  else
    {
      if (self->pf.v.usesWeakReadAndWriteBarriers)
	{
	  zone = (NSZone*)nodeSW;
	}
      else
	{
	  zone = (NSZone*)nodeSS;
	}
    }
#endif
  GSIMapInitWithZoneAndCapacity(self, zone, initialCapacity);
  return self;
}

- (BOOL) isEqual: (id)other
{
  return (BOOL)(uintptr_t)[self subclassResponsibility: _cmd];
}

- (NSEnumerator*) keyEnumerator
{
  return [self subclassResponsibility: _cmd];
}

- (NSPointerFunctions*) keyPointerFunctions
{
  NSConcretePointerFunctions	*p = [NSConcretePointerFunctions new];

  p->_x = self->pf.k;
  return [p autorelease];
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility: _cmd];
}

- (id) objectForKey: (id)aKey
{
  if (aKey != nil)
    {
      GSIMapNode	node  = GSIMapNodeForKey(self, (GSIMapKey)aKey);

      if (node)
	{
	  return node->value.obj;
	}
    }
  return nil;
}

- (void) removeAllObjects
{
  GSIMapEmptyMap(self);
}

- (void) removeObjectForKey: (id)aKey
{
  if (aKey == nil)
    {
      NSWarnMLog(@"attempt to remove nil key from map table %@", self);
      return;
    }
  GSIMapRemoveKey(self, (GSIMapKey)aKey);
}

- (void) setObject: (id)anObject forKey: (id)aKey
{
  GSIMapNode	node;

  if (aKey == nil)
    {
      NSException	*e;

      e = [NSException exceptionWithName: NSInvalidArgumentException
				  reason: @"Tried to add nil key to map table"
				userInfo: nil];
      [e raise];
    }
  node = GSIMapNodeForKey(self, (GSIMapKey)aKey);
  if (node)
    {
      if (node->value.obj != anObject)
	{
          GSI_MAP_RELEASE_VAL(self, node->value);
          node->value.obj = anObject;
          GSI_MAP_RETAIN_VAL(self, node->value);
	}
    }
  else
    {
      GSIMapAddPair(self, (GSIMapKey)aKey, (GSIMapVal)anObject);
    }
}

- (NSPointerFunctions*) valuePointerFunctions
{
  NSConcretePointerFunctions	*p = [NSConcretePointerFunctions new];

  p->_x = self->pf.v;
  return [p autorelease];
}
@end

