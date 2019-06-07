/** Concrete implementation of GSOrderedSet based on GNU Set class
    Copyright (C) 2019 Free Software Foundation, Inc.
    
    Written by: Gregory Casamento <greg.casamento@gmail.com>
    Created: May 17 2019
    
    This file is part of the GNUstep Base Library.
    
    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    _version 2 of the License, or (at your option) any later _version.
    
    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.
    
    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free
    Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02111 USA.
*/

#import "common.h"
#import "Foundation/NSOrderedSet.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSIndexSet.h"
// For private method _decodeArrayOfObjectsForKey:
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "GSPThread.h"
#import "GSFastEnumeration.h"
#import "GSDispatch.h"
#import "GSSorting.h"

#define	GSI_MAP_HAS_VALUE	0
#define	GSI_MAP_KTYPES		GSUNION_OBJ


#include "GNUstepBase/GSIMap.h"

static SEL	memberSel;
static SEL      privateCountOfSel;
@interface GSOrderedSet : NSOrderedSet
{
@public
  GSIMapTable_t	map;
}
@end

@interface GSMutableOrderedSet : NSMutableOrderedSet
{
@public
  GSIMapTable_t	map;
@private
  NSUInteger _version;
}
@end

@interface GSOrderedSetEnumerator : NSEnumerator
{
  GSOrderedSet			*set;
  GSIMapEnumerator_t	enumerator;
}
@end

@implementation GSOrderedSetEnumerator
- (id) initWithOrderedSet: (NSOrderedSet*)d
{
  self = [super init];
  if (self != nil)
    {
      set = (GSOrderedSet*)RETAIN(d);
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

@implementation GSOrderedSet

static Class	arrayClass;
static Class	setClass;
static Class	mutableSetClass;

+ (void) initialize
{
  if (self == [GSOrderedSet class])
    {
      arrayClass = [NSArray class];
      setClass = [GSOrderedSet class];
      mutableSetClass = [GSMutableOrderedSet class];
      memberSel = @selector(member:);
      privateCountOfSel = @selector(_countForObject:);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (NSUInteger) count
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
  if ([aCoder allowsKeyedCoding])
    {
      [super encodeWithCoder: aCoder];
    }
  else
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
}

- (NSUInteger) hash
{
  return map.nodeCount;
}

- (id) init
{
  return [self initWithObjects: 0 count: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      self = [super initWithCoder: aCoder];
    }
  else
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
    }
  return self;
}

/* Designated initialiser */
- (id) initWithObjects: (const id*)objs count: (NSUInteger)c
{
  NSUInteger i;

  GSIMapInitWithZoneAndCapacity(&map, [self zone], c);
  for (i = 0; i < c; i++)
    {
      GSIMapNode     node;

      if (objs[i] == nil)
	{
	  DESTROY(self);
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

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[GSOrderedSetEnumerator alloc] initWithOrderedSet: self]);
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (id*)stackbuf
                                     count: (NSUInteger)len
{
  state->mutationsPtr = (unsigned long *)self;
  return GSIMapCountByEnumeratingWithStateObjectsCount
    (&map, state, stackbuf, len);
}

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  NSUInteger	size = GSPrivateMemorySize(self, exclude);

  if (size > 0)
    {
      GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
      GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

      size += GSIMapSize(&map) - sizeof(map);
      while (node != 0)
        {
          size += [node->key.obj sizeInBytesExcluding: exclude];
          node = GSIMapEnumeratorNextNode(&enumerator);
        }
      GSIMapEndEnumerator(&enumerator);
    }
  return size;
}

// Put required overrides here...

@end

@implementation GSMutableOrderedSet

+ (void) initialize
{
  if (self == [GSMutableOrderedSet class])
    {
      GSObjCAddClassBehavior(self, [GSOrderedSet class]);
    }
}

- (void) addObject: (id)anObject
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
      _version++;
    }
}

- (id) init
{
  return [self initWithCapacity: 0];
}

/* Designated initialiser */
- (id) initWithCapacity: (NSUInteger)cap
{
  GSIMapInitWithZoneAndCapacity(&map, [self zone], cap);
  return self;
}

- (id) initWithObjects: (const id*)objects
		 count: (NSUInteger)count
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

- (BOOL) makeImmutable
{
  GSClassSwizzle(self, [GSOrderedSet class]);
  return YES;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
  GSClassSwizzle(self, [GSOrderedSet class]);
  return self;
}

- (void) removeObject: (id)anObject
{
  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  GSIMapRemoveKey(&map, (GSIMapKey)anObject);
  _version++;
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (id*)stackbuf
                                     count: (NSUInteger)len
{
  state->mutationsPtr = (unsigned long *)&_version;
  return GSIMapCountByEnumeratingWithStateObjectsCount
    (&map, state, stackbuf, len);
}
@end

@interface	NSGOrderedSet : NSOrderedSet
@end

@implementation	NSGOrderedSet
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  DESTROY(self);
  self = (id)NSAllocateObject([GSOrderedSet class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

@interface	NSGMutableOrderedSet : NSMutableOrderedSet
@end
@implementation	NSGMutableOrderedSet
- (id) initWithCoder: (NSCoder*)aCoder
{
  NSLog(@"Warning - decoding archive containing obsolete %@ object - please delete/replace this archive", NSStringFromClass([self class]));
  DESTROY(self);
  self = (id)NSAllocateObject([GSMutableOrderedSet class], 0, NSDefaultMallocZone());
  self = [self initWithCoder: aCoder];
  return self;
}
@end

