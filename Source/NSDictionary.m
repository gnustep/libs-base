/* NSDictionary - Dictionary object to store key/value pairs
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
   */

#include <config.h>
#include <base/behavior.h>
#include <base/fast.x>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSDebug.h>

@interface NSDictionaryNonCore : NSDictionary
@end
@interface NSMutableDictionaryNonCore: NSMutableDictionary
@end

@implementation NSDictionary 

@class	NSGMutableCString;

@class	NSGDictionary;
@class	NSGMutableDictionary;

static Class NSArray_class;
static Class NSDictionary_abstract_class;
static Class NSMutableDictionary_abstract_class;
static Class NSDictionary_concrete_class;
static Class NSMutableDictionary_concrete_class;

static SEL	nxtSel = @selector(nextObject);
static SEL	objSel = @selector(objectForKey:);
static SEL	remSel = @selector(removeObjectForKey:);
static SEL	setSel = @selector(setObject:forKey:);
static SEL	appSel = @selector(appendString:);

+ (void) _setConcreteClass: (Class)c
{
  NSDictionary_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableDictionary_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSDictionary_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableDictionary_concrete_class;
}

+ (void) initialize
{
  if (self == [NSDictionary class])
    {
      NSArray_class = [NSArray class];
      NSDictionary_abstract_class = [NSDictionary class];
      NSMutableDictionary_abstract_class = [NSMutableDictionary class];
      NSDictionary_concrete_class = [NSGDictionary class];
      NSMutableDictionary_concrete_class = [NSGMutableDictionary class];
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSDictionary_abstract_class)
    return NSAllocateObject(NSDictionary_concrete_class, 0, z);
  return [super allocWithZone: z];
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
  return [[NSMutableDictionary_concrete_class allocWithZone: z] 
	  initWithDictionary: self];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}
@end

@implementation NSDictionaryNonCore

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
  id		os[c];
  id		ks[c];
  id		k;
  NSEnumerator	*e = [other keyEnumerator];
  unsigned	i = 0;
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
      return self;
    }
  else
    {
      while ((k = (*nxtObj)(e, nxtSel)) != nil)
	{
	  ks[i] = k;
	  os[i] = (*otherObj)(other, objSel, k);
	  i++;
	}
      return [self initWithObjects: os forKeys: ks count: c];
    }
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
      if ([result isKindOfClass: NSDictionary_abstract_class])
	{
	  [self initWithDictionary: result];
	  return self;
	}
    }
  NSLog(@"Contents of file does not contain a dictionary");
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

  if ([other isKindOfClass: NSDictionary_abstract_class])
    return [self isEqualToDictionary: other];

  return NO;
}

- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
  if (other == self)
    return YES;

  if ([self count] == [other count])
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

	  if ([o1 isEqual: o2] == NO)
	    return NO;
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
  unsigned	c = [self count];

  if (c == 0)
    {
      return nil;
    }
  else
    {
      static SEL	eqSel = @selector(isEqual:);
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
	  if ((*eqObj)(anObject, eqSel, (*myObj)(self, objSel, k)))
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
  return [[self description] writeToFile: path atomically: useAuxiliaryFile];
}

- (NSString*) description
{
  return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionInStringsFileFormat
{
  NSMutableString	*result;
  NSEnumerator		*enumerator = [self keyEnumerator];
  IMP			nxtObj = [enumerator methodForSelector: nxtSel];
  IMP			myObj = [self methodForSelector: objSel];
  IMP			appImp;
  id                    key;

  result = AUTORELEASE([[NSGMutableCString alloc] initWithCapacity: 1024]);
  appImp = [(NSObject*)result methodForSelector: appSel];
  while ((key = (*nxtObj)(enumerator, nxtSel)) != nil)
    {
      id val = (*myObj)(self, objSel, key);

      [key descriptionWithLocale: nil
                              to: (id<GNUDescriptionDestination>)result];
      if (val != nil && [val isEqualToString: @""] == NO)
        {
	  (*appImp)(result, appSel, @" = ");
          [val descriptionWithLocale: nil
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

  result = AUTORELEASE([[NSGMutableCString alloc] initWithCapacity:
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
  BOOL			canCompare = YES;
  NSString		*iBaseString;
  NSString		*iSizeString;
  unsigned		i;
  NSArray		*keyArray = [self allKeys];
  unsigned		numKeys = [keyArray count];
  NSString		*plists[numKeys];
  NSString		*keys[numKeys];
  IMP			appImp;
  Class			lastClass = 0;

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

  [keyArray getObjects: keys];
  for (i = 0; i < numKeys; i++)
    {
      if (fastClass(keys[i]) == lastClass)
	continue;
      if ([keys[i] respondsToSelector: @selector(compare:)] == NO)
	{
	  canCompare = NO;
	  break;
	}
      lastClass = fastClass(keys[i]);
    }

  if (canCompare)
    {
/*
 * Shell sort algorithm taken from SortingInAction - a NeXT example
 * good value for stride factor is not well-understood
 * 3 is a fairly good choice (Sedgewick)
 */
#define STRIDE_FACTOR 3
      unsigned	c,d, stride;
      BOOL	found;
      NSComparisonResult	(*comp)(id, SEL, id);
      int	count = numKeys;
#ifdef	GSWARN
      BOOL	badComparison = NO;
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

		  x = fastClass(a);
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
	  NSWarnMLog(@"Detected bad return value from comparison", 0);
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
      id	item = plists[i];

      (*appImp)(result, appSel, iSizeString);

      [keys[i] descriptionTo: result];

      (*appImp)(result, appSel, @" = ");

      if ([item respondsToSelector: @selector(descriptionWithLocale:indent:)])
	{
	  [item descriptionWithLocale: locale indent: level to: result];
	}
      else if ([item respondsToSelector: @selector(descriptionWithLocale:)])
	{
	  [item descriptionWithLocale: locale to: result];
	}
      else
	{
	  [item descriptionTo: result];
	}

      (*appImp)(result, appSel, @";\n");
    }
  (*appImp)(result, appSel, iBaseString);
  (*appImp)(result, appSel, @"}");
}

@end

@implementation NSMutableDictionary

+ (void) initialize
{
  if (self == [NSMutableDictionary class])
    {
      behavior_class_add_class (self, [NSMutableDictionaryNonCore class]);
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableDictionary_abstract_class)
    return NSAllocateObject(NSMutableDictionary_concrete_class, 0, z);
  return [super allocWithZone: z];
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
  newDictionary = [[NSDictionary_concrete_class allocWithZone: z] 
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

@end

@implementation NSMutableDictionaryNonCore

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
  IMP	setObj;

  [self initWithCapacity: count];
  setObj = [self methodForSelector: setSel];
  while (count--)
    (*setObj)(self, setSel, objects[count], keys[count]);
  return self;
}

- (void) removeAllObjects
{
  id		k;
  NSEnumerator	*e = [self keyEnumerator];
  IMP		nxtObj = [e methodForSelector: nxtSel];
  IMP		remObj = [self methodForSelector: remSel];

  while ((k = (*nxtObj)(e, nxtSel)) != nil)
    (*remObj)(self, remSel, k);
}

- (void) removeObjectsForKeys: (NSArray*)keyArray
{
  unsigned	c = [keyArray count];

  if (c)
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
  id		k;
  NSEnumerator	*e = [other keyEnumerator];
  IMP		nxtObj = [e methodForSelector: nxtSel];
  IMP		setObj = [self methodForSelector: setSel];

  while ((k = (*nxtObj)(e, nxtSel)) != nil)
    (*setObj)(self, setSel, [other objectForKey: k], k);
}

- (void) setDictionary: (NSDictionary*)otherDictionary
{
  [self removeAllObjects];
  [self addEntriesFromDictionary: otherDictionary];
}

@end
