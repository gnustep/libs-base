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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
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

@interface NSDictionaryNonCore : NSDictionary
@end
@interface NSMutableDictionaryNonCore: NSMutableDictionary
@end

@implementation NSDictionary 

@class	NSGMutableCString;

@class	NSGDictionary;
@class	NSGMutableDictionary;

static Class NSDictionary_concrete_class;
static Class NSMutableDictionary_concrete_class;

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
      NSDictionary_concrete_class = [NSGDictionary class];
      NSMutableDictionary_concrete_class = [NSGMutableDictionary class];
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
    }
}

+ allocWithZone: (NSZone*)z
{
  if ([self class] == [NSDictionary class])
    return NSAllocateObject([self _concreteClass], 0, z);
  return [super allocWithZone: z];
}

/* This is the designated initializer */
- initWithObjects: (id*)objects
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

- objectForKey: (id)aKey
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
  return [[[[self class] _mutableConcreteClass] allocWithZone: z] 
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
  int objectCount = [objects count];
  id os[objectCount], ks[objectCount];
  
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
  int capacity = 16;
  int num_pairs = 0;
  id *objects;
  id *keys;
  id arg;
  int argi = 1;

  va_start (ap, firstObject);
  if (firstObject == nil)
    {
      return [self init];
    }
  /* Gather all the arguments in a simple array, in preparation for
     calling the designated initializer. */
  OBJC_MALLOC (objects, id, capacity);
  OBJC_MALLOC (keys, id, capacity);

  objects[num_pairs] = firstObject;
  /* Keep grabbing arguments until we get a nil... */
  while ((arg = va_arg (ap, id)))
    {
      if (num_pairs >= capacity)
	{
	  /* Must increase capacity in order to fit additional ARG's. */
	  capacity *= 2;
	  OBJC_REALLOC (objects, id, capacity);
	  OBJC_REALLOC (keys, id, capacity);
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
      OBJC_FREE(objects);
      OBJC_FREE(keys);
      [NSException raise: NSInvalidArgumentException
		  format: @"init dictionary with nil key"];
    }
  self = [self initWithObjects: objects forKeys: keys count: num_pairs];
  OBJC_FREE(objects);
  OBJC_FREE(keys);
  return self;
}

+ dictionaryWithObjectsAndKeys: (id)firstObject, ...
{
  va_list ap;
  int capacity = 16;
  int num_pairs = 0;
  id *objects;
  id *keys;
  id arg;
  int argi = 1;

  va_start (ap, firstObject);
  /* Gather all the arguments in a simple array, in preparation for
     calling the designated initializer. */
  OBJC_MALLOC (objects, id, capacity);
  OBJC_MALLOC (keys, id, capacity);
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
	      OBJC_REALLOC (objects, id, capacity);
	      OBJC_REALLOC (keys, id, capacity);
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
      OBJC_FREE(objects);
      OBJC_FREE(keys);
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

- initWithDictionary: (NSDictionary*)other
{
  return [self initWithDictionary: other copyItems: NO];
}

- initWithDictionary: (NSDictionary*)other copyItems: (BOOL)shouldCopy
{
  int c = [other count];
  id os[c], ks[c], k, e = [other keyEnumerator];
  int i = 0;

  if (shouldCopy)
    {
      NSZone	*z = [self zone];

      while ((k = [e nextObject]))
	{
	  ks[i] = k;
	  os[i] = [[other objectForKey: k] copyWithZone: z];
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
      while ((k = [e nextObject]))
	{
	  ks[i] = k;
	  os[i] = [other objectForKey: k];
	  i++;
	}
      return [self initWithObjects: os forKeys: ks count: c];
    }
}

- initWithContentsOfFile: (NSString*)path
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
      if ([result isKindOfClass: [NSDictionary class]])
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
  if ([other isKindOfClass: [NSDictionary class]])
    return [self isEqualToDictionary: other];
  return NO;
}

- (BOOL) isEqualToDictionary: (NSDictionary*)other
{
  if ([self count] != [other count])
    return NO;
  {
    id k, e = [self keyEnumerator];
    while ((k = [e nextObject]))
      {
	id o1 = [self objectForKey: k];
	id o2 = [other objectForKey: k];
	if (![o1 isEqual: o2])
	  return NO;
	/*
      if (![[self objectForKey: k] isEqual: [other objectForKey: k]])
	return NO; */
      }
  }
  /* xxx Recheck this. */
  return YES;
}

- (NSArray*) allKeys
{
  id e = [self keyEnumerator];
  int i, c = [self count];
  id k[c];

  for (i = 0; i < c; i++)
    {
      k[i] = [e nextObject];
      NSAssert (k[i], NSInternalInconsistencyException);
    }
  NSAssert (![e nextObject], NSInternalInconsistencyException);
  return AUTORELEASE([[NSArray allocWithZone: NSDefaultMallocZone()]
    initWithObjects: k count: c]);
}

- (NSArray*) allValues
{
  id e = [self objectEnumerator];
  int i, c = [self count];
  id k[c];

  for (i = 0; i < c; i++)
    {
      k[i] = [e nextObject];
      NSAssert (k[i], NSInternalInconsistencyException);
    }
  NSAssert (![e nextObject], NSInternalInconsistencyException);
  return AUTORELEASE([[NSArray allocWithZone: NSDefaultMallocZone()]
    initWithObjects: k count: c]);
}

- (NSArray*) allKeysForObject: anObject
{
  id k, e = [self keyEnumerator];
  id a[[self count]];
  int c = 0;

  while ((k = [e nextObject]))
    if ([anObject isEqual: [self objectForKey: k]])
      a[c++] = k;
  if (c == 0)
    return nil;
  return AUTORELEASE([[NSArray allocWithZone: NSDefaultMallocZone()]
    initWithObjects: a count: c]);
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
  info.i = [self methodForSelector: @selector(objectForKey:)];
  k = [[self allKeys] sortedArrayUsingFunction: compareIt context: &info];
  return k;
}

- (NSArray*) objectsForKeys: (NSArray*)keys notFoundMarker: (id)marker
{
  int	i, c = [keys count];
  id	obuf[c];

  for (i = 0; i < c; i++)
    {
      id o = [self objectForKey: [keys objectAtIndex: i]];

      if (o)
        obuf[i] = o;
      else
	obuf[i] = marker;
    }
  return [NSArray arrayWithObjects: obuf count: c];
}

- (BOOL)writeToFile: (NSString *)path atomically: (BOOL)useAuxiliaryFile
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
  NSEnumerator		*enumerator;
  id                    key;

  result = AUTORELEASE([[NSGMutableCString alloc] initWithCapacity: 1024]);
  enumerator = [self keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      id val = [self objectForKey: key];

      [key descriptionWithLocale: nil
                              to: (id<GNUDescriptionDestination>)result];
      if (val != nil && [val isEqualToString: @""] == NO)
        {
          [result appendString: @" = "];
          [val descriptionWithLocale: nil
                                  to: (id<GNUDescriptionDestination>)result];
        }
      [result appendString: @";\n"];
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
  NSEnumerator		*enumerator;
  id			key;
  BOOL			canCompare = YES;
  NSString		*iBaseString;
  NSString		*iSizeString;
  int			i;
  NSArray		*keyArray = [self allKeys];
  NSMutableArray	*theKeys = [NSMutableArray arrayWithArray: keyArray];
  int			numKeys = [theKeys count];
  NSString		*plists[numKeys];
  NSString		*keys[numKeys];
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

  enumerator = [self keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      if ([key respondsToSelector: @selector(compare:)] == NO)
	{
	  canCompare = NO;
	  break;
	}
    }

  if (canCompare)
    {
      [theKeys sortUsingSelector: @selector(compare:)];
    }

  [theKeys getObjects: keys];
  for (i = 0; i < numKeys; i++)
    {
      plists[i] = [self objectForKey: keys[i]];
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

+ (void)initialize
{
  if (self == [NSMutableDictionary class])
    {
      behavior_class_add_class (self, [NSMutableDictionaryNonCore class]);
      behavior_class_add_class (self, [NSDictionaryNonCore class]);
    }
}

+ allocWithZone: (NSZone*)z
{
  if ([self class] == [NSMutableDictionary class])
    return NSAllocateObject([self _mutableConcreteClass], 0, z);
  return [super allocWithZone: z];
}

- copyWithZone: (NSZone*)z
{
  /* a deep copy */
  unsigned	count = [self count];
  id		keys[count];
  id		objects[count];
  NSDictionary	*newDictionary;
  unsigned	i;
  id		key;
  NSEnumerator	*enumerator = [self keyEnumerator];
  static SEL	nxtSel = @selector(nextObject);
  IMP		nxtImp = [enumerator methodForSelector: nxtSel];
  static SEL	objSel = @selector(objectForKey:);
  IMP		objImp = [self methodForSelector: objSel];

  for (i = 0; (key = (*nxtImp)(enumerator, nxtSel)); i++)
    {
      keys[i] = key;
      objects[i] = (*objImp)(self, objSel, key);
      objects[i] = [objects[i] copyWithZone: z];
    }
  newDictionary = [[[[self class] _concreteClass] allocWithZone: z] 
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
- initWithCapacity: (unsigned)numItems
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
  [self initWithCapacity: count];
  while (count--)
    [self setObject: objects[count] forKey: keys[count]];
  return self;
}

- (void) removeAllObjects
{
  id k, e = [self keyEnumerator];
  while ((k = [e nextObject]))
    [self removeObjectForKey: k];
}

- (void) removeObjectsForKeys: (NSArray*)keyArray
{
  int c = [keyArray count];
  while (c--)
    [self removeObjectForKey: [keyArray objectAtIndex: c]];
}

- (void) addEntriesFromDictionary: (NSDictionary*)other
{
  id k, e = [other keyEnumerator];
  while ((k = [e nextObject]))
    [self setObject: [other objectForKey: k] forKey: k];
}

- (void) setDictionary: (NSDictionary*)otherDictionary
{
  [self removeAllObjects];
  [self addEntriesFromDictionary: otherDictionary];
}

@end
