/* A fast map table implementation for NSObjects
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

/*
 *	This file should be INCLUDED in files wanting to use the FastMap
 *	functions - these are all declared inline for maximum performance.
 */

/* To easily un-inline functions for debugging */
#define INLINE inline

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
    NSObject	*key;
    NSObject	*value;
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
};

struct	_FastMapEnumerator {
    FastMapTable	map;		/* the map being enumerated.	*/
    FastMapNode		node;		/* The next node to use.	*/
};

static INLINE FastMapBucket
FastMapPickBucket(NSObject *key, FastMapBucket buckets, size_t bucketCount)
{
    return buckets + [key hash] % bucketCount;
}

static INLINE FastMapBucket
FastMapBucketForKey(FastMapTable map, NSObject *key)
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
    }
}

static INLINE FastMapNode
FastMapNewNodeNoRetain(FastMapTable map, NSObject *key, NSObject *value)
{
    FastMapNode	node;

    node = (FastMapNode)NSZoneMalloc(map->zone, sizeof(FastMapNode_t));

    if (node != 0) {
	node->key = key;
	node->value = value;
	node->nextInBucket = 0;
	node->nextInMap = 0;
    }
    return node;
}

static INLINE void
FastMapFreeNode(FastMapNode node)
{
    if (node != 0) {
	[node->key release];
	[node->value release];
	NSZoneFree(NSZoneFromPointer(node), node);
    }
}

static INLINE FastMapNode 
FastMapNodeForKeyInBucket(FastMapBucket bucket, NSObject *key)
{
    FastMapNode	node = bucket->firstNode;

    while ((node != 0) && [node->key isEqual: key] == NO) {
	node = node->nextInBucket;
    }
    return node;
}

static INLINE FastMapNode 
FastMapNodeForKey(FastMapTable map, NSObject *key)
{
    FastMapBucket	bucket;
    FastMapNode		node;

    bucket = FastMapBucketForKey(map, key);
    node = FastMapNodeForKeyInBucket(bucket, key);
    return node;
}

static INLINE size_t
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

    /* Return the new capacity. */
    return map->bucketCount;
}

static INLINE size_t
FastMapRightSizeMap(FastMapTable map, size_t capacity)
{
  /* FIXME: Now, this is a guess, based solely on my intuition.  If anyone
   * knows of a better ratio (or other test, for that matter) and can
   * provide evidence of its goodness, please get in touch with me, Albin
   * L. Jones <Albin.L.Jones@Dartmouth.EDU>. */

    if (3 * capacity >= 4 * map->bucketCount) {
	return FastMapResize(map, (3 * capacity)/4 + 1);
    }
    else {
	return map->bucketCount;
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

static INLINE FastMapNode
FastMapAddPairNoRetain(FastMapTable map, NSObject *key, NSObject *value)
{
    FastMapNode node;

    node = FastMapNewNodeNoRetain(map, key, value);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}

static INLINE FastMapNode
FastMapAddPair(FastMapTable map, NSObject *key, NSObject *value)
{
    FastMapNode node;

    [key retain];
    [value retain];
    node = FastMapNewNodeNoRetain(map, key, value);

    if (node != 0) {
	FastMapRightSizeMap(map, map->nodeCount);
	FastMapAddNodeToMap(map, node);
    }
    return node;
}

static INLINE void
FastMapRemoveKey(FastMapTable map, NSObject *key)
{
    FastMapBucket	bucket = FastMapBucketForKey(map, key);

    if (bucket != 0) {
	FastMapNode	node = FastMapNodeForKeyInBucket(bucket, key);

	if (node != 0) {
	    FastMapRemoveNodeFromMap(map, bucket, node);
	    FastMapFreeNode(node);
	}
    }
}

static INLINE void
FastMapEmptyMap(FastMapTable map)
{
    FastMapBucket	bucket = map->buckets;
    int			i;

    for (i = 0; i < map->bucketCount; i++) {
	while (bucket->nodeCount != 0) {
	    FastMapNode	node = bucket->firstNode;

	    FastMapRemoveNodeFromBucket(bucket, node);
	    FastMapFreeNode(node);
	}
	bucket++;
    }
    if (map->buckets != 0) {
	NSZoneFree(map->zone, map->buckets);
    }
    map->firstNode = 0;
    map->nodeCount = 0;
    map->buckets = 0;
    map->bucketCount = 0;
}

static INLINE FastMapTable 
FastMapInitWithZoneAndCapacity(FastMapTable map, NSZone *zone, size_t capacity)
{
    map->zone = zone;
    map->nodeCount = 0;
    map->bucketCount = 0;
    map->firstNode = 0;
    map->buckets = 0;
    FastMapRightSizeMap(map, capacity);
}


