/* NSArray - Array object to hold other objects.
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: March 1995
   
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

#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGArray.h>
#include <limits.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSException.h>

@class NSArrayEnumerator;
@class NSArrayEnumeratorReverse;

@interface NSArrayNonCore : NSArray
@end
@interface NSMutableArrayNonCore : NSMutableArray
@end

static Class NSArray_concrete_class;
static Class NSMutableArray_concrete_class;


@implementation NSArray

+ (void) initialize
{
  if (self == [NSArray class])
    {
      NSArray_concrete_class = [NSGArray class];
      NSMutableArray_concrete_class = [NSGMutableArray class];
      behavior_class_add_class (self, [NSArrayNonCore class]);
    }
}

+ (void) _setConcreteClass: (Class)c
{
  NSArray_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableArray_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSArray_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableArray_concrete_class;
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject ([self _concreteClass], 0, z);
}

/* This is the designated initializer for NSArray. */
- initWithObjects: (id*)objects count: (unsigned)count
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (unsigned) count
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- objectAtIndex: (unsigned)index
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end


@implementation NSArrayNonCore

+ array
{
  return [[[self alloc] init] 
	  autorelease];
}

+ arrayWithObject: anObject
{
  if (anObject == nil)
    [NSException raise:NSInvalidArgumentException
		 format:@"Tried to add nil"];
  return [[[self alloc] initWithObjects:&anObject count:1]
	  autorelease];
}

- (NSArray*) arrayByAddingObject: anObject
{
  id na;
  int i, c;
  id *objects;
 
  c = [self count];
  OBJC_MALLOC (objects, id, c+1);
  for (i = 0; i < c; i++)
    objects[i] = [self objectAtIndex: i];
  objects[c] = anObject;
  na = [[NSArray alloc] initWithObjects: objects count: c+1];
  OBJC_FREE (objects);
  return [na autorelease];
}

- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray
{
  id na;
  int i, c, l;
  id *objects;
 
  c = [self count];
  l = [anotherArray count];
  OBJC_MALLOC (objects, id, c+l);
  for (i = 0; i < c; i++)
    objects[i] = [self objectAtIndex: i];
  for (i = c; i < c+l; i++)
    objects[i] = [anotherArray objectAtIndex: i-c];
  na = [[NSArray alloc] initWithObjects: objects count: c+l];
  OBJC_FREE (objects);
  return [na autorelease];
}

- initWithObjects: firstObject rest: (va_list) ap
{
  register	int			i;
  register	int			curSize;
  auto		int			prevSize;
  auto		int			newSize;
  auto		id			*objsArray;
  auto		id			tmpId;

  /*	Do initial allocation.	*/
  prevSize = 1;
  curSize  = 2;
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

  /*	Put object ids into NSArray.	*/
  self = [self initWithObjects: objsArray count: i];
  OBJC_FREE( objsArray );
  return( self );
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
  self = [[self alloc] initWithObjects:firstObject rest:ap];
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
  self = [self initWithObjects:objects count:c];
  OBJC_FREE(objects);
  return self;
}


- (unsigned) indexOfObjectIdenticalTo:anObject
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    if (anObject == [self objectAtIndex:i])
      return i;
  return NSNotFound;
}

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: anObject
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    if ([[self objectAtIndex:i] isEqual: anObject])
      return i;
  return NSNotFound;
}

- (BOOL) containsObject: anObject
{
  return ([self indexOfObject:anObject] != NSNotFound);
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
    if (![[self objectAtIndex: i] isEqual: [otherArray objectAtIndex: i]])
      return NO;
  return YES;
}

- lastObject
{
  int count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: count-1];
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
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 perform:comparator withObject:elem2];
    }

    return [self sortedArrayUsingFunction:compare context:NULL];
}

- (NSArray*) sortedArrayUsingFunction: (int(*)(id,id,void*))comparator 
   context: (void*)context
{
  id sortedArray = [[self mutableCopy] autorelease];

  [sortedArray sortUsingFunction:comparator context:context];
  return [[sortedArray copy] autorelease];
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

- (NSArray*) subarrayWithRange: (NSRange)range
{
  id na;
  id *objects;
  unsigned c = [self count];
  unsigned i, j, k;

  // If array is empty or start is beyond end of array
  // then return an empty array
  if (([self count] == 0) || (range.location > (c-1)))
    return [NSArray array];

  // Obtain bounds
  i = range.location;
  // Check if length extends beyond end of array
  if ((range.location + range.length) > (c-1))
    j = c-1;
  else
    j = range.location + range.length - 1;

  // Copy the ids from the range into a temporary array
  OBJC_MALLOC(objects, id, j-i+1);
  for (k = i; k <= j; k++)
    objects[k-i] = [self objectAtIndex:k];

  // Create the new array
  na = [[NSArray alloc] initWithObjects:objects count:j-i+1];
  OBJC_FREE(objects);
  return [na autorelease];

}

- (NSEnumerator*) objectEnumerator
{
  return [[[NSArrayEnumerator alloc] initWithArray:self]
	  autorelease];
}

- (NSEnumerator*) reverseObjectEnumerator
{
  return [[[NSArrayEnumeratorReverse alloc] initWithArray:self]
	  autorelease];
}

- (NSString*) description
{
  id desc;
  int count = [self count];
  int i;

  desc = [NSMutableString stringWithCapacity: 2];
  [desc appendString: @"("];
  if (count > 0)
    [desc appendString: [[self objectAtIndex: 0] description]];
  for (i=1; i<count; i++)
    {
      [desc appendString: @", "];
      [desc appendString: [[self objectAtIndex: i] description]];
    }
  [desc appendString: @")"];
  return desc;
}

- (NSString*) descriptionWithIndent: (unsigned)level
{
  return [self description];
}

/* The NSCopying Protocol */

- (id) copy
{
    return [self copyWithZone:NSDefaultMallocZone()];
}

- copyWithZone: (NSZone*)zone
{
  /* a deep copy */
  int count = [self count];
  id objects[count];
  int i;
  for (i = 0; i < count; i++)
    objects[i] = [[self objectAtIndex:i] copyWithZone:zone];
  return [[[[self class] _concreteClass] allocWithZone:zone] 
	  initWithObjects:objects count:count];
}

/* The NSMutableCopying Protocol */

- mutableCopyWithZone: (NSZone*)zone
{
  /* a shallow copy */
  return [[[[self class] _mutableConcreteClass] allocWithZone:zone] 
	  initWithArray:self];
}

@end


@implementation NSMutableArray

+ (void) initialize
{
  if (self == [NSMutableArray class])
    {
      behavior_class_add_class (self, [NSMutableArrayNonCore class]);
      behavior_class_add_class (self, [NSArrayNonCore class]);
    }
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject ([self _mutableConcreteClass], 0, z);
}

/* This is the desgnated initializer for NSMutableArray */
- initWithCapacity: (unsigned)numItems
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (void) addObject: anObject
{
  [self subclassResponsibility: _cmd];
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject
{
  [self subclassResponsibility:_cmd];
}

- (void) insertObject: anObject atIndex: (unsigned)index
{
  [self subclassResponsibility:_cmd];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  [self subclassResponsibility:_cmd];
}

@end


@implementation NSMutableArrayNonCore

+ arrayWithCapacity: (unsigned)numItems
{
  return [[[self alloc] initWithCapacity:numItems] 
	  autorelease];
}

/* Override our superclass's designated initializer to go our's */
- initWithObjects: (id*)objects count: (unsigned)count
{
  /* xxx Could be made more efficient by increasing capacity all at once. */
  int i;
  self = [self initWithCapacity: count];
  for (i = 0; i < count; i++)
    [self addObject:objects[i]];
  return self;
}

- (void) removeLastObject
{
  int count = [self count];
  if (count == 0)
    [NSException raise: NSRangeException
		 format: @"Trying to remove from an empty array."];
  [self removeObjectAtIndex:count-1];
}

- (void) removeObjectIdenticalTo: anObject
{
  unsigned index;

  /* Retain the object.  Yuck, but necessary in case the array holds
     the last reference to anObject. */
  /* xxx Is there an alternative to this expensive retain/release? */
  [anObject retain];

  for (index = [self indexOfObjectIdenticalTo: anObject];
       index != NO_INDEX;
       index = [self indexOfObjectIdenticalTo: anObject])
    [self removeObjectAtIndex: index];

  [anObject release];
}

- (void) removeObject: anObject
{
  unsigned index;

  /* Retain the object.  Yuck, but necessary in case the array holds
     the last reference to anObject. */
  /* xxx Is there an alternative to this expensive retain/release? */
  [anObject retain];

  for (index = [self indexOfObject: anObject];
       index != NO_INDEX;
       index = [self indexOfObject: anObject])
    [self removeObjectAtIndex: index];

  [anObject release];
}

- (void) removeAllObjects
{
  while ([self count])
    [self removeLastObject];
}

- (void) addObjectsFromArray: (NSArray*)otherArray
{
  /* xxx Could be made more efficient by increasing capacity all at once. */
  int i, c = [otherArray count];
  for (i = 0; i < c; i++)
    [self addObject: [otherArray objectAtIndex: i]];
}

- (void) setArray:(NSArray *)otherArray
{
  [self removeAllObjects];
  [self addObjectsFromArray: otherArray];
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

- (void) sortUsingSelector: (SEL)comparator
{
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 perform:comparator withObject:elem2];
    }

    [self sortUsingFunction:compare context:NULL];
}

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  int c,d, stride;
  BOOL found;
  int count = [self count];

  stride = 1;
  while (stride <= count)
    stride = stride * STRIDE_FACTOR + 1;
    
  while(stride > (STRIDE_FACTOR - 1)) {
    // loop to sort for each value of stride
    stride = stride / STRIDE_FACTOR;
    for (c = stride; c < count; c++) {
      found = NO;
      d = c - stride;
      while ((d >= 0) && !found) {
	// move to left until correct place
	id a = [self objectAtIndex:d + stride];
	id b = [self objectAtIndex:d];
	if ((*compare)(a, b, context) == NSOrderedAscending) {
	  [a retain];
	  [b retain];
	  [self replaceObjectAtIndex:d + stride withObject:b];
	  [self replaceObjectAtIndex:d withObject:a];
	  d -= stride;		// jump by stride factor
	  [a release];
	  [b release];
	}
	else found = YES;
      }
    }
  }
}

@end


@interface NSArrayEnumerator : NSEnumerator
{
  id array;
  int next_index;
}
@end

@implementation NSArrayEnumerator

- initWithArray: (NSArray*)anArray
{
  [super init];
  array = anArray;
  [array retain];
  next_index = 0;
  return self;
}

- (id) nextObject
{
  if (next_index >= [array count])
    return nil;
  return [array objectAtIndex:next_index++];
}

- (void) dealloc
{
  [array release];
  [super dealloc];
}

@end


@interface NSArrayEnumeratorReverse : NSArrayEnumerator
@end

@implementation NSArrayEnumeratorReverse

- initWithArray: (NSArray*)anArray
{
  [super init];
  array = anArray;
  [array retain];
  next_index = [array count]-1;
  return self;
}

- (id) nextObject
{
  if (next_index < 0)
    return nil;
  return [array objectAtIndex:next_index--];
}


