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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <Foundation/NSSet.h>
#include <base/behavior.h>
#include <base/fast.x>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSDebug.h>

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

- (id) initWithSet: (NSSet*)d
{
  self = [super init];
  if (self != nil)
    {
      set = (NSGSet*)RETAIN(d);
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


@implementation NSGSet

static Class	arrayClass;
static Class	setClass;
static Class	mutableSetClass;

+ (void) initialize
{
  if (self == [NSGSet class])
    {
      class_add_behavior(self, [NSSetNonCore class]);
      arrayClass = [NSArray class];
      setClass = [NSGSet class];
      mutableSetClass = [NSGMutableSet class];
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
	  IF_NO_GC(AUTORELEASE(self));
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

@implementation	NSGSet (NonCore)

- (NSArray*) allObjects
{
  id		objs[map.nodeCount];
  GSIMapNode	node = map.firstNode;
  unsigned	i = 0;

  while (node != 0)
    {
      objs[i++] = node->key.obj;
      node = node->nextInMap;
    }
  return AUTORELEASE([[arrayClass allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objs count: i]);
}

- (id) anyObject
{
  if (map.nodeCount > 0)
    return map.firstNode->key.obj;
  else
    return nil;
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

- (BOOL) intersectsSet: (NSSet*) otherSet
{
  Class	c;

  /*
   *  If this set is empty, or the other is nil, this method should return NO.
   */
  if (map.nodeCount == 0)
    return NO;
  if (otherSet == nil)
    return NO;

  // Loop for all members in otherSet
  c = fastClass(otherSet);
  if (c == setClass || c == mutableSetClass)
    {
      GSIMapNode	node = ((NSGSet*)otherSet)->map.firstNode;

      while (node != 0)
	{
	  if (GSIMapNodeForKey(&map, node->key) != 0)
	    {
	      return YES;
	    }
	  node = node->nextInMap;
	}
    }
  else
    {
      NSEnumerator	*e;
      id		o;

      e = [otherSet objectEnumerator];
      while ((o = [e nextObject])) // 1. pick a member from otherSet.
	{
	  if (GSIMapNodeForKey(&map, (GSIMapKey)o) != 0)
	    {
	      return YES;
	    }
	}
    }
  return NO;
}

- (BOOL) isSubsetOfSet: (NSSet*) otherSet
{
  GSIMapNode	node = map.firstNode;

  // -1. members of this set(self) <= that of otherSet
  if (map.nodeCount > [otherSet count])
    return NO;

  // 0. Loop for all members in this set(self).
  while (node != 0)
    {
      // 1. check the member is in the otherSet.
      if ([otherSet member: node->key.obj])
       {
         // 1.1 if true -> continue, try to check the next member.
         node = node->nextInMap;
       }
      else
       {
         // 1.2 if false -> return NO;
         return NO;
       }
    }
  // 2. return YES; all members in this set are also in the otherSet.
  return YES;
}

- (BOOL) isEqualToSet: (NSSet*)other
{
  if (other == nil)
    {
      return NO;
    }
  else if (other == self)
    {
      return YES;
    }
  else
    {
      Class	c = fastClass(other);

      if (c == setClass || c == mutableSetClass)
	{
	  if (map.nodeCount != ((NSGSet*)other)->map.nodeCount)
	    {
	      return NO;
	    }
	  else
	    {
	      GSIMapNode	node = map.firstNode;

	      while (node != 0)
		{
		  if (GSIMapNodeForKey(&(((NSGSet*)other)->map), node->key)
		    == 0)
		    {
		      return NO;
		    }
		  node = node->nextInMap;
		}
	    }
	}
      else
	{
	  if (map.nodeCount != [other count])
	    {
	      return NO;
	    }
	  else
	    {
	      GSIMapNode	node = map.firstNode;

	      while (node != 0)
		{
		  if ([other member: node->key.obj] == nil)
		    {
		      return NO;
		    }
		  node = node->nextInMap;
		}
	    }
	}
      return YES;
    }
}

- (void) makeObjectsPerform: (SEL)aSelector
{
  GSIMapNode	node = map.firstNode;

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector];
      node = node->nextInMap;
    }
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  GSIMapNode	node = map.firstNode;

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector];
      node = node->nextInMap;
    }
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: argument
{
  GSIMapNode	node = map.firstNode;

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector withObject: argument];
      node = node->nextInMap;
    }
}

- (void) makeObjectsPerform: (SEL)aSelector withObject: argument
{
  GSIMapNode	node = map.firstNode;

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector withObject: argument];
      node = node->nextInMap;
    }
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

- (id) initWithObjects: (id*)objects
		 count: (unsigned)count
{
  self = [self initWithCapacity: count];

  while (count--)
    {
      id	anObject = objects[count];

      if (anObject == nil)
	{
	  NSLog(@"Tried to init a set with a nil object");
	  continue;
	}
      else
	{
	  GSIMapNode node;

	  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
	  if (node == 0)
	    {
	      GSIMapAddKey(&map, (GSIMapKey)anObject);
	    }
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
		  format: @"Tried to add nil to set"];
    }
  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
  if (node == 0)
    {
      GSIMapAddKey(&map, (GSIMapKey)anObject);
    }
}

- (void) removeObject: (NSObject *)anObject
{
  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object", 0);
      return;
    }
  GSIMapRemoveKey(&map, (GSIMapKey)anObject);
}

- (void) removeAllObjects
{
  GSIMapCleanMap(&map);
}

@end

@implementation NSGMutableSet (NonCore)

- (void) addObjectsFromArray: (NSArray*)array
{
  unsigned	count = [array count];

  while (count--)
    {
      id	anObject = [array objectAtIndex: count];

      if (anObject == nil)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to add nil to set"];
	}
      else
	{
	  GSIMapNode node;

	  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
	  if (node == 0)
	    {
	      GSIMapAddKey(&map, (GSIMapKey)anObject);
	    }
	}
    }
}

- (void) unionSet: (NSSet*) other
{
  if (other != self)
    {
      NSEnumerator	*e = [other objectEnumerator];
      id		anObject;

      while ((anObject = [e nextObject]) != nil)
	{
	  GSIMapNode node;

	  if (anObject == nil)
	    {
	      [NSException raise: NSInvalidArgumentException
			  format: @"Tried to add nil to set"];
	    }
	  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
	  if (node == 0)
	    {
	      GSIMapAddKey(&map, (GSIMapKey)anObject);
	    }
	}
    }
}

- (void) intersectSet: (NSSet*) other
{
  if (other != self)
    {
      GSIMapNode	node = map.firstNode;

      while (node != 0)
	{
	  GSIMapNode	next = node->nextInMap;

	  if ([other containsObject: node->key.obj] == NO)
	    {
	      GSIMapRemoveKey(&map, node->key);
	    }
	  node = next;
	}
    }
}

- (void) minusSet: (NSSet*) other
{
  if (other == self)
    {
      GSIMapCleanMap(&map);
    }
  else
    {
      NSEnumerator	*e = [other objectEnumerator];
      id		anObject;

      while ((anObject = [e nextObject]) != nil)
	{
	  GSIMapRemoveKey(&map, (GSIMapKey)anObject);
	}
    }
}

@end
