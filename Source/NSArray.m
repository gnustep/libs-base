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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGArray.h>
#include <Foundation/NSRange.h>
#include <limits.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDebug.h>

#include <base/fast.x>

@class NSArrayEnumerator;
@class NSArrayEnumeratorReverse;

@interface NSArrayNonCore : NSArray
@end
@interface NSMutableArrayNonCore : NSMutableArray
@end

static Class NSArray_abstract_class;
static Class NSArray_concrete_class;
static Class NSMutableArray_abstract_class;
static Class NSMutableArray_concrete_class;

static SEL	addSel = @selector(addObject:);
static SEL	appSel = @selector(appendString:);
static SEL	countSel = @selector(count);
static SEL	eqSel = @selector(isEqual:);
static SEL	oaiSel = @selector(objectAtIndex:);
static SEL	remSel = @selector(removeObjectAtIndex:);
static SEL	rlSel = @selector(removeLastObject);


@implementation NSArray

+ (void) initialize
{
  if (self == [NSArray class])
    {
      NSArray_abstract_class = [NSArray class];
      NSMutableArray_abstract_class = [NSMutableArray class];
      NSArray_concrete_class = [NSGArray class];
      NSMutableArray_concrete_class = [NSGMutableArray class];
      behavior_class_add_class (self, [NSArrayNonCore class]);
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSArray_abstract_class)
    {
      return NSAllocateObject(NSArray_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

+ (id) array
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] init]);
}

+ (id) arrayWithArray: (NSArray*)array
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithArray: array]);
}

+ (id) arrayWithContentsOfFile: (NSString*)file
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: file]);
}

+ (id) arrayWithObject: anObject
{
  if (anObject == nil)
    [NSException raise: NSInvalidArgumentException
		 format: @"Tried to add nil"];
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: &anObject count: 1]);
}

/* This is the designated initializer for NSArray. */
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (unsigned) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) objectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/* The NSCoding Protocol */

- (Class) classForCoder
{
  return NSArray_abstract_class;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	count = [self count];

  [aCoder encodeValueOfObjCType: @encode(unsigned)
			     at: &count];

  if (count > 0)
    {
      id	a[count];

      [self getObjects: a];
      [aCoder encodeArrayOfObjCType: @encode(id)
                              count: count
                                 at: a];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned    count;

  [aCoder decodeValueOfObjCType: @encode(unsigned)
			     at: &count];
  if (count > 0)
    {
      id	contents[count];

      [aCoder decodeArrayOfObjCType: @encode(id)
                              count: count
                                 at: contents];
      return [self initWithObjects: contents count: count];
    }
  else
    return [self initWithObjects: 0 count: 0];
}

/* The NSCopying Protocol */

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

/* The NSMutableCopying Protocol */

- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[NSMutableArray_concrete_class allocWithZone: zone] 
    initWithArray: self];
}

@end


@implementation NSArrayNonCore

- (NSArray*) arrayByAddingObject: (id)anObject
{
  id na;
  unsigned	c = [self count];
 
  if (anObject == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Attempt to add nil to an array"];
  if (c == 0)
    na = [[NSArray_concrete_class allocWithZone: NSDefaultMallocZone()]
      initWithObjects: &anObject count: 1];
  else
    {
      id	objects[c+1];

      [self getObjects: objects];
      objects[c] = anObject;
      na = [[NSArray_concrete_class allocWithZone: NSDefaultMallocZone()]
	initWithObjects: objects count: c+1];
    }
  return AUTORELEASE(na);
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
    na = [NSArray_abstract_class arrayWithObjects: objects count: c+l];
  }
  return na;
}

- (id) initWithObjects: firstObject rest: (va_list) ap
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

  /*	Put object ids into NSArray.	*/
  self = [self initWithObjects: objsArray count: i];
  NSZoneFree(NSDefaultMallocZone(), objsArray);
  return( self );
}

- (id) initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self initWithObjects: firstObject rest: ap];
  va_end(ap);
  return self;
}

- (id) initWithContentsOfFile: (NSString*)file
{
  NSString 	*myString;

  myString = [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: file];
  if (myString)
    {
      id result;

      NS_DURING
	{
	  result = [myString propertyList];
	}
      NS_HANDLER
	{
          result = nil;
	}
      NS_ENDHANDLER
      RELEASE(myString);
      if ([result isKindOfClass: NSArray_abstract_class])
	{
	  [self initWithArray: result];
	  return self;
	}
    }
  NSWarnMLog(@"Contents of file does not contain an array", 0);
  RELEASE(self);
  return nil;
}

+ (id) arrayWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: firstObject rest: ap];
  va_end(ap);
  return AUTORELEASE(self);
}

+ (id) arrayWithObjects: (id*)objects count: (unsigned)count
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objects count: count]);
}

- (id) initWithArray: (NSArray*)array
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
  IMP	get = [self methodForSelector: oaiSel];

  for (i = 0; i < c; i++)
    aBuffer[i] = (*get)(self, oaiSel, i);
}

- (void) getObjects: (id*)aBuffer range: (NSRange)aRange
{
  unsigned i, j = 0, c = [self count], e = aRange.location + aRange.length;
  IMP	get = [self methodForSelector: oaiSel];

  GS_RANGE_CHECK(aRange, c);

  for (i = aRange.location; i < e; i++)
    aBuffer[j++] = (*get)(self, oaiSel, i);
}

- (unsigned) hash
{
  return [self count];
}

- (unsigned) indexOfObjectIdenticalTo: anObject
{
  unsigned c = [self count];

  if (c > 0)
    {
      IMP	get = [self methodForSelector: oaiSel];
      unsigned	i;

      for (i = 0; i < c; i++)
	if (anObject == (*get)(self, oaiSel, i))
	  return i;
    }
  return NSNotFound;
}

- (unsigned) indexOfObjectIdenticalTo: anObject inRange: (NSRange)aRange
{
  unsigned i, e = aRange.location + aRange.length, c = [self count];
  IMP	get = [self methodForSelector: oaiSel];

  GS_RANGE_CHECK(aRange, c);

  for (i = aRange.location; i < e; i++)
    if (anObject == (*get)(self, oaiSel, i))
      return i;
  return NSNotFound;
}

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: (id)anObject
{
  unsigned	c = [self count];

  if (c > 0 && anObject != nil)
    {
      unsigned	i;
      IMP	get = [self methodForSelector: oaiSel];
      BOOL	(*eq)(id, SEL, id)
	= (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];

      for (i = 0; i < c; i++)
	if ((*eq)(anObject, eqSel, (*get)(self, oaiSel, i)) == YES)
	  return i;
    }
  return NSNotFound;
}

/* Inefficient, should be overridden. */
- (unsigned) indexOfObject: (id)anObject inRange: (NSRange)aRange
{
  unsigned i, e = aRange.location + aRange.length, c = [self count];
  IMP	get = [self methodForSelector: oaiSel];
  BOOL	(*eq)(id, SEL, id)
    = (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];

  GS_RANGE_CHECK(aRange, c);

  for (i = aRange.location; i < e; i++)
    {
      if ((*eq)(anObject, eqSel, (*get)(self, oaiSel, i)) == YES)
        return i;
    }
  return NSNotFound;
}

- (BOOL) containsObject: anObject
{
  return ([self indexOfObject: anObject] != NSNotFound);
}

- (BOOL) isEqual: (id)anObject
{
  if (self == anObject)
    return YES;
  if ([anObject isKindOfClass: NSArray_abstract_class])
    return [self isEqualToArray: anObject];
  return NO;
}

- (BOOL) isEqualToArray: (NSArray*)otherArray
{
  unsigned i, c;
 
  if (self == (id)otherArray)
    return YES;
  c = [self count];
  if (c != [otherArray count])
    return NO;
  if (c > 0)
    {
      IMP	get0 = [self methodForSelector: oaiSel];
      IMP	get1 = [otherArray methodForSelector: oaiSel];

      for (i = 0; i < c; i++)
	if (![(*get0)(self, oaiSel, i) isEqual: (*get1)(otherArray, oaiSel, i)])
	  return NO;
    }
  return YES;
}

- (id) lastObject
{
  unsigned count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: count-1];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector
{
  unsigned i = [self count];

  if (i > 0)
    {
      IMP	get = [self methodForSelector: oaiSel];

      while (i-- > 0)
	[(*get)(self, oaiSel, i) performSelector: aSelector];
    }
}

- (void) makeObjectsPerform: (SEL)aSelector
{
   [self makeObjectsPerformSelector: aSelector];
}

- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id) arg
{
  unsigned i = [self count];

  if (i > 0)
    {
      IMP	get = [self methodForSelector: oaiSel];

      while (i-- > 0)
	[(*get)(self, oaiSel, i) performSelector: aSelector withObject: arg];
    }
}

- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument
{
   [self makeObjectsPerformSelector: aSelector withObject: argument];
}

- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 performSelector: comparator withObject: elem2];
    }

  return [self sortedArrayUsingFunction: compare context: NULL];
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

  sortedArray = [[NSMutableArray_abstract_class allocWithZone:
    NSDefaultMallocZone()] initWithArray: self];
  [sortedArray sortUsingFunction: comparator context: context];
  result = [NSArray_abstract_class arrayWithArray: sortedArray];
  RELEASE(sortedArray);
  return result;
}

- (NSString*) componentsJoinedByString: (NSString*)separator
{
  unsigned i, c = [self count];
  id s = [NSMutableString stringWithCapacity: 2]; /* arbitrary capacity */
  
  if (!c)
    return s;
  [s appendString: [[self objectAtIndex: 0] description]];
  for (i = 1; i < c; i++)
    {
      [s appendString: separator];
      [s appendString: [[self objectAtIndex: i] description]];
    }
  return s;
}

- (NSArray*) pathsMatchingExtensions: (NSArray*)extensions
{
  unsigned i, c = [self count];
  NSMutableArray *a = [NSMutableArray arrayWithCapacity: 1];
  Class	cls = [NSString class];
  IMP	get = [self methodForSelector: oaiSel];
  IMP	add = [a methodForSelector: addSel];

  for (i = 0; i < c; i++)
    {
      id o = (*get)(self, oaiSel, i);

      if ([o isKindOfClass: cls])
	if ([extensions containsObject: [o pathExtension]])
	  (*add)(a, addSel, o);
    }
  return a;
}

- (id) firstObjectCommonWithArray: (NSArray*)otherArray
{
  unsigned i, c = [self count];
  id o;
  for (i = 0; i < c; i++)
    if ([otherArray containsObject: (o = [self objectAtIndex: i])])
      return o;
  return nil;
}

- (NSArray*) subarrayWithRange: (NSRange)aRange
{
  id na;
  unsigned c = [self count];

  GS_RANGE_CHECK(aRange, c);

  if (aRange.length == 0)
    {
      na = [NSArray array];
    }
  else
    {
      id	objects[aRange.length];

      [self getObjects: objects range: aRange];
      na = [NSArray arrayWithObjects: objects count: aRange.length];
    }
  return na;
}

- (NSEnumerator*) objectEnumerator
{
  id	e;

  e = [NSArrayEnumerator allocWithZone: NSDefaultMallocZone()];
  e = [e initWithArray: self];
  return AUTORELEASE(e);
}

- (NSEnumerator*) reverseObjectEnumerator
{
  id	e;

  e = [NSArrayEnumeratorReverse allocWithZone: NSDefaultMallocZone()];
  e = [e initWithArray: self];
  return AUTORELEASE(e);
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
  extern BOOL GSMacOSXCompatiblePropertyLists();

  if (GSMacOSXCompatiblePropertyLists() == YES)
    {
      extern NSString	*GSXMLPlMake(id obj, NSDictionary *loc, unsigned lev);

      return GSXMLPlMake(self, locale, level);
    }
  else
    {
      NSMutableString	*result;

      result = [[NSMutableString alloc] initWithCapacity: 20*[self count]];
      result = AUTORELEASE(result);
      [self descriptionWithLocale: locale
			   indent: level
			       to: (id<GNUDescriptionDestination>)result];
      return result;
    }
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
  unsigned		count = [self count];
  unsigned		last = count - 1;
  NSString		*plists[count];
  unsigned		i;
  IMP			appImp;

  appImp = [(NSObject*)result methodForSelector: appSel];

  [self getObjects: plists];

  if (locale == nil)
    {
      (*appImp)(result, appSel, @"(");
      for (i = 0; i < count; i++)
	{
	  id	item = plists[i];

	  [item descriptionWithLocale: nil indent: 0 to: result];
	  if (i != last)
	    {
	      (*appImp)(result, appSel, @", ");
	    }
	}
      (*appImp)(result, appSel, @")");
    }
  else
    {
      NSString	*iBaseString;
      NSString	*iSizeString;

      if (level < sizeof(indentStrings)/sizeof(id))
	{
	  iBaseString = indentStrings[level];
	}
      else
	{
	  iBaseString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}
      level++;
      if (level < sizeof(indentStrings)/sizeof(id))
	{
	  iSizeString = indentStrings[level];
	}
      else
	{
	  iSizeString = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}

      (*appImp)(result, appSel, @"(\n");
      for (i = 0; i < count; i++)
	{
	  id	item = plists[i];

	  (*appImp)(result, appSel, iSizeString);
     
	  [item descriptionWithLocale: locale indent: level to: result];
	  if (i == last)
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
}

- (BOOL) writeToFile: (NSString *)path atomically: (BOOL)useAuxiliaryFile
{
  NSDictionary	*loc;
  NSString	*desc;

  loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  desc = [self descriptionWithLocale: loc indent: 0];

  return [desc writeToFile: path atomically: useAuxiliaryFile];
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

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableArray_abstract_class)
    {
      return NSAllocateObject(NSMutableArray_concrete_class, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

- (Class) classForCoder
{
  return NSMutableArray_abstract_class;
}

/* The NSCopying Protocol */

- (id) copyWithZone: (NSZone*)zone
{
  /* a deep copy */
  unsigned	count = [self count];
  id		objects[count];
  NSArray	*newArray;
  unsigned	i;

  [self getObjects: objects];
  for (i = 0; i < count; i++)
    objects[i] = [objects[i] copyWithZone: zone];
  newArray = [[NSArray_concrete_class allocWithZone: zone]
    initWithObjects: objects count: count];
  while (i > 0)
    RELEASE(objects[--i]);
  return newArray;
}

/* This is the desgnated initializer for NSMutableArray */
- (id) initWithCapacity: (unsigned)numItems
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) addObject: anObject
{
  [self subclassResponsibility: _cmd];
}

- (void) replaceObjectAtIndex: (unsigned)index withObject: anObject
{
  [self subclassResponsibility: _cmd];
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
  [self subclassResponsibility: _cmd];
}

- (void) removeObjectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
}

@end


@implementation NSMutableArrayNonCore

+ (id) arrayWithCapacity: (unsigned)numItems
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: numItems]);
}

/* Override our superclass's designated initializer to go our's */
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  self = [self initWithCapacity: count];
  if (count > 0)
    {
      unsigned	i;
      IMP	add = [self methodForSelector: addSel];

      for (i = 0; i < count; i++)
	(*add)(self, addSel, objects[i]);
    }
  return self;
}

- (void) removeLastObject
{
  unsigned	count = [self count];

  if (count == 0)
    [NSException raise: NSRangeException
		 format: @"Trying to remove from an empty array."];
  [self removeObjectAtIndex: count-1];
}

- (void) removeObjectIdenticalTo: (id)anObject
{
  unsigned	i;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object", 0);
      return;
    }
  i = [self count];
  if (i > 0)
    {
      IMP	rem = 0;
      IMP	get = [self methodForSelector: oaiSel];

      while (i-- > 0)
	{
	  id	o = (*get)(self, oaiSel, i);

	  if (o == anObject)
	    {
	      if (rem == 0)
		{
		  rem = [self methodForSelector: remSel];
		}
	      (*rem)(self, remSel, i);
	    }
	}
    }
}

- (void) removeObject: (id)anObject inRange: (NSRange)aRange
{
  unsigned	c;
  unsigned	s;
  unsigned	i;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object", 0);
      return;
    }
  c = [self count];
  s = aRange.location;
  i = aRange.location + aRange.length;
  if (i > c)
    {
      i = c;
    }
  if (i > s)
    {
      IMP	rem = 0;
      IMP	get = [self methodForSelector: oaiSel];
      BOOL	(*eq)(id, SEL, id)
	= (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];

      while (i-- > s)
	{
	  id	o = (*get)(self, oaiSel, i);

	  if (o == anObject || (*eq)(anObject, eqSel, o) == YES)
	    {
	      if (rem == 0)
		{
		  rem = [self methodForSelector: remSel];
		  /*
		   * We need to retain the object so that when we remove the
		   * first equal object we don't get left with a bad object
		   * pointer for later comparisons.
		   */
		  RETAIN(anObject);
		}
	      (*rem)(self, remSel, i);
	    }
	}
#ifndef GS_WITH_GC
      if (rem != 0)
	{
	  RELEASE(anObject);
	}
#endif
    }
}

- (void) removeObjectIdenticalTo: (id)anObject inRange: (NSRange)aRange
{
  unsigned	c;
  unsigned	s;
  unsigned	i;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object", 0);
      return;
    }
  c = [self count];
  s = aRange.location;
  i = aRange.location + aRange.length;
  if (i > c)
    {
      i = c;
    }
  if (i > s)
    {
      IMP	rem = 0;
      IMP	get = [self methodForSelector: oaiSel];

      while (i-- > s)
	{
	  id	o = (*get)(self, oaiSel, i);

	  if (o == anObject)
	    {
	      if (rem == 0)
		{
		  rem = [self methodForSelector: remSel];
		}
	      (*rem)(self, remSel, i);
	    }
	}
    }
}

- (void) removeObject: (id)anObject
{
  unsigned	i;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object", 0);
      return;
    }
  i = [self count];
  if (i > 0)
    {
      IMP	rem = 0;
      IMP	get = [self methodForSelector: oaiSel];
      BOOL	(*eq)(id, SEL, id)
	= (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];

      while (i-- > 0)
	{
	  id	o = (*get)(self, oaiSel, i);

	  if (o == anObject || (*eq)(anObject, eqSel, o) == YES)
	    {
	      if (rem == 0)
		{
		  rem = [self methodForSelector: remSel];
		  /*
		   * We need to retain the object so that when we remove the
		   * first equal object we don't get left with a bad object
		   * pointer for later comparisons.
		   */
		  RETAIN(anObject);
		}
	      (*rem)(self, remSel, i);
	    }
	}
#ifndef GS_WITH_GC
      if (rem != 0)
	{
	  RELEASE(anObject);
	}
#endif
    }
}

- (void) removeAllObjects
{
  unsigned	c = [self count];

  if (c > 0)
    {
      IMP	remLast = [self methodForSelector: rlSel];

      while (c--)
	{
	  (*remLast)(self, rlSel);
	}
    }
}

- (void) addObjectsFromArray: (NSArray*)otherArray
{
  unsigned c = [otherArray count];

  if (c > 0)
    {
      unsigned	i;
      IMP	get = [otherArray methodForSelector: oaiSel];
      IMP	add = [self methodForSelector: addSel];

      for (i = 0; i < c; i++)
	(*add)(self, addSel,  (*get)(otherArray, oaiSel, i));
    }
}

- (void) setArray: (NSArray *)otherArray
{
  [self removeAllObjects];
  [self addObjectsFromArray: otherArray];
}

- (void) removeObjectsFromIndices: (unsigned*)indices 
		       numIndices: (unsigned)count
{
  if (count > 0)
    {
      unsigned	sorted[count];
      unsigned	to = 0;
      unsigned	from = 0;
      unsigned	i;

      while (from < count)
	{
	  unsigned	val = indices[from++];

	  i = to;
	  while (i > 0 && sorted[i] > val)
	    {
	      i--;
	    }
	  if (i == to)
	    {
	      sorted[to++] = val;
	    }
	  else if (sorted[i] != val)
	    {
	      unsigned	j = to++;

	      if (sorted[i] < val)
		{
		  i++;
		}
	      while (j > i)
		{
		  sorted[j] = sorted[j-1];
		  j--;
		}
	      sorted[i] = val;
	    }
	}

      if (to > 0)
	{
	  IMP	rem = [self methodForSelector: remSel];

	  while (to--)
	    {
	      (*rem)(self, remSel, sorted[to]);
	    }
	}
    }
}

- (void) removeObjectsInArray: (NSArray*)otherArray
{
  unsigned	c = [otherArray count];

  if (c > 0)
    {
      unsigned	i;
      IMP	get = [otherArray methodForSelector: oaiSel];
      IMP	rem = [self methodForSelector: @selector(removeObject:)];

      for (i = 0; i < c; i++)
	(*rem)(self, @selector(removeObject:), (*get)(otherArray, oaiSel, i));
    }
}

- (void) removeObjectsInRange: (NSRange)aRange
{
  unsigned	i;
  unsigned	s = aRange.location;
  unsigned	c = [self count];

  i = aRange.location + aRange.length;

  if (c < i)
    i = c;

  if (i > s)
    {
      IMP	rem = [self methodForSelector: remSel];

      while (i-- > s)
	{
	  (*rem)(self, remSel, i);
	}
    }
}

- (void) sortUsingSelector: (SEL)comparator
{
  int compare(id elem1, id elem2, void* context)
    {
      return (int)[elem1 performSelector: comparator withObject: elem2];
    }

  [self sortUsingFunction: compare context: NULL];
}

- (void) sortUsingFunction: (int(*)(id,id,void*))compare 
		   context: (void*)context
{
  /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
                        // 3 is a fairly good choice (Sedgewick)
  unsigned	c,d, stride;
  BOOL		found;
  int		count = [self count];
#ifdef	GSWARN
  BOOL		badComparison = NO;
#endif

  stride = 1;
  while (stride <= count)
    {
      stride = stride * STRIDE_FACTOR + 1;
    }
    
  while(stride > (STRIDE_FACTOR - 1))
    {
      // loop to sort for each value of stride
      stride = stride / STRIDE_FACTOR;
      for (c = stride; c < count; c++)
	{
	  found = NO;
	  if (stride > c)
	    {
	      break;
	    }
	  d = c - stride;
	  while (!found)	/* move to left until correct place */
	    {
	      id			a = [self objectAtIndex: d + stride];
	      id			b = [self objectAtIndex: d];
	      NSComparisonResult	r;

	      r = (*compare)(a, b, context);
	      if (r < 0)
		{
#ifdef	GSWARN
		  if (r != NSOrderedAscending)
		    {
		      badComparison = YES;
		    }
#endif
		  IF_NO_GC(RETAIN(a));
		  [self replaceObjectAtIndex: d + stride withObject: b];
		  [self replaceObjectAtIndex: d withObject: a];
		  RELEASE(a);
		  if (stride > d)
		    {
		      break;
		    }
		  d -= stride;		// jump by stride factor
		}
	      else
		{
#ifdef	GSWARN
		  if (r != NSOrderedDescending && r != NSOrderedSame)
		    {
		      badComparison = YES;
		    }
#endif
		  found = YES;
		}
	    }
	}
    }
#ifdef	GSWARN
  if (badComparison == YES)
    {
      NSWarnMLog(@"Detected bad return value from comparison", 0);
    }
#endif
}

@end

@interface NSArrayEnumerator : NSEnumerator
{
  NSArray	*array;
  unsigned	pos;
  IMP		get;
  unsigned	(*cnt)(NSArray*, SEL);
}
- (id) initWithArray: (NSArray*)anArray;
@end

@implementation NSArrayEnumerator

- (id) initWithArray: (NSArray*)anArray
{
  [super init];
  array = anArray;
  IF_NO_GC(RETAIN(array));
  pos = 0;
  get = [array methodForSelector: oaiSel];
  cnt = (unsigned (*)(NSArray*, SEL))[array methodForSelector: countSel];
  return self;
}

- (id) nextObject
{
  if (pos >= (*cnt)(array, countSel))
    return nil;
  return (*get)(array, oaiSel, pos++);
}

- (void) dealloc
{
  RELEASE(array);
  [super dealloc];
}

@end

@interface NSArrayEnumeratorReverse : NSArrayEnumerator
@end

@implementation NSArrayEnumeratorReverse

- (id) initWithArray: (NSArray*)anArray
{
  [super initWithArray: anArray];
  pos = (*cnt)(array, countSel);
  return self;
}

- (id) nextObject
{
  if (pos == 0)
    return nil;
  return (*get)(array, oaiSel, --pos);
}
@end


@implementation	NSArray (GNUstep)

/*
 *	The comparator function takes two items as arguments, the first is the
 *	item to be added, the second is the item already in the array.
 *      The function should return NSOrderedAscending if the item to be
 *      added is 'less than' the item in the array, NSOrderedDescending
 *      if it is greater, and NSOrderedSame if it is equal.
 */
- (unsigned) insertionPosition: (id)item
		 usingFunction: (NSComparisonResult (*)(id, id))sorter
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (sorter == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }

  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*sorter)(item, (*oai)(self, oaiSel, index));
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count
    && (*sorter)(item, (*oai)(self, oaiSel, index)) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}

- (unsigned) insertionPosition: (id)item
		 usingSelector: (SEL)comp
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  NSComparisonResult	(*imp)(id, SEL, id);
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (comp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }
  imp = (NSComparisonResult (*)(id, SEL, id))[item methodForSelector: comp];
  if (imp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with unknown method"];
    }

  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*imp)(item, comp, (*oai)(self, oaiSel, index));
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count
    && (*imp)(item, comp, (*oai)(self, oaiSel, index)) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}
@end

