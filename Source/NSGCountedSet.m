/* Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1998 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <richard@brainstorm.co.uk>
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <Foundation/NSSet.h>
#include <base/behavior.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPortCoder.h>


#define	GSI_MAP_RETAIN_VAL(X)	
#define	GSI_MAP_RELEASE_VAL(X)	
#define GSI_MAP_KTYPES	GSUNION_OBJ
#define GSI_MAP_VTYPES	GSUNION_INT

#include <base/GSIMap.h>

@class	NSSetNonCore;
@class	NSMutableSetNonCore;

@interface NSGCountedSet : NSCountedSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface NSGCountedSetEnumerator : NSEnumerator
{
  NSGCountedSet	*set;
  GSIMapNode	node;
}
@end

@implementation NSGCountedSetEnumerator

- (id) initWithSet: (NSSet*)d
{
  self = [super init];
  if (self)
    {
      set = RETAIN((NSGCountedSet*)d);
      node = set->map.firstNode;
    }
  return self;
}

- (id) nextObject
{
  GSIMapNode old = node;

  if (node == 0)
    {
      return nil;
    }
  node = node->nextInMap;
  return old->key.obj;
}

- (void) dealloc
{
  RELEASE(set);
  [super dealloc];
}

@end


@implementation NSGCountedSet

+ (void) initialize
{
  if (self == [NSGCountedSet class])
    {
      class_add_behavior(self, [NSSetNonCore class]);
      class_add_behavior(self, [NSMutableSetNonCore class]);
    }
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
  SEL		sel1 = @selector(encodeObject:);
  IMP		imp1 = [aCoder methodForSelector: sel1];
  SEL		sel2 = @selector(encodeValueOfObjCType:at:);
  IMP		imp2 = [aCoder methodForSelector: sel2];
  const char	*type = @encode(unsigned);

  (*imp2)(aCoder, sel2, type, &count);

  while (node != 0)
    {
      (*imp1)(aCoder, sel1, node->key.obj);
      (*imp2)(aCoder, sel2, type, &node->value.uint);
      node = node->nextInMap;
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;
  id		value;
  unsigned	valcnt;
  SEL		sel = @selector(decodeValueOfObjCType:at:);
  IMP		imp = [aCoder methodForSelector: sel];
  const char	*utype = @encode(unsigned);
  const char	*otype = @encode(id);

  (*imp)(aCoder, sel, utype, &count);

  GSIMapInitWithZoneAndCapacity(&map, [self zone], count);
  while (count-- > 0)
    {
      (*imp)(aCoder, sel, otype, &value);
      (*imp)(aCoder, sel, utype, &valcnt);
      GSIMapAddPairNoRetain(&map, (GSIMapKey)value, (GSIMapVal)valcnt);
    }

  return self;
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
  GSIMapInitWithZoneAndCapacity(&map, [self zone], cap);
  return self;
}

- (id) initWithObjects: (id*)objs count: (unsigned)c
{
  int i;

  if ([self initWithCapacity: c] == nil)
    {
      return nil;
    }
  for (i = 0; i < c; i++)
    {
      GSIMapNode     node;

      if (objs[i] == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init counted set with nil value"];
	}
      node = GSIMapNodeForKey(&map, (GSIMapKey)objs[i]);
      if (node == 0)
	{
	  GSIMapAddPair(&map,(GSIMapKey)objs[i],(GSIMapVal)(unsigned)1);
        }
      else
	{
	  node->value.uint++;
	}
    }
  return self;
}

- (void) addObject: (NSObject*)anObject
{
  GSIMapNode node;

  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to nil value to counted set"];
    }

  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
  if (node == 0)
    {
      GSIMapAddPair(&map,(GSIMapKey)anObject,(GSIMapVal)(unsigned)1);
    }
  else
    {
      node->value.uint++;
    }
}

- (unsigned) count
{
  return map.nodeCount;
}

- (unsigned) countForObject: (id)anObject
{
  if (anObject)
    {
      GSIMapNode node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);

      if (node)
	{
	  return node->value.uint;
	}
    }
  return 0;
}

- (unsigned) hash
{
  return map.nodeCount;
}

- (id) member: (id)anObject
{
  if (anObject)
    {
      GSIMapNode node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);

      if (node)
	{
	  return node->key.obj;
	}
    }
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[NSGCountedSetEnumerator allocWithZone:
    NSDefaultMallocZone()] initWithSet: self]);
}

- (void) removeObject: (NSObject*)anObject
{
  if (anObject)
    {
      GSIMapBucket       bucket;

      bucket = GSIMapBucketForKey(&map, (GSIMapKey)anObject);
      if (bucket)
	{
	  GSIMapNode     node;

	  node = GSIMapNodeForKeyInBucket(bucket, (GSIMapKey)anObject);
	  if (node)
	    {
	      if (--node->value.uint == 0)
		{
		  GSIMapRemoveNodeFromMap(&map, bucket, node);
		  GSIMapFreeNode(&map, node);
		}
	    }
	}
    }
}

- (void) removeAllObjects
{
  GSIMapCleanMap(&map);
}

@end
