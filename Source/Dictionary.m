/* Implementation for Objective-C Dictionary collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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
#include <gnustep/base/Dictionary.h>
#include <gnustep/base/CollectionPrivate.h>
#include <Foundation/NSCharacterSet.h>

#define DEFAULT_DICTIONARY_CAPACITY 32

@implementation Dictionary

// MANAGING CAPACITY;

/* Eventually we will want to have better capacity management,
   potentially keep default capacity as a class variable. */

+ (unsigned) defaultCapacity
{
  return DEFAULT_DICTIONARY_CAPACITY;
}
  
// INITIALIZING;

/* This is the designated initializer of this class */
- initWithCapacity: (unsigned)cap
{
  _contents_hash = NSCreateMapTable (NSObjectMapKeyCallBacks,
				     NSObjectMapValueCallBacks,
				     cap);
  return self;
}

/* Override the KeyedCollection designated initializer */
- initWithObjects: (id*)objects forKeys: (id*)keys count: (unsigned)c
{
  [self initWithCapacity: c];
  while (c--)
    [self putObject: objects[c] atKey: keys[c]];
  return self;
}

- init
{
  return [self initWithCapacity: DEFAULT_DICTIONARY_CAPACITY];
}

/* Archiving must mimic the above designated initializer */

- _initCollectionWithCoder: (id <Decoding>)coder
{
  _contents_hash = NSCreateMapTable (NSObjectMapKeyCallBacks,
				     NSObjectMapValueCallBacks,
				     0);
  return self;
}

/* Empty copy must empty an allocCopy'ed version of self */

- emptyCopy
{
  Dictionary *copy = [super emptyCopy];
  copy->_contents_hash = NSCreateMapTable (NSObjectMapKeyCallBacks,
					   NSObjectMapValueCallBacks,
					   0);
  return copy;
}

- (void) _collectionReleaseContents
{
  if (_contents_hash) {
    NSFreeMapTable (_contents_hash);
    _contents_hash = 0;
  }
}

- (void) dealloc
{
  [self _collectionReleaseContents];
  [super dealloc];
}

/* This must work without sending any messages to content objects */
- (void) _collectionEmpty
{
  NSResetMapTable (_contents_hash);
}


// ADDING OR REPLACING;

- (void) addObject: newObject
{
  [self shouldNotImplement: _cmd];
  /* or should I make up some default behavior here? 
     Base it on object conforming to <Associating> protocol, perhaps */
}

- (void) putObject: newObject atKey: aKey
{
  NSMapInsert (_contents_hash, aKey, newObject);
}


// REMOVING;

- (void) removeObjectAtKey: aKey
{
  NSMapRemove (_contents_hash, aKey);
}

- (void) removeObject: oldObject
{
  /* xxx Could be more efficient! */
  int count = [self count];
  id keys_to_remove[count];
  int num_keys_to_remove = 0;
  id o, k;
  NSMapEnumerator me = NSEnumerateMapTable (_contents_hash);

  /* Find all the keys with corresponding objects that equal oldObject. */
  while (NSNextMapEnumeratorPair (&me, (void**)&k, (void**)&o))
    if ([oldObject isEqual: o])
      keys_to_remove[num_keys_to_remove++] = k;
  /* Remove them. */
  while (num_keys_to_remove--)
    [self removeObjectAtKey: keys_to_remove[num_keys_to_remove]];
}


// GETTING ELEMENTS;

- (NSArray*) allKeys
{
  return NSAllMapTableKeys(_contents_hash);
}

- (NSArray*) allValues
{
  return NSAllMapTableValues(_contents_hash);
}

- objectAtKey: aKey
{
  return NSMapGet (_contents_hash, aKey);
}



// TESTING;

- (BOOL) containsKey: aKey
{
  if (NSMapGet (_contents_hash, aKey))
    return YES;
  else
    return NO;
}

- (unsigned) count
{
  return NSCountMapTable (_contents_hash);
}

// ENUMERATIONS;

- nextObjectAndKey: (id*)aKeyPtr withEnumState: (void**)enumState
{
  id o;
  if (!NSNextMapEnumeratorPair (*enumState, (void**)aKeyPtr, (void**)&o))
    return NO_OBJECT;
  return o;
}

- (void*) newEnumState
{
  void *me;

  OBJC_MALLOC (me, NSMapEnumerator, 1);
  *((NSMapEnumerator*)me) = NSEnumerateMapTable (_contents_hash);
  return me;
}

- (void) freeEnumState: (void**)enumState
{
  OBJC_FREE (*enumState);
}

- (NSString*) descriptionWithIndent: (unsigned)level
{
  int dict_count;
  id desc;
  id keyenum = [self keyEnumerator];
  id key;
  NSCharacterSet *quotables;

  quotables = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

  dict_count = [self count];
  desc = [NSMutableString stringWithCapacity: 2];
  [desc appendString: @"{"];
  if (dict_count > 0)
    [desc appendString: @"\n"];

  level += 2;

  while ((key = [keyenum nextObject]))
    {
      NSString *string;
      id object;
      string = [key description];

      if ([string length] == 0
	|| [string rangeOfCharacterFromSet: quotables].length > 0)
      	[desc appendFormat: @"%*s%s = ", level, "", [string quotedCString]];
      else
	[desc appendFormat: @"%*s%s = ", level, "", [string cStringNoCopy]];
      object = [self objectAtKey: key];
      if ([object respondsToSelector: @selector(descriptionWithIndent:)])
	{
	  /* This a dictionary or array, so don't quote it */
	  string = [object descriptionWithIndent: level];
	  [desc appendFormat: @"%@;\n", string];
	}
      else
	{
	  /* This should be a string or number, so decide if we need to 
	     quote it */
	  string = [object description];
	  if ([string length] == 0
		|| [string rangeOfCharacterFromSet: quotables].length > 0)
	    [desc appendFormat: @"%s;\n", [string quotedCString]];
	  else
	    [desc appendFormat: @"%s;\n", [string cStringNoCopy]];
	}
    }
  if (dict_count == 0)
    level = 0;
  else
    level -= 2;
  [desc appendFormat: @"%*s}", level, ""];
  return desc;
}

- (NSString*) description
{
  return [self descriptionWithIndent: 0];
}

@end
