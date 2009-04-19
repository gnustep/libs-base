/** NSHashTable implementation for GNUStep.
 * Copyright (C) 2009  Free Software Foundation, Inc.
 *
 * Author: Richard Frith-Macdonald <rfm@gnu.org>
 *
 * This file is part of the GNUstep Base Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02111 USA.
 *
 * <title>NSHashTable class reference</title>
 * $Date$ $Revision$
 */

#include "config.h"
#include "Foundation/NSObject.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSException.h"
#include "Foundation/NSPointerFunctions.h"
#include "Foundation/NSSet.h"
#include "Foundation/NSZone.h"
#include "Foundation/NSHashTable.h"
#include "Foundation/NSDebug.h"
#include "NSCallBacks.h"
#include "GSPrivate.h"

@implementation	NSHashTable

@class	NSConcreteHashTable;

static Class	abstractClass = 0;
static Class	concreteClass = 0;

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == abstractClass)
    {
      return NSAllocateObject(concreteClass, 0, aZone);
    }
  return NSAllocateObject(self, 0, aZone);
}

+ (void) initialize
{
  if (abstractClass == 0)
    {
      abstractClass = [NSHashTable class];
      concreteClass = [NSConcreteHashTable class];
    }
}

+ (id) hashTableWithOptions: (NSPointerFunctionsOptions)options
{
  NSHashTable	*t;

  t = [self allocWithZone: NSDefaultMallocZone()];
  t = [t initWithOptions: options
		capacity: 0];
  return AUTORELEASE(t);
}

+ (id) hashTableWithWeakObjects;
{
  return [self hashTableWithOptions:
    NSPointerFunctionsObjectPersonality | NSPointerFunctionsZeroingWeakMemory];
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
	      capacity: (NSUInteger)initialCapacity
{
  NSPointerFunctions	*k;
  id			o;

  k = [[NSPointerFunctions alloc] initWithOptions: options];
  o = [self initWithPointerFunctions: k capacity: initialCapacity];
#if	!GS_WITH_GC
  [k release];
#endif
  return o;
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
		capacity: (NSUInteger)initialCapacity
{
  return [self subclassResponsibility: _cmd];
}

- (void) addObject: (id)object
{
  [self subclassResponsibility: _cmd];
}

- (NSArray*) allObjects
{
  NSEnumerator	*enumerator;
  unsigned	nodeCount = [self count];
  unsigned	index;
  NSArray	*a;
  GS_BEGINITEMBUF(objects, nodeCount, id);

  enumerator = [self objectEnumerator];
  index = 0;
  while ((objects[index] = [enumerator nextObject]) != nil)
    {
      index++;
    }
  a = [[[NSArray alloc] initWithObjects: objects count: nodeCount] autorelease];
  GS_ENDITEMBUF();
  return a;
}

- (id) anyObject
{
  return [[self objectEnumerator] nextObject];
}

- (BOOL) containsObject: (id)anObject
{
  return (BOOL)(uintptr_t)[self subclassResponsibility: _cmd];
}

- (id) copyWithZone: (NSZone*)aZone
{
  return [self subclassResponsibility: _cmd];
}

- (NSUInteger) count
{
  return (NSUInteger)[self subclassResponsibility: _cmd];
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (NSUInteger)len
{
  return (NSUInteger)[self subclassResponsibility: _cmd];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (NSUInteger) hash
{
  return [self count];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  return [self subclassResponsibility: _cmd];
}

- (void) intersectHashTable: (NSHashTable*)other
{
  unsigned		count = [self count];

  if (count > 0)
    {
      NSEnumerator	*enumerator;
      NSMutableArray	*array;
      id		object;

      array = [NSMutableArray arrayWithCapacity: count];
      enumerator = [self objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  if ([other member: object] != nil)
	    {
	      [array addObject: object];
	    }
	}
      enumerator = [array objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  [self removeObject: object];
	}
    }
}

- (BOOL) intersectsHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [self objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([other member: object] != nil)
	{
	  return YES;
	}
    }
  return NO;
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: abstractClass] == NO) return NO;
  return NSCompareHashTables(self, other);
}

- (BOOL) isEqualToHashTable: (NSHashTable*)other
{
  return NSCompareHashTables(self, other);
}

- (BOOL) isSubsetOfHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [self objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([other member: object] == nil)
	{
	  return NO;
	}
    }
  return YES;
}

- (id) member: (id)object
{
  return [self subclassResponsibility: _cmd];
}

- (void) minusHashTable: (NSHashTable*)other
{
  if ([self count] > 0 && [other count] > 0)
    {
      NSEnumerator	*enumerator;
      id		object;

      enumerator = [other objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  [self removeObject: object];
	}
    }
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility: _cmd];
}

- (NSPointerFunctions*) pointerFunctions
{
  return [self subclassResponsibility: _cmd];
}

- (void) removeAllObjects
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [[self allObjects] objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [self removeObject: object];
    }
}

- (void) removeObject: (id)aKey
{
  [self subclassResponsibility: _cmd];
}

- (NSSet*) setRepresentation 
{
  NSEnumerator	*enumerator;
  NSMutableSet	*set;
  id		object;

  set = [NSMutableSet setWithCapacity: [self count]];
  enumerator = [[self allObjects] objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [set addObject: object];
    }
  return [[set copy] autorelease];
}

- (void) unionHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [other objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [self addObject: object];
    }
}

@end

