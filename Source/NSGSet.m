/* Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: September 1995
   Rewrite by:  Richard frith-Macdonald <richard@brainstorm.co.uk>
   
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
#include <Foundation/NSSet.h>
#include <base/behavior.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPortCoder.h>

#define	GSI_MAP_HAS_VALUE	0
#define	GSI_MAP_KTYPES		GSUNION_OBJ

#include <base/GSIMap.h>

@class	NSSetNonCore;
@class	NSMutableSetNonCore;

@interface NSGSet : NSSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface NSGMutableSet : NSMutableSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface NSGSetEnumerator : NSEnumerator
{
  NSGSet	*set;
  GSIMapNode	node;
}
@end

@implementation NSGSetEnumerator

- initWithSet: (NSSet*)d
{
  [super init];
  set = (NSGSet*)RETAIN(d);
  node = set->map.firstNode;
  return self;
}

- nextObject
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


@implementation NSGSet

+ (void) initialize
{
  if (self == [NSGSet class])
    {
      class_add_behavior(self, [NSSetNonCore class]);
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
  id		value;
  SEL		sel = @selector(decodeValueOfObjCType:at:);
  IMP		imp = [aCoder methodForSelector: sel];
  const char	*type = @encode(id);

  (*imp)(aCoder, sel, @encode(unsigned), &count);

  GSIMapInitWithZoneAndCapacity(&map, [self zone], count);
  while (count-- > 0)
    {
      (*imp)(aCoder, sel, type, &value);
      GSIMapAddKeyNoRetain(&map, (GSIMapKey)value);
    }

  return self;
}

/* Designated initialiser */
- (id) initWithObjects: (id*)objs count: (unsigned)c
{
  int i;

  GSIMapInitWithZoneAndCapacity(&map, [self zone], c);
  for (i = 0; i < c; i++)
    {
      GSIMapNode     node;

      if (objs[i] == nil)
	{
	  AUTORELEASE(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init set with nil value"];
	}
      node = GSIMapNodeForKey(&map, (GSIMapKey)objs[i]);
      if (node == 0)
	{
	  GSIMapAddKey(&map, (GSIMapKey)objs[i]);
        }
    }
  return self;
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
  return AUTORELEASE([[NSGSetEnumerator alloc] initWithSet: self]);
}

@end

@implementation NSGMutableSet

+ (void) initialize
{
  if (self == [NSGMutableSet class])
    {
      class_add_behavior(self, [NSMutableSetNonCore class]);
      class_add_behavior(self, [NSGSet class]);
    }
}

/* Designated initialiser */
- (id) initWithCapacity: (unsigned)cap
{
  GSIMapInitWithZoneAndCapacity(&map, [self zone], cap);
  return self;
}

- (void) addObject: (NSObject*)anObject
{
  GSIMapNode node;

  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to add nil to  set"];
    }
  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
  if (node == 0)
    {
      GSIMapAddKey(&map, (GSIMapKey)anObject);
    }
}

- (void) removeObject: (NSObject *)anObject
{
  if (anObject)
    {
      GSIMapRemoveKey(&map, (GSIMapKey)anObject);
    }
}

- (void) removeAllObjects
{
  GSIMapCleanMap(&map);
}

@end
