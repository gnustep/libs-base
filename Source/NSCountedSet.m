/* NSCountedSet - CountedSet object 
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

@implementation NSCountedSet 

static Class NSCountedSet_concrete_class;

+ (void) _CountedSetConcreteClass: (Class)c
{
  NSCountedSet_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSCountedSet_concrete_class;
}

+ (void) initialize
{
  NSCountedSet_concrete_class = [NSGCountedSet class];
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}


/* This is the designated initializer */
/* Also, override superclass's designated initializer */
- initWithCapacity: (unsigned)numItems
{
  return [self subclassResponsibility:_cmd];
}

- initWithArray: (NSArray*)array
{
  int i, c = [array count];
  [self initWithCapacity:c];
  for (i = 0; i < c; i++)
    [self addObject:[array objectAtIndex:i]];
  return self;
}

- initWithSet: (NSSet*)other
{
  id o, e = [other objectEnumerator];

  [self initWithCapacity:[other count]];
  while ((o = [e nextObject]))
    [self addObject:o];
  return self;
}

- (NSEnumerator*) objectEnumerator
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

- (unsigned int) countForObject: anObject
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- copyWithZone: (NSZone*)z
{
  id o, e = [self objectEnumerator];
  id c = [[[[self class] _concreteClass] alloc]
	  initWithCapacity:[self count]];
  while ((o = [e nextObject]))
    [(NSCountedSet*)c addObject:o]; 
  /* Cast to avoid type warning.  
     I'll fix the type in gnustep/base/Collecting.h eventually. */
  return o;
}

- initWithCoder: aCoder
{
  [self notImplemented:_cmd];
  return self;
}

- (void) encodeWithCoder: aCoder
{
  [self notImplemented:_cmd];
}

@end
