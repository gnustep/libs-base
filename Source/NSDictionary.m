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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <config.h>
#include <gnustep/base/behavior.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>

@interface NSDictionaryNonCore : NSDictionary
@end
@interface NSMutableDictionaryNonCore: NSMutableDictionary
@end

@implementation NSDictionary 

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
  return NSAllocateObject([self _concreteClass], 0, z);
}

/* This is the designated initializer */
- initWithObjects: (id*)objects
	  forKeys: (id*)keys
	    count: (unsigned)count
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (unsigned) count
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- objectForKey: (id)aKey
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (NSEnumerator*) keyEnumerator
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- copyWithZone: (NSZone*)z
{
  /* a deep copy */
  unsigned count = [self count];
  id oldKeys[count];
  id newKeys[count];
  id oldObjects[count];
  id newObjects[count];
  id newDictionary;
  unsigned i;
  id key;
  NSEnumerator *enumerator = [self keyEnumerator];
  BOOL needCopy = [self isKindOfClass: [NSMutableDictionary class]];

  if (NSShouldRetainWithZone(self, z) == NO)
    needCopy = YES;
  for (i = 0; (key = [enumerator nextObject]); i++)
    {
      oldKeys[i] = key;
      oldObjects[i] = [self objectForKey:key];
      newKeys[i] = [oldKeys[i] copyWithZone:z];
      newObjects[i] = [oldObjects[i] copyWithZone:z];
      if (oldKeys[i] != newKeys[i] || oldObjects[i] != newObjects[i])
	needCopy = YES;
    }
  if (needCopy)
    newDictionary = [[[[self class] _concreteClass] alloc] 
	  initWithObjects:newObjects
	  forKeys:newKeys
	  count:count];
  else
    newDictionary = [self retain];
  for (i = 0; i < count; i++)
    {
      [newKeys[i] release];
      [newObjects[i] release];
    }
  return newDictionary;
}

- mutableCopyWithZone: (NSZone*)z
{
  /* a shallow copy */
  return [[[[[self class] _mutableConcreteClass] _mutableConcreteClass] alloc] 
	  initWithDictionary:self];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility:_cmd];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility:_cmd];
  return nil;
}
@end

@implementation NSDictionaryNonCore

+ dictionary
{
  return [[[self alloc] init] 
	  autorelease];
}

+ dictionaryWithDictionary: (NSDictionary*)otherDictionary
{
  return [[[self alloc] initWithDictionary: otherDictionary] autorelease];
}

+ dictionaryWithObjects: (id*)objects 
		forKeys: (id*)keys
		  count: (unsigned)count
{
  return [[[self alloc] initWithObjects:objects
			forKeys:keys
			count:count]
	  autorelease];
}

- (unsigned) hash
{
  return [self count];
}

- initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  int objectCount = [objects count];
  id os[objectCount], ks[objectCount];
  int i;
  
  if (objectCount != [keys count])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"init with obj and key arrays of different sizes"];
    }
  [objects getObjects: os];
  [keys getObjects: ks];
  return [self initWithObjects:os forKeys:ks count:objectCount];
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
      d = [[[self alloc] initWithObjects: objects forKeys: keys
			    count: num_pairs] autorelease];
      OBJC_FREE(objects);
      OBJC_FREE(keys);
      return d;
    }
  /* FIRSTOBJECT was nil; just return an empty NSDictionary object. */
  return [self dictionary];
}

+ dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  return [[[self alloc] initWithObjects:objects forKeys:keys]
	  autorelease];
}

+ dictionaryWithObject: (id)object forKey: (id)key
{
  return [[[self alloc] initWithObjects: &object forKeys: &key count: 1]
	  autorelease];
}

/* Override superclass's designated initializer */
- init
{
  return [self initWithObjects:NULL forKeys:NULL count:0];
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
      while (i > 0)
	{
	  [os[--i] release];
	}
      return self;
    }
  else
    {
      while ((k = [e nextObject]))
	{
	  ks[i] = k;
	  os[i] = [other objectForKey:k];
	  i++;
	}
      return [self initWithObjects:os forKeys:ks count:c];
    }
}

- initWithContentsOfFile: (NSString*)path
{
  NSString 	*myString;

  myString = [[NSString alloc] initWithContentsOfFile:path];
  if (myString)
    {
      id result = [myString propertyList];
      if ( [result isKindOfClass: [NSDictionary class]] )
	{
	  [self initWithDictionary: result];
	  return self;
	}
    }
  NSLog(@"Contents of file does not contain a dictionary");
  [self autorelease];
  return nil;
}

+ dictionaryWithContentsOfFile:(NSString *)path
{
  return [[[self alloc] initWithContentsOfFile:path] 
	   autorelease];
}

- (BOOL) isEqual: other
{
  if ([other isKindOfClass:[NSDictionary class]])
    return [self isEqualToDictionary:other];
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
      if (![[self objectForKey:k] isEqual:[other objectForKey:k]])
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
  return [[[NSArray alloc] initWithObjects:k count:c]
	  autorelease];
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
  return [[[NSArray alloc] initWithObjects:k count:c]
	  autorelease];
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
  return [[[NSArray alloc] initWithObjects: a count: c]
	  autorelease];
}

struct foo { NSDictionary *d; SEL s; };
   
static int
compareIt(id o1, id o2, void* context)
{
  struct foo	*f = (struct foo*)context;
  o1 = [f->d objectForKey: o1];
  o2 = [f->d objectForKey: o2];
  return (int)[o1 performSelector: f->s withObject: o2];
}

- (NSArray*)keysSortedByValueUsingSelector: (SEL)comp
{
  struct foo	info;
  id	k;

  info.d = self;
  info.s = comp;
  k = [[self allKeys] sortedArrayUsingFunction: compareIt context: &info];
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

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
  return [[self description] writeToFile:path atomically:useAuxiliaryFile];
}

- (NSString*) description
{
    return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionInStringsFileFormat
{
    NSMutableString	*result;
    int			size;
    int			i;
    NSAutoreleasePool	*arp = [[NSAutoreleasePool alloc] init];
    NSArray		*keysArray = [self allKeys];
    int			numKeys = [keysArray count];
    NSString		*plists[numKeys];
    NSString		*keys[numKeys];

    [keysArray getObjects: keys];

    size = 1;

    for (i = 0; i < numKeys; i++) {
	NSString	*newKey;
	id		key;
	id		item;

	key = keys[i];
	item = [self objectForKey: key];
	if ([key respondsToSelector: @selector(descriptionForPropertyList)]) {
	    newKey = [key descriptionForPropertyList];
	}
	else {
	    newKey = [key description];
	}
	keys[i] = newKey;

	if (item == nil) {
	    item = @"";
	}
	else if ([item isKindOfClass: [NSString class]]) {
	   item = [item descriptionForPropertyList];
	}
	else {
	   item = [item description];
	}
	plists[i] = item;

	size += [newKey length] + [item length];
	if ([item length]) {
	    size += 5;
	}
	else {
	    size += 2;
	}
    }

    result = [[NSMutableString alloc] initWithCapacity: size];
    for (i = 0; i < numKeys; i++) {
	NSString*	item = plists[i];

	[result appendString: keys[i]];
	if ([item length]) {
            [result appendString: @" = "];
	    [result appendString: item];
	}
	[result appendString: @";\n"];
    }

    [arp release];

    return [result autorelease];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
    return [self descriptionWithLocale: locale indent: 0];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
			     indent: (unsigned int)level
{
    NSMutableString	*result;
    NSEnumerator	*enumerator;
    id			key;
    BOOL		canCompare = YES;
    int			count;
    int			size;
    int			indentSize;
    int			indentBase;
    NSMutableString	*iBaseString;
    NSMutableString	*iSizeString;
    int			i;
    NSAutoreleasePool	*arp = [[NSAutoreleasePool alloc] init];
    NSArray		*keyArray = [self allKeys];
    NSMutableArray	*theKeys = [NSMutableArray arrayWithArray: keyArray];
    int			numKeys = [theKeys count];
    NSString		*plists[numKeys];
    NSString		*keys[numKeys];

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

    enumerator = [self keyEnumerator];
    while ((key = [enumerator nextObject]) != nil) {
	if ([key respondsToSelector: @selector(compare:)] == NO) {
	    canCompare = NO;
	    break;
	}
    }

    if (canCompare) {
	[theKeys sortUsingSelector: @selector(compare:)];
    }

    [theKeys getObjects: keys];
    for (i = 0; i < numKeys; i++) {
	NSString	*newKey;
	id		item;

	key = keys[i];
	item = [self objectForKey: key];
	if ([key respondsToSelector: @selector(descriptionForPropertyList)]) {
	    newKey = [key descriptionForPropertyList];
	}
	else {
	    newKey = [key description];
	}
	keys[i] = newKey;

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
	plists[i] = item;

	size += [newKey length] + [item length] + indentSize;
	if (i == numKeys - 1) {
	    size += 4;			/* ' = ' and newline	*/
	}
	else {
	    size += 5;			/* ' = ' and ';' and newline	*/
	}
    }

    result = [[NSMutableString alloc] initWithCapacity: size];
    [result appendString: @"{\n"];
    for (i = 0; i < numKeys; i++) {
	[result appendString: iSizeString];
	[result appendString: keys[i]];
        [result appendString: @" = "];
	[result appendString: plists[i]];
	if (i == numKeys - 1) {
            [result appendString: @"\n"];
	}
	else {
            [result appendString: @";\n"];
	}
    }
    [result appendString: iBaseString];
    [result appendString: @"}"];

    [arp release];

    return [result autorelease];
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
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

/* This is the designated initializer */
- initWithCapacity: (unsigned)numItems
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) setObject:anObject forKey:(id)aKey
{
  [self subclassResponsibility:_cmd];
}

- (void) removeObjectForKey:(id)aKey
{
  [self subclassResponsibility:_cmd];
}

@end

@implementation NSMutableDictionaryNonCore

+ dictionaryWithCapacity: (unsigned)numItems
{
  return [[[self alloc] initWithCapacity:numItems]
	  autorelease];
}

/* Override superclass's designated initializer */
- initWithObjects: (id*)objects
	  forKeys: (id*)keys
	    count: (unsigned)count
{
  [self initWithCapacity:count];
  while (count--)
    [self setObject:objects[count] forKey:keys[count]];
  return self;
}

- (void) removeAllObjects
{
  id k, e = [self keyEnumerator];
  while ((k = [e nextObject]))
    [self removeObjectForKey:k];
}

- (void) removeObjectsForKeys: (NSArray*)keyArray
{
  int c = [keyArray count];
  while (c--)
    [self removeObjectForKey:[keyArray objectAtIndex:c]];
}

- (void) addEntriesFromDictionary: (NSDictionary*)other
{
  id k, e = [other keyEnumerator];
  while ((k = [e nextObject]))
    [self setObject:[other objectForKey:k] forKey:k];
}

- (void) setDictionary: (NSDictionary*)otherDictionary
{
  [self removeAllObjects];
  [self addEntriesFromDictionary: otherDictionary];
}

@end
