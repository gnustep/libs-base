/** NSHashTable implementation for GNUStep.
 * Copyright (C) 1994, 1995, 1996, 1997, 2002  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Mon Dec 12 23:54:09 EST 1994
 * Updated: Mon Mar 11 01:48:31 EST 1996
 * Serial: 96.03.11.06
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
 * <title>NSHashTable class reference</title>
 * $Date$ $Revision$
 */ 

/**** Included Headers *******************************************************/

#include <config.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSDebug.h>
#include "NSCallBacks.h"


#define GSI_NEW 1
/*
 *      The 'Fastmap' stuff provides an inline implementation of a hash
 *      table - for maximum performance.
 */
#define GSI_MAP_HAS_VALUE	0
#define GSI_MAP_EXTRA           NSHashTableCallBacks
#define GSI_MAP_KTYPES          GSUNION_PTR
#define GSI_MAP_HASH(M, X)\
 (M->extra.hash)((NSHashTable*)M, X.ptr)
#define GSI_MAP_EQUAL(M, X, Y)\
 (M->extra.isEqual)((NSHashTable*)M, X.ptr, Y.ptr)
#define GSI_MAP_RELEASE_KEY(M, X)\
 (M->extra.release)((NSHashTable*)M, X.ptr)
#define GSI_MAP_RETAIN_KEY(M, X)\
 (M->extra.retain)((NSHashTable*)M, X.ptr)
#define GSI_MAP_ENUMERATOR	NSHashEnumerator

#include <base/GSIMap.h>

/**
 * Returns an array of all the objects in the table.
 * NB. The table <em>must</em> contain objects, not pointers or integers.
 */
NSArray *
NSAllHashTableObjects(NSHashTable *table)
{
  NSMutableArray	*array;
  NSHashEnumerator	enumerator;
  id			element;

  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
      return nil;
    }

  array = [NSMutableArray arrayWithCapacity: NSCountHashTable(table)];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  while ((element = NSNextHashEnumeratorItem(&enumerator)) != 0)
    {
      [array addObject: element];
    }
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
  GSIMapTable   t1 = (GSIMapTable)table1;
  GSIMapTable   t2 = (GSIMapTable)table2;

  if (t1 == t2)
    {
      return YES;
    }
  if (t1 == 0)
    {
      NSWarnLog(@"Nul first argument supplied");
      return NO;
    }
  if (t2 == 0)
    {
      NSWarnLog(@"Nul second argument supplied");
      return NO;
    }

  if (t1->nodeCount != t2->nodeCount)
    {
      return NO;
    }
  else
    {
      GSIMapNode        n = t1->firstNode;

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
NSHashTable *
NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone)
{
  GSIMapTable   t;
  GSIMapNode    n;

  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
      return 0;
    }

  t = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(t, zone, ((GSIMapTable)table)->nodeCount);
  t->extra = ((GSIMapTable)table)->extra;
  n = ((GSIMapTable)table)->firstNode;
  while (n != 0)
    {
      GSIMapAddKey(t, n->key);
      n = n->nextInMap;
    }

  return (NSHashTable*)t;
}

/**
 * Returns the number of objects in the table.
 */
unsigned int
NSCountHashTable(NSHashTable *table)
{
  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
      return 0;
    }
  return ((GSIMapTable)table)->nodeCount;
}

/**
 * Create a new hash table by calling NSCreateHashTableWithZone() using
 * NSDefaultMallocZone().
 */
NSHashTable *
NSCreateHashTable(
  NSHashTableCallBacks callBacks,
  unsigned int capacity)
{
  return NSCreateHashTableWithZone(callBacks, capacity, NSDefaultMallocZone());
}

/**
 * Create a new hash table using the supplied callbacks structure.
 * If any functions in the callback structure is null the default
 * values are used ... as for non-owned pointers.
 * The table will be created with the specified capacity ... ie ready
 * to hold at lest that many items.
 */
NSHashTable *
NSCreateHashTableWithZone(
  NSHashTableCallBacks callBacks,
  unsigned int capacity,
  NSZone *zone)
{
  GSIMapTable	table;

  table = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t));
  GSIMapInitWithZoneAndCapacity(table, zone, capacity);
  table->extra = callBacks;

  if (table->extra.hash == 0)
    table->extra.hash = NSNonOwnedPointerHashCallBacks.hash;
  if (table->extra.isEqual == 0)
    table->extra.isEqual = NSNonOwnedPointerHashCallBacks.isEqual;
  if (table->extra.retain == 0)
    table->extra.retain = NSNonOwnedPointerHashCallBacks.retain;
  if (table->extra.release == 0)
    table->extra.release = NSNonOwnedPointerHashCallBacks.release;
  if (table->extra.describe == 0)
    table->extra.describe = NSNonOwnedPointerHashCallBacks.describe;

  return (NSHashTable*)table;
}

/**
 * Function to be called when finished with the enumerator.
 * Not required in GNUstep ... just provided for MacOS-X compatibility.
 */
void
NSEndHashTableEnumeration(NSHashEnumerator *enumerator)
{
  if (enumerator == 0)
    {
      NSWarnLog(@"Nul enumerator argument supplied");
    }
}

/**
 * Return an enumerator for stepping through a map table using the
 * NSNextHashEnumeratorPair() function.
 */
NSHashEnumerator
NSEnumerateHashTable(NSHashTable *table)
{
  if (table == 0)
    {
      NSHashEnumerator	v = { 0, 0 };

      NSWarnLog(@"Nul table argument supplied");
      return v;
    }
  else
    {
      return GSIMapEnumeratorForMap((GSIMapTable)table);
    }
}

/**
 * Destroy the hash table and relase its contents.
 */
void
NSFreeHashTable(NSHashTable *table)
{
  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
    }
  else
    {
      NSZone	*z = ((GSIMapTable)table)->zone;

      GSIMapEmptyMap((GSIMapTable)table);
      NSZoneFree(z, table);
    }
}

/**
 * Returns the value for the specified element, or a nul pointer if the
 * element is not found in the table.
 */
void *
NSHashGet(NSHashTable *table, const void *element)
{
  GSIMapNode    n;

  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
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
 * If element is nul raises an NSInvalidArgumentException.
 */
void
NSHashInsert(NSHashTable *table, const void *element)
{
  GSIMapTable   t = (GSIMapTable)table;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place value in nul hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place nul in hash table"];
    }
  GSIMapAddKey(t, (GSIMapKey)element);
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
                  format: @"Attempt to place value in nul hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place nul in hash table"];
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
 * <br />If element is nul raises an NSInvalidArgumentException.
 */
void
NSHashInsertKnownAbsent(NSHashTable *table, const void *element)
{
  GSIMapTable   t = (GSIMapTable)table;
  GSIMapNode    n;

  if (table == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place value in nul hash table"];
    }
  if (element == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Attempt to place nul in hash table"];
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
      NSWarnLog(@"Nul table argument supplied");
    }
  else
    {
      GSIMapRemoveKey((GSIMapTable)table, (GSIMapKey)element);
    }
}

/**
 * Step through the hash table ... return the next item or
 * return nulif we hit the of the table.
 */
void *
NSNextHashEnumeratorItem(NSHashEnumerator *enumerator)
{
  GSIMapNode    n = GSIMapEnumeratorNextNode((GSIMapEnumerator)enumerator);
 
  if (enumerator == 0)
    {
      NSWarnLog(@"Nul enumerator argument supplied");
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
 * Empty the hash table, but preserve its capacity.
 */
void
NSResetHashTable(NSHashTable *table)
{
  if (table == 0)
    {
      NSWarnLog(@"Nul table argument supplied");
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
      NSWarnLog(@"Nul table argument supplied");
      return nil;
    }

  /* This will be our string. */
  string = [NSMutableString stringWithCapacity: 0];

  /* Get an enumerator for TABLE. */
  enumerator = NSEnumerateHashTable(table);

  /* Iterate over the elements of TABLE, appending the description of
   * each to the mutable string STRING. */
  while ((element = NSNextHashEnumeratorItem(&enumerator)) != 0)
    {
      [string appendFormat: @"%@;\n", (t->extra.describe)(table, element)];
    }
  return string;
}

