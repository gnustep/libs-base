/** Interface to concrete implementation of NSDictionary
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */


#include <config.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSDebug.h>

#include <base/behavior.h>

/*
 *	The 'Fastmap' stuff provides an inline implementation of a mapping
 *	table - for maximum performance.
 */
#define	GSI_MAP_KTYPES		GSUNION_OBJ
#define	GSI_MAP_VTYPES		GSUNION_OBJ
#ifdef	GSI_NEW
#define	GSI_MAP_HASH(M, X)		[X.obj hash]
#define	GSI_MAP_EQUAL(M, X,Y)		[X.obj isEqual: Y.obj]
#define	GSI_MAP_RETAIN_KEY(M, X)	((id)(X).obj) = \
				[((id)(X).obj) copyWithZone: map->zone]
#else
#define	GSI_MAP_HASH(X)		[X.obj hash]
#define	GSI_MAP_EQUAL(X,Y)		[X.obj isEqual: Y.obj]
#define	GSI_MAP_RETAIN_KEY(X)	((id)(X).obj) = \
				[((id)(X).obj) copyWithZone: map->zone]
#endif

#include	<base/GSIMap.h>

@interface GSDictionary : NSDictionary
{
@public
  GSIMapTable_t	map;
}
@end

@interface GSMutableDictionary : NSMutableDictionary
{
@public
  GSIMapTable_t	map;
}
@end

@interface GSDictionaryKeyEnumerator : NSEnumerator
{
  GSDictionary		*dictionary;
  GSIMapEnumerator_t	enumerator;
}
@end

@interface GSDictionaryObjectEnumerator : GSDictionaryKeyEnumerator
@end

@implementation GSDictionary

static SEL	nxtSel;
static SEL	objSel;

+ (void) initialize
{
  if (self == [GSDictionary class])
    {
      nxtSel = @selector(nextObject);
      objSel = @selector(objectForKey:);
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
  SEL		sel = @selector(encodeObject:);
  IMP		imp = [aCoder methodForSelector: sel];
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  while (node != 0)
    {
      (*imp)(aCoder, sel, node->key.obj);
      (*imp)(aCoder, sel, node->value.obj);
      node = GSIMapEnumeratorNextNode(&enumerator);
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

  GSIMapInitWithZoneAndCapacity(&map, GSObjCZone(self), count);
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

  GSIMapInitWithZoneAndCapacity(&map, GSObjCZone(self), c);
  for (i = 0; i < c; i++)
    {
      GSIMapNode	node;

      if (keys[i] == nil)
	{
	  IF_NO_GC(AUTORELEASE(self));
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil key"];
	}
      if (objs[i] == nil)
	{
	  IF_NO_GC(AUTORELEASE(self));
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init dictionary with nil value"];
	}

      node = GSIMapNodeForKey(&map, (GSIMapKey)keys[i]);
      if (node)
	{
	  IF_NO_GC(RETAIN(objs[i]));
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
  NSZone	*z = GSObjCZone(self);
  unsigned	c = [other count];

  GSIMapInitWithZoneAndCapacity(&map, z, c);

  if (c > 0)
    {
      NSEnumerator	*e = [other keyEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      IMP		otherObj = [other methodForSelector: objSel];
      unsigned		i;

      for (i = 0; i < c; i++)
	{
	  GSIMapNode	node;
	  id		k = (*nxtObj)(e, nxtSel);
	  id		o = (*otherObj)(other, objSel, k);

	  k = [k copyWithZone: z];
	  if (k == nil)
	    {
	      IF_NO_GC(AUTORELEASE(self));
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
	      IF_NO_GC(AUTORELEASE(self));
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
    }
  return self;
}

- (NSEnumerator*) keyEnumerator
{
  return AUTORELEASE([[GSDictionaryKeyEnumerator allocWithZone:
    NSDefaultMallocZone()] initWithDictionary: self]);
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[GSDictionaryObjectEnumerator allocWithZone:
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

@implementation GSMutableDictionary

+ (void) initialize
{
  if (self == [GSMutableDictionary class])
    {
      behavior_class_add_class(self, [GSDictionary class]);
    }
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
  GSIMapInitWithZoneAndCapacity(&map, GSObjCZone(self), cap);
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
      IF_NO_GC(RETAIN(anObject));
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
  if (aKey == nil)
    {
      NSWarnMLog(@"attempt to remove nil key");
      return;
    }
  GSIMapRemoveKey(&map, (GSIMapKey)aKey);
}

@end

@implementation GSDictionaryKeyEnumerator

- (id) initWithDictionary: (NSDictionary*)d
{
  [super init];
  dictionary = (GSDictionary*)RETAIN(d);
  enumerator = GSIMapEnumeratorForMap(&dictionary->map);
  return self;
}

- (id) nextObject
{
  GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);

  if (node == 0)
    {
      return nil;
    }
  return node->key.obj;
}

- (void) dealloc
{
  RELEASE(dictionary);
  [super dealloc];
}

@end

@implementation GSDictionaryObjectEnumerator

- (id) nextObject
{
  GSIMapNode	node = GSIMapEnumeratorNextNode(&enumerator);

  if (node == 0)
    {
      return nil;
    }
  return node->value.obj;
}

@end



@interface	NSGDictionary : NSDictionary
@end
@implementation	NSGDictionary
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSDictionary class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

@interface	NSGMutableDictionary : NSMutableDictionary
@end
@implementation	NSGMutableDictionary
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSMutableDictionary class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

