/* NSSet - Set object to store key/value pairs
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.
   
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
#include <gnustep/base/behavior.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSGSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <assert.h>

@interface NSSetNonCore : NSSet
@end
@interface NSMutableSetNonCore: NSMutableSet
@end

@implementation NSSet 

static Class NSSet_concrete_class;
static Class NSMutableSet_concrete_class;

+ (void) initialize
{
    if (self == [NSSet class]) {
        NSSet_concrete_class = [NSGSet class];
        NSMutableSet_concrete_class = [NSGMutableSet class];
        behavior_class_add_class(self, [NSSetNonCore class]);
    }
}

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
  return [[[self alloc] initWithArray: objects]
	  autorelease];
}

+ setWithObject: anObject
{
  return [[[self alloc] initWithObjects:&anObject
			count:1]
	  autorelease];
}

+ setWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [[self alloc] initWithObjects:firstObject rest:ap];
  va_end(ap);
  return [self autorelease];
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

/* This is the designated initializer */
- initWithObjects: (id*)objects
	    count: (unsigned)count
{
  [self subclassResponsibility:_cmd];
  return 0;
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
    newSet = [[[[self class] _concreteClass] allocWithZone: z] 
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
  return [[[[self class] _mutableConcreteClass] allocWithZone: z] 
	  initWithSet: self];
}

@end

@implementation NSSetNonCore

/* Same as NSArray */
- initWithObjects: firstObject rest: (va_list)ap
{
  register	unsigned		i;
  register	unsigned		curSize;
  auto		unsigned		prevSize;
  auto		unsigned		newSize;
  auto		id			*objsArray;
  auto		id			tmpId;

  /*	Do initial allocation.	*/
  prevSize = 3;
  curSize  = 5;
  OBJC_MALLOC(objsArray, id, curSize);
  tmpId = firstObject;

  /*	Loop through adding objects to array until a nil is
   *	found.
   */
  for (i = 0; tmpId != nil; i++)
    {
      /*	Put id into array.	*/
      objsArray[i] = tmpId;

      /*	If the index equals the current size, increase size.	*/
      if (i == curSize - 1)
	{
	  /*	Fibonacci series.  Supposedly, for this application,
	   *	the fibonacci series will be more memory efficient.
	   */
	  newSize  = prevSize + curSize;
	  prevSize = curSize;
	  curSize  = newSize;

	  /*	Reallocate object array.	*/
	  OBJC_REALLOC(objsArray, id, curSize);
	}
      tmpId = va_arg(ap, id);
    }
  va_end( ap );

  /*	Put object ids into NSSet.	*/
  self = [self initWithObjects: objsArray count: i];
  OBJC_FREE( objsArray );
  return( self );
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

- initWithArray: (NSArray*)other
{
    unsigned	count = [other count];

    if (count == 0) {
	return [self init];
    }
    else {
	id	objs[count];

	[other getObjects: objs];
	return [self initWithObjects: objs count: count];
    }
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
  self = [self initWithObjects:os count:c];
  if (flag)
    while (--i)
      [os[i] release];
  return self;
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

@end

@implementation NSMutableSet

+ (void) initialize
{
    if (self == [NSMutableSet class]) {
        behavior_class_add_class(self, [NSMutableSetNonCore class]);
        behavior_class_add_class(self, [NSSetNonCore class]);
    }
}

+ setWithCapacity: (unsigned)numItems
{
  return [[[self alloc] initWithCapacity:numItems]
	  autorelease];
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

/* This is the designated initializer */
- initWithCapacity: (unsigned)numItems
{
  return [self subclassResponsibility:_cmd];
}

- (void) addObject: anObject
{
  [self subclassResponsibility:_cmd];
}

- (void) removeObject: anObject
{
  [self subclassResponsibility:_cmd];
}

@end

@implementation NSMutableSetNonCore

/* Override superclass's designated initializer */
- initWithObjects: (id*)objects
	    count: (unsigned)count
{
  [self initWithCapacity:count];
  while (count--)
    [self addObject:objects[count]];
  return self;
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

@end
