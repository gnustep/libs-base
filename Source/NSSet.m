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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSObjCRuntime.h>

@class	GSSet;
@class	GSMutableSet;

@implementation NSSet 

static Class NSSet_abstract_class;
static Class NSMutableSet_abstract_class;
static Class NSSet_concrete_class;
static Class NSMutableSet_concrete_class;

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSSet_abstract_class)
    {
      return NSAllocateObject(NSSet_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

+ (void) initialize
{
  if (self == [NSSet class])
    {
      NSSet_abstract_class = [NSSet class];
      NSMutableSet_abstract_class = [NSMutableSet class];
      NSSet_concrete_class = [GSSet class];
      NSMutableSet_concrete_class = [GSMutableSet class];
    }
}

+ (id) set
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] init]);
}

+ (id) setWithArray: (NSArray*)objects
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithArray: objects]);
}

+ (id) setWithObject: anObject
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: &anObject count: 1]);
}

+ (id) setWithObjects: (id*)objects 
	        count: (unsigned)count
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objects count: count]);
}

+ (id) setWithObjects: firstObject, ...
{
  id	set;
  va_list ap;
  va_start(ap, firstObject);
  set = [[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: firstObject rest: ap];
  va_end(ap);
  return AUTORELEASE(set);
}

+ (id) setWithSet: (NSSet*)aSet
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithSet: aSet]);
}

- (Class) classForCoder
{
  return NSSet_abstract_class;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (unsigned) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	count = [self count];
  NSEnumerator	*e = [self objectEnumerator];
  id		o;

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  while ((o = [e nextObject]) != nil)
    {
      [aCoder encodeValueOfObjCType: @encode(id) at: &o];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;
  Class		c;

  c = GSObjCClass(self);
  if (c == NSSet_abstract_class)
    {
      RELEASE(self);
      self = [NSSet_concrete_class allocWithZone: NSDefaultMallocZone()];
      return [self initWithCoder: aCoder];
    }
  else if (c == NSMutableSet_abstract_class)
    {
      RELEASE(self);
      self = [NSMutableSet_concrete_class allocWithZone: NSDefaultMallocZone()];
      return [self initWithCoder: aCoder];
    }
  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  {
    id	objs[count];
    unsigned	i;

    for (i = 0; i < count; i++)
      {
	[aCoder decodeValueOfObjCType: @encode(id) at: &objs[i]];
      }
    return [self initWithObjects: objs count: count];
  }
}

/* This is the designated initializer */
- (id) initWithObjects: (id*)objects
		 count: (unsigned)count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) member: (id)anObject
{
  return [self subclassResponsibility: _cmd];
  return 0;  
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  return [[NSMutableSet_concrete_class allocWithZone: z] initWithSet: self];
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility: _cmd];
}

/* Same as NSArray */
- (id) initWithObjects: firstObject rest: (va_list)ap
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
  objsArray = (id*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(id) * curSize);
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
	  objsArray = (id*)NSZoneRealloc(NSDefaultMallocZone(), objsArray,
	    sizeof(id) * curSize);
	}
      tmpId = va_arg(ap, id);
    }
  va_end( ap );

  /*	Put object ids into NSSet.	*/
  self = [self initWithObjects: objsArray count: i];
  NSZoneFree(NSDefaultMallocZone(), objsArray);
  return( self );
}

/* Same as NSArray */
- (id) initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self initWithObjects: firstObject rest: ap];
  va_end(ap);
  return self;
}

/* Override superclass's designated initializer */
- (id) init
{
  return [self initWithObjects: NULL count: 0];
}

- (id) initWithArray: (NSArray*)other
{
  unsigned	count = [other count];

  if (count == 0)
    {
      return [self init];
    }
  else
    {
      id	objs[count];

      [other getObjects: objs];
      return [self initWithObjects: objs count: count];
    }
}

- (id) initWithSet: (NSSet*)other copyItems: (BOOL)flag
{
  unsigned	c = [other count];
  id		os[c], o, e = [other objectEnumerator];
  unsigned	i = 0;

  while ((o = [e nextObject]))
    {
      if (flag)
	os[i] = [o copy];
      else
	os[i] = o;
      i++;
    }
  self = [self initWithObjects: os count: c];
#if	!GS_WITH_GC
  if (flag)
    while (i--)
      [os[i] release];
#endif
  return self;
}

- (id) initWithSet: (NSSet*)other 
{
  return [self initWithSet: other copyItems: NO];
}

- (NSArray*) allObjects
{
  id		e = [self objectEnumerator];
  unsigned	i, c = [self count];
  id		k[c];

  for (i = 0; i < c; i++)
    {
      k[i] = [e nextObject];
    }
  return AUTORELEASE([[NSArray allocWithZone: NSDefaultMallocZone()]
    initWithObjects: k count: c]);
}

- (id) anyObject
{
  if ([self count] == 0)
    return nil;
  else
    {
      id e = [self objectEnumerator];
      return [e nextObject];
    }
}

- (BOOL) containsObject: (id)anObject
{
  return (([self member: anObject]) ? YES : NO);
}

- (unsigned) hash
{
  return [self count];
}

- (void) makeObjectsPerform: (SEL)aSelector
{
  id	o, e = [self objectEnumerator];

  while ((o = [e nextObject]))
    [o performSelector: aSelector];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  id	o, e = [self objectEnumerator];

  while ((o = [e nextObject]))
    [o performSelector: aSelector];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: argument
{
  id	o, e = [self objectEnumerator];

  while ((o = [e nextObject]))
    [o performSelector: aSelector withObject: argument];
}

- (void) makeObjectsPerform: (SEL)aSelector withObject: argument
{
  id	o, e = [self objectEnumerator];

  while ((o = [e nextObject]))
    [o performSelector: aSelector withObject: argument];
}

- (BOOL) intersectsSet: (NSSet*) otherSet
{
  id	o = nil, e = nil;

  // -1. If this set is empty, this method should return NO.
  if ([self count] == 0)
    return NO;

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
  if ([self count] > [otherSet count])
    return NO;

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

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: [NSSet class]])
    return [self isEqualToSet: other];
  return NO;
}

- (BOOL) isEqualToSet: (NSSet*)other
{
  if ([self count] != [other count])
    return NO;
  else
    {
      id	o, e = [self objectEnumerator];

      while ((o = [e nextObject]))
	if (![other member: o])
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
  if (self == [NSMutableSet class])
    {
    }
}

+ (id) setWithCapacity: (unsigned)numItems
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: numItems]);
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableSet_abstract_class)
    {
      return NSAllocateObject(NSMutableSet_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

- (Class) classForCoder
{
  return NSMutableSet_concrete_class;
}

- (id) copyWithZone: (NSZone*)z
{
  return [[NSSet_concrete_class allocWithZone: z] initWithSet: self];
}

/* This is the designated initializer */
- (id) initWithCapacity: (unsigned)numItems
{
  return [self subclassResponsibility: _cmd];
}

- (void) addObject: (id)anObject
{
  [self subclassResponsibility: _cmd];
}

- (void) removeObject: (id)anObject
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithObjects: (id*)objects
		 count: (unsigned)count
{
  self = [self initWithCapacity: count];
  if (self != nil)
    {
      while (count--)
	{
	  [self addObject: objects[count]];
	}
    }
  return self;
}

- (void) addObjectsFromArray: (NSArray*)array
{
  unsigned	i, c = [array count];

  for (i = 0; i < c; i++)
    {
      [self addObject: [array objectAtIndex: i]];
    }
}

- (void) unionSet: (NSSet*) other
{
  if (other != self)
    {
      id keys = [other objectEnumerator];
      id key;

      while ((key = [keys nextObject]))
	{
	  [self addObject: key];
	}
    }
}

- (void) intersectSet: (NSSet*) other
{
  if (other != self)
    {
      id keys = [self objectEnumerator];
      id key;

      while ((key = [keys nextObject]))
	{
	  if ([other containsObject: key] == NO)
	    {
	      [self removeObject: key];
	    }
	}
    }
}

- (void) minusSet: (NSSet*) other
{
  if (other == self)
    {
      [self removeAllObjects];
    }
  else
    {
      id keys = [other objectEnumerator];
      id key;

      while ((key = [keys nextObject]))
	{
	  [self removeObject: key];
	}
    }
}

- (void) removeAllObjects
{
  [self subclassResponsibility: _cmd];
}

@end
