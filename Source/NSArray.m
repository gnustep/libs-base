/* NSArray - Array object to hold other objects.
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: March 1995
   
   This file is part of the GNU Objective C Class Library.
   
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

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGArray.h>
#include <Foundation/NSArrayEnumerator.h>
#include <limits.h>

@implementation NSArray

+ array
{
  return [[[NSGArray alloc] init] autorelease];
}

+ arrayWithObject: anObject
{
  id a = [[[NSGArray class] alloc] init];
  [a addObject: anObject];
  return [a autorelease];
}

/* This is the designated initializer for NSArray. */
- initWithObjects: (id*)objects count: (unsigned)count
{
  [self notImplemented:_cmd];
  return nil;
}

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

- initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self initWithObjects:firstObject rest:ap];
  va_end(ap);
  return self;
}

+ arrayWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [[NSGArray alloc] initWithObjects:firstObject rest:ap];
  va_end(ap);
  return [self autorelease];
}


- initWithArray: (NSArray*)array
{
  int i, c;
  id *objects;
 
  c = [array count];
  OBJC_MALLOC(objects, id, c);
  for (i = 0; i < c; i++)
    objects[i] = [array objectAtIndex:i];
  return [self initWithObjects:objects count:c];
}


- (unsigned) count
{
  [self notImplemented:_cmd];
  return 0;
}

- objectAtIndex: (unsigned)index
{
  [self notImplemented:_cmd];
  return nil;
}

- (unsigned) indexOfObjectIdenticalTo:anObject
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    if (anObject == [self objectAtIndex:i])
      return i;
  return UINT_MAX;
}

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: anObject
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    if ([[self objectAtIndex:i] isEqual: anObject])
      return i;
  return UINT_MAX;
}

- (BOOL) containsObject: anObject
{
  return ([self indexOfObject:anObject] != UINT_MAX);
}

- (BOOL) isEqual: anObject
{
  if ([anObject isKindOf:[NSArray class]])
    return [self isEqualToArray:anObject];
  return NO;
}

- (BOOL) isEqualToArray: (NSArray*)otherArray
{
  int i, c = [self count];
 
  if (c != [otherArray count])
    return NO;
  for (i = 0; i < c; i++)
    if ([[self objectAtIndex:i] isEqual:[otherArray objectAtIndex:i]])
      return NO;
  return YES;
}

- lastObject
{
  int count = [self count];
  assert(count);		/* xxx should raise an NSException instead */
  return [self objectAtIndex:count-1];
}

- (void) makeObjectsPerform: (SEL)aSelector
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    [[self objectAtIndex:i] perform:aSelector];
}

- (void) makeObjectsPerform: (SEL)aSelector withObject:argument
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    [[self objectAtIndex:i] perform:aSelector withObject:argument];
}


- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSArray*) sortedArrayUsingFunction: (int(*)(id,id,void*))comparator 
   context: (void*)context
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSString*) componentsJoinedByString: (NSString*)separator
{
  int i, c = [self count];
  id s = [NSMutableString stringWithCapacity:2]; /* arbitrary capacity */
  
  if (!c)
    return s;
  [s appendString:[[self objectAtIndex:0] description]];
  for (i = 1; i < c; i++)
    {
      [s appendString:separator];
      [s appendString:[[self objectAtIndex:i] description]];
    }
  return s;
}


- firstObjectCommonWithArray: (NSArray*)otherArray
{
  int i, c = [self count];
  id o;
  for (i = 0; i < c; i++)
    if ([otherArray containsObject:(o = [self objectAtIndex:i])])
      return o;
  return nil;
}

- (NSArray*)subarrayWithRange: (NSRange)range
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  return [[NSArrayEnumerator alloc] initWithArray:self];
}

- (NSEnumerator*) reverseObjectEnumerator
{
  return [[NSArrayEnumeratorReverse alloc] initWithArray:self];
}

- (NSString*) description
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSString*) descriptionWithIndent: (unsigned)level
{
  [self notImplemented:_cmd];
  return nil;
}

/* The NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone] initWithArray:self];
}

/* The NSMutableCopying Protocol */

- mutableCopyWithZone: (NSZone*)zone
{
  return [[NSGMutableArray allocWithZone:zone] initWithArray:self];
}

@end

@implementation NSMutableArray: NSArray

+ arrayWithCapacity: (unsigned)numItems
{
  return [[[[NSGMutableArray class] alloc] initWithCapacity:numItems] 
	  autorelease];
}

/* This is the desgnated initializer for NSMutableArray */
- initWithCapacity: (unsigned)numItems
{
  [self notImplemented:_cmd];
  return nil;
}

/* Not in OpenStep. */
- (void) addObjects: (id*)objects count: (unsigned)count
{
}

/* Override our superclass's designated initializer to go our's */
- initWithObjects: (id*)objects count: (unsigned)count
{
  /* xxx Could be made more efficient by increasing capacity all at once. */
  int i;
  self = [self initWithCapacity:count];
  for (i = 0; i < count; i++)
    [self addObject:objects[i]];
  return self;
}

- (void) addObject: anObject
{
  [self notImplemented:_cmd];
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject
{
  [self notImplemented:_cmd];
}

- (void) insertObject: anObject atIndex: (unsigned)index
{
  [self notImplemented:_cmd];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  [self notImplemented:_cmd];
}

- (void) removeLastObject
{
  int count = [self count];
  assert(count);		/* xxx should raise an NSException instead */
  [self removeObjectAtIndex:count-1];
}

- (void) removeObjectIdenticalTo: anObject
{
  int i = [self indexOfObjectIdenticalTo:anObject];
  assert (i != UINT_MAX);	/* xxx should raise an NSException instead */
  [self removeObjectAtIndex:i];
}

- (void) removeObject: anObject
{
  int i = [self indexOfObject:anObject];
  assert (i != UINT_MAX);	/* xxx should raise an NSException instead */
  [self removeObjectAtIndex:i];
}

- (void) removeAllObjects
{
  [self notImplemented:_cmd];
}

- (void) addObjectsFromArray: (NSArray*)otherArray
{
  /* xxx Could be made more efficient by increasing capacity all at once. */
  int i, c = [otherArray count];
  for (i = 0; i < c; i++)
    [self addObject:[otherArray objectAtIndex:i]];
}

- (void) removeObjectsFromIndices: (unsigned*)indices 
   numIndices: (unsigned)count
{
  int compare_unsigned(const void *u1, const void *u2)
    {
      return *((int*)u1) - *((int*)u2);
    }
  /* xxx are we allowed to modify the contents of indices? */
  qsort(indices, count, sizeof(unsigned), compare_unsigned);
  while (count--)
    [self removeObjectAtIndex:indices[count]];
}

- (void) removeObjectsInArray: (NSArray*)otherArray
{
  int i, c = [otherArray count];
  for (i = 0; i < c; i++)
    [self removeObject:[otherArray objectAtIndex:i]];
}

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
   context: (void*)context
{
  [self notImplemented:_cmd];
}

@end

