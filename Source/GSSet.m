/** Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1995, 1996, 1998, 2000 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: September 1995
   Rewrite by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   
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
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSObjCRuntime.h>

#define	GSI_MAP_HAS_VALUE	0
#define	GSI_MAP_KTYPES		GSUNION_OBJ

#include <base/GSIMap.h>

@interface GSSet : NSSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface GSMutableSet : NSMutableSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface GSSetEnumerator : NSEnumerator
{
  GSSet			*set;
  GSIMapEnumerator_t	enumerator;
}
@end

@implementation GSSetEnumerator

- (id) initWithSet: (NSSet*)d
{
  self = [super init];
  if (self != nil)
    {
      set = (GSSet*)RETAIN(d);
      enumerator = GSIMapEnumeratorForMap(&set->map);
    }
  return self;
}

- (id) nextObject
{
  GSIMapNode node = GSIMapEnumeratorNextNode(&enumerator);

  if (node == 0)
    {
      return nil;
    }
  return node->key.obj;
}

- (void) dealloc
{
  GSIMapEndEnumerator(&enumerator);
  RELEASE(set);
  [super dealloc];
}

@end


@implementation GSSet

static Class	arrayClass;
static Class	setClass;
static Class	mutableSetClass;

+ (void) initialize
{
  if (self == [GSSet class])
    {
      arrayClass = [NSArray class];
      setClass = [GSSet class];
      mutableSetClass = [GSMutableSet class];
    }
}

- (NSArray*) allObjects
{
  id			objs[map.nodeCount];
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);
  unsigned		i = 0;

  while (node != 0)
    {
      objs[i++] = node->key.obj;
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
  return AUTORELEASE([[arrayClass allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objs count: i]);
}

- (id) anyObject
{
  if (map.nodeCount > 0)
    {
      GSIMapBucket bucket = map.buckets;
      while(1)
	if(bucket->firstNode)
	  return bucket->firstNode->key.obj;
	else
	  bucket++;
    }
  else
    {
      return nil;
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
  unsigned		count = map.nodeCount;
  SEL			sel = @selector(encodeObject:);
  IMP			imp = [aCoder methodForSelector: sel];
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  while (node != 0)
    {
      (*imp)(aCoder, sel, node->key.obj);
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
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
  unsigned i;

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

- (BOOL) intersectsSet: (NSSet*) otherSet
{
  Class	c;

  /*
   *  If this set is empty, or the other is nil, this method should return NO.
   */
  if (map.nodeCount == 0)
    {
      return NO;
    }
  if (otherSet == nil)
    {
      return NO;
    }

  // Loop for all members in otherSet
  c = GSObjCClass(otherSet);
  if (c == setClass || c == mutableSetClass)
    {
      GSIMapTable		m = &((GSSet*)otherSet)->map;
      GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(m);
      GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

      while (node != 0)
	{
	  if (GSIMapNodeForKey(&map, node->key) != 0)
	    {
	      GSIMapEndEnumerator(&enumerator);
	      return YES;
	    }
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
      GSIMapEndEnumerator(&enumerator);
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
  GSIMapEnumerator_t	enumerator;
  GSIMapNode 		node;

  // -1. members of this set(self) <= that of otherSet
  if (map.nodeCount > [otherSet count])
    {
      return NO;
    }

  enumerator = GSIMapEnumeratorForMap(&map);
  node = GSIMapEnumeratorNextNode(&enumerator);

  // 0. Loop for all members in this set(self).
  while (node != 0)
    {
      // 1. check the member is in the otherSet.
      if ([otherSet member: node->key.obj])
	{
	  // 1.1 if true -> continue, try to check the next member.
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
      else
	{
	  // 1.2 if false -> return NO;
	  GSIMapEndEnumerator(&enumerator);
	  return NO;
	}
    }
  GSIMapEndEnumerator(&enumerator);
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
      Class	c = GSObjCClass(other);

      if (c == setClass || c == mutableSetClass)
	{
	  if (map.nodeCount != ((GSSet*)other)->map.nodeCount)
	    {
	      return NO;
	    }
	  else
	    {
	      GSIMapEnumerator_t	enumerator;
	      GSIMapNode 		node;

	      enumerator = GSIMapEnumeratorForMap(&map);
	      node = GSIMapEnumeratorNextNode(&enumerator);

	      while (node != 0)
		{
		  if (GSIMapNodeForKey(&(((GSSet*)other)->map), node->key) == 0)
		    {
		      GSIMapEndEnumerator(&enumerator);
		      return NO;
		    }
		  node = GSIMapEnumeratorNextNode(&enumerator);
		}
	      GSIMapEndEnumerator(&enumerator);
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
	      GSIMapEnumerator_t	enumerator;
	      GSIMapNode 		node;

	      enumerator = GSIMapEnumeratorForMap(&map);
	      node = GSIMapEnumeratorNextNode(&enumerator);

	      while (node != 0)
		{
		  if ([other member: node->key.obj] == nil)
		    {
		      GSIMapEndEnumerator(&enumerator);
		      return NO;
		    }
		  node = GSIMapEnumeratorNextNode(&enumerator);
		}
	      GSIMapEndEnumerator(&enumerator);
	    }
	}
      return YES;
    }
}

- (void) makeObjectsPerform: (SEL)aSelector
{
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector];
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector];
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: argument
{
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector withObject: argument];
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
}

- (void) makeObjectsPerform: (SEL)aSelector withObject: argument
{
  GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
  GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

  while (node != 0)
    {
      [node->key.obj performSelector: aSelector withObject: argument];
      node = GSIMapEnumeratorNextNode(&enumerator);
    }
  GSIMapEndEnumerator(&enumerator);
}

- (id) member: (id)anObject
{
  if (anObject != nil)
    {
      GSIMapNode node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);

      if (node != 0)
	{
	  return node->key.obj;
	}
    }
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[GSSetEnumerator alloc] initWithSet: self]);
}

@end

@implementation GSMutableSet

+ (void) initialize
{
  if (self == [GSMutableSet class])
    {
      behavior_class_add_class(self, [GSSet class]);
    }
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

- (void) addObjectsFromArray: (NSArray*)array
{
  unsigned	count = [array count];

  while (count-- > 0)
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

- (void) intersectSet: (NSSet*) other
{
  if (other != self)
    {
      GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
      GSIMapBucket		bucket = GSIMapEnumeratorBucket(&enumerator);
      GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

      while (node != 0)
	{

	  if ([other containsObject: node->key.obj] == NO)
	    {
	      GSIMapRemoveNodeFromMap(&map, bucket, node);
	      GSIMapFreeNode(&map, node);
	    }
	  bucket = GSIMapEnumeratorBucket(&enumerator);
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
      GSIMapEndEnumerator(&enumerator);
    }
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
#ifndef NDEBUG
  GSDebugAllocationRemove(isa, self);
#endif
  isa = [GSSet class];
#ifndef NDEBUG
  GSDebugAllocationAdd(isa, self);
#endif
  return self;
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

- (void) removeAllObjects
{
  GSIMapCleanMap(&map);
}

- (void) removeObject: (NSObject *)anObject
{
  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  GSIMapRemoveKey(&map, (GSIMapKey)anObject);
}

- (void) unionSet: (NSSet*) other
{
  if (other != self)
    {
      NSEnumerator	*e = [other objectEnumerator];

      if (e != nil)
	{
	  id	anObject;
	  SEL	sel = @selector(nextObject);
	  IMP	imp = [e methodForSelector: sel];

	  while ((anObject = (*imp)(e, sel)) != nil)
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
}

@end

@interface	NSGSet : NSSet
@end
@implementation	NSGSet
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSSet class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

@interface	NSGMutableSet : NSMutableSet
@end
@implementation	NSGMutableSet
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  RELEASE(self);
  self = (id)NSAllocateObject([GSMutableSet class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

