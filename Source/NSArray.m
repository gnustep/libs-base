/** NSArray - Array object to hold other objects.
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

   <title>NSArray class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRange.h>
#include <limits.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSDebug.h>
#include "GSPrivate.h"

@class NSArrayEnumerator;
@class NSArrayEnumeratorReverse;

@class	GSArray;
@class	GSInlineArray;
@class	GSMutableArray;
@class	GSPlaceholderArray;

static Class NSArrayClass;
static Class GSArrayClass;
static Class GSInlineArrayClass;
static Class NSMutableArrayClass;
static Class GSMutableArrayClass;
static Class GSPlaceholderArrayClass;

static GSPlaceholderArray	*defaultPlaceholderArray;
static NSMapTable		*placeholderMap;
static NSLock			*placeholderLock;

@interface	NSArray (GSPrivate)
- (id) _initWithObjects: firstObject rest: (va_list) ap;
@end


/**
 * A simple, low overhead, ordered container for objects.
 */
@implementation NSArray

static SEL	addSel;
static SEL	appSel;
static SEL	countSel;
static SEL	eqSel;
static SEL	oaiSel;
static SEL	remSel;
static SEL	rlSel;

+ (void) initialize
{
  if (self == [NSArray class])
    {
      [self setVersion: 1];

      addSel = @selector(addObject:);
      appSel = @selector(appendString:);
      countSel = @selector(count);
      eqSel = @selector(isEqual:);
      oaiSel = @selector(objectAtIndex:);
      remSel = @selector(removeObjectAtIndex:);
      rlSel = @selector(removeLastObject);

      NSArrayClass = [NSArray class];
      NSMutableArrayClass = [NSMutableArray class];
      GSArrayClass = [GSArray class];
      GSInlineArrayClass = [GSInlineArray class];
      GSMutableArrayClass = [GSMutableArray class];
      GSPlaceholderArrayClass = [GSPlaceholderArray class];

      /*
       * Set up infrastructure for placeholder arrays.
       */
      defaultPlaceholderArray = (GSPlaceholderArray*)
	NSAllocateObject(GSPlaceholderArrayClass, 0, NSDefaultMallocZone());
      placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      placeholderLock = [NSLock new];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSArrayClass)
    {
      /*
       * For a constant array, we return a placeholder object that can
       * be converted to a real object when its initialisation method
       * is called.
       */
      if (z == NSDefaultMallocZone() || z == 0)
	{
	  /*
	   * As a special case, we can return a placeholder for an array
	   * in the default malloc zone extremely efficiently.
	   */
	  return defaultPlaceholderArray;
	}
      else
	{
	  id	obj;

	  /*
	   * For anything other than the default zone, we need to
	   * locate the correct placeholder in the (lock protected)
	   * table of placeholders.
	   */
	  [placeholderLock lock];
	  obj = (id)NSMapGet(placeholderMap, (void*)z);
	  if (obj == nil)
	    {
	      /*
	       * There is no placeholder object for this zone, so we
	       * create a new one and use that.
	       */
	      obj = (id)NSAllocateObject(GSPlaceholderArrayClass, 0, z);
	      NSMapInsert(placeholderMap, (void*)z, (void*)obj);
	    }
	  [placeholderLock unlock];
	  return obj;
	}
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

/**
 * Returns an empty autoreleased array.
 */
+ (id) array
{
  id	o;

  o = [self allocWithZone: NSDefaultMallocZone()];
  o = [o initWithObjects: (id*)0 count: 0];
  return AUTORELEASE(o);
}

/**
 * Returns a new autoreleased NSArray instance containing all the objects from
 * array, in the same order as the original.
 */
+ (id) arrayWithArray: (NSArray*)array
{
  id	o;

  o = [self allocWithZone: NSDefaultMallocZone()];
  o = [o initWithArray: array];
  return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array based upon the file.
 * This may be in property list format or in XML format
 * (if XML is available on your system).
 * This method returns nil if file does not represent an array.
 */
+ (id) arrayWithContentsOfFile: (NSString*)file
{
  id	o;

  o = [self allocWithZone: NSDefaultMallocZone()];
  o = [o initWithContentsOfFile: file];
  return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array containing anObject.
 */
+ (id) arrayWithObject: (id)anObject
{
  id	o;

  o = [self allocWithZone: NSDefaultMallocZone()];
  o = [o initWithObjects: &anObject count: 1];
  return AUTORELEASE(o);
}

/**
 * Returns an autoreleased array containing the list
 * of objects, preserving order.
 */
+ (id) arrayWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [[self allocWithZone: NSDefaultMallocZone()]
  _initWithObjects: firstObject rest: ap];
  va_end(ap);
  return AUTORELEASE(self);
}

/**
 * Returns an autoreleased array containing the specified
 * objects, preserving order.
 */
+ (id) arrayWithObjects: (id*)objects count: (unsigned)count
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objects count: count]);
}

/**
 * Returns an autoreleased array formed from the contents of
 * the receiver and adding anObject as the last item.
 */
- (NSArray*) arrayByAddingObject: (id)anObject
{
  id na;
  unsigned	c = [self count];
 
  if (anObject == nil)
    [NSException raise: NSInvalidArgumentException
		format: @"Attempt to add nil to an array"];
  if (c == 0)
    na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
      initWithObjects: &anObject count: 1];
  else
    {
      id	objects[c+1];

      [self getObjects: objects];
      objects[c] = anObject;
      na = [[GSArrayClass allocWithZone: NSDefaultMallocZone()]
	initWithObjects: objects count: c+1];
    }
  return AUTORELEASE(na);
}

/**
 * Returns a new array which is the concatenation of self and
 * otherArray (in this precise order).
 */
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
    na = [NSArrayClass arrayWithObjects: objects count: c+l];
  }
  return na;
}

/**
 * Returns the abstract class ... arrays are coded as abstract arrays
 */
- (Class) classForCoder
{
  return NSArrayClass;
}

/**
 * Returns YES if anObject belongs to self. No otherwise.<br />
 * The -isEqual: method of anObject is used to test for equality.
 */
- (BOOL) containsObject: (id)anObject
{
  return ([self indexOfObject: anObject] != NSNotFound);
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

/** <override-subclass />
 * Returns the number of elements contained in the receiver.
 */
- (unsigned) count
{
  [self subclassResponsibility: _cmd];
  return 0;
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

/**
 * Copies the objects from the receiver to aBuffer, which must be
 * an area of memory large enough to hold them.
 */
- (void) getObjects: (id*)aBuffer
{
  unsigned i, c = [self count];
  IMP	get = [self methodForSelector: oaiSel];

  for (i = 0; i < c; i++)
    aBuffer[i] = (*get)(self, oaiSel, i);
}

/**
 * Copies the objects from the range aRange of the receiver to aBuffer,
 * which must be an area of memory large enough to hold them.
 */
- (void) getObjects: (id*)aBuffer range: (NSRange)aRange
{
  unsigned i, j = 0, c = [self count], e = aRange.location + aRange.length;
  IMP	get = [self methodForSelector: oaiSel];

  GS_RANGE_CHECK(aRange, c);

  for (i = aRange.location; i < e; i++)
    aBuffer[j++] = (*get)(self, oaiSel, i);
}

/**
 * Returns the ame value as -count
 */
- (unsigned) hash
{
  return [self count];
}

/**
 * Returns the index of the specified object in the receiver, or
 * NSNotFound if the object is not present.
 */
- (unsigned) indexOfObjectIdenticalTo: (id)anObject
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

/**
 * Returns the index of the specified object in the range of the receiver,
 * or NSNotFound if the object is not present.
 */
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

/**
 * Returns the index of the first object found in the receiver
 * which is equal to anObject (using anObject's -isEqual: method).
 * Returns NSNotFound on failure.
 */
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

/**
 * Returns the index of the first object found in aRange of receiver
 * which is equal to anObject (using anObject's -isEqual: method).
 * Returns NSNotFound on failure.
 */
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

- (id) init
{
  return [self initWithObjects: (id*)0 count: 0];
}

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
  unsigned	c = [array count];
  id		objects[c];

  [array getObjects: objects];
  if (shouldCopy == YES)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [objects[i] copy];
	}
      self = [self initWithObjects: objects count: c];
#if GS_WITH_GC == 0
      while (i > 0)
	{
	  [objects[--i] release];
	}
#endif
    }
  else
    {
      self = [self initWithObjects: objects count: c];
    }
  return self;
}

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array
{
  unsigned	c = [array count];
  id		objects[c];

  [array getObjects: objects];
  self = [self initWithObjects: objects count: c];
  return self;
}

/**
 * Initialize the array by decoding from an archive.<br />
 * Invokes -initWithObjects:count:
 */
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
    {
      return [self initWithObjects: 0 count: 0];
    }
}

/**
 * <p>Initialises the array with the contents of the specified file,
 * which must contain an array in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (URF8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the file for any reason, the receiver
 * will be released and the method will return nil.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfFile:] and
 * [NSString-propertyList] then checking that the result is an array.  
 * </p>
 */
- (id) initWithContentsOfFile: (NSString*)file
{
  NSString 	*myString;

  myString = [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: file];
  if (myString == nil)
    {
      DESTROY(self);
    }
  else
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
      if ([result isKindOfClass: NSArrayClass])
	{
	  self = [self initWithArray: result];
	}
      else
	{
	  NSWarnMLog(@"Contents of file '%@' does not contain an array", file);
	  DESTROY(self);
	}
    }
  return self;
}

/** <init />
 * Initialize the array with count objects.<br />
 * Retains each object placed in the array.<br />
 * Like all initializers, may change the value of self before returning it.
 */
- (id) initWithObjects: (id*)objects count: (unsigned)count
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) _initWithObjects: firstObject rest: (va_list) ap
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

/**
 * Initialize the array the list of objects.
 * <br />May change the value of self before returning it.
 */
- (id) initWithObjects: firstObject, ...
{
  va_list ap;
  va_start(ap, firstObject);
  self = [self _initWithObjects: firstObject rest: ap];
  va_end(ap);
  return self;
}

/**
 * Returns an NSMutableArray instance containing the same objects as
 * the receiver.
 */
- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[GSMutableArrayClass allocWithZone: zone] 
    initWithArray: self];
}

/** <override-subclass />
 * Returns the object at the specified index.
 * Raises an exception of the index is beyond the array.
 */
- (id) objectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) isEqual: (id)anObject
{
  if (self == anObject)
    return YES;
  if ([anObject isKindOfClass: NSArrayClass])
    return [self isEqualToArray: anObject];
  return NO;
}

/**
 * Returns YES if the receiver is equal to otherArray, NO otherwise.
 */
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

/**
 * Returns the last object in the receiver, or nil if the receiver is empty.
 */
- (id) lastObject
{
  unsigned count = [self count];
  if (count == 0)
    return nil;
  return [self objectAtIndex: count-1];
}

/**
 * Makes each object in the array perform aSelector.<br />
 * This is done sequentially from the last to the first object.
 */
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

/**
 * Obsolete version of -makeObjectsPerformSelector:
 */
- (void) makeObjectsPerform: (SEL)aSelector
{
   [self makeObjectsPerformSelector: aSelector];
}

/**
 * Makes each object in the array perform aSelector with arg.<br />
 * This is done sequentially from the last to the first object.
 */
- (void) makeObjectsPerformSelector: (SEL)aSelector withObject: (id)arg
{
  unsigned i = [self count];

  if (i > 0)
    {
      IMP	get = [self methodForSelector: oaiSel];

      while (i-- > 0)
	[(*get)(self, oaiSel, i) performSelector: aSelector withObject: arg];
    }
}

/**
 * Obsolete version of -makeObjectsPerformSelector:withObject:
 */
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)argument
{
   [self makeObjectsPerformSelector: aSelector withObject: argument];
}

static int compare(id elem1, id elem2, void* context)
{
  return (int)[elem1 performSelector: (SEL)context withObject: elem2];
}

/**
 * Returns an autoreleased array in which the objects are ordered
 * according to a sort with comparator.
 */
- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
  return [self sortedArrayUsingFunction: compare context: (void *)comparator];
}

/**
 * Returns an autoreleased array in which the objects are ordered
 * according to a sort with comparator.
 */
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

  sortedArray = [[NSMutableArrayClass allocWithZone:
    NSDefaultMallocZone()] initWithArray: self];
  [sortedArray sortUsingFunction: comparator context: context];
  result = [NSArrayClass arrayWithArray: sortedArray];
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

/**
 * Returns an enumerator describing the array sequentially 
 * from the first to the last element.<br/>
 * If you use a mutable subclass of NSArray, 
 * you should not modify the array during enumeration.
 */
- (NSEnumerator*) objectEnumerator
{
  id	e;

  e = [NSArrayEnumerator allocWithZone: NSDefaultMallocZone()];
  e = [e initWithArray: self];
  return AUTORELEASE(e);
}

/**
 * Returns an enumerator describing the array sequentially 
 * from the last to the first element.<br/>
 * If you use a mutable subclass of NSArray, 
 * you should not modify the array during enumeration.
 */
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
  NSMutableString	*result;

  result = [[NSMutableString alloc] initWithCapacity: 20*[self count]];
  result = AUTORELEASE(result);
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

/**
 * <p>Writes the contents of the array to the file specified by path.
 * The file contents will be in property-list format ... under GNUstep
 * this is either OpenStep style (ASCII characters using \U hexadecimal
 * escape sequences for unicode), or MacOS-X style (XML in the UTF8
 * character set).
 * </p>
 * <p>If the useAuxiliaryFile flag is YES, the file write operation is
 * atomic ... the data is written to a temporary file, which is then
 * renamed to the actual file name.
 * </p>
 * <p>If the conversion of data into the correct property-list format fails
 * or the write operation fails, the method returns NO, otherwise it
 * returns YES.
 * </p>
 * <p>NB. The fact that the file is in property-list format does not
 * necessarily mean that it can be used to reconstruct the array using
 * the -initWithContentsOfFile: method.  If the original array contains
 * non-property-list objects, the descriptions of those objects will
 * have been written, and reading in the file as a property-list will
 * result in a new array containing the string descriptions.
 * </p>
 */
- (BOOL) writeToFile: (NSString *)path atomically: (BOOL)useAuxiliaryFile
{
  extern BOOL	GSMacOSXCompatiblePropertyLists();
  NSDictionary	*loc;
  NSString	*desc;

  loc = GSUserDefaultsDictionaryRepresentation();

  if (GSMacOSXCompatiblePropertyLists() == YES)
    {
      extern NSString	*GSXMLPlMake(id obj, NSDictionary *loc);

      desc = GSXMLPlMake(self, loc);
    }
  else
    {
      NSMutableString	*result;

      result = [[NSMutableString alloc] initWithCapacity: 20*[self count]];
      result = AUTORELEASE(result);
      [self descriptionWithLocale: loc
			   indent: 0
			       to: (id<GNUDescriptionDestination>)result];
      desc = result;
    }

  return [[desc dataUsingEncoding: NSUTF8StringEncoding]
    writeToFile: path atomically: useAuxiliaryFile];
}

/**
 * <p>Writes the contents of the array to the specified url.
 * This functions just like -writeToFile:atomically: except that the
 * output may be written to any URL, not just a local file.
 * </p>
 */
- (BOOL) writeToURL: (NSURL *)url atomically: (BOOL)useAuxiliaryFile
{
  extern BOOL	GSMacOSXCompatiblePropertyLists();
  NSDictionary	*loc;
  NSString	*desc;

  loc = GSUserDefaultsDictionaryRepresentation();

  if (GSMacOSXCompatiblePropertyLists() == YES)
    {
      extern NSString	*GSXMLPlMake(id obj, NSDictionary *loc);

      desc = GSXMLPlMake(self, loc);
    }
  else
    {
      NSMutableString	*result;

      result = [[NSMutableString alloc] initWithCapacity: 20*[self count]];
      result = AUTORELEASE(result);
      [self descriptionWithLocale: loc
			   indent: 0
			       to: (id<GNUDescriptionDestination>)result];
      desc = result;
    }

  return [[desc dataUsingEncoding: NSUTF8StringEncoding]
    writeToURL: url atomically: useAuxiliaryFile];
}

@end


@implementation NSMutableArray

+ (void) initialize
{
  if (self == [NSMutableArray class])
    {
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableArrayClass)
    {
      return NSAllocateObject(GSMutableArrayClass, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

+ (id) arrayWithObject: (id)anObject
{
  NSMutableArray	*obj = [self allocWithZone: NSDefaultMallocZone()];

  obj = [obj initWithObjects: &anObject count: 1];
  return AUTORELEASE(obj);
}

- (Class) classForCoder
{
  return NSMutableArrayClass;
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
    {
      objects[i] = [objects[i] copyWithZone: zone];
    }
  newArray = [[GSArrayClass allocWithZone: zone]
    initWithObjects: objects count: count];
#if GS_WITH_GC == 0
  while (i > 0)
    {
      [objects[--i] release];
    }
#endif
  return newArray;
}

/** <init />
 * Initialise the array with the specified capacity ... this
 * should ensure that the array can have numItems added efficiently.
 */
- (id) initWithCapacity: (unsigned)numItems
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/** <override-subclass />
 * Adds an object at the end of the array.
 */
- (void) addObject: (id)anObject
{
  [self subclassResponsibility: _cmd];
}

/**
 * Swaps the positions of two objects in the array.  Raises an exception
 * if either array index is out of bounds.
 */
- (void) exchangeObjectAtIndex: (unsigned int)i1 
             withObjectAtIndex: (unsigned int)i2
{
  id	tmp = [self objectAtIndex: i1];

  RETAIN(tmp);
  [self replaceObjectAtIndex: i1 withObject: [self objectAtIndex: i2]];
  [self replaceObjectAtIndex: i2 withObject: tmp];
  RELEASE(tmp);
}

/** <override-subclass />
 * Places an object into the receiver at the specified location.<br />
 * Raises an exception if given an array index which is too large.<br />
 * The object is retained by the array.
 */
- (void) replaceObjectAtIndex: (unsigned)index withObject: (id)anObject
{
  [self subclassResponsibility: _cmd];
}

/**
 * Replaces objects in the receiver with those from anArray.<br />
 * Raises an exception if given a range extending beyond the array.<br />
 */
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

/**
 * Replaces objects in the receiver with some of those from anArray.<br />
 * Raises an exception if given a range extending beyond the array.<br />
 */
- (void) replaceObjectsInRange: (NSRange)aRange
	  withObjectsFromArray: (NSArray*)anArray
			 range: (NSRange)anotherRange
{
  [self replaceObjectsInRange: aRange
	 withObjectsFromArray: [anArray subarrayWithRange: anotherRange]];
}

/** <override-subclass />
 * Inserts an object into the receiver at the specified location.<br />
 * Raises an exception if given an array index which is too large.<br />
 * The object is retained by the array.
 */
- (void) insertObject: anObject atIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
}

/** <override-subclass />
 * Removes an object from the receiver at the specified location.<br />
 * Raises an exception if given an array index which is too large.<br />
 */
- (void) removeObjectAtIndex: (unsigned)index
{
  [self subclassResponsibility: _cmd];
}

+ (id) arrayWithCapacity: (unsigned)numItems
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: numItems]);
}

/** <init /> Override our superclass's designated initializer to go our's */
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
      NSWarnMLog(@"attempt to remove nil object");
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
      NSWarnMLog(@"attempt to remove nil object");
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
#if GS_WITH_GC == 0
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
      NSWarnMLog(@"attempt to remove nil object");
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
      NSWarnMLog(@"attempt to remove nil object");
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
  [self sortUsingFunction: compare context: (void *)comparator];
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
      NSWarnMLog(@"Detected bad return value from comparison");
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
		 usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		       context: (void *)context
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

      comparison = (*sorter)(item, (*oai)(self, oaiSel, index), context);
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
    && (*sorter)(item, (*oai)(self, oaiSel, index), context) != NSOrderedAscending)
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

