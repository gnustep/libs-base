/** NSMapTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996, 2002  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:59:57 EST 1994
 * Updated: Sun Mar 17 18:37:12 EST 1996
 * Serial: 96.03.17.31
 * Rewrite by: Richard Frith-Macdonald <rfm@gnu.org>
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 *
 * <title>NSMapTable class reference</title>
 * $Date$ $Revision$
 */

/**** Included Headers *******************************************************/

#include <config.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDebug.h>
#include "NSCallBacks.h"


typedef struct {
  NSMapTableKeyCallBacks	k;
  NSMapTableValueCallBacks	v;
} extraData;

/*
 *      The 'Fastmap' stuff provides an inline implementation of a mapping
 *      table - for maximum performance.
 */
#define	GSI_MAP_EXTRA		extraData
#define GSI_MAP_KTYPES		GSUNION_PTR
#define GSI_MAP_VTYPES		GSUNION_PTR
#define GSI_MAP_HASH(M, X)\
 (M->extra.k.hash)((NSMapTable*)M, X.ptr)
#define GSI_MAP_EQUAL(M, X, Y)\
 (M->extra.k.isEqual)((NSMapTable*)M, X.ptr, Y.ptr)
#define GSI_MAP_RELEASE_KEY(M, X)\
 (M->extra.k.release)((NSMapTable*)M, X.ptr)
#define GSI_MAP_RETAIN_KEY(M, X)\
 (M->extra.k.retain)((NSMapTable*)M, X.ptr)
#define GSI_MAP_RELEASE_VAL(M, X)\
 (M->extra.v.release)((NSMapTable*)M, X.ptr)
#define GSI_MAP_RETAIN_VAL(M, X)\
 (M->extra.v.retain)((NSMapTable*)M, X.ptr)
#define	GSI_MAP_ENUMERATOR	NSMapEnumerator

#include <base/GSIMap.h>

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

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
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

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
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
  if (t1 == 0)
    {
      NSWarnFLog(@"Nul first argument supplied");
      return NO;
    }
  if (t2 == 0)
    {
      NSWarnFLog(@"Nul second argument supplied");
      return NO;
    }

  if (t1->nodeCount != t2->nodeCount)
    {
      return NO;
    }
  else
    {
      GSIMapNode	n = t1->firstNode;

      while (n != 0)
	{
	  if (GSIMapNodeForKey(t2, n->key) == 0)
	    {
	      return NO;
	    }
	  n = n->nextInMap;
	}
      return YES;
    }
}

/**
 * Copy the supplied map table creating the new table in the specified zone.
 */
NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
  GSIMapTable	t;
  GSIMapNode	n;

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
      return 0;
    }

  t = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(t, zone, ((GSIMapTable)table)->nodeCount);
  t->extra.k = ((GSIMapTable)table)->extra.k;
  t->extra.v = ((GSIMapTable)table)->extra.v;
  n = ((GSIMapTable)table)->firstNode;
  while (n != 0)
    {
      GSIMapAddPair(t, n->key, n->value);
      n = n->nextInMap;
    }

  return (NSMapTable*)t;
}

/**
 * Returns the number of keys in the table.
 */
unsigned int
NSCountMapTable(NSMapTable *table)
{
  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
      return 0;
    }
  return ((GSIMapTable)table)->nodeCount;
}

/**
 * Create a new map table by calling NSCreateMapTableWithZone() using
 * NSDefaultMallocZone().
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
 * values are used ... as for non-owned pointers.
 * The table will be created with the specified capacity ... ie ready
 * to hold at lest that many items.
 */
NSMapTable *
NSCreateMapTableWithZone(
  NSMapTableKeyCallBacks keyCallBacks,
  NSMapTableValueCallBacks valueCallBacks,
  unsigned int capacity,
  NSZone *zone)
{
  GSIMapTable	table;

  table = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(table, zone, capacity);
  table->extra.k = keyCallBacks;
  table->extra.v = valueCallBacks;

  if (table->extra.k.hash == 0)
    table->extra.k.hash = NSNonOwnedPointerMapKeyCallBacks.hash;
  if (table->extra.k.isEqual == 0)
    table->extra.k.isEqual = NSNonOwnedPointerMapKeyCallBacks.isEqual;
  if (table->extra.k.retain == 0)
    table->extra.k.retain = NSNonOwnedPointerMapKeyCallBacks.retain;
  if (table->extra.k.release == 0)
    table->extra.k.release = NSNonOwnedPointerMapKeyCallBacks.release;
  if (table->extra.k.describe == 0)
    table->extra.k.describe = NSNonOwnedPointerMapKeyCallBacks.describe;

  if (table->extra.v.retain == 0)
    table->extra.v.retain = NSNonOwnedPointerMapValueCallBacks.retain;
  if (table->extra.v.release == 0)
    table->extra.v.release = NSNonOwnedPointerMapValueCallBacks.release;
  if (table->extra.v.describe == 0)
    table->extra.v.describe = NSNonOwnedPointerMapValueCallBacks.describe;

  return (NSMapTable*)table;
}

/**
 * Function to be called when finished with the enumerator.
 * Not required in GNUstep ... just provided for MacOS-X compatibility.
 */
void
NSEndMapTableEnumeration(NSMapEnumerator *enumerator)
{
  if (enumerator == 0)
    {
      NSWarnFLog(@"Nul enumerator argument supplied");
    }
}

/**
 * Return an enumerator for stepping through a map table using the
 * NSNextMapEnumeratorPair() function.
 */
NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table)
{
  if (table == 0)
    {
      NSMapEnumerator	v = {0, 0};

      NSWarnFLog(@"Nul table argument supplied");
      return v;
    }
  return GSIMapEnumeratorForMap((GSIMapTable)table);
}

/**
 * Destroy the map table and relase its contents.
 */
void
NSFreeMapTable(NSMapTable *table)
{
  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
    }
  else
    {
      NSZone	*z = ((GSIMapTable)table)->zone;

      GSIMapEmptyMap((GSIMapTable)table);
      NSZoneFree(z, table);
    }
}

/**
 * Returns the value for the specified key, or a nul pointer if the
 * key is not found in the table.
 */
void *
NSMapGet(NSMapTable *table, const void *key)
{
  GSIMapNode	n;

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
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
 * with the new one, without changing the key itsself.<br />
 * If key is equal to the notAKeyMarker field of the tables
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void
NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in nul table"];
    }
  if (key == t->extra.k.notAKeyMarker)
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
 * If key is equal to the notAKeyMarker field of the tables
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in nul table"];
    }
  if (key == t->extra.k.notAKeyMarker)
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
 * <br />If key is equal to the notAKeyMarker field of the tables
 * NSMapTableKeyCallBacks, raises an NSInvalidArgumentException.
 */
void
NSMapInsertKnownAbsent(NSMapTable *table, const void *key, const void *value)
{
  GSIMapTable	t = (GSIMapTable)table;
  GSIMapNode	n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Attempt to place key-value in nul table"];
    }
  if (key == t->extra.k.notAKeyMarker)
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
 * they are nul pointers, and only updates them if non-null.
 */
BOOL
NSMapMember(NSMapTable *table, const void *key,
  void **originalKey, void **value)
{
  GSIMapNode	n;

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
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
 * Remove the specified key from the table.
 */
void
NSMapRemove(NSMapTable *table, const void *key)
{
  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
      return;
    }
  GSIMapRemoveKey((GSIMapTable)table, (GSIMapKey)key);
}

/**
 * Step through the map table ... return the next key-value pair and
 * return YES, or hit the end of the table and return NO.<br />
 * The GNUstep implementation permits either key or value to be a
 * nul pointer, and refrains from attempting to return the appropriate
 * result in that case.
 */
BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
			void **key, void **value)
{
  GSIMapNode	n;
  
  if (enumerator == 0)
    {
      NSWarnFLog(@"Nul enumerator argument supplied");
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
	  NSWarnFLog(@"Nul key return address");
	}

      if (value != 0)
	{
	  *value = n->value.ptr;
	}
      else
	{
	  NSWarnFLog(@"Nul value return address");
	}
      return YES;
    }
}

/**
 * Empty the map table, but preserve its capacity.
 */
void
NSResetMapTable(NSMapTable *table)
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

  if (table == 0)
    {
      NSWarnFLog(@"Nul table argument supplied");
      return nil;
    }
  string = [NSMutableString stringWithCapacity: 0];
  enumerator = NSEnumerateMapTable(table);

  /*
   * Now, just step through the elements of the table, and add their
   * descriptions to the string.
   */
  while (NSNextMapEnumeratorPair(&enumerator, &key, &value) == YES)
    {
      [string appendFormat: @"%@ = %@;\n",
	(t->extra.k.describe)(table, key),
	(t->extra.v.describe)(table, value)];
    }
  return string;
}


