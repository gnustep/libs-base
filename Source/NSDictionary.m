/* NSDictionary - Dictionary object to store key/value pairs
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   From skeleton by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995
   
   This file is part of the GNU Objective C Class Library.
   
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

#include <Foundation/NSDictionary.h>
#include <Foundation/NSGDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <objects/NSString.h>
#include <assert.h>

@implementation NSDictionary 

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
  NSDictionary_concrete_class = [NSGDictionary class];
  NSMutableDictionary_concrete_class = [NSGMutableDictionary class];
}

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _concreteClass], 0, z);
}

+ dictionary
{
  return [[[[self _concreteClass] alloc] init] 
	  autorelease];
}

+ dictionaryWithObjects: (id*)objects 
		forKeys: (NSString**)keys
		  count: (unsigned)count
{
  return [[[[self _concreteClass] alloc] initWithObjects:objects
					 forKeys:keys
					 count:count]
	  autorelease];
}

- initWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  int c = [objects count];
  id os[c], ks[c];
  int i;
  
  assert(c == [keys count]); /* Should be NSException instead */
  for (i = 0; i < c; i++)
    {
      os[i] = [objects objectAtIndex:i];
      ks[i] = [keys objectAtIndex:i];
    }
  return [self initWithObjects:os forKeys:ks count:c];
}

+ dictionaryWithObjects: (NSArray*)objects forKeys: (NSArray*)keys
{
  return [[[[self _concreteClass] alloc] initWithObjects:objects forKeys:keys]
	  autorelease];
}

/* This is the designated initializer */
- initWithObjects: (id*)objects
	  forKeys: (NSString**)keys
	    count: (unsigned)count
{
  [self notImplemented:_cmd];
  return 0;
}

/* Override superclass's designated initializer */
- init
{
  return [self initWithObjects:NULL forKeys:NULL count:0];
}

- initWithDictionary: (NSDictionary*)other
{
  int c = [other count];
  id os[c], ks[c], k, e = [other keyEnumerator];
  int i = 0;

  while ((k = [e nextObject]))
    {
      ks[i] = k;
      os[i] = [other objectForKey:k];
      i++;
    }
  return [self initWithObjects:os forKeys:ks count:c];
}

- initWithContentsOfFile: (NSString*)path
{
  [self notImplemented:_cmd];
  return 0;
}

- (unsigned) count
{
  [self notImplemented:_cmd];
  return 0;
}

- objectForKey: (NSString*)aKey
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSEnumerator*) keyEnumerator
{
  [self notImplemented:_cmd];
  return nil;
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
      if (![[self objectForKey:k] isEqual:[other objectForKey:k]])
	return NO;
  }
  /* xxx Recheck this. */
  return YES;
}

- (NSString*) description
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSString*) descriptionWithIndent: (unsigned)level
{
  /* xxx Fix this when we get %@ working in format strings. */
  return [NSString stringWithFormat:@"%*s%s", 
		   level, "", [[self description] cString]];
}

- (NSArray*) allKeys
{
  id e = [self keyEnumerator];
  int i, c = [self count];
  id k[c];

  for (i = 0; i < c; i++)
    {
      k[i] = [e nextObject];
      assert(k[i]);
    }
  assert(![e nextObject]);
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
      assert(k[i]);
    }
  assert(![e nextObject]);
  return [[[NSArray alloc] initWithObjects:k count:c]
	  autorelease];
}

- (NSArray*) allKeysForObject: anObject
{
  id k, e = [self keyEnumerator];
  id a[[self count]];
  int c = 0;

  while ((k = [e nextObject]))
    if ([anObject isEqual:[k objectForKey:k]])
      a[c++] = k;
  return [[[NSArray alloc] initWithObjects:a count:c]
	  autorelease];
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSEnumerator*) objectEnumerator
{
  [self notImplemented:_cmd];
  return nil;
}

- copyWithZone: (NSZone*)z
{
  /* a deep copy */
  int count = [self count];
  id objects[count];
  NSString *keys[count];
  id enumerator = [self keyEnumerator];
  id key;
  int i;

  for (i = 0; (key = [enumerator nextObject]); i++)
    {
      keys[i] = [key copyWithZone:z];
      objects[i] = [[self objectForKey:key] copyWithZone:z];
    }
  return [[[[self class] _concreteClass] alloc] 
	  initWithObjects:objects
	  forKeys:keys
	  count:count];
}

- mutableCopyWithZone: (NSZone*)z
{
  /* a shallow copy */
  return [[[[[self class] _mutableConcreteClass] _mutableConcreteClass] alloc] 
	  initWithDictionary:self];
}

@end

@implementation NSMutableDictionary

+ allocWithZone: (NSZone*)z
{
  return NSAllocateObject([self _mutableConcreteClass], 0, z);
}

+ dictionaryWithCapacity: (unsigned)numItems
{
  return [[[[self _mutableConcreteClass] alloc] initWithCapacity:numItems]
	  autorelease];
}

/* This is the designated initializer */
- initWithCapacity: (unsigned)numItems
{
  [self notImplemented:_cmd];
  return 0;
}

/* Override superclass's designated initializer */
- initWithObjects: (id*)objects
	  forKeys: (NSString**)keys
	    count: (unsigned)count
{
  [self initWithCapacity:count];
  while (count--)
    [self setObject:objects[count] forKey:keys[count]];
  return self;
}

- (void) setObject:anObject forKey:(NSString *)aKey
{
  [self notImplemented:_cmd];
}

- (void) removeObjectForKey:(NSString *)aKey
{
  [self notImplemented:_cmd];
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


@end
