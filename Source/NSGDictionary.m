/* Interface to concrete implementation of NSDictionary
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 1998

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
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <gnustep/base/Coding.h>

/*
 *	The 'Fastmap' stuff provides an inline implementation of a mapping
 *	table - for maximum performance.
 */
#include	"FastMap.x"

@class	NSDictionaryNonCore;
@class	NSMutableDictionaryNonCore;
@class	NSGDictionary;
@class	NSGMutableDictionary;

@interface NSGDictionaryKeyEnumerator : NSEnumerator
{
    NSGDictionary	*dictionary;
    FastMapNode		node;
}
@end

@interface NSGDictionaryObjectEnumerator : NSGDictionaryKeyEnumerator
@end

@interface NSGDictionary : NSDictionary
{
@public
    FastMapTable_t	map;
}
@end

@interface NSGMutableDictionary : NSMutableDictionary
{
@public
    FastMapTable_t	map;
}
@end

@implementation NSGDictionary

+ (void) initialize
{
  if (self == [NSGDictionary class])
    {
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
    }
}

- (unsigned) count
{
    return map.nodeCount;
}

- (void) dealloc
{
    FastMapEmptyMap(&map);
    [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    unsigned	count = map.nodeCount;
    FastMapNode	node = map.firstNode;

    [(id<Encoding>)aCoder encodeValueOfCType: @encode(unsigned)
					  at: &count
				    withName: @"Dictionary content count"];

    while (node != 0) {
	[(id<Encoding>)aCoder encodeObject: node->key
				  withName: @"Dictionary key"];
	[(id<Encoding>)aCoder encodeObject: node->value
				  withName: @"Dictionary content"];
	node = node->nextInMap;
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned    count;
    id		key;
    id		value;

    [(id<Decoding>)aCoder decodeValueOfCType: @encode(unsigned)
					  at: &count
				    withName: NULL];

    FastMapInitWithZoneAndCapacity(&map, [self zone], count);
    while (count-- > 0) {
	[(id<Decoding>)aCoder decodeObjectAt: &key withName: NULL];
	[(id<Decoding>)aCoder decodeObjectAt: &value withName: NULL];
	FastMapAddPairNoRetain(&map, key, value);
    }
    
    return self;
}

- (id) initWithObjects: (id*)objs forKeys: (NSObject**)keys count: (unsigned)c
{
    int	i;
    FastMapInitWithZoneAndCapacity(&map, [self zone], c);
    for (i = 0; i < c; i++) {
	FastMapNode	node = FastMapNodeForKey(&map, keys[i]);

	if (node) {
	    [objs[i] retain];
	    [node->value release];
	    node->value = objs[i];
	}
	else {
	    FastMapAddPair(&map, keys[i], objs[i]);
	}
    }
    return self;
}

- (NSEnumerator*) keyEnumerator
{
    return [[[NSGDictionaryKeyEnumerator alloc] initWithDictionary: self]
		autorelease];
}

- (NSEnumerator*) objectEnumerator
{
    return [[[NSGDictionaryObjectEnumerator alloc] initWithDictionary: self]
		autorelease];
}

- (id) objectForKey: aKey
{
    FastMapNode	node = FastMapNodeForKey(&map, aKey);

    if (node)
	return node->value;
    return nil;
}

@end

@implementation NSGMutableDictionary

+ (void) initialize
{
  if (self == [NSGMutableDictionary class])
    {
      behavior_class_add_class (self, [NSMutableDictionaryNonCore class]);
      behavior_class_add_class (self, [NSGDictionary class]);
    }
}

- (id) initWithCapacity: (unsigned)cap
{
    FastMapInitWithZoneAndCapacity(&map, [self zone], cap);
    return self;
}

- (void) setObject:anObject forKey:(NSObject *)aKey
{
    FastMapNode	node = FastMapNodeForKey(&map, aKey);

    if (node) {
	[anObject retain];
	[node->value release];
	node->value = anObject;
    }
    else {
	FastMapAddPair(&map, aKey, anObject);
    }
}

- (void) removeObjectForKey:(NSObject *)aKey
{
    FastMapRemoveKey(&map, aKey);
}

@end

@implementation NSGDictionaryKeyEnumerator

- (id) initWithDictionary: (NSDictionary*)d
{
    [super init];
    dictionary = (NSGDictionary*)[d retain];
    node = dictionary->map.firstNode;
    return self;
}

- nextObject
{
    FastMapNode	old = node;

    if (node == 0) {
	return nil;
    }
    node = node->nextInMap;
    return old->key;
}

- (void) dealloc
{
  [dictionary release];
  [super dealloc];
}

@end

@implementation NSGDictionaryObjectEnumerator

- nextObject
{
    FastMapNode	old = node;

    if (node == 0) {
	return nil;
    }
    node = node->nextInMap;
    return old->value;
}

@end
