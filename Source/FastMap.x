/* A fast map/hash table implementation for NSObjects
 * Copyright (C) 1998  Free Software Foundation, Inc.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#include <config.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>

/* To easily un-inline functions for debugging */
#ifndef	INLINE
#define INLINE inline
#endif

/*
 *	This file should be INCLUDED in files wanting to use the FastMap
 *	functions - these are all declared inline for maximum performance.
 *
 *	The file including this one may predefine some macros to alter
 *	the behaviour (default macros assume the items are NSObjects
 *	that are to be retained in the table) ...
 *
 *	FAST_MAP_HAS_VALUE
 *		If defined as 0, then this becomes a hash table rather than
 *		a map table.
 *
 *	FAST_MAP_RETAIN_KEY()
 *		Macro to retain the key item in a map or hash table.
 *
 *	FAST_MAP_RETAIN_VAL()
 *		Macro to retain the value item in a map table.
 *
 *	FAST_MAP_RELEASE_KEY()
 *		Macro to release the key item in a map or hash table.
 *
 *	FAST_MAP_RELEASE_VAL()
 *		Macro to release the value item in a map table.
 *
 *	FAST_MAP_HASH()
 *		Macro to get the hash of a key item.
 *
 *	FAST_MAP_EQUAL()
 *		Macro to compare two key items for equality - produces zero
 *		if the items are not equal.
 */

#ifndef	FAST_MAP_HAS_VALUE
#define	FAST_MAP_HAS_VALUE	1
#endif

#ifndef	FAST_MAP_RETAIN_KEY
#define	FAST_MAP_RETAIN_KEY(X)	[(X).o retain]
#endif

#ifndef	FAST_MAP_RELEASE_KEY
#define	FAST_MAP_RELEASE_KEY(X)	[(X).o release]
#endif

#ifndef	FAST_MAP_RETAIN_VAL
#define	FAST_MAP_RETAIN_VAL(X)	[(X).o retain]
#endif

#ifndef	FAST_MAP_RELEASE_VAL
#define	FAST_MAP_RELEASE_VAL(X)	[(X).o release]
#endif

#ifndef	FAST_MAP_HASH
#define	FAST_MAP_HASH(X)	[(X).o hash]
#endif

#ifndef	FAST_MAP_EQUAL
#define	FAST_MAP_EQUAL(X,Y)	[(X).o isEqual: (Y).o]
#endif

typedef	union {
    id		o;
    Class	c;
    int		i;
    unsigned	I;
    long 	l;
    unsigned long	L;
    void	*p;
    const void	*P;
    char	*s;
    const char	*S;
} FastMapItem;

typedef struct _FastMapTable FastMapTable_t;
typedef struct _FastMapBucket FastMapBucket_t;
typedef struct _FastMapNode FastMapNode_t;
typedef struct _FastMapEnumerator FastMapEnumerator_t;

typedef FastMapTable_t *FastMapTable;
typedef FastMapBucket_t *FastMapBucket;
typedef FastMapNode_t *FastMapNode;
typedef FastMapEnumerator_t *FastMapEnumerator;

struct	_FastMapNode {
    FastMapNode	nextInBucket;	/* Linked list of bucket.	*/
    FastMapNode	nextInMap;	/* For enumerating.		*/
    FastMapItem	key;
#if	FAST_MAP_HAS_VALUE
    FastMapItem	value;
#endif
};

struct	_FastMapBucket {
    size_t	nodeCount;	/* Number of nodes in bucket.	*/
    FastMapNode	firstNode;	/* The linked list of nodes.	*/
};

struct	_FastMapTable {
    NSZone		*zone;
    size_t		nodeCount;	/* Number of nodes in map.	*/
    FastMapNode		firstNode;	/* List for enumerating.	*/
    size_t		bucketCount;	/* Number of buckets in map.	*/
    FastMapBucket	buckets;	/* Array of buckets.		*/
    FastMapNode		freeNodes;	/* List of unused nodes.	*/
    size_t		chunkCount;	/* Number of chunks in array.	*/
    FastMapNode		*nodeChunks;	/* Chunks of allocated memory.	*/
};

struct	_FastMapEnumerator {
    FastMapTable	map;		/* the map being enumerated.	*/
    FastMapNode		node;		/* The next node to use.	*/
};

static INLINE FastMapBucket
FastMapPickBucket(FastMapItem key, FastMapBucket buckets, size_t bucketCount)
{
    return buckets + FAST_MAP_HASH(key) % bucketCount;
}

static INLINE FastMapBucket
FastMapBucketForKey(FastMapTable map, FastMapItem key)
{
    return FastMapPickBucket(key, map->buckets, map->bucketCount);
}

static INLINE void
FastMapLinkNodeIntoBucket(FastMapBucket bucket, FastMapNode node)
{
    node->nextInBucket = bucket->firstNode;
    bucket->firstNode = node;
}

static INLINE void
FastMapUnlinkNodeFromBucket(FastMapBucket bucket, FastMapNode node)
{
    if (node == bucket->firstNode) {
	bucket->firstNode = node->nextInBucket;
    }
    else {
	FastMapNode	tmp = bucket->firstNode;

	while (tmp->nextInBucket != node) {
	    tmp = tmp->nextInBucket;
	}
	tmp->nextInBucket = node->nextInBucket;
    }
    node->nextInBucket = 0;
}

static INLINE void
FastMapLinkNodeIntoMap(FastMapTable map, FastMapNode node)
{
    node->nextInMap = map->firstNode;
    map->firstNode = node;
}

static INLINE void
FastMapUnlinkNodeFromMap(FastMapTable map, FastMapNode node)
{
    if (node == map->firstNode) {
	map->firstNode = node->nextInMap;
    }
    else {
	FastMapNode	tmp = map->firstNode;

	while (tmp->nextInMap != node) {
	    tmp = tmp->nextInMap;
	}
	tmp->nextInMap = node->nextInMap;
    }
    node->nextInMap = 0;
}

static INLINE void
FastMapAddNodeToBucket(FastMapBucket bucket, FastMapNode node)
{
  FastMapLinkNodeIntoBucket(bucket, node);
  bucket->nodeCount += 1;
}

static INLINE void
FastMapAddNodeToMap(FastMapTable map, FastMapNode node)
{
    FastMapBucket	bucket;

    bucket = FastMapBucketForKey(map, node->key);
    FastMapAddNodeToBucket(bucket, node);
    FastMapLinkNodeIntoMap(map, node);
    map->nodeCount++;
}

static INLINE void
FastMapRemoveNodeFromBucket(FastMapBucket bucket, FastMapNode node)
{
    bucket->nodeCount--;
    FastMapUnlinkNodeFromBucket(bucket, node);
}

static INLINE void
FastMapRemoveNodeFromMap(FastMapTable map, FastMapBucket bkt, FastMapNode node)
{
    map->nodeCount--;
    FastMapUnlinkNodeFromMap(map, node);
    FastMapRemoveNodeFromBucket(bkt, node);
}

static INLINE void
FastMapRemangleBuckets(FastMapTable map,
			      FastMapBucket old_buckets,
			      size_t old_bucketCount,
			      FastMapBucket new_buckets,
			      size_t new_bucketCount)
{
    while (old_bucketCount-- > 0) {
	FastMapNode	node;

	while ((node = old_buckets->firstNode) != 0) {
	    FastMapBucket	bkt;

	    FastMapRemoveNodeFromBucket(old_buckets, node);
	    bkt = FastMapPickBucket(node->key, new_buckets, new_bucketCount);
	    FastMapAddNodeToBucket(bkt, node);
	}
	old_buckets++;
    }
}

static INLINE void
FastMapMoreNodes(FastMapTable map)
{
    FastMapNode	*newArray;
    size_t	arraySize = (map->chunkCount+1)*sizeof(FastMapNode);

    newArray = (FastMapNode*)NSZoneMalloc(map->zone, arraySize);
    
    if (newArray) {
	FastMapNode	newNodes;
	size_t		chunkCount;
	size_t		chunkSize;

	memcpy(newArray,map->nodeChunks,(map->chunkCount)*sizeof(FastMapNode));
	if (map->nodeChunks != 0)
	    NSZoneFree(map->zone, map->nodeChunks);
	map->nodeChunks = newArray;

	if (map->chunkCount == 0) {
	    chunkCount = map->bucketCount > 1 ? map->bucketCount : 2;
	}
	else {
	    chunkCount = ((map->nodeCount>>2)+1)<<1;
	}
	chunkSize = chunkCount * sizeof(FastMapNode_t);
	newNodes = (FastMapNode)NSZoneMalloc(map->zone, chunkSize);
	if (newNodes) {
	    map->nodeChunks[map->chunkCount++] = newNodes;
	    newNodes[--chunkCount].nextInMap = map->freeNodes;
	    while (chunkCount--) {
		newNodes[chunkCount].nextInMap = &newNodes[chunkCount+1];
	    }
	    map->freeNodes = newNodes;
	}
    }
}

#if	FAST_MAP_HAS_VALUE
static INLINE FastMapNode
FastMapNewNode(FastMapTable map, FastMapItem key, FastMapItem value)
{
    FastMapNode	node = map->freeNodes;

    if (node == 0) {
	FastMapMoreNodes(map);
	node = map->freeNodes;
	if (node == 0) {
	    return 0;
	}
    }

    map->freeNodes = node->nextInMap;
    node->key = key;
    node->value = value;
    node->nextInBucket = 0;
    node->nextInMap = 0;

    return node;
}
#else
static INLINE FastMapNode
FastMapNewNode(FastMapTable map, FastMapItem key)
{
    FastMapNode	node = map->freeNodes;

    if (node == 0) {
	FastMapMoreNodes(map);
	node = map->freeNodes;
	if (node == 0) {
	    return 0;
	}
    }

    map->freeNodes = node->nextInMap;
    node->key = key;
    node->nextInBucket = 0;
    node->nextInMap = 0;
    return node;
}
#endif

static INLINE void
FastMapFreeNode(FastMapTable map, FastMapNode node)
{
    FAST_MAP_RELEASE_KEY(node->key);
#if	FAST_MAP_HAS_VALUE
    FAST_MAP_RELEASE_VAL(node->value);
#endif
    node->nextInMap = map->freeNodes;
    map->freeNodes = node;
}

static INLINE FastMapNode 
FastMapNodeForKeyInBucket(FastMapBucket bucket, FastMapItem key)
{
    FastMapNode	node = bucket->firstNode;

    while ((node != 0) && FAST_MAP_EQUAL(node->key, key) == NO) {
	node = node->nextInBucket;
    }
    return node;
}

static INLINE FastMapNode 
FastMapNodeForKey(FastMapTable map, FastMapItem key)
{
    FastMapBucket	bucket;
    FastMapNode		node;

    bucket = FastMapBucketForKey(map, key);
    node = FastMapNodeForKeyInBucket(bucket, key);
    return node;
}

static INLINE void
FastMapResize(FastMapTable map, size_t new_capacity)
{
    FastMapBucket	new_buckets;
    size_t		size = 1;
    size_t		old = 1;

    /*
     *	Find next size up in the fibonacci series
     */
    while (size < new_capacity) {
	size_t	tmp = old;
	old = size;
	size += tmp;
    }
    /*
     *	Avoid 8 - since hash functions frequently generate uneven distributions
     *	around powers of two - we don't want lots of keys falling into a single
     *	bucket.
     */
    if (size == 8) size++;

    /*
     *	Make a new set of buckets for this map
     */
    new_buckets = (FastMapBucket)NSZoneCalloc(map->zone, size,
		sizeof(FastMapBucket_t));
    if (new_buckets != 0) {
	FastMapRemangleBuckets(map,
				  map->buckets,
				  map->bucketCount,
				  new_buckets,
				  size);

	if (map->buckets != 0) {
	    NSZoneFree(map->zone, map->buckets);
	}
	map->buckets = new_buckets;
	map->bucketCount = size;
    }
}

static INLINE void
FastMapRightSizeMap(FastMapTable map, size_t capacity)
{
  /* FIXME: Now, this is a guess, based solely on my intuition.  If anyone
   * knows of a better ratio (or other test, for that matter) and can
   * provide evidence of its goodness, please get in touch with me, Albin
   * L. Jones <Albin.L.Jones@Dartmouth.EDU>. */

    if (3 * capacity >= 4 * map->bucketCount) {
	FastMapResize(map, (3 * capacity)/4 + 1);
    }
}

/** Enumerating **/

/* WARNING: You should not alter a map while an enumeration is
 * in progress.  The results of doing so are reasonably unpremapable.
 * With that in mind, read the following warnings carefully.  But
 * remember, DON'T MESS WITH A MAP WHILE YOU'RE ENUMERATING IT. */

/* IMPORTANT WARNING: Map enumerators, as I have map them up, have a
 * wonderous property.  Namely, that, while enumerating, one may add
 * new elements (i.e., new nodes) to the map while an enumeration is
 * in progress (i.e., after `o_map_enumerator_for_map()' has been
 * called), and the enumeration remains the same. */

/* WARNING: The above warning should not, in any way, be taken as
 * assurance that this property of map enumerators will be preserved
 * in future editions of the library.  I'm still thinking about
 * this. */

/* IMPORTANT WARNING: Enumerators have yet another wonderous property.
 * Once a node has been returned by `FastMapEnumeratorNextNode()', it may be
 * removed from the map without effecting the rest of the current
 * enumeration. */

/* EXTREMELY IMPORTANT WARNING: The purpose of this warning is point
 * out that, at this time, various (i.e., many) functions depend on
 * the behaviours outlined above.  So be prepared for some serious
 * breakage when you go fudging around with these things. */

static INLINE FastMapEnumerator_t
FastMapEnumeratorForMap(FastMapTable map)
{
    FastMapEnumerator_t	enumerator;

    enumerator.map = map;
    enumerator.node = map->firstNode;

    return enumerator;
}

static INLINE FastMapNode 
FastMapEnumeratorNextNode(FastMapEnumerator enumerator)
{
    FastMapNode node;

    node = enumerator->node;

    if (node != 0)
	enumerator->node = node->nextInMap;

    /* Send back NODE. */
    return node;
}

#if	FAST_MAP_HAS_VALUE
static INLINE FastMapNode
FastMapAddPairNoRetain(FastMapTable map, FastMapItem key, FastMapItem value)
{
    FastMapNode node;

    node = FastMapNewNode(map, key, value);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}

static INLINE FastMapNode
FastMapAddPair(FastMapTable map, FastMapItem key, FastMapItem value)
{
    FastMapNode node;

    FAST_MAP_RETAIN_KEY(key);
    FAST_MAP_RETAIN_VAL(value);
    node = FastMapNewNode(map, key, value);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}
#else
static INLINE FastMapNode
FastMapAddKeyNoRetain(FastMapTable map, FastMapItem key)
{
    FastMapNode node;

    node = FastMapNewNode(map, key);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}

static INLINE FastMapNode
FastMapAddKey(FastMapTable map, FastMapItem key)
{
    FastMapNode node;

    FAST_MAP_RETAIN_KEY(key);
    node = FastMapNewNode(map, key);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}
#endif

static INLINE void
FastMapRemoveKey(FastMapTable map, FastMapItem key)
{
    FastMapBucket	bucket = FastMapBucketForKey(map, key);

    if (bucket != 0) {
	FastMapNode	node = FastMapNodeForKeyInBucket(bucket, key);

	if (node != 0) {
	    FastMapRemoveNodeFromMap(map, bucket, node);
	    FastMapFreeNode(map, node);
	}
    }
}

static INLINE void
FastMapCleanMap(FastMapTable map)
{
    FastMapBucket	bucket = map->buckets;
    int			i;

    for (i = 0; i < map->bucketCount; i++) {
	while (bucket->nodeCount != 0) {
	    FastMapNode	node = bucket->firstNode;

	    FastMapRemoveNodeFromBucket(bucket, node);
	    FastMapFreeNode(map, node);
	}
	bucket++;
    }
    map->firstNode = 0;
    map->nodeCount = 0;
}

static INLINE void
FastMapEmptyMap(FastMapTable map)
{
    int			i;

    FastMapCleanMap(map);
    if (map->buckets != 0) {
	NSZoneFree(map->zone, map->buckets);
	map->buckets = 0;
	map->bucketCount = 0;
    }
    if (map->nodeChunks != 0) {
	for (i = 0; i < map->chunkCount; i++) {
	    NSZoneFree(map->zone, map->nodeChunks[i]);
	}
	map->chunkCount = 0;
	NSZoneFree(map->zone, map->nodeChunks);
	map->nodeChunks = 0;
    }
    map->freeNodes = 0;
    map->zone = 0;
}

static INLINE FastMapTable 
FastMapInitWithZoneAndCapacity(FastMapTable map, NSZone *zone, size_t capacity)
{
    map->zone = zone;
    map->nodeCount = 0;
    map->bucketCount = 0;
    map->firstNode = 0;
    map->buckets = 0;
    map->nodeChunks = 0;
    map->freeNodes = 0;
    map->chunkCount = 0;
    FastMapRightSizeMap(map, capacity);
    FastMapMoreNodes(map);
}


