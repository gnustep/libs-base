/* A fast (Inline) map/hash table implementation for NSObjects
 * Copyright (C) 1998,1999  Free Software Foundation, Inc.
 * 
 * Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
 * Created:	Thu Oct  1 09:30:00 GMT 1998
 * 
 * Based on original o_map code by Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */

#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>

/* To easily un-inline functions for debugging */
#ifndef	INLINE
#define INLINE inline
#endif

/*
 *	This file should be INCLUDED in files wanting to use the GSIMap
 *	functions - these are all declared inline for maximum performance.
 *
 *	The file including this one may predefine some macros to alter
 *	the behaviour
 *
 *	GSI_MAP_HAS_VALUE
 *		If defined as 0, then this becomes a hash table rather than
 *		a map table.
 *
 *	GSI_MAP_RETAIN_KEY()
 *		Macro to retain the key item in a map or hash table.
 *
 *	GSI_MAP_RETAIN_VAL()
 *		Macro to retain the value item in a map table.
 *
 *	GSI_MAP_RELEASE_KEY()
 *		Macro to release the key item in a map or hash table.
 *
 *	GSI_MAP_RELEASE_VAL()
 *		Macro to release the value item in a map table.
 *
 *	GSI_MAP_HASH()
 *		Macro to get the hash of a key item.
 *
 *	GSI_MAP_EQUAL()
 *		Macro to compare two key items for equality - produces zero
 *		if the items are not equal.
 *
 *	GSI_MAP_EXTRA
 *		If this value is defined, there is an 'extra' field in each
 *		map table whose type is that specified by the value of the
 *		preprocessor constant. This field can be used
 *		to store additional information for the map.
 *
 *	GSI_MAP_NOCLEAN
 *		Define this to a non-zero integer value if the map keys and
 *		values do not need to be released when the map is emptied.
 *		This permits some optimisation.
 *
 */

#ifndef	GSI_MAP_HAS_VALUE
#define	GSI_MAP_HAS_VALUE	1
#endif

#ifndef	GSI_MAP_RETAIN_KEY
#define	GSI_MAP_RETAIN_KEY(M, X)	[(X).obj retain]
#endif
#ifndef	GSI_MAP_RELEASE_KEY
#define	GSI_MAP_RELEASE_KEY(M, X)	[(X).obj release]
#endif
#ifndef	GSI_MAP_RETAIN_VAL
#define	GSI_MAP_RETAIN_VAL(M, X)	[(X).obj retain]
#endif
#ifndef	GSI_MAP_RELEASE_VAL
#define	GSI_MAP_RELEASE_VAL(M, X)	[(X).obj release]
#endif
#ifndef	GSI_MAP_HASH
#define	GSI_MAP_HASH(M, X)		[(X).obj hash]
#endif
#ifndef	GSI_MAP_EQUAL
#define	GSI_MAP_EQUAL(M, X, Y)		[(X).obj isEqual: (Y).obj]
#endif

/*
 *      If there is no bitmask defined to supply the types that
 *      may be used as keys in the  map, default to permitting all types.
 */
#ifndef GSI_MAP_KTYPES
#define GSI_MAP_KTYPES        GSUNION_ALL
#endif

/*
 *	Set up the name of the union to store keys.
 */
#ifdef	GSUNION
#undef	GSUNION
#endif
#define	GSUNION	GSIMapKey

/*
 *	Set up the types that will be storable in the union.
 *	See 'GSUnion.h' for further information.
 */
#ifdef	GSUNION_TYPES
#undef	GSUNION_TYPES
#endif
#define	GSUNION_TYPES	GSI_MAP_KTYPES
#ifdef	GSUNION_EXTRA
#undef	GSUNION_EXTRA
#endif
#ifdef	GSI_MAP_KEXTRA
#define	GSUNION_EXTRA	GSI_MAP_KEXTRA
#endif

/*
 *	Generate the union typedef
 */
#include <base/GSUnion.h>


#if (GSI_MAP_KTYPES) & GSUNION_OBJ
#define GSI_MAP_CLEAR_KEY(node)  node->key.obj = nil
#elif  (GSI_MAP_KTYPES) & GSUNION_PTR
#define GSI_MAP_CLEAR_KEY(node)  node->key.ptr = 0
#else
#define GSI_MAP_CLEAR_KEY(node)  
#endif

/*
 *      If there is no bitmask defined to supply the types that
 *      may be used as values in the  map, default to permitting all types.
 */
#ifndef GSI_MAP_VTYPES
#define GSI_MAP_VTYPES        GSUNION_ALL
#endif

/*
 *	Set up the name of the union to store map values.
 */
#ifdef	GSUNION
#undef	GSUNION
#endif
#define	GSUNION	GSIMapVal

/*
 *	Set up the types that will be storable in the union.
 *	See 'GSUnion.h' for further information.
 */
#ifdef	GSUNION_TYPES
#undef	GSUNION_TYPES
#endif
#define	GSUNION_TYPES	GSI_MAP_VTYPES
#ifdef	GSUNION_EXTRA
#undef	GSUNION_EXTRA
#endif
#ifdef	GSI_MAP_VEXTRA
#define	GSUNION_EXTRA	GSI_MAP_VEXTRA
#endif

#ifndef	GSI_MAP_SIMPLE
#define	GSI_MAP_SIMPLE	0
#endif

/*
 *	Generate the union typedef
 */
#include <base/GSUnion.h>

#if (GSI_MAP_VTYPES) & GSUNION_OBJ
#define GSI_MAP_CLEAR_VAL(node)  node->value.obj = nil
#elif  (GSI_MAP_VTYPES) & GSUNION_PTR
#define GSI_MAP_CLEAR_VAL(node)  node->value.ptr = 0
#else
#define GSI_MAP_CLEAR_VAL(node)  
#endif


typedef struct _GSIMapTable GSIMapTable_t;
typedef struct _GSIMapBucket GSIMapBucket_t;
typedef struct _GSIMapNode GSIMapNode_t;

typedef GSIMapTable_t *GSIMapTable;
typedef GSIMapBucket_t *GSIMapBucket;
typedef GSIMapNode_t *GSIMapNode;

struct	_GSIMapNode {
  GSIMapNode	nextInBucket;	/* Linked list of bucket.	*/
  GSIMapKey	key;
#if	GSI_MAP_HAS_VALUE
  GSIMapVal	value;
#endif
};

struct	_GSIMapBucket {
  size_t	nodeCount;	/* Number of nodes in bucket.	*/
  GSIMapNode	firstNode;	/* The linked list of nodes.	*/
};

struct	_GSIMapTable {
  NSZone	*zone;
  size_t	nodeCount;	/* Number of nodes in map.	*/
  size_t	bucketCount;	/* Number of buckets in map.	*/
  GSIMapBucket	buckets;	/* Array of buckets.		*/
  GSIMapNode	freeNodes;	/* List of unused nodes.	*/
  size_t	chunkCount;	/* Number of chunks in array.	*/
  GSIMapNode	*nodeChunks;	/* Chunks of allocated memory.	*/
#ifdef	GSI_MAP_EXTRA
  GSI_MAP_EXTRA	extra;
#endif
};

#ifdef	GSI_MAP_ENUMERATOR
typedef GSI_MAP_ENUMERATOR	GSIMapEnumerator_t;
#else
struct	_GSIMapEnumerator {
  GSIMapTable	map;		/* the map being enumerated.	*/
  GSIMapNode	node;		/* The next node to use.	*/
  size_t	bucket;		/* The next bucket to use.	*/
};
typedef struct _GSIMapEnumerator GSIMapEnumerator_t;
#endif
typedef GSIMapEnumerator_t *GSIMapEnumerator;

static INLINE GSIMapBucket
GSIMapPickBucket(unsigned hash, GSIMapBucket buckets, size_t bucketCount)
{
  return buckets + hash % bucketCount;
}

static INLINE GSIMapBucket
GSIMapBucketForKey(GSIMapTable map, GSIMapKey key)
{
  return GSIMapPickBucket(GSI_MAP_HASH(map, key),
    map->buckets, map->bucketCount);
}

static INLINE void
GSIMapLinkNodeIntoBucket(GSIMapBucket bucket, GSIMapNode node)
{
  node->nextInBucket = bucket->firstNode;
  bucket->firstNode = node;
}

static INLINE void
GSIMapUnlinkNodeFromBucket(GSIMapBucket bucket, GSIMapNode node)
{
  if (node == bucket->firstNode)
    {
      bucket->firstNode = node->nextInBucket;
    }
  else
    {
      GSIMapNode	tmp = bucket->firstNode;

      while (tmp->nextInBucket != node)
	{
	  tmp = tmp->nextInBucket;
	}
      tmp->nextInBucket = node->nextInBucket;
    }
  node->nextInBucket = 0;
}

static INLINE void
GSIMapAddNodeToBucket(GSIMapBucket bucket, GSIMapNode node)
{
  GSIMapLinkNodeIntoBucket(bucket, node);
  bucket->nodeCount += 1;
}

static INLINE void
GSIMapAddNodeToMap(GSIMapTable map, GSIMapNode node)
{
  GSIMapBucket	bucket;

  bucket = GSIMapBucketForKey(map, node->key);
  GSIMapAddNodeToBucket(bucket, node);
  map->nodeCount++;
}

static INLINE void
GSIMapRemoveNodeFromBucket(GSIMapBucket bucket, GSIMapNode node)
{
  bucket->nodeCount--;
  GSIMapUnlinkNodeFromBucket(bucket, node);
}

static INLINE void
GSIMapRemoveNodeFromMap(GSIMapTable map, GSIMapBucket bkt, GSIMapNode node)
{
  map->nodeCount--;
  GSIMapRemoveNodeFromBucket(bkt, node);
}

static INLINE void
GSIMapRemangleBuckets(GSIMapTable map,
			      GSIMapBucket old_buckets,
			      size_t old_bucketCount,
			      GSIMapBucket new_buckets,
			      size_t new_bucketCount)
{
  while (old_bucketCount-- > 0)
    {
      GSIMapNode	node;

      while ((node = old_buckets->firstNode) != 0)
	{
	  GSIMapBucket	bkt;

	  GSIMapRemoveNodeFromBucket(old_buckets, node);
	  bkt = GSIMapPickBucket(GSI_MAP_HASH(map, node->key),
	    new_buckets, new_bucketCount);
	  GSIMapAddNodeToBucket(bkt, node);
	}
      old_buckets++;
    }
}

static INLINE void
GSIMapMoreNodes(GSIMapTable map, unsigned required)
{
  GSIMapNode	*newArray;
  size_t	arraySize = (map->chunkCount+1)*sizeof(GSIMapNode);

#if	GS_WITH_GC == 1
  /*
   * Our nodes may be allocated from the atomic zone - but we don't want
   * them freed - so we must keep the array of pointers to memory chunks in
   * the default zone
   */
  if (map->zone == GSAtomicMallocZone())
    newArray = (GSIMapNode*)NSZoneMalloc(NSDefaultMallocZone(), arraySize);
  else
#endif
  newArray = (GSIMapNode*)NSZoneMalloc(map->zone, arraySize);
  if (newArray)
    {
      GSIMapNode	newNodes;
      size_t		chunkCount;
      size_t		chunkSize;

      memcpy(newArray, map->nodeChunks, (map->chunkCount)*sizeof(GSIMapNode));
      if (map->nodeChunks != 0)
	{
	  NSZoneFree(map->zone, map->nodeChunks);
	}
      map->nodeChunks = newArray;

      if (required == 0)
	{
	  if (map->chunkCount == 0)
	    {
	      chunkCount = map->bucketCount > 1 ? map->bucketCount : 2;
	    }
	  else
	    {
	      chunkCount = ((map->nodeCount>>2)+1)<<1;
	    }
	}
      else
	{
	  chunkCount = required;
	}
      chunkSize = chunkCount * sizeof(GSIMapNode_t);
      newNodes = (GSIMapNode)NSZoneMalloc(map->zone, chunkSize);
      if (newNodes)
	{
	  map->nodeChunks[map->chunkCount++] = newNodes;
	  newNodes[--chunkCount].nextInBucket = map->freeNodes;
	  while (chunkCount--)
	    {
	      newNodes[chunkCount].nextInBucket = &newNodes[chunkCount+1];
	    }
	  map->freeNodes = newNodes;
	}
    }
}

#if	GSI_MAP_HAS_VALUE
static INLINE GSIMapNode
GSIMapNewNode(GSIMapTable map, GSIMapKey key, GSIMapVal value)
{
  GSIMapNode	node = map->freeNodes;

  if (node == 0)
    {
      GSIMapMoreNodes(map, 0);
      node = map->freeNodes;
      if (node == 0)
	{
	  return 0;
	}
    }

  map->freeNodes = node->nextInBucket;
  node->key = key;
  node->value = value;
  node->nextInBucket = 0;

  return node;
}
#else
static INLINE GSIMapNode
GSIMapNewNode(GSIMapTable map, GSIMapKey key)
{
  GSIMapNode	node = map->freeNodes;

  if (node == 0)
    {
      GSIMapMoreNodes(map, 0);
      node = map->freeNodes;
      if (node == 0)
	{
	  return 0;
	}
    }

  map->freeNodes = node->nextInBucket;
  node->key = key;
  node->nextInBucket = 0;
  return node;
}
#endif

static INLINE void
GSIMapFreeNode(GSIMapTable map, GSIMapNode node)
{
  GSI_MAP_RELEASE_KEY(map, node->key);
  GSI_MAP_CLEAR_KEY(node);
#if	GSI_MAP_HAS_VALUE
  GSI_MAP_RELEASE_VAL(map, node->value);
  GSI_MAP_CLEAR_VAL(node);
#endif
  
  node->nextInBucket = map->freeNodes;
  map->freeNodes = node;
}

static INLINE GSIMapNode 
GSIMapNodeForKeyInBucket(GSIMapTable map, GSIMapBucket bucket, GSIMapKey key)
{
  GSIMapNode	node = bucket->firstNode;

  while ((node != 0) && GSI_MAP_EQUAL(map, node->key, key) == NO)
    {
      node = node->nextInBucket;
    }
  return node;
}

static INLINE GSIMapNode 
GSIMapNodeForKey(GSIMapTable map, GSIMapKey key)
{
  GSIMapBucket	bucket;
  GSIMapNode	node;

  if (map->nodeCount == 0)
    return 0;
  bucket = GSIMapBucketForKey(map, key);
  node = GSIMapNodeForKeyInBucket(map, bucket, key);
  return node;
}

#if     (GSI_MAP_KTYPES & GSUNION_INT)
/*
 * Specialized lookup for the case where keys are known to be simple integer
 * or pointer values that are their own hash values and con be compared with
 * a test for integer equality.
 */
static INLINE GSIMapNode 
GSIMapNodeForSimpleKey(GSIMapTable map, GSIMapKey key)
{
  GSIMapBucket	bucket;
  GSIMapNode	node;

  if (map->nodeCount == 0)
    return 0;
  bucket = map->buckets + key.uint % map->bucketCount;
  node = bucket->firstNode;
  while ((node != 0) && node->key.uint != key.uint)
    {
      node = node->nextInBucket;
    }
  return node;
}
#endif

static INLINE void
GSIMapResize(GSIMapTable map, size_t new_capacity)
{
  GSIMapBucket	new_buckets;
  size_t	size = 1;
  size_t	old = 1;

  /*
   *	Find next size up in the fibonacci series
   */
  while (size < new_capacity)
    {
      size_t	tmp = old;
      old = size;
      size += tmp;
    }
  /*
   *	Avoid 8 - since hash functions frequently generate uneven distributions
   *	around powers of two - we don't want lots of keys falling into a single
   *	bucket.
   */
  if (size == 8)
    size++;

  /*
   *	Make a new set of buckets for this map
   */
  new_buckets = (GSIMapBucket)NSZoneCalloc(map->zone, size,
    sizeof(GSIMapBucket_t));
  if (new_buckets != 0)
    {
      GSIMapRemangleBuckets(map, map->buckets, map->bucketCount, new_buckets,
	size);

      if (map->buckets != 0)
	{
	  NSZoneFree(map->zone, map->buckets);
	}
      map->buckets = new_buckets;
      map->bucketCount = size;
    }
}

static INLINE void
GSIMapRightSizeMap(GSIMapTable map, size_t capacity)
{
  /* FIXME: Now, this is a guess, based solely on my intuition.  If anyone
   * knows of a better ratio (or other test, for that matter) and can
   * provide evidence of its goodness, please get in touch with me, Albin
   * L. Jones <Albin.L.Jones@Dartmouth.EDU>. */

  if (3 * capacity >= 4 * map->bucketCount)
    {
      GSIMapResize(map, (3 * capacity)/4 + 1);
    }
}

/** Enumerating **/

/* WARNING: You should not alter a map while an enumeration is
 * in progress.  The results of doing so are reasonably unpremapable.
 * With that in mind, read the following warnings carefully.  But
 * remember, DON'T MESS WITH A MAP WHILE YOU'RE ENUMERATING IT. */

/* IMPORTANT WARNING: Enumerators have a wonderous property.
 * Once a node has been returned by `GSIMapEnumeratorNextNode()', it may be
 * removed from the map without effecting the rest of the current
 * enumeration. */

/* EXTREMELY IMPORTANT WARNING: The purpose of this warning is point
 * out that, at this time, various (i.e., many) functions depend on
 * the behaviour outlined above.  So be prepared for some serious
 * breakage when you go fudging around with these things. */

static INLINE GSIMapEnumerator_t
GSIMapEnumeratorForMap(GSIMapTable map)
{
  GSIMapEnumerator_t	enumerator;

  enumerator.map = map;
  enumerator.node = 0;
  enumerator.bucket = 0;

  return enumerator;
}

static INLINE GSIMapNode 
GSIMapEnumeratorNextNode(GSIMapEnumerator enumerator)
{
  GSIMapNode node;
  int bucketCount = ((GSIMapTable)enumerator->map)->bucketCount;
  node = enumerator->node;

  while(!node && enumerator->bucket < bucketCount)
    {
      node = (((GSIMapTable)enumerator->map)->buckets[enumerator->bucket]).firstNode;
      enumerator->bucket++;
    }
  if (node != 0)
    enumerator->node = node->nextInBucket;

  /* Send back NODE. */
  return node;
}

#if	GSI_MAP_HAS_VALUE
static INLINE GSIMapNode
GSIMapAddPairNoRetain(GSIMapTable map, GSIMapKey key, GSIMapVal value)
{
  GSIMapNode node;

  node = GSIMapNewNode(map, key, value);

  if (node != 0)
    {
      GSIMapRightSizeMap(map, map->nodeCount);
      GSIMapAddNodeToMap(map, node);
    }
  return node;
}

static INLINE GSIMapNode
GSIMapAddPair(GSIMapTable map, GSIMapKey key, GSIMapVal value)
{
  GSIMapNode node;

  GSI_MAP_RETAIN_KEY(map, key);
  GSI_MAP_RETAIN_VAL(map, value);
  node = GSIMapNewNode(map, key, value);

  if (node != 0)
    {
      GSIMapRightSizeMap(map, map->nodeCount);
      GSIMapAddNodeToMap(map, node);
    }
  return node;
}
#else
static INLINE GSIMapNode
GSIMapAddKeyNoRetain(GSIMapTable map, GSIMapKey key)
{
  GSIMapNode node;

  node = GSIMapNewNode(map, key);

  if (node != 0)
    {
      GSIMapRightSizeMap(map, map->nodeCount);
      GSIMapAddNodeToMap(map, node);
    }
  return node;
}

static INLINE GSIMapNode
GSIMapAddKey(GSIMapTable map, GSIMapKey key)
{
  GSIMapNode node;

  GSI_MAP_RETAIN_KEY(map, key);
  node = GSIMapNewNode(map, key);

  if (node != 0)
    {
      GSIMapRightSizeMap(map, map->nodeCount);
      GSIMapAddNodeToMap(map, node);
    }
  return node;
}
#endif

static INLINE void
GSIMapRemoveKey(GSIMapTable map, GSIMapKey key)
{
  GSIMapBucket	bucket = GSIMapBucketForKey(map, key);
  GSIMapNode	node;
  
  node = GSIMapNodeForKeyInBucket(map, bucket, key);
  if (node != 0)
    {
      GSIMapRemoveNodeFromMap(map, bucket, node);
      GSIMapFreeNode(map, node);
    }
}

static INLINE void
GSIMapCleanMap(GSIMapTable map)
{
  if (map->nodeCount > 0)
    {
      GSIMapBucket	bucket = map->buckets;
      int		i;
      GSIMapNode	startNode = 0;
      GSIMapNode	prevNode = 0;
      GSIMapNode	node;
      
      map->nodeCount = 0;
      for (i = 0; i < map->bucketCount; i++)
	{
	  node = bucket->firstNode;
	  if(prevNode)
	      prevNode->nextInBucket = node;
	  else
	      startNode = node;
	  while(node != 0)
	    {
	      GSI_MAP_RELEASE_KEY(map, node->key);
	  
#if	GSI_MAP_HAS_VALUE
	      GSI_MAP_RELEASE_VAL(map, node->value);
#endif
	      prevNode = node;
	      node = node->nextInBucket;
	    }
	  bucket->nodeCount = 0;
	  bucket->firstNode = 0;
	  bucket++;
	}
      
      prevNode->nextInBucket = map->freeNodes;
      map->freeNodes = startNode;
    }
}

static INLINE void
GSIMapEmptyMap(GSIMapTable map)
{
  int	i;

#ifdef	GSI_MAP_NOCLEAN
  if (GSI_MAP_NOCLEAN)
    {
      map->nodeCount = 0;
    }
  else
    {
      GSIMapCleanMap(map);
    }
#else
  GSIMapCleanMap(map);
#endif
  if (map->buckets != 0)
    {
      NSZoneFree(map->zone, map->buckets);
      map->buckets = 0;
      map->bucketCount = 0;
    }
  if (map->nodeChunks != 0)
    {
      for (i = 0; i < map->chunkCount; i++)
	{
	  NSZoneFree(map->zone, map->nodeChunks[i]);
	}
      map->chunkCount = 0;
      NSZoneFree(map->zone, map->nodeChunks);
      map->nodeChunks = 0;
    }
  map->freeNodes = 0;
  map->zone = 0;
}

static INLINE void 
GSIMapInitWithZoneAndCapacity(GSIMapTable map, NSZone *zone, size_t capacity)
{
  map->zone = zone;
  map->nodeCount = 0;
  map->bucketCount = 0;
  map->buckets = 0;
  map->nodeChunks = 0;
  map->freeNodes = 0;
  map->chunkCount = 0;
  GSIMapRightSizeMap(map, capacity);
  GSIMapMoreNodes(map, capacity);
}

