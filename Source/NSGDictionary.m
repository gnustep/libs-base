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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */


#include <config.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>

#include <base/behavior.h>
#include <base/fast.x>

/*
 *	Evil hack - this structure MUST correspond to the layout of all
 *	instances of the string classes we know about!
 */
typedef struct {
  @defs(NSGCString)
} *dictAccessToStringHack;

static inline unsigned
myHash(id obj)
{
  if (fastIsInstance(obj))
    {
      Class	c = fastClass(obj);

      if (c == _fastCls._NSGCString ||
	  c == _fastCls._NSGMutableCString ||
	  c == _fastCls._NSGString ||
	  c == _fastCls._NSGMutableString)
	{
	  if (((dictAccessToStringHack)obj)->_hash == 0)
	    {
	      ((dictAccessToStringHack)obj)->_hash =
	            _fastImp._NSString_hash(obj, @selector(hash));
	    }
	  return ((dictAccessToStringHack)obj)->_hash;
	}
      else if (c == _fastCls._NXConstantString)
	{
	  return _fastImp._NSString_hash(obj, @selector(hash));
	}
    }
  return [obj hash];
}

static inline BOOL
myEqual(id self, id other)
{
  if (self == other)
    {
      return YES;
    }
  if (fastIsInstance(self))
    {
      Class	c = fastClass(self);

      if (c == _fastCls._NXConstantString ||
	  c == _fastCls._NSGCString ||
	  c == _fastCls._NSGMutableCString)
	{
	  return _fastImp._NSGCString_isEqual_(self,
		@selector(isEqual:), other);
	}
      if (c == _fastCls._NSGString ||
	  c == _fastCls._NSGMutableString)
	{
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
#define	GSI_MAP_KTYPES		GSUNION_OBJ
#define	GSI_MAP_VTYPES		GSUNION_OBJ
#define	GSI_MAP_HASH(X)	myHash(X.obj)
#define	GSI_MAP_EQUAL(X,Y)	myEqual(X.obj,Y.obj)
#define	GSI_MAP_RETAIN_KEY(X)	((id)(X).obj) = \
				[((id)(X).obj) copyWithZone: map->zone]

#include	<base/GSIMap.h>

@class	NSDictionaryNonCore;
@class	NSMutableDictionaryNonCore;

@interface NSGDictionary : NSDictionary
{
@public
  GSIMapTable_t	map;
}
@end

@interface NSGMutableDictionary : NSMutableDictionary
{
@public
  GSIMapTable_t	map;
}
@end

@interface NSGDictionaryKeyEnumerator : NSEnumerator
{
  NSGDictionary	*dictionary;
  GSIMapNode	node;
}
@end

@interface NSGDictionaryObjectEnumerator : NSGDictionaryKeyEnumerator
@end

@implementation NSGDictionary

+ (void) initialize
{
  if (self == [NSGDictionary class])
    {
      behavior_class_add_class(self, [NSDictionaryNonCore class]);
    }
}

- (unsigned) count
{
  return map.nodeCount;
}

- (void) dealloc
{
  GSIMapEmptyMap(&map);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	count = map.nodeCount;
  GSIMapNode	node = map.firstNode;
  SEL		sel = @selector(encodeObject:);
  IMP		imp = [aCoder methodForSelector: sel];

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  while (node != 0)
    {
      (*imp)(aCoder, sel, node->key.obj);
      (*imp)(aCoder, sel, node->value.obj);
      node = node->nextInMap;
    }
}

- (unsigned) hash
{
  return map.nodeCount;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;
  id		key;
  id		value;
  SEL		sel = @selector(decodeValueOfObjCType:at:);
  IMP		imp = [aCoder methodForSelector: sel];
  const char	*type = @encode(id);

  [aCoder decodeValueOfObjCType: @encode(unsigned)
			     at: &count];

  GSIMapInitWithZoneAndCapacity(&map, fastZone(self), count);
  while (count-- > 0)
    {
      (*imp)(aCoder, sel, type, &key);
      (*imp)(aCoder, sel, type, &value);
      GSIMapAddPairNoRetain(&map, (GSIMapKey)key, (GSIMapVal)value);
    }
  return self;
}

/* Designated initialiser */
- (id) initWithObjects: (id*)objs forKeys: (id*)keys count: (unsigned)c
{
  int	i;

  GSIMapInitWithZoneAndCapacity(&map, fastZone(self), c);
  for (i = 0; i < c; i++)
    {
      GSIMapNode	node;

      if (keys[i] == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil key"];
	}
      if (objs[i] == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil value"];
	}

      node = GSIMapNodeForKey(&map, (GSIMapKey)keys[i]);
      if (node)
	{
	  RETAIN(objs[i]);
	  RELEASE(node->value.obj);
	  node->value.obj = objs[i];
	}
      else
	{
	  GSIMapAddPair(&map, (GSIMapKey)keys[i], (GSIMapVal)objs[i]);
	}
    }
  return self;
}

/*
 *	This avoids using the designated initialiser for performance reasons.
 */
- (id) initWithDictionary: (NSDictionary*)other
		copyItems: (BOOL)shouldCopy
{
  NSEnumerator	*e = [other keyEnumerator];
  NSZone	*z = fastZone(self);
  unsigned	c = [other count];
  unsigned	i;

  GSIMapInitWithZoneAndCapacity(&map, z, c);
  for (i = 0; i < c; i++)
    {
      GSIMapNode	node;
      id		k = [e nextObject];
      id		o = [other objectForKey: k];

      k = [k copyWithZone: z];
      if (k == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil key"];
	}
      if (shouldCopy)
	{
	  o = [o copyWithZone: z];
	}
      else
	{
	  o = RETAIN(o);
	}
      if (o == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil value"];
	}

      node = GSIMapNodeForKey(&map, (GSIMapKey)k);
      if (node)
	{
	  RELEASE(node->value.obj);
	  node->value.obj = o;
	}
      else
	{
	  GSIMapAddPairNoRetain(&map, (GSIMapKey)k, (GSIMapVal)o);
	}
    }
  return self;
}

- (NSEnumerator*) keyEnumerator
{
  return AUTORELEASE([[NSGDictionaryKeyEnumerator allocWithZone:
    NSDefaultMallocZone()] initWithDictionary: self]);
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[NSGDictionaryObjectEnumerator allocWithZone:
    NSDefaultMallocZone()] initWithDictionary: self]);
}

- (id) objectForKey: aKey
{
  if (aKey != nil)
    {
      GSIMapNode	node  = GSIMapNodeForKey(&map, (GSIMapKey)aKey);

      if (node)
	{
	  return node->value.obj;
	}
    }
  return nil;
}

@end

@implementation NSGMutableDictionary

+ (void) initialize
{
  if (self == [NSGMutableDictionary class])
    {
      behavior_class_add_class(self, [NSMutableDictionaryNonCore class]);
      behavior_class_add_class(self, [NSGDictionary class]);
    }
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
  GSIMapInitWithZoneAndCapacity(&map, fastZone(self), cap);
  return self;
}

- (void) setObject: (id)anObject forKey: (id)aKey
{
  GSIMapNode	node;

  if (aKey == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to add nil key to dictionary"];
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to add nil value to dictionary"];
    }
  node = GSIMapNodeForKey(&map, (GSIMapKey)aKey);
  if (node)
    {
      RETAIN(anObject);
      RELEASE(node->value.obj);
      node->value.obj = anObject;
    }
  else
    {
      GSIMapAddPair(&map, (GSIMapKey)aKey, (GSIMapVal)anObject);
    }
}

- (void) removeAllObjects
{
  GSIMapCleanMap(&map);
}

- (void) removeObjectForKey: (id)aKey
{
  if (aKey)
    {
      GSIMapRemoveKey(&map, (GSIMapKey)aKey);
    }
}

@end

@implementation NSGDictionaryKeyEnumerator

- (id) initWithDictionary: (NSDictionary*)d
{
  [super init];
  dictionary = (NSGDictionary*)RETAIN(d);
  node = dictionary->map.firstNode;
  return self;
}

- (id) nextObject
{
  GSIMapNode	old = node;

  if (node == 0)
    {
      return nil;
    }
  node = node->nextInMap;
  return old->key.obj;
}

- (void) dealloc
{
  RELEASE(dictionary);
  [super dealloc];
}

@end

@implementation NSGDictionaryObjectEnumerator

- (id) nextObject
{
  GSIMapNode	old = node;

  if (node == 0)
    {
      return nil;
    }
  node = node->nextInMap;
  return old->value.obj;
}

@end
