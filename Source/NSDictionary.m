/** NSDictionary - Dictionary object to store key/value pairs
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995
   
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

   <title>NSDictionary class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSObjCRuntime.h>
#include "GSUserDefaults.h"

@implementation NSDictionary 

@class	GSDictionary;
@class	GSMutableDictionary;

static Class NSArray_class;
static Class NSDictionaryClass;
static Class NSMutableDictionaryClass;
static Class GSDictionaryClass;
static Class GSMutableDictionaryClass;

static SEL	eqSel;
static SEL	nxtSel;
static SEL	objSel;
static SEL	remSel;
static SEL	setSel;
static SEL	appSel;

+ (void) initialize
{
  if (self == [NSDictionary class])
    {
      NSArray_class = [NSArray class];
      NSDictionaryClass = [NSDictionary class];
      NSMutableDictionaryClass = [NSMutableDictionary class];
      GSDictionaryClass = [GSDictionary class];
      GSMutableDictionaryClass = [GSMutableDictionary class];

      eqSel = @selector(isEqual:);
      nxtSel = @selector(nextObject);
      objSel = @selector(objectForKey:);
      remSel = @selector(removeObjectForKey:);
      setSel = @selector(setObject:forKey:);
      appSel = @selector(appendString:);
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSDictionaryClass)
    {
      return NSAllocateObject(GSDictionaryClass, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

/* This is the designated initializer */
- (id) initWithObjects: (id*)objects
	       forKeys: (id*)keys
		 count: (unsigned)count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (unsigned) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) objectForKey: (id)aKey
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSEnumerator*) keyEnumerator
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  return [[GSMutableDictionaryClass allocWithZone: z] 
	  initWithDictionary: self];
}

- (Class) classForCoder
{
  return NSDictionaryClass;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	count = [self count];

  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      NSEnumerator	*enumerator = [self keyEnumerator];
      id		key;
      IMP		enc;
      IMP		nxt;
      IMP		ofk;

      nxt = [enumerator methodForSelector: @selector(nextObject)];
      enc = [aCoder methodForSelector: @selector(encodeObject:)];
      ofk = [self methodForSelector: @selector(objectForKey:)];

      while ((key = (*nxt)(enumerator, @selector(nextObject))) != nil)
	{
	  id	val = (*ofk)(self, @selector(objectForKey:), key);

	  (*enc)(aCoder, @selector(encodeObject:), key);
	  (*enc)(aCoder, @selector(encodeObject:), val);
	}
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;

  [aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
  if (count > 0)
    {
      id	*keys = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*count);
      id	*vals = NSZoneMalloc(NSDefaultMallocZone(), sizeof(id)*count);
      unsigned	i;
      IMP	dec;

      dec = [aCoder methodForSelector: @selector(decodeObject)];
      for (i = 0; i < count; i++)
	{
	  keys[i] = (*dec)(aCoder, @selector(decodeObject));
	  vals[i] = (*dec)(aCoder, @selector(decodeObject));
	}
      self = [self initWithObjects: vals forKeys: keys count: count];
      NSZoneFree(NSDefaultMallocZone(), keys);
      NSZoneFree(NSDefaultMallocZone(), vals);
    }

  return self;
}

+ (id) dictionary
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] init]);
}

+ (id) dictionaryWithDictionary: (NSDictionary*)otherDictionary
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithDictionary: otherDictionary]);
}

+ (id) dictionaryWithObjects: (id*)objects 
		     forKeys: (id*)keys
		       count: (unsigned)count
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objects forKeys: keys count: count]);
}

- (unsigned) hash
{
  return [self count];
}

- (id) initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  unsigned	objectCount = [objects count];
  id		os[objectCount];
  id		ks[objectCount];
  
  if (objectCount != [keys count])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"init with obj and key arrays of different sizes"];
    }
  [objects getObjects: os];
  [keys getObjects: ks];
  return [self initWithObjects: os forKeys: ks count: objectCount];
}

- (id) initWithObjectsAndKeys: (id)firstObject, ...
{
  va_list ap;
  int	capacity = 16;
  int	num_pairs = 0;
  id	*objects;
  id	*keys;
  id	arg;
  int	argi = 1;

  va_start (ap, firstObject);
  if (firstObject == nil)
    {
      return [self init];
    }
  /* Gather all the arguments in a simple array, in preparation for
     calling the designated initializer. */
  objects = (id*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(id) * capacity);
  keys = (id*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(id) * capacity);

  objects[num_pairs] = firstObject;
  /* Keep grabbing arguments until we get a nil... */
  while ((arg = va_arg (ap, id)))
    {
      if (num_pairs >= capacity)
	{
	  /* Must increase capacity in order to fit additional ARG's. */
	  capacity *= 2;
	  objects = (id*)NSZoneRealloc(NSDefaultMallocZone(), objects,
	    sizeof(id) * capacity);
	  keys = (id*)NSZoneRealloc(NSDefaultMallocZone(), keys,
	    sizeof(id) * capacity);
	}
      /* ...and alternately dump them into OBJECTS and KEYS */
      if (argi++ % 2 == 0)
	objects[num_pairs] = arg;
      else
	{
	  keys[num_pairs] = arg;
	  num_pairs++;
	}
    }
  if (argi %2 != 0)
    {
      NSZoneFree(NSDefaultMallocZone(), objects);
      NSZoneFree(NSDefaultMallocZone(), keys);
      [NSException raise: NSInvalidArgumentException
		  format: @"init dictionary with nil key"];
    }
  self = [self initWithObjects: objects forKeys: keys count: num_pairs];
  NSZoneFree(NSDefaultMallocZone(), objects);
  NSZoneFree(NSDefaultMallocZone(), keys);
  return self;
}

+ (id) dictionaryWithObjectsAndKeys: (id)firstObject, ...
{
  va_list ap;
  int	capacity = 16;
  int	num_pairs = 0;
  id	*objects;
  id	*keys;
  id	arg;
  int	argi = 1;

  va_start (ap, firstObject);
  /* Gather all the arguments in a simple array, in preparation for
     calling the designated initializer. */
  objects = (id*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(id) * capacity);
  keys = (id*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(id) * capacity);
  if (firstObject != nil)
    {
      NSDictionary *d;
      objects[num_pairs] = firstObject;
      /* Keep grabbing arguments until we get a nil... */
      while ((arg = va_arg (ap, id)))
	{
	  if (num_pairs >= capacity)
	    {
	      /* Must increase capacity in order to fit additional ARG's. */
	      capacity *= 2;
	      objects = (id*)NSZoneRealloc(NSDefaultMallocZone(), objects,
		sizeof(id) * capacity);
	      keys = (id*)NSZoneRealloc(NSDefaultMallocZone(), keys,
		sizeof(id) * capacity);
	    }
	  /* ...and alternately dump them into OBJECTS and KEYS */
	  if (argi++ % 2 == 0)
	    objects[num_pairs] = arg;
	  else
	    {
	      keys[num_pairs] = arg;
	      num_pairs++;
	    }
	}
      NSAssert (argi % 2 == 0, NSInvalidArgumentException);
      d = AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
	initWithObjects: objects forKeys: keys count: num_pairs]);
      NSZoneFree(NSDefaultMallocZone(), objects);
      NSZoneFree(NSDefaultMallocZone(), keys);
      return d;
    }
  /* FIRSTOBJECT was nil; just return an empty NSDictionary object. */
  return [self dictionary];
}

+ (id) dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: objects forKeys: keys]);
}

+ (id) dictionaryWithObject: (id)object forKey: (id)key
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithObjects: &object forKeys: &key count: 1]);
}

/* Override superclass's designated initializer */
- (id) init
{
  return [self initWithObjects: NULL forKeys: NULL count: 0];
}

- (id) initWithDictionary: (NSDictionary*)other
{
  return [self initWithDictionary: other copyItems: NO];
}

- (id) initWithDictionary: (NSDictionary*)other copyItems: (BOOL)shouldCopy
{
  unsigned	c = [other count];

  if (c > 0)
    {
      id		os[c];
      id		ks[c];
      id		k;
      NSEnumerator	*e = [other keyEnumerator];
      unsigned		i = 0;
      IMP		nxtObj = [e methodForSelector: nxtSel];
      IMP		otherObj = [other methodForSelector: objSel];

      if (shouldCopy)
	{
	  NSZone	*z = [self zone];

	  while ((k = (*nxtObj)(e, nxtSel)) != nil)
	    {
	      ks[i] = k;
	      os[i] = [(*otherObj)(other, objSel, k) copyWithZone: z];
	      i++;
	    }
	  self = [self initWithObjects: os forKeys: ks count: i];
#if	!GS_WITH_GC
	  while (i > 0)
	    {
	      [os[--i] release];
	    }
#endif
	}
      else
	{
	  while ((k = (*nxtObj)(e, nxtSel)) != nil)
	    {
	      ks[i] = k;
	      os[i] = (*otherObj)(other, objSel, k);
	      i++;
	    }
	  self = [self initWithObjects: os forKeys: ks count: c];
	}
    }
  return self;
}

- (id) initWithContentsOfFile: (NSString*)path
{
  NSString 	*myString;

  myString = [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: path];
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
      if ([result isKindOfClass: NSDictionaryClass])
	{
	  self = [self initWithDictionary: result];
	  return self;
	}
    }
  NSWarnMLog(@"Contents of file '%@' does not contain a dictionary", path);
  RELEASE(self);
  return nil;
}

+ (id) dictionaryWithContentsOfFile: (NSString *)path
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: path]);
}

- (BOOL) isEqual: other
{
  if (other == self)
    return YES;

  if ([other isKindOfClass: NSDictionaryClass])
    return [self isEqualToDictionary: other];

  return NO;
}

- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
  unsigned	count;

  if (other == self)
    {
      return YES;
    }
  count = [self count];
  if (count == [other count])
    {
      if (count > 0)
	{
	  NSEnumerator	*e = [self keyEnumerator];
	  IMP		nxtObj = [e methodForSelector: nxtSel];
	  IMP		myObj = [self methodForSelector: objSel];
	  IMP		otherObj = [other methodForSelector: objSel];
	  id		k;

	  while ((k = (*nxtObj)(e, @selector(nextObject))) != nil)
	    {
	      id o1 = (*myObj)(self, objSel, k);
	      id o2 = (*otherObj)(other, objSel, k);

	      if (o1 == o2)
		continue;
	      if ([o1 isEqual: o2] == NO)
		return NO;
	    }
	}
      return YES;
    }
  return NO;
}

- (NSArray*) allKeys
{
  unsigned	c = [self count];

  if (c == 0)
    {
      return [NSArray_class array];
    }
  else
    {
      NSEnumerator	*e = [self keyEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      id		k[c];
      unsigned		i;

      for (i = 0; i < c; i++)
	{
	  k[i] = (*nxtObj)(e, nxtSel);
	  NSAssert (k[i], NSInternalInconsistencyException);
	}
      return AUTORELEASE([[NSArray_class allocWithZone: NSDefaultMallocZone()]
	initWithObjects: k count: c]);
    }
}

- (NSArray*) allValues
{
  unsigned	c = [self count];

  if (c == 0)
    {
      return [NSArray_class array];
    }
  else
    {
      NSEnumerator	*e = [self objectEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      id		k[c];
      unsigned		i;

      for (i = 0; i < c; i++)
	{
	  k[i] = (*nxtObj)(e, nxtSel);
	}
      return AUTORELEASE([[NSArray_class allocWithZone: NSDefaultMallocZone()]
	initWithObjects: k count: c]);
    }
}

- (NSArray*) allKeysForObject: (id)anObject
{
  unsigned	c;

  if (anObject == nil || (c = [self count]) == 0)
    {
      return nil;
    }
  else
    {
      NSEnumerator	*e = [self keyEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      IMP		myObj = [self methodForSelector: objSel];
      BOOL		(*eqObj)(id, SEL, id);
      id		k;
      id		a[c];

      eqObj = (BOOL (*)(id, SEL, id))[anObject methodForSelector: eqSel];
      c = 0;
      while ((k = (*nxtObj)(e, nxtSel)) != nil)
	{
	  id	o = (*myObj)(self, objSel, k);

	  if (o == anObject || (*eqObj)(anObject, eqSel, o))
	    {
	      a[c++] = k;
	    }
	}
      if (c == 0)
	return nil;
      return AUTORELEASE([[NSArray_class allocWithZone: NSDefaultMallocZone()]
	initWithObjects: a count: c]);
    }
}

struct foo { NSDictionary *d; SEL s; IMP i; };
   
static int
compareIt(id o1, id o2, void* context)
{
  struct foo	*f = (struct foo*)context;
  o1 = (*f->i)(f->d, @selector(objectForKey:), o1);
  o2 = (*f->i)(f->d, @selector(objectForKey:), o2);
  return (int)[o1 performSelector: f->s withObject: o2];
}

- (NSArray*) keysSortedByValueUsingSelector: (SEL)comp
{
  struct foo	info;
  id	k;

  info.d = self;
  info.s = comp;
  info.i = [self methodForSelector: objSel];
  k = [[self allKeys] sortedArrayUsingFunction: compareIt context: &info];
  return k;
}

- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)marker
{
  unsigned	c = [keys count];

  if (c == 0)
    {
      return [NSArray_class array];
    }
  else
    {
      unsigned	i;
      id	obuf[c];
      IMP	myObj = [self methodForSelector: objSel];

      [keys getObjects: obuf];
      for (i = 0; i < c; i++)
	{
	  id o = (*myObj)(self, objSel, obuf[i]);

	  if (o)
	    obuf[i] = o;
	  else
	    obuf[i] = marker;
	}
      return [NSArray_class arrayWithObjects: obuf count: c];
    }
}

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

      result = AUTORELEASE([[NSMutableString alloc] initWithCapacity:
	20*[self count]]);
      [self descriptionWithLocale: loc
			   indent: 0
			       to: (id<GNUDescriptionDestination>)result];
      desc = result;
    }

  return [desc writeToFile: path atomically: useAuxiliaryFile];
}

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

      result = AUTORELEASE([[NSMutableString alloc] initWithCapacity:
	20*[self count]]);
      [self descriptionWithLocale: loc
			   indent: 0
			       to: (id<GNUDescriptionDestination>)result];
      desc = result;
    }

  return [desc writeToURL: url atomically: useAuxiliaryFile];
}

- (NSString*) description
{
  return [self descriptionWithLocale: nil indent: 0];
}

- (NSString*) descriptionInStringsFileFormat
{
  NSMutableString	*result;
  NSEnumerator		*enumerator = [self keyEnumerator];
  IMP			nxtObj = [enumerator methodForSelector: nxtSel];
  IMP			myObj = [self methodForSelector: objSel];
  IMP			appImp;
  id                    key;

  result = AUTORELEASE([[NSMutableString alloc] initWithCapacity: 1024]);
  appImp = [(NSObject*)result methodForSelector: appSel];
  while ((key = (*nxtObj)(enumerator, nxtSel)) != nil)
    {
      id val = (*myObj)(self, objSel, key);

      [key descriptionWithLocale: nil
			  indent: 0
                              to: (id<GNUDescriptionDestination>)result];
      if (val != nil && [val isEqualToString: @""] == NO)
        {
	  (*appImp)(result, appSel, @" = ");
          [val descriptionWithLocale: nil
			      indent: 0
                                  to: (id<GNUDescriptionDestination>)result];
        }
      (*appImp)(result, appSel, @";\n");
    }

  return result;
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  return [self descriptionWithLocale: locale indent: 0];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level
{
  NSMutableString	*result;

  result = AUTORELEASE([[NSMutableString alloc] initWithCapacity:
    20*[self count]]);
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
  IMP			myObj = [self methodForSelector: objSel];
  unsigned		i;
  NSArray		*keyArray = [self allKeys];
  unsigned		numKeys = [keyArray count];
  NSString		*plists[numKeys];
  NSString		*keys[numKeys];
  IMP			appImp;

  appImp = [(NSObject*)result methodForSelector: appSel];

  [keyArray getObjects: keys];

  if (locale == nil)
    {
      for (i = 0; i < numKeys; i++)
	{
	  plists[i] = (*myObj)(self, objSel, keys[i]);
	}

      (*appImp)(result, appSel, @"{");
      for (i = 0; i < numKeys; i++)
	{
	  id	o = plists[i];

	  [keys[i] descriptionWithLocale: nil indent: 0 to: result];
	  (*appImp)(result, appSel, @" = ");
	  [o descriptionWithLocale: nil indent: 0 to: result];
	  (*appImp)(result, appSel, @"; ");
	}
      (*appImp)(result, appSel, @"}");
    }
  else
    {
      NSString	*iBaseString;
      NSString	*iSizeString;
      BOOL	canCompare = YES;
      Class	lastClass = 0;

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

      for (i = 0; i < numKeys; i++)
	{
	  if (GSObjCClass(keys[i]) == lastClass)
	    continue;
	  if ([keys[i] respondsToSelector: @selector(compare:)] == NO)
	    {
	      canCompare = NO;
	      break;
	    }
	  lastClass = GSObjCClass(keys[i]);
	}

      if (canCompare == YES)
	{
	  /*
	   * Shell sort algorithm taken from SortingInAction - a NeXT example
	   * good value for stride factor is not well-understood
	   * 3 is a fairly good choice (Sedgewick)
	   */
#define STRIDE_FACTOR 3
	  unsigned	c,d, stride;
	  BOOL		found;
	  NSComparisonResult	(*comp)(id, SEL, id) = 0;
	  int		count = numKeys;
#ifdef	GSWARN
	  BOOL		badComparison = NO;
#endif

	  stride = 1;
	  while (stride <= count)
	    {
	      stride = stride * STRIDE_FACTOR + 1;
	    }
	  lastClass = 0;
	  while (stride > (STRIDE_FACTOR - 1))
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
		  while (!found)	// move to left until correct place
		    {
		      id			a = keys[d + stride];
		      id			b = keys[d];
		      Class			x;
		      NSComparisonResult	r;

		      x = GSObjCClass(a);
		      if (x != lastClass)
			{
			  lastClass = x;
			  comp = (NSComparisonResult (*)(id, SEL, id))
			    [a methodForSelector: @selector(compare:)];
			}
		      r = (*comp)(a, @selector(compare:), b);
		      if (r < 0)
			{
#ifdef	GSWARN
			  if (r != NSOrderedAscending)
			    {
			      badComparison = YES;
			    }
#endif
			  keys[d + stride] = b;
			  keys[d] = a;
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

      for (i = 0; i < numKeys; i++)
	{
	  plists[i] = (*myObj)(self, objSel, keys[i]);
	}

      (*appImp)(result, appSel, @"{\n");
      for (i = 0; i < numKeys; i++)
	{
	  id	o = plists[i];

	  (*appImp)(result, appSel, iSizeString);
	  [keys[i] descriptionWithLocale: nil indent: 0 to: result];
	  (*appImp)(result, appSel, @" = ");
	  [o descriptionWithLocale: locale indent: level to: result];
	  (*appImp)(result, appSel, @";\n");
	}
      (*appImp)(result, appSel, iBaseString);
      (*appImp)(result, appSel, @"}");
    }
}

@end

@implementation NSMutableDictionary

+ (void) initialize
{
  if (self == [NSMutableDictionary class])
    {
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableDictionaryClass)
    {
      return NSAllocateObject(GSMutableDictionaryClass, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  /* a deep copy */
  unsigned	count = [self count];
  id		keys[count];
  id		objects[count];
  NSDictionary	*newDictionary;
  unsigned	i;
  id		key;
  NSEnumerator	*enumerator = [self keyEnumerator];
  IMP		nxtImp = [enumerator methodForSelector: nxtSel];
  IMP		objImp = [self methodForSelector: objSel];

  for (i = 0; (key = (*nxtImp)(enumerator, nxtSel)); i++)
    {
      keys[i] = key;
      objects[i] = (*objImp)(self, objSel, key);
      objects[i] = [objects[i] copyWithZone: z];
    }
  newDictionary = [[GSDictionaryClass allocWithZone: z] 
	  initWithObjects: objects
		  forKeys: keys
		    count: count];
#if	!GS_WITH_GC
  while (i > 0)
    {
      [objects[--i] release];
    }
#endif
  return newDictionary;
}

- (Class) classForCoder
{
  return NSMutableDictionaryClass;
}

/* This is the designated initializer */
- (id) initWithCapacity: (unsigned)numItems
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) setObject: anObject forKey: (id)aKey
{
  [self subclassResponsibility: _cmd];
}

- (void) removeObjectForKey: (id)aKey
{
  [self subclassResponsibility: _cmd];
}

+ (id) dictionaryWithCapacity: (unsigned)numItems
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: numItems]);
}

/* Override superclass's designated initializer */
- (id) initWithObjects: (id*)objects
	       forKeys: (id*)keys
		 count: (unsigned)count
{
  self = [self initWithCapacity: count];
  if (self != nil)
    {
      IMP	setObj;

      setObj = [self methodForSelector: setSel];
      while (count--)
	{
	  (*setObj)(self, setSel, objects[count], keys[count]);
	}
    }
  return self;
}

- (void) removeAllObjects
{
  id		k;
  NSEnumerator	*e = [self keyEnumerator];
  IMP		nxtObj = [e methodForSelector: nxtSel];
  IMP		remObj = [self methodForSelector: remSel];

  while ((k = (*nxtObj)(e, nxtSel)) != nil)
    {
      (*remObj)(self, remSel, k);
    }
}

- (void) removeObjectsForKeys: (NSArray*)keyArray
{
  unsigned	c = [keyArray count];

  if (c > 0)
    {
      id	keys[c];
      IMP	remObj = [self methodForSelector: remSel];

      [keyArray getObjects: keys];
      while (c--)
	{
	  (*remObj)(self, remSel, keys[c]);
	}
    }
}

- (void) addEntriesFromDictionary: (NSDictionary*)other
{
  if (other != nil && other != self)
    {
      id		k;
      NSEnumerator	*e = [other keyEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      IMP		getObj = [other methodForSelector: objSel];
      IMP		setObj = [self methodForSelector: setSel];

      while ((k = (*nxtObj)(e, nxtSel)) != nil)
	{
	  (*setObj)(self, setSel, (*getObj)(other, objSel, k), k);
	}
    }
}

- (void) setDictionary: (NSDictionary*)otherDictionary
{
  [self removeAllObjects];
  [self addEntriesFromDictionary: otherDictionary];
}

@end
