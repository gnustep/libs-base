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
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>
#include <gnustep/base/Coding.h>

#include <gnustep/base/fast.x>

/*
 *	Evil hack - this structure MUST correspond to the layout of all
 *	instances of the string classes we know about!
 */
typedef struct {
    Class	*isa;
    char	*_contents_chars;
    int		_count;
    NSZone	*_zone;
    unsigned	_hash;
} *dictAccessToStringHack;

static INLINE unsigned
myHash(NSObject *obj)
{
    if (fastIsInstance(obj)) {
	Class	c = fastClass(obj);

	if (c == _fastCls._NXConstantString ||
	    c == _fastCls._NSGCString ||
	    c == _fastCls._NSGMutableCString ||
	    c == _fastCls._NSGString ||
	    c == _fastCls._NSGMutableString) {

	    if (((dictAccessToStringHack)obj)->_hash == 0) {
	        ((dictAccessToStringHack)obj)->_hash =
	            _fastImp._NSString_hash(obj, @selector(hash));
	    }
	    return ((dictAccessToStringHack)obj)->_hash;
	}
    }
    return [obj hash];
}

static INLINE BOOL
myEqual(NSObject *self, NSObject *other)
{
    if (self == other) {
	return YES;
    }
    if (fastIsInstance(self)) {
	Class	c = fastClass(self);

	if (c == _fastCls._NXConstantString ||
	    c == _fastCls._NSGCString ||
	    c == _fastCls._NSGMutableCString) {
	    return _fastImp._NSGCString_isEqual_(self,
		@selector(isEqual:), other);
	}
	if (c == _fastCls._NSGString ||
	    c == _fastCls._NSGMutableString) {
	    return _fastImp._NSGString_isEqual_(self,
		@selector(isEqual:), other);
	}
    }
    return [self isEqual: other];
}

/*
 *	The 'Fastmap' stuff provides an inline implementation of a mapping
 *	table - for maximum performance.
 */
#define	FAST_MAP_HASH(X)	myHash(X.o)
#define	FAST_MAP_EQUAL(X,Y)	myEqual(X.o,Y.o)

#include	"FastMap.x"

@class	NSDictionaryNonCore;
@class	NSMutableDictionaryNonCore;

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

@interface NSGDictionaryKeyEnumerator : NSEnumerator
{
    NSGDictionary	*dictionary;
    FastMapNode		node;
}
@end

@interface NSGDictionaryObjectEnumerator : NSGDictionaryKeyEnumerator
@end

@implementation NSGDictionary

+ (void) initialize
{
    if (self == [NSGDictionary class]) {
        behavior_class_add_class(self, [NSDictionaryNonCore class]);
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

    if ([aCoder isKindOfClass: [NSPortCoder class]] &&
        [(NSPortCoder*)aCoder isBycopy]) {
	while (node != 0) {
	    [(id<Encoding>)aCoder encodeBycopyObject: node->key.o
					    withName: @"Dictionary key"];
	    [(id<Encoding>)aCoder encodeBycopyObject: node->value.o
					    withName: @"Dictionary content"];
	    node = node->nextInMap;
	}
    }
    else {
	while (node != 0) {
	    [(id<Encoding>)aCoder encodeObject: node->key.o
				      withName: @"Dictionary key"];
	    [(id<Encoding>)aCoder encodeObject: node->value.o
				      withName: @"Dictionary content"];
	    node = node->nextInMap;
	}
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

    FastMapInitWithZoneAndCapacity(&map, fastZone(self), count);
    while (count-- > 0) {
	[(id<Decoding>)aCoder decodeObjectAt: &key withName: NULL];
	[(id<Decoding>)aCoder decodeObjectAt: &value withName: NULL];
	FastMapAddPairNoRetain(&map, (FastMapItem)key, (FastMapItem)value);
    }
    
    return self;
}

/* Designated initialiser */
- (id) initWithObjects: (id*)objs forKeys: (NSObject**)keys count: (unsigned)c
{
    int	i;
    FastMapInitWithZoneAndCapacity(&map, fastZone(self), c);
    for (i = 0; i < c; i++) {
	FastMapNode	node = FastMapNodeForKey(&map, (FastMapItem)keys[i]);

	if (keys[i] == nil) {
	    [self autorelease];
	    [NSException raise: NSInvalidArgumentException
			format: @"Tried to init dictionary with nil key"];
	}
	if (objs[i] == nil) {
	    [self autorelease];
	    [NSException raise: NSInvalidArgumentException
			format: @"Tried to init dictionary with nil value"];
	}

	node = FastMapNodeForKey(&map, (FastMapItem)keys[i]);
	if (node) {
	    [objs[i] retain];
	    [node->value.o release];
	    node->value.o = objs[i];
	}
	else {
	    FastMapAddPair(&map, (FastMapItem)keys[i], (FastMapItem)objs[i]);
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
    if (aKey != nil) {
	FastMapNode	node  = FastMapNodeForKey(&map, (FastMapItem)aKey);

	if (node) {
	    return node->value.o;
	}
    }
    return nil;
}

@end

@implementation NSGMutableDictionary

+ (void) initialize
{
    if (self == [NSGMutableDictionary class]) {
        behavior_class_add_class(self, [NSMutableDictionaryNonCore class]);
        behavior_class_add_class(self, [NSGDictionary class]);
    }
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
    FastMapInitWithZoneAndCapacity(&map, fastZone(self), cap);
    return self;
}

- (void) setObject: (NSObject*)anObject forKey: (NSObject *)aKey
{
    FastMapNode	node;

    if (aKey == nil) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Tried to add nil key to dictionary"];
    }
    if (anObject == nil) {
	[NSException raise: NSInvalidArgumentException
		    format: @"Tried to add nil value to dictionary"];
    }
    node = FastMapNodeForKey(&map, (FastMapItem)aKey);
    if (node) {
	[anObject retain];
	[node->value.o release];
	node->value.o = anObject;
    }
    else {
	FastMapAddPair(&map, (FastMapItem)aKey, (FastMapItem)anObject);
    }
}

- (void) removeAllObjects
{
    FastMapCleanMap(&map);
}

- (void) removeObjectForKey: (NSObject *)aKey
{
    if (aKey) {
	FastMapRemoveKey(&map, (FastMapItem)aKey);
    }
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
    return old->key.o;
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
    return old->value.o;
}

@end
