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
#include <Foundation/NSData.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSValue.h>
#include "GSPrivate.h"

@implementation NSDictionary 

@class	GSDictionary;
@class	GSMutableDictionary;

extern BOOL	GSMacOSXCompatiblePropertyLists(void);
extern void	GSPropertyListMake(id, NSDictionary*, BOOL, unsigned, id*);


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

/** <init />
 */
- (id) initWithObjects: (id*)objects
	       forKeys: (id*)keys
		 count: (unsigned)count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 * Returns an unsigned integer which is the number of elements
 * stored in the dictionary.
 */
- (unsigned) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 * Returns the object in the dictionary corresponding to aKey, or nil if
 * the key is not present.
 */
- (id) objectForKey: (id)aKey
{
  [self subclassResponsibility: _cmd];
  return 0;
}

/**
 * Return an enumerator object containing all the keys of the dictionary.
 */
- (NSEnumerator*) keyEnumerator
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Return an enumerator object containing all the objects of the dictionary.
 */
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

/**
 * Returns a newly created dictionary with the keys and objects
 * of otherDictionary.
 * (The keys and objects are not copied.)
 */
+ (id) dictionaryWithDictionary: (NSDictionary*)otherDictionary
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithDictionary: otherDictionary]);
}

/**
 * Returns a dictionary created using the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
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

/**
 * Initialises a dictionary created using the given objects and keys.
 * The two arrays must have the same size.
 * The n th element of the objects array is associated with the n th
 * element of the keys array.
 */
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

/**
 * Initialises a dictionary created using the list given as argument.
 * The list is alernately composed of objects and keys.
 * Thus, the list's length must be pair.
 */
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

/**
 * Returns a dictionary created using the list given as argument.
 * The list is alernately composed of objects and keys.
 * Thus, the list's length must be pair.
 */
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

/**
 * Returns a dictionary containing only one object which is associated
 * with a key.
 */
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

- (id) initWithDictionary: (NSDictionary*)otherDictionary
{
  return [self initWithDictionary: otherDictionary copyItems: NO];
}

/**
 * Initialise dictionary with the keys and values of otherDictionary.
 * If the shouldCopy flag is YES then the values are copied into the
 * newly initialised dictionary, otherwise they are simply retained.
 */
- (id) initWithDictionary: (NSDictionary*)other
		copyItems: (BOOL)shouldCopy
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

/**
 * <p>Initialises the dictionary with the contents of the specified file,
 * which must contain a dictionary in property-list format.
 * </p>
 * <p>In GNUstep, the property-list format may be either the OpenStep
 * format (ASCII data), or the MacOS-X format (URF8 XML data) ... this
 * method will recognise which it is.
 * </p>
 * <p>If there is a failure to load the file for any reason, the receiver
 * will be released and the method will return nil.
 * </p>
 * <p>Works by invoking [NSString-initWithContentsOfFile:] and
 * [NSString-propertyList] then checking that the result is a dictionary.  
 * </p>
 */
- (id) initWithContentsOfFile: (NSString*)path
{
  NSString 	*myString;

  myString = [[NSString allocWithZone: NSDefaultMallocZone()]
    initWithContentsOfFile: path];
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
      if ([result isKindOfClass: NSDictionaryClass])
	{
	  self = [self initWithDictionary: result];
	}
      else
	{
	  NSWarnMLog(@"Contents of file '%@' does not contain a dictionary",
	    path);
	  DESTROY(self);
	}
    }
  return self;
}

/**
 * Returns a dictionary using the file located at path.
 * The file must be a property list containing a dictionary as its root object.
 */
+ (id) dictionaryWithContentsOfFile: (NSString*)path
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

/**
 * Returns an array containing all the dictionary's keys.
 */
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

/**
 * Returns an array containing all the dictionary's objects.
 */
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

/**
 * Returns an array containing all the dictionary's keys that are
 * associated with anObject.
 */
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

/**
 * <p>Writes the contents of the dictionary to the file specified by path.
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
 * necessarily mean that it can be used to reconstruct the dictionary using
 * the -initWithContentsOfFile: method.  If the original dictionary contains
 * non-property-list objects, the descriptions of those objects will
 * have been written, and reading in the file as a property-list will
 * result in a new dictionary containing the string descriptions.
 * </p>
 */
- (BOOL) writeToFile: (NSString *)path atomically: (BOOL)useAuxiliaryFile
{
  NSDictionary	*loc = GSUserDefaultsDictionaryRepresentation();
  NSString	*desc = nil;

  if (GSMacOSXCompatiblePropertyLists() == YES)
    {
      GSPropertyListMake(self, loc, YES, 2, &desc);
    }
  else
    {
      GSPropertyListMake(self, loc, NO, 2, &desc);
    }

  return [[desc dataUsingEncoding: NSUTF8StringEncoding]
    writeToFile: path atomically: useAuxiliaryFile];
}

/**
 * <p>Writes the contents of the dictionary to the specified url.
 * This functions just like -writeToFile:atomically: except that the
 * output may be written to any URL, not just a local file.
 * </p>
 */
- (BOOL) writeToURL: (NSURL *)url atomically: (BOOL)useAuxiliaryFile
{
  NSDictionary	*loc = GSUserDefaultsDictionaryRepresentation();
  NSString	*desc = nil;

  if (GSMacOSXCompatiblePropertyLists() == YES)
    {
      GSPropertyListMake(self, loc, YES, 2, &desc);
    }
  else
    {
      GSPropertyListMake(self, loc, NO, 2, &desc);
    }

  return [[desc dataUsingEncoding: NSUTF8StringEncoding]
    writeToURL: url atomically: useAuxiliaryFile];
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with a nil
 * locale and zero indent.
 */
- (NSString*) description
{
  return [self descriptionWithLocale: nil indent: 0];
}

/**
 * Returns the receiver as a text property list strings file format.<br />
 * See [NSString-propertyListFromStringsFileFormat] for details.<br />
 * The order of the items is undefined.
 */
- (NSString*) descriptionInStringsFileFormat
{
  NSMutableString	*result = nil;
  NSEnumerator		*enumerator = [self keyEnumerator];
  IMP			nxtObj = [enumerator methodForSelector: nxtSel];
  IMP			myObj = [self methodForSelector: objSel];
  id                    key;

  while ((key = (*nxtObj)(enumerator, nxtSel)) != nil)
    {
      id val = (*myObj)(self, objSel, key);

      GSPropertyListMake(key, nil, NO, 0, &result);
      if (val != nil && [val isEqualToString: @""] == NO)
        {
	  [result appendString: @" = "];
	  GSPropertyListMake(val, nil, NO, 0, &result);
        }
      [result appendString: @";\n"];
    }

  return result;
}

/**
 * Returns the result of invoking -descriptionWithLocale:indent: with
 * a zero indent.
 */
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
  return [self descriptionWithLocale: locale indent: 0];
}

/**
 * Returns the receiver as a text property list in the traditional format.<br />
 * See [NSString-propertyList] for details.<br />
 * If locale is nil, no formatting is done, otherwise entries are formatted
 * according to the locale, and indented according to level.<br />
 * Unless locale is nil, a level of zero indents items by four spaces,
 * while a level of one indents them by a tab.<br />
 * If the keys in the dictionary respond to -compare:, the items are
 * listed by key in ascending order.  If not, the order in which the
 * items are listed is undefined.
 */
- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level
{
  NSMutableString	*result = nil;

  GSPropertyListMake(self, locale, NO, level == 1 ? 3 : 2, &result);
  return result;
}

/**
 * Default implementation for this class is to return the value stored in
 * the dictionary under the specified key, or nil if there is no value.
 */
- (id) valueForKey: (NSString*)key
{
  id	o = [self objectForKey: key];

  if (o == nil)
    {
      if ([key isEqualToString: @"count"] == YES)
	{
	  o = [NSNumber numberWithUnsignedInt: [self count]];
	}
      else if ([key isEqualToString: @"allKeys"] == YES)
	{
	  o = [self allKeys];
	}
      else if ([key isEqualToString: @"allValues"] == YES)
	{
	  o = [self allValues];
	}
      if (o != nil)
	{
	  NSWarnMLog(@"Key '%@' would return nil in MacOS-X Foundation", key);
	}
    }
  return o;
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

/**
 * Merges information from otherDictionary into the receiver.
 * If a key exists in both dictionaries, the value from otherDictionary
 * replaces that which was originally in the reciever.
 */
- (void) addEntriesFromDictionary: (NSDictionary*)otherDictionary
{
  if (otherDictionary != nil && otherDictionary != self)
    {
      id		k;
      NSEnumerator	*e = [otherDictionary keyEnumerator];
      IMP		nxtObj = [e methodForSelector: nxtSel];
      IMP		getObj = [otherDictionary methodForSelector: objSel];
      IMP		setObj = [self methodForSelector: setSel];

      while ((k = (*nxtObj)(e, nxtSel)) != nil)
	{
	  (*setObj)(self, setSel, (*getObj)(otherDictionary, objSel, k), k);
	}
    }
}

- (void) setDictionary: (NSDictionary*)otherDictionary
{
  [self removeAllObjects];
  [self addEntriesFromDictionary: otherDictionary];
}

/**
 * Default implementation for this class is equivalent to the
 * -setObject:forKey: method unless value is nil, in which case
 * it is equivalent to -removeObjectForKey:
 */
- (void) takeStoredValue: (id)value forKey: (NSString*)key
{
  if (value == nil)
    {
      [self removeObjectForKey: key];
    }
  else
    {
      [self setObject: value forKey: key];
    }
}

/**
 * Default implementation for this class is equivalent to the
 * -setObject:forKey: method unless value is nil, in which case
 * it is equivalent to -removeObjectForKey:
 */
- (void) takeValue: (id)value forKey: (NSString*)key
{
  if (value == nil)
    {
      [self removeObjectForKey: key];
    }
  else
    {
      [self setObject: value forKey: key];
    }
}
@end
