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

#include <config.h>
#include <gnustep/base/behavior.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGArray.h>
#include <limits.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>

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

+ arrayWithArray: (NSArray*)array
{
  return [[[self alloc] initWithArray: array] autorelease];
}

+ arrayWithContentsOfFile: (NSString*)file
{
  return [[[self alloc] initWithContentsOfFile: file] autorelease];
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

+ arrayWithObjects: (id*)objects count: (unsigned)count
{
  return [[[self alloc] initWithObjects: objects count: count]
	  autorelease];
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

- (void) getObjects: (id*)aBuffer
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    aBuffer[i] = [self objectAtIndex: i];
}

- (void) getObjects: (id*)aBuffer range: (NSRange)aRange
{
  int i, j = 0, c = [self count], e = aRange.location + aRange.length;
  if (c < e)
    e = c;
  for (i = aRange.location; i < c; i++)
    aBuffer[j++] = [self objectAtIndex: i];
}

- (unsigned) indexOfObjectIdenticalTo:anObject
{
  int i, c = [self count];
  for (i = 0; i < c; i++)
    if (anObject == [self objectAtIndex:i])
      return i;
  return NSNotFound;
}

- (unsigned) indexOfObjectIdenticalTo:anObject inRange: (NSRange)aRange
{
  int i, e = aRange.location + aRange.length, c = [self count];
  if (c < e)
    e = c;
  for (i = aRange.location; i < e; i++)
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

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: anObject inRange: (NSRange)aRange
{
  int i, e = aRange.location + aRange.length, c = [self count];
  if (c < e)
    e = c;
  for (i = aRange.location; i < e; i++)
    {
      id o = [self objectAtIndex: i];
      if (anObject == o || [o isEqual: anObject])
        return i;
    }
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
  for (i = c-1; i >= 0; i--)
    [[self objectAtIndex:i] perform:aSelector];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
   [self makeObjectsPerform: aSelector];
}

- (void) makeObjectsPerform: (SEL)aSelector withObject:argument
{
  int i, c = [self count];
  for (i = c-1; i >= 0; i--)
    [[self objectAtIndex:i] perform:aSelector withObject:argument];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject:argument
{
   [self makeObjectsPerform: aSelector withObject:argument];
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
  return [self sortedArrayUsingFunction: comparator context: context hint: nil];
}

- (NSData*) sortedArrayHint
{
    return nil;
}

- (NSArray*) sortedArrayUsingFunction: (int(*)(id,id,void*))comparator 
   context: (void*)context
   hint: (NSData*)hint
{
  NSMutableArray	*sortedArray;
  NSArray		*result;

  sortedArray = [[NSMutableArray alloc] initWithArray: self];
  [sortedArray sortUsingFunction:comparator context:context];
  result = [NSArray arrayWithArray: sortedArray];
  [sortedArray release];
  return result;
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

- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions
{
  int i, c = [self count];
  NSMutableArray *a = [NSMutableArray arrayWithCapacity: 1];
  for (i = 0; i < c; i++)
    {
      id o = [self objectAtIndex: i];
      if ([o isKindOfClass: [NSString class]])
	if ([extensions containsObject: [o pathExtension]])
	  [a addObject: o];
    }
  return a;
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
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  return [self descriptionWithLocale: locale indent: 0];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level
{
    NSMutableString	*result;
    NSMutableArray	*plists;
    int			count;
    int			size;
    NSAutoreleasePool	*arp;
    int			indentSize;
    int			indentBase;
    NSMutableString	*iBaseString;
    NSMutableString	*iSizeString;
    int			i;

    arp = [[NSAutoreleasePool alloc] init];

    /*
     *	Indentation is at four space intervals using tab characters to
     *	replace multiples of eight spaces.
     *
     *	We work out the sizes of the strings needed to perform indentation for
     *	this level and build strings to make up the indentation.
     */
    indentBase = level << 2;
    count = indentBase >> 3;
    if ((indentBase % 8) == 0) {
	indentBase = count;
    }
    else {
	indentBase == count + 4;
    }
    iBaseString = [NSMutableString stringWithCapacity: indentBase];
    for (i = 0; i < count; i++) {
	[iBaseString appendString: @"\t"];
    }
    if (count != indentBase) {
	[iBaseString appendString: @"    "];
    }

    level++;
    indentSize = level << 2;
    count = indentSize >> 3;
    if ((indentSize % 8) == 0) {
	indentSize = count;
    }
    else {
	indentSize == count + 4;
    }
    iSizeString = [NSMutableString stringWithCapacity: indentSize];
    for (i = 0; i < count; i++) {
	[iSizeString appendString: @"\t"];
    }
    if (count != indentSize) {
	[iSizeString appendString: @"    "];
    }

    /*
     *	Basic size is - opening bracket, newline, closing bracket,
     *	indentation for the closing bracket, and a nul terminator.
     */
    size = 4 + indentBase;

    count = [self count];
    plists = [NSMutableArray arrayWithCapacity: count];

    for (i = 0; i < count; i++) {
	id		item;

	item = [self objectAtIndex: i];
	if ([item isKindOfClass: [NSString class]]) {
	   item = [item descriptionForPropertyList];
	}
	else if ([item respondsToSelector:
		@selector(descriptionWithLocale:indent:)]) {
	   item = [item descriptionWithLocale: locale indent: level];
	}
	else if ([item respondsToSelector:
		@selector(descriptionWithLocale:)]) {
	   item = [item descriptionWithLocale: locale];
	}
	else {
	   item = [item description];
	}
	[plists addObject: item];

	size += [item length] + indentSize;
	if (i == count - 1) {
	    size += 1;			/* newline	*/
	}
	else {
	    size += 2;			/* ',' and newline	*/
	}
    }

    result = [[NSMutableString alloc] initWithCapacity: size];
    [result appendString: @"(\n"];
    for (i = 0; i < count; i++) {
	[result appendString: iSizeString];
	[result appendString: [plists objectAtIndex: i]];
	if (i == count - 1) {
            [result appendString: @"\n"];
	}
	else {
            [result appendString: @",\n"];
	}
    }
    [result appendString: iBaseString];
    [result appendString: @")"];

    [arp release];

    return [result autorelease];
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

- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray
{
  int	i;

  if ([self count] <= aRange.location)
    [NSException raise: NSRangeException
		 format: @"Replacing objects beyond end of array."];
  [self removeObjectsInRange: aRange];
  for (i = [anArray count] - 1; i >= 0; i--) 
    [self insertObject: [anArray objectAtIndex: i] atIndex: aRange.location];
}

- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray
			 range: (NSRange)anotherRange
{
  [self replaceObjectsInRange: aRange
	 withObjectsFromArray: [anArray subarrayWithRange: anotherRange]];
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

- initWithContentsOfFile: (NSString*)file
{
  NSString 	*myString;

  myString = [[NSString alloc] initWithContentsOfFile:file];
  if (myString)
    {
      id result = [myString propertyList];
      if ( [result isKindOfClass: [NSArray class]] )
	{
	  [self initWithArray: result];
	  return self;
	}
    }
  [self dealloc];
  return nil;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
  return [[self description] writeToFile:path atomically:useAuxiliaryFile];
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

- (void) removeObject: anObject inRange:(NSRange)aRange
{
  int c = [self count], s = aRange.location;
  int i = aRange.location + aRange.length;
  if (i > c)
    i = c;
  [anObject retain];
  for (i--; i >= s; i--)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject || [o isEqual: anObject])
	[self removeObjectAtIndex:i];
    }
  [anObject release];
}

- (void) removeObjectIdenticalTo: anObject inRange:(NSRange)aRange
{
  int c = [self count], s = aRange.location;
  int i = aRange.location + aRange.length;
  if (i > c)
    i = c;
  [anObject retain];
  for (i--; i >= s; i--)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject)
	[self removeObjectAtIndex:i];
    }
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

- (void) removeObjectsInRange: (NSRange)aRange
{
  int i, s = aRange.location, c = [self count];
  i = aRange.location + aRange.length;
  if (c < i)
    i = c;
  for (i--; i >= s; i--)
    [self removeObjectAtIndex: i];
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


