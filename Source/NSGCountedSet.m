/* Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <richard@brainstorm.co.Ik>
   Created: October 1998
   
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

#include <config.h>
#include <Foundation/NSSet.h>
#include <gnustep/base/behavior.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPortCoder.h>
#include <gnustep/base/Coding.h>


#define	FAST_MAP_RETAIN_VAL(X)	X
#define	FAST_MAP_RELEASE_VAL(X)	

#include "FastMap.x"

@class	NSSetNonCore;
@class	NSMutableSetNonCore;

@interface NSGCountedSet : NSCountedSet
{
@public
    FastMapTable_t	map;
}
@end

@interface NSGCountedSetEnumerator : NSEnumerator
{
    NSGCountedSet	*set;
    FastMapNode		node;
}
@end

@implementation NSGCountedSetEnumerator

- initWithSet: (NSSet*)d
{
    self = [super init];
    if (self) {
	set = [(NSGCountedSet*)d retain];
	node = set->map.firstNode;
    }
    return self;
}

- nextObject
{
    FastMapNode old = node;

    if (node == 0) {
        return nil;
    }
    node = node->nextInMap;
    return old->key.o;
}

- (void) dealloc
{
    [set release];
    [super dealloc];
}

@end


@implementation NSGCountedSet

+ (void) initialize
{
    if (self == [NSGCountedSet class]) {
	class_add_behavior(self, [NSSetNonCore class]);
	class_add_behavior(self, [NSMutableSetNonCore class]);
    }
}

- (void) dealloc
{
    FastMapEmptyMap(&map);
    [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    unsigned    count = map.nodeCount;
    FastMapNode node = map.firstNode;

    [(id<Encoding>)aCoder encodeValueOfCType: @encode(unsigned)
                                          at: &count
                                    withName: @"Set content count"];

    if ([aCoder isKindOfClass: [NSPortCoder class]] &&
        [(NSPortCoder*)aCoder isBycopy]) {
        while (node != 0) {
            [(id<Encoding>)aCoder encodeBycopyObject: node->key.o
                                            withName: @"Set value"];
	    [(id<Encoding>)aCoder encodeValueOfCType: @encode(unsigned)
						  at: &node->value.I
					    withName: @"Set value count"];
            node = node->nextInMap;
        }
    }
    else {
        while (node != 0) {
            [(id<Encoding>)aCoder encodeObject: node->key.o
                                      withName: @"Set content"];
	    [(id<Encoding>)aCoder encodeValueOfCType: @encode(unsigned)
						  at: &node->value.I
					    withName: @"Set value count"];
            node = node->nextInMap;
        }
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned    count;
    id          value;
    unsigned	valcnt;

    [(id<Decoding>)aCoder decodeValueOfCType: @encode(unsigned)
                                          at: &count
                                    withName: NULL];

    FastMapInitWithZoneAndCapacity(&map, [self zone], count);
    while (count-- > 0) {
        [(id<Decoding>)aCoder decodeObjectAt: &value withName: NULL];
	[(id<Decoding>)aCoder decodeValueOfCType: @encode(unsigned)
					      at: &valcnt
					withName: NULL];
        FastMapAddPairNoRetain(&map, (FastMapItem)value, (FastMapItem)valcnt);
    }

    return self;
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
    FastMapInitWithZoneAndCapacity(&map, [self zone], cap);
    return self;
}

- (id) initWithObjects: (id*)objs count: (unsigned)c
{
    int i;

    if ([self initWithCapacity: c] == nil) {
	return nil;
    }
    for (i = 0; i < c; i++) {
        FastMapNode     node;

	if (objs[i] == nil) {
	    [self autorelease];
	    [NSException raise: NSInvalidArgumentException
			format: @"Tried to init counted set with nil value"];
	}
        node = FastMapNodeForKey(&map, (FastMapItem)objs[i]);
        if (node == 0) {
            FastMapAddPair(&map,(FastMapItem)objs[i],(FastMapItem)(unsigned)1);
        }
	else {
	    node->value.I++;
	}
    }
    return self;
}

- (void) addObject: (NSObject*)anObject
{
    FastMapNode node;

    if (anObject == nil) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Tried to nil value to counted set"];
    }

    node = FastMapNodeForKey(&map, (FastMapItem)anObject);
    if (node == 0) {
        FastMapAddPair(&map,(FastMapItem)anObject,(FastMapItem)(unsigned)1);
    }
    else {
	node->value.I++;
    }
}

- (unsigned) count
{
    return map.nodeCount;
}

- (unsigned) countForObject: (id)anObject
{
    if (anObject) {
	FastMapNode node = FastMapNodeForKey(&map, (FastMapItem)anObject);

	if (node) {
	    return node->value.I;
	}
    }
    return 0;
}

- (id) member: (id)anObject
{
    if (anObject) {
	FastMapNode node = FastMapNodeForKey(&map, (FastMapItem)anObject);

	if (node) {
	    return node->key.o;
	}
    }
    return nil;
}

- (NSEnumerator*) objectEnumerator
{
    return [[[NSGCountedSetEnumerator alloc] initWithSet: self] autorelease];
}

- (void) removeObject: (NSObject*)anObject
{
    if (anObject) {
	FastMapBucket       bucket;
	
	bucket = FastMapBucketForKey(&map, (FastMapItem)anObject);
	if (bucket) {
	    FastMapNode     node;

	    node = FastMapNodeForKeyInBucket(bucket, (FastMapItem)anObject);
	    if (node) {
		if (--node->value.I == 0) {
		    FastMapRemoveNodeFromMap(&map, bucket, node);
		    FastMapFreeNode(&map, node);
		}
	    }
	}
    }
}

- (void) removeAllObjects
{
    FastMapCleanMap(&map);
}

@end
