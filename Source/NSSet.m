/* NSSet - Set object to store key/value pairs
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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
#include <Foundation/NSSet.h>
#include <Foundation/NSGSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <gnustep/base/NSString.h>
#include <assert.h>

@implementation NSSet 

static Class NSSet_concrete_class;
static Class NSMutableSet_concrete_class;

+ (void) _setConcreteClass: (Class)c
{
  NSSet_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableSet_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSSet_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableSet_concrete_class;
}

+ (void) initialize
{
  NSSet_concrete_class = [NSGSet class];
  NSMutableSet_concrete_class = [NSGMutableSet class];
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

+ set
{
  return [[[self alloc] init] 
	  autorelease];
}

+ setWithObjects: (id*)objects 
	   count: (unsigned)count
{
  return [[[self alloc] initWithObjects:objects
			count:count]
	  autorelease];
}

+ setWithArray: (NSArray*)objects
{
  /* xxx Only works because NSArray also responds to objectEnumerator
     and nextObject. */
  return [[[self alloc] initWithSet:(NSSet*)objects]
	  autorelease];
}

+ setWithObject: anObject
{
  return [[[self alloc] initWithObjects:&anObject
			count:1]
	  autorelease];
}

/* Same as NSArray */
/* Not very pretty... */
#define INITIAL_OBJECTS_SIZE 10
- initWithObjects: firstObject rest: (va_list)ap
{
  id *objects;
  int i = 0;
  int s = INITIAL_OBJECTS_SIZE;

  OBJC_MALLOC(objects, id, s);
  if (firstObject != nil)
    {
      objects[i++] = firstObject;
      while ((objects[i++] = va_arg(ap, id)))
	{
	  if (i >= s)
	    {
	      s *= 2;
	      OBJC_REALLOC(objects, id, s);
	    }
	}
    }
  self = [self initWithObjects:objects count:i-1];
  OBJC_FREE(objects);
  return self;
}

/* Same as NSArray */
+ setWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [[self alloc] initWithObjects:firstObject rest:ap];
  va_end(ap);
  return [self autorelease];
}

/* This is the designated initializer */
- initWithObjects: (id*)objects
	    count: (unsigned)count
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- initWithArray: (NSArray*)array
{
  /* xxx Only works because NSArray also responds to objectEnumerator
     and nextObject. */
  return [self initWithSet:(NSSet*)array];
}

/* Same as NSArray */
- initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self initWithObjects:firstObject rest:ap];
  va_end(ap);
  return self;
}

/* Override superclass's designated initializer */
- init
{
  return [self initWithObjects:NULL count:0];
}

- initWithSet: (NSSet*)other copyItems: (BOOL)flag
{
  int c = [other count];
  id os[c], o, e = [other objectEnumerator];
  int i = 0;

  while ((o = [e nextObject]))
    {
      if (flag)
	os[i] = [o copy];
      else
	os[i] = o;
      i++;
    }
  return [self initWithObjects:os count:c];
}

- initWithSet: (NSSet*)other 
{
  return [self initWithSet:other copyItems:NO];
}

- (NSArray*) allObjects
{
  id e = [self objectEnumerator];
  int i, c = [self count];
  id k[c];

  for (i = 0; i < c; i++)
    {
      k[i] = [e nextObject];
      assert(k[i]);
    }
  assert(![e nextObject]);
  return [[[NSArray alloc] initWithObjects:k count:c]
	  autorelease];
}

- anyObject
{
  if ([self count] == 0)
    return nil;
  else
    {
      id e = [self objectEnumerator];
      return [e nextObject];
    }
}

- (BOOL) containsObject: anObject
{
  return (([self member:anObject]) ? YES : NO);
}

- (unsigned) count
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- member: anObject
{
  return [self subclassResponsibility:_cmd];
  return 0;  
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility:_cmd];
}

- (void) makeObjectsPerform: (SEL)aSelector
{
  id o, e = [self objectEnumerator];
  while ((o = [e nextObject]))
    [o performSelector:aSelector];
}

- (void) makeObjectsPerform: (SEL)aSelector withObject:argument
{
  id o, e = [self objectEnumerator];
  while ((o = [e nextObject]))
    [o performSelector:aSelector withObject: argument];
}

- (BOOL) intersectsSet: (NSSet*) otherSet
{
  id o = nil, e = nil;

  // -1. If this set is empty, this method should return NO.
  if ([self count] == 0) return NO;

  // 0. Loop for all members in otherSet
  e = [otherSet objectEnumerator];
  while ((o = [e nextObject])) // 1. pick a member from otherSet.
    {
      if ([self member: o])    // 2. check the member is in this set(self).
       return YES;
    }
  return NO;
}

- (BOOL) isSubsetOfSet: (NSSet*) otherSet
{
  id o = nil, e = nil;

  // -1. members of this set(self) <= that of otherSet
  if ([self count] > [otherSet count]) return NO;

  // 0. Loop for all members in this set(self).
  e = [self objectEnumerator];
  while ((o = [e nextObject]))
    {
      // 1. check the member is in the otherSet.
      if ([otherSet member: o])
       {
         // 1.1 if true -> continue, try to check the next member.
         continue ;
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

- (BOOL) isEqual: other
{
  if ([other isKindOfClass:[NSSet class]])
    return [self isEqualToSet:other];
  return NO;
}

- (BOOL) isEqualToSet: (NSSet*)other
{
  if ([self count] != [other count])
    return NO;
  {
    id o, e = [self objectEnumerator];
    while ((o = [e nextObject]))
      if (![other member:o])
	return NO;
  }
  /* xxx Recheck this. */
  return YES;
}

- (NSString*) description
{
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  return [[self allObjects] descriptionWithLocale: locale];
}

- copyWithZone: (NSZone*)z
{
  /* a deep copy */
  int count = [self count];
  id objects[count];
  id enumerator = [self objectEnumerator];
  id o;
  NSSet *newSet;
  int i;
  BOOL needCopy = [self isKindOfClass: [NSMutableSet class]];

  if (NSShouldRetainWithZone(self, z) == NO)
    needCopy = YES;

  for (i = 0; (o = [enumerator nextObject]); i++)
    {
      objects[i] = [o copyWithZone:z];
      if (objects[i] != o)
        needCopy = YES;
    }
  if (needCopy)
    newSet = [[[[self class] _concreteClass] alloc] 
	  initWithObjects:objects
	  count:count];
  else
    newSet = [self retain];
  for (i = 0; i < count; i++) 
    [objects[i] release];
  return newSet;
}

- mutableCopyWithZone: (NSZone*)z
{
  /* a shallow copy */
  return [[[[[self class] _mutableConcreteClass] _mutableConcreteClass] alloc] 
	  initWithSet:self];
}

- initWithCoder: aCoder
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (void) encodeWithCoder: aCoder
{
  [self subclassResponsibility:_cmd];
}

@end

@implementation NSMutableSet

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

+ setWithCapacity: (unsigned)numItems
{
  return [[[self alloc] initWithCapacity:numItems]
	  autorelease];
}

/* This is the designated initializer */
- initWithCapacity: (unsigned)numItems
{
  return [self subclassResponsibility:_cmd];
}

/* Override superclass's designated initializer */
- initWithObjects: (id*)objects
	    count: (unsigned)count
{
  [self initWithCapacity:count];
  while (count--)
    [self addObject:objects[count]];
  return self;
}

- (void) addObject: anObject
{
  [self subclassResponsibility:_cmd];
}

- (void) addObjectsFromArray: (NSArray*)array
{
  int i, c = [array count];

  for (i = 0; i < c; i++)
    [self addObject: [array objectAtIndex: i]];
}

- (void) unionSet: (NSSet*) other
{
  id keys = [other objectEnumerator];
  id key;

  while ((key = [keys nextObject]))
    [self addObject: key];
}

- (void) intersectSet: (NSSet*) other
{
  id keys = [self objectEnumerator];
  id key;

  while ((key = [keys nextObject]))
    if ([other containsObject:key] == NO)
      [self removeObject:key];
}

- (void) minusSet: (NSSet*) other
{
  id keys = [other objectEnumerator];
  id key;

  while ((key = [keys nextObject]))
    [self removeObject:key];
}

- (void) removeAllObjects
{
  [self subclassResponsibility:_cmd];
}

- (void) removeObject: anObject
{
  [self subclassResponsibility:_cmd];
}

@end
