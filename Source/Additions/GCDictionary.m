/* Implementation of garbage collecting dictionary classes

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Inspired by gc classes of  Ovidiu Predescu and Mircea Oancea

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

#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <gnustep/base/behavior.h>
#include <gnustep/base/GCObject.h>

typedef struct {
  id	object;
  BOOL	isGCObject;
} GCInfo;

@interface _GCDictionaryKeyEnumerator : NSObject
{
@public
  GCDictionary		*dict;
  NSMapEnumerator	enumerator;
}
- (id) nextObject;
@end

@interface _GCDictionaryObjectEnumerator : _GCDictionaryKeyEnumerator
- (id) nextObject;
@end

@implementation _GCDictionaryKeyEnumerator
- (id) copyWithZone: (NSZone*)z
{
  return [self retain];
}
- (void) dealloc
{
  NSEndMapTableEnumeration(&enumerator);
  [dict release];
  [super dealloc];
}
- (id) nextObject
{
  GCInfo	*keyStruct;
  GCInfo	*valueStruct;

  return NSNextMapEnumeratorPair(&enumerator, 
    (void**)&keyStruct, (void**)&valueStruct) ? keyStruct->object : nil;
}
@end

@implementation _GCDictionaryObjectEnumerator
- (id) nextObject
{
  GCInfo	*keyStruct;
  GCInfo	*valueStruct;

  return NSNextMapEnumeratorPair(&enumerator, 
    (void**)&keyStruct, (void**)&valueStruct) ? valueStruct->object : nil;
}
@end

@implementation GCDictionary

static unsigned
_GCHashObject(NSMapTable *table, const GCInfo *objectStruct)
{
  return [objectStruct->object hash];
}

static BOOL
_GCCompareObjects(NSMapTable *table, const GCInfo *o1, const GCInfo *o2)
{
  return [o1->object isEqual: o2->object];
}

static void
_GCRetainObjects(NSMapTable *table, const void *ptr)
{
  GCInfo	*objectStruct = (GCInfo*)ptr;

  [objectStruct->object retain];
}

static void
_GCReleaseObjects(NSMapTable *table, const void *ptr)
{
  GCInfo	*objectStruct = (GCInfo*)ptr;

  if ([GCObject gcIsCollecting])
    {
      if (objectStruct->isGCObject == NO)
	{
	  [objectStruct->object release];
	}
    }
  else
    {
      [objectStruct->object release];
    }
  NSZoneFree(NSDefaultMallocZone(), objectStruct);
}

static NSString*
_GCDescribeObjects(NSMapTable *table, const GCInfo *objectStruct)
{
  return [objectStruct->object description];
}

static const NSMapTableKeyCallBacks GCInfoMapKeyCallBacks = {
  (unsigned(*)(NSMapTable *, const void *))_GCHashObject,
  (BOOL(*)(NSMapTable *, const void *, const void *))_GCCompareObjects,
  (void (*)(NSMapTable *, const void *))_GCRetainObjects,
  (void (*)(NSMapTable *, const void *))_GCReleaseObjects,
  (NSString *(*)(NSMapTable *, const void *))_GCDescribeObjects,
  (const void *)NULL
}; 

static const NSMapTableValueCallBacks GCInfoValueCallBacks = {
  (void (*)(NSMapTable *, const void *))_GCRetainObjects,
  (void (*)(NSMapTable *, const void *))_GCReleaseObjects,
  (NSString *(*)(NSMapTable *, const void *))_GCDescribeObjects
}; 

static Class	gcClass = 0;

+ (void) initialize
{
  if (gcClass == 0)
    {
      gcClass = [GCObject class];
      behavior_class_add_class(self, gcClass);
    }
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return [self retain];
    }
  return [[GCDictionary allocWithZone: zone] initWithDictionary: self];
}

- (unsigned int) count
{
  return NSCountMapTable(_map);
}

- (void) dealloc
{
  [GCObject gcObjectWillBeDeallocated: (GCObject*)self];
  NSFreeMapTable(_map);
  [super dealloc];
}

- (void) gcDecrementRefCountOfContainedObjects
{
  NSMapEnumerator	enumerator = NSEnumerateMapTable(_map);
  GCInfo		*keyStruct;
  GCInfo		*valueStruct;

  gc.flags.visited = 0;
  while (NSNextMapEnumeratorPair(&enumerator,
    (void**)&keyStruct, (void**)&valueStruct))
    {
      if (keyStruct->isGCObject)
	{
	  [keyStruct->object gcDecrementRefCount];
	}
      if (valueStruct->isGCObject)
	{
	  [valueStruct->object gcDecrementRefCount];
	}
    }
  NSEndMapTableEnumeration(&enumerator);
}

- (BOOL) gcIncrementRefCountOfContainedObjects
{
  NSMapEnumerator	enumerator;
  GCInfo		*keyStruct;
  GCInfo		*valueStruct;

  if (gc.flags.visited == 1)
    {
      return NO;
    }
  gc.flags.visited = 1;

  enumerator = NSEnumerateMapTable(_map);
  while (NSNextMapEnumeratorPair(&enumerator,
    (void**)&keyStruct, (void**)&valueStruct))
    {
      if (keyStruct->isGCObject)
	{
	  [keyStruct->object gcIncrementRefCount];
	  [keyStruct->object gcIncrementRefCountOfContainedObjects];
	}
      if (valueStruct->isGCObject)
	{
	  [valueStruct->object gcIncrementRefCount];
	  [valueStruct->object gcIncrementRefCountOfContainedObjects];
	}
    }
  NSEndMapTableEnumeration(&enumerator);
  return YES;
}

- (id) initWithDictionary: (NSDictionary*)dictionary
{
  id		keys = [dictionary keyEnumerator];
  id		key;
  unsigned int	size = ([dictionary count] * 4) / 3;
  NSZone	*z = NSDefaultMallocZone();

  _map = NSCreateMapTableWithZone(GCInfoMapKeyCallBacks,
    GCInfoValueCallBacks, size, z);

  while ((key = [keys nextObject]) != nil)
    {
      GCInfo	*keyStruct;
      GCInfo	*valueStruct;
      id	value;

      keyStruct = NSZoneMalloc(z, sizeof(GCInfo));
      valueStruct = NSZoneMalloc(z, sizeof(GCInfo));
      value = [dictionary objectForKey: key];
      keyStruct->object = key;
      keyStruct->isGCObject = [key isKindOfClass: gcClass];
      valueStruct->object = value;
      valueStruct->isGCObject = [value isKindOfClass: gcClass];
      NSMapInsert(_map, keyStruct, valueStruct);
    }
  
  return self;
}

- (id) initWithObjects: (id*)objects
	       forKeys: (id*)keys 
		 count: (unsigned int)count
{
  unsigned int	size = (count * 4) / 3;
  NSZone	*z = NSDefaultMallocZone();

  _map = NSCreateMapTableWithZone(GCInfoMapKeyCallBacks,
    GCInfoValueCallBacks, size, z);

  while (count-- > 0)
    {
      GCInfo	*keyStruct;
      GCInfo	*valueStruct;

      if (!keys[count] || !objects[count])
	{
	  [self release];
	  [NSException raise: NSInvalidArgumentException
		      format: @"Nil object added in dictionary"];
	}
      keyStruct = NSZoneMalloc(z, sizeof(GCInfo));
      valueStruct = NSZoneMalloc(z, sizeof(GCInfo));
      keyStruct->object = keys[count];
      keyStruct->isGCObject = [keys[count] isKindOfClass: gcClass];
      valueStruct->object = objects[count];
      valueStruct->isGCObject
	  = [objects[count] isKindOfClass: gcClass];
      NSMapInsert(_map, keyStruct, valueStruct);
    }
  return self;
}

/**
 * We use the same initial instance variable layout as a GCObject and
 * ue the <em>behavior</em> mechanism to inherit methods from that class
 * to implement a form of multiple inheritance.  We need to implement
 * this method to make this apparent at runtime.
 */
- (BOOL) isKindOfClass: (Class)c
{
  if (c == gcClass)
    {
      return YES;
    }
  return [super isKindOfClass: c];
}

- (NSEnumerator*) keyEnumerator
{
  _GCDictionaryKeyEnumerator	*e;

  e = [_GCDictionaryKeyEnumerator alloc];
  e->dict = [self retain];
  e->enumerator = NSEnumerateMapTable(_map);
  return [e autorelease];
}

- (NSEnumerator*) objectEnumerator
{
  _GCDictionaryObjectEnumerator	*e;

  e = [_GCDictionaryObjectEnumerator alloc];
  e->dict = [self retain];
  e->enumerator = NSEnumerateMapTable(_map);
  return [e autorelease];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[GCMutableDictionary allocWithZone: zone] initWithDictionary: self];
}

- (id) objectForKey: (id)key
{
  GCInfo	keyStruct = { key, 0 };
  GCInfo	*valueStruct;

  valueStruct = NSMapGet(_map, (void**)&keyStruct);
  return valueStruct ? valueStruct->object : nil;
}

@end



@implementation GCMutableDictionary

+ (void) initialize
{
  static BOOL beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;
      behavior_class_add_class(self, [GCDictionary class]);
    }
}

- (id) init
{
  return [self initWithCapacity: 0];
}

- (id) initWithCapacity: (unsigned int)aNumItems
{
  unsigned int	size = (aNumItems * 4) / 3;

  _map = NSCreateMapTableWithZone(GCInfoMapKeyCallBacks,
    GCInfoValueCallBacks, size, [self zone]);
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  return [[GCDictionary allocWithZone: zone] initWithDictionary: self];
}

- (void) setObject: (id)anObject forKey: (id)aKey
{
  GCInfo	*keyStruct;
  GCInfo	*valueStruct;
  NSZone		*z = NSDefaultMallocZone();

  keyStruct = NSZoneMalloc(z, sizeof(GCInfo));
  valueStruct = NSZoneMalloc(z, sizeof(GCInfo));
  keyStruct->object = aKey;
  keyStruct->isGCObject = [aKey isKindOfClass: gcClass];
  valueStruct->object = anObject;
  valueStruct->isGCObject = [anObject isKindOfClass: gcClass];
  NSMapInsert(_map, keyStruct, valueStruct);
}

- (void) removeObjectForKey: (id)key
{
  GCInfo keyStruct = { key, 0 };

  NSMapRemove(_map, (void**)&keyStruct);
}

- (void) removeAllObjects
{
  NSResetMapTable(_map);
}

@end
