/* NSArray - Array object to hold other objects.
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: March 1995
   
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   January 1998 - new methods and changes as documented for Rhapsody plus 
   changes of array indices to type unsigned, plus major efficiency hacks.

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
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGArray.h>
#include <limits.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>

#include <gnustep/base/fast.x>

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

/* The NSCoding Protocol */

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    unsigned	count = [self count];

    [aCoder encodeValueOfObjCType: @encode(unsigned)
			       at: &count];

    if (count > 0) {
        unsigned	i;

	for (i = 0; i < count; i++) {
	    [aCoder encodeObject: [self objectAtIndex: i]];
	}
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned    count;

    if ([aCoder systemVersion] == 0) {
	unsigned dummy;
	[aCoder decodeValueOfObjCType: @encode(unsigned) at: &dummy];
	[aCoder decodeValueOfObjCType: @encode(unsigned) at: &dummy];
    }
    [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
    if (count > 0) {
	id	contents[count];
	int	i;

	for (i = 0; i < count; i++) {
	    contents[i] = [aCoder decodeObject];
	}
	return [self initWithObjects: contents count: count];
    }
    return [self initWithObjects: 0 count: 0];
}

/* The NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  /* a deep copy */
  unsigned count = [self count];
  id oldObjects[count];
  id newObjects[count];
  id newArray;
  unsigned i;
  BOOL needCopy = [self isKindOfClass: [NSMutableArray class]];

  if (NSShouldRetainWithZone(self, zone) == NO)
    needCopy = YES;
  [self getObjects: oldObjects];
  for (i = 0; i < count; i++)
    {
      newObjects[i] = [oldObjects[i] copyWithZone:zone];
      if (newObjects[i] != oldObjects[i])
	needCopy = YES;
    }
  if (needCopy)
    newArray = [[[[self class] _concreteClass] allocWithZone:zone]
	      initWithObjects:newObjects count:count];
  else
    newArray = [self retain];
  for (i = 0; i < count; i++)
    [newObjects[i] release];
  return newArray;
}

/* The NSMutableCopying Protocol */

- mutableCopyWithZone: (NSZone*)zone
{
  /* a shallow copy */
  return [[[[self class] _mutableConcreteClass] allocWithZone:zone] 
	  initWithArray:self];
}

@end


@implementation NSArrayNonCore

- (NSArray*) arrayByAddingObject: anObject
{
  id na;
  unsigned i, c;
  id *objects;
 
  c = [self count];
  {
    id	objects[c+1];

    [self getObjects: objects];
    objects[c] = anObject;
    na = [[NSArray alloc] initWithObjects: objects count: c+1];
  }
  return [na autorelease];
}

- (NSArray*) arrayByAddingObjectsFromArray: (NSArray*)anotherArray
{
    id		na;
    unsigned	c, l;
 
    c = [self count];
    l = [anotherArray count];
    {
	id	objects[c+l];

	[self getObjects: objects];
	[anotherArray getObjects: &objects[c]];
	na = [NSArray arrayWithObjects: objects count: c+l];
    }
    return na;
}

- initWithObjects: firstObject rest: (va_list) ap
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
  NSLog(@"Contents of file does not contain an array");
  [self dealloc];
  return nil;
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
    unsigned c;
 
    c = [array count];
    {
	id	objects[c];

	[array getObjects: objects];
	self = [self initWithObjects: objects count: c];
    }
    return self;
}

- (void) getObjects: (id*)aBuffer
{
  unsigned i, c = [self count];
  for (i = 0; i < c; i++)
    aBuffer[i] = [self objectAtIndex: i];
}

- (void) getObjects: (id*)aBuffer range: (NSRange)aRange
{
  unsigned i, j = 0, c = [self count], e = aRange.location + aRange.length;
  if (c < e)
    e = c;
  for (i = aRange.location; i < c; i++)
    aBuffer[j++] = [self objectAtIndex: i];
}

- (unsigned) hash
{
    return [self count];
}

- (unsigned) indexOfObjectIdenticalTo:anObject
{
  unsigned i, c = [self count];
  for (i = 0; i < c; i++)
    if (anObject == [self objectAtIndex:i])
      return i;
  return NSNotFound;
}

- (unsigned) indexOfObjectIdenticalTo:anObject inRange: (NSRange)aRange
{
  unsigned i, e = aRange.location + aRange.length, c = [self count];
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
  unsigned i, c = [self count];
  for (i = 0; i < c; i++)
    if ([[self objectAtIndex:i] isEqual: anObject])
      return i;
  return NSNotFound;
}

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: anObject inRange: (NSRange)aRange
{
  unsigned i, e = aRange.location + aRange.length, c = [self count];
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
  unsigned i, c = [self count];
 
  if (c != [otherArray count])
    return NO;
  for (i = 0; i < c; i++)
    if (![[self objectAtIndex: i] isEqual: [otherArray objectAtIndex: i]])
      return NO;
  return YES;
}

- lastObject
{
  unsigned count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: count-1];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  unsigned i = [self count];
  while (i-- > 0)
    [[self objectAtIndex:i] performSelector:aSelector];
}

- (void) makeObjectsPerform: (SEL)aSelector
{
   [self makeObjectsPerformSelector: aSelector];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject:argument
{
  unsigned i = [self count];
  while (i-- > 0)
    [[self objectAtIndex:i] performSelector:aSelector withObject:argument];
}

- (void) makeObjectsPerform: (SEL)aSelector withObject:argument
{
   [self makeObjectsPerformSelector: aSelector withObject:argument];
}

- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 performSelector:comparator withObject:elem2];
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
  unsigned i, c = [self count];
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
  unsigned i, c = [self count];
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
  unsigned i, c = [self count];
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

  {
    id	objects[j-i+1];

    [self getObjects: objects range: NSMakeRange(i, j-i+1)];
    na = [NSArray arrayWithObjects: objects count: j-i+1];
  }
  return na;
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

  result = [NSMutableString stringWithCapacity: 20*[self count]];
  [self descriptionWithLocale: locale
		       indent: level
			   to: (id<GNUDescriptionDestination>)result];
  return result;
}

static NSString	*indentStrings[] = {
  @"",
  @"    ",
  @"\t",
  @"\t    ",
  @"\t\t",
  @"\t\t    ",
  @"\t\t\t",
  @"\t\t\t    ",
  @"\t\t\t\t",
  @"\t\t\t\t    ",
  @"\t\t\t\t\t",
  @"\t\t\t\t\t    ",
  @"\t\t\t\t\t\t"
};

- (void) descriptionWithLocale: (NSDictionary*)locale
		        indent: (unsigned int)level
			    to: (id<GNUDescriptionDestination>)result
{
  NSString		*iBaseString;
  NSString		*iSizeString;
  unsigned		count = [self count];
  NSString		*plists[count];
  unsigned		i;
  SEL			appSel;
  IMP			appImp;

  appSel = @selector(appendString:);
  appImp = [(NSObject*)result methodForSelector: appSel];

  if (level < sizeof(indentStrings)/sizeof(NSString*))
    iBaseString = indentStrings[level];
  else
    iBaseString = indentStrings[sizeof(indentStrings)/sizeof(NSString*)-1];
  level++;
  if (level < sizeof(indentStrings)/sizeof(NSString*))
    iSizeString = indentStrings[level];
  else
    iSizeString = indentStrings[sizeof(indentStrings)/sizeof(NSString*)-1];

  (*appImp)(result, appSel, @"(\n");

  [self getObjects: plists];
  for (i = 0; i < count; i++)
    {
      id	item = plists[i];

      (*appImp)(result, appSel, iSizeString);
 
      if ([item respondsToSelector:
	      @selector(descriptionWithLocale:indent:)])
	{
	  [item descriptionWithLocale: locale indent: level to: result];
	}
      else if ([item respondsToSelector:
	      @selector(descriptionWithLocale:)])
	{
	  [item descriptionWithLocale: locale to: result];
	}
      else
	{
	  [item descriptionTo: result];
	}
      if (i == count - 1)
	{
	  (*appImp)(result, appSel, @"\n");
	}
      else
	{
	  (*appImp)(result, appSel, @",\n");
	}
    }
  (*appImp)(result, appSel, iBaseString);
  (*appImp)(result, appSel, @")");
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
  id e, o;

  if ([self count] < (aRange.location + aRange.length))
    [NSException raise: NSRangeException
		 format: @"Replacing objects beyond end of array."];
  [self removeObjectsInRange: aRange];
  e = [anArray reverseObjectEnumerator];
  while ((o = [e nextObject]))
    [self insertObject: o atIndex: aRange.location];
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

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
  return [[self description] writeToFile:path atomically:useAuxiliaryFile];
}

/* Override our superclass's designated initializer to go our's */
- initWithObjects: (id*)objects count: (unsigned)count
{
  unsigned i;
  self = [self initWithCapacity: count];
  for (i = 0; i < count; i++)
    [self addObject:objects[i]];
  return self;
}

- (void) removeLastObject
{
  unsigned count = [self count];
  if (count == 0)
    [NSException raise: NSRangeException
		 format: @"Trying to remove from an empty array."];
  [self removeObjectAtIndex:count-1];
}

- (void) removeObjectIdenticalTo: anObject
{
  unsigned pos = NSNotFound;
  unsigned i = [self count];

  while (i-- > 0)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject)
	{
	  if (pos != NSNotFound)
	    [self removeObjectAtIndex: pos];
	  pos = i;
	}
    }
  if (pos != NSNotFound)
    [self removeObjectAtIndex: pos];
}

- (void) removeObject: anObject inRange:(NSRange)aRange
{
  unsigned c = [self count], s = aRange.location;
  unsigned i = aRange.location + aRange.length;
  unsigned pos = NSNotFound;
  if (i > c)
    i = c;
  while (i-- > s)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject || [o isEqual: anObject])
	{
	  if (pos != NSNotFound)
	    [self removeObjectAtIndex: pos];
	  pos = i;
	}
    }
  if (pos != NSNotFound)
    [self removeObjectAtIndex: pos];
}

- (void) removeObjectIdenticalTo: anObject inRange:(NSRange)aRange
{
  unsigned c = [self count], s = aRange.location;
  unsigned i = aRange.location + aRange.length;
  unsigned pos = NSNotFound;
  if (i > c)
    i = c;
  while (i-- > s)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject)
	{
	  if (pos != NSNotFound)
	    [self removeObjectAtIndex: pos];
	  pos = i;
	}
    }
  if (pos != NSNotFound)
    [self removeObjectAtIndex: pos];
}

- (void) removeObject: anObject
{
  unsigned pos = NSNotFound;
  unsigned i = [self count];

  while (i-- > 0)
    {
      id o = [self objectAtIndex: i];
      if (o == anObject || [o isEqual: anObject])
	{
	  if (pos != NSNotFound)
	    [self removeObjectAtIndex: pos];
	  pos = i;
	}
    }
  if (pos != NSNotFound)
    [self removeObjectAtIndex: pos];
}

- (void) removeAllObjects
{
  while ([self count])
    [self removeLastObject];
}

- (void) addObjectsFromArray: (NSArray*)otherArray
{
  unsigned i, c = [otherArray count];
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
  while (count--)
    [self removeObjectAtIndex:indices[count]];
}

- (void) removeObjectsInArray: (NSArray*)otherArray
{
  unsigned i, c = [otherArray count];
  for (i = 0; i < c; i++)
    [self removeObject:[otherArray objectAtIndex:i]];
}

- (void) removeObjectsInRange: (NSRange)aRange
{
  unsigned i, s = aRange.location, c = [self count];
  i = aRange.location + aRange.length;
  if (c < i)
    i = c;
  while (i-- > s)
    [self removeObjectAtIndex: i];
}

- (void) sortUsingSelector: (SEL)comparator
{
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 performSelector:comparator withObject:elem2];
    }

    [self sortUsingFunction:compare context:NULL];
}

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  unsigned c,d, stride;
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
      if (stride > c)
	break;
      d = c - stride;
      while (!found) {
	// move to left until correct place
	id a = [self objectAtIndex:d + stride];
	id b = [self objectAtIndex:d];
	if ((*compare)(a, b, context) == NSOrderedAscending) {
	  [a retain];
	  [self replaceObjectAtIndex:d + stride withObject:b];
	  [self replaceObjectAtIndex:d withObject:a];
	  [a release];
	  if (stride > d)
	    break;
	  d -= stride;		// jump by stride factor
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


