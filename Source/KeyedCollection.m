/* Implementation for Objective-C KeyedCollection collection object
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#include <gnustep/base/KeyedCollection.h>
#include <gnustep/base/CollectionPrivate.h>
#include <stdio.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/NSString.h>
#include <gnustep/base/behavior.h>

@implementation KeyEnumerator

- initWithCollection: coll
{
  collection = [coll retain];
  enum_state = [coll newEnumState];
  return self;
}

- nextObject
{
  id k;
  [collection nextObjectAndKey: &k withEnumState: &enum_state];
  return k;
}

- (void) dealloc
{
  [collection freeEnumState: &enum_state];
  [collection release];
}

@end

@implementation ConstantKeyedCollection


// INITIALIZING;

/* This is the designated initializer */
- initWithObjects: (id*)objects forKeys: (id*)keys count: (unsigned)c
{
  [self subclassResponsibility: _cmd];
  return nil;
}


// GETTING ELEMENTS AND KEYS;

- objectAtKey: aKey
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- keyOfObject: aContentObject
{
  [self subclassResponsibility: _cmd];
  return nil;
}


// TESTING;

- (BOOL) containsKey: aKey
{
  if ([self objectAtKey: aKey] == NO_OBJECT)
    return NO;
  return YES;
}


// ENUMERATIONS;

- (id <Enumerating>) keyEnumerator
{
  return [[[KeyEnumerator alloc] initWithCollection: self]
	   autorelease];
}

- (void) withKeysInvoke: (id <Invoking>)anInvocation
{
  id o, k;

  FOR_KEYED_COLLECTION(self, o, k)
    {
      [anInvocation invokeWithObject: k];
    }
  END_FOR_KEYED_COLLECTION(self);
}

- (void) withKeysInvoke: (id <Invoking>)anInvocation
    whileTrue: (BOOL *)flag
{
  id o, k;

  FOR_KEYED_COLLECTION_WHILE_TRUE(self, o, k, *flag)
    {
      [anInvocation invokeWithObject: k];
    }
  END_FOR_KEYED_COLLECTION(self);
}

/* Override this Collection method */
- nextObjectWithEnumState: (void**)enumState
{
  id k;
  return [self nextObjectAndKey: &k withEnumState: enumState];
}



// LOW-LEVEL ENUMERATING;

- nextObjectAndKey: (id*)keyPtr withEnumState: (void**)enumState
{
  [self subclassResponsibility: _cmd];
  return nil;
}



// COPYING;

- shallowCopyValuesAs: (Class)aConstantCollectingClass
{
  int count = [self count];
  id contents[count];
  id k;
  int i = 0;
  id o;

  FOR_KEYED_COLLECTION(self, o, k)
    {
      contents[i++] = o;
    }
  END_FOR_KEYED_COLLECTION(self);
  return [[aConstantCollectingClass alloc] 
	   initWithObjects: contents count: count];
}

- shallowCopyKeysAs: (Class)aCollectingClass;
{
  int count = [self count];
  id contents[count];
  id k;
  int i = 0;
  id o;

  FOR_KEYED_COLLECTION(self, o, k)
    {
      contents[i++] = k;
    }
  END_FOR_KEYED_COLLECTION(self);
  return [[aCollectingClass alloc] 
	   initWithObjects: contents count: count];
}

- copyValuesAs: (Class)aCollectingClass
{
  [self notImplemented: _cmd];
  return nil;
}

- copyKeysAs: (Class)aCollectingClass;
{
  [self notImplemented: _cmd];
  return nil;
}


// ARCHIVING

- (void) _encodeContentsWithCoder: (id <Encoding>)aCoder
{
  unsigned int count = [self count];
  id o, k;

  [aCoder encodeValueOfCType: @encode(unsigned)
	  at: &count
	  withName: @"Collection content count"];
  FOR_KEYED_COLLECTION(self, o, k)
    {
      [aCoder encodeObject: k
	      withName: @"KeyedCollection key"];
      [aCoder encodeObject: o
	      withName:@"KeyedCollection content"];
    }
  END_FOR_KEYED_COLLECTION(self);
}

- (void) _decodeContentsWithCoder: (id <Decoding>)aCoder
{
  unsigned int count, i;
  id *objs, *keys;

  [aCoder decodeValueOfCType:@encode(unsigned)
	  at:&count
	  withName:NULL];
  OBJC_MALLOC(objs, id, count);
  OBJC_MALLOC(keys, id, count);
  for (i = 0; i < count; i++)
    {
      [aCoder decodeObjectAt: &(keys[i])
	      withName: NULL];
      [aCoder decodeObjectAt: &(objs[i])
	      withName: NULL];
    }
  [self initWithObjects: objs forKeys: keys count: count];
  OBJC_FREE(objs);
  OBJC_FREE(keys);
}

- (id <String>) description
{
  id s = [NSMutableString new];
  id o, k;

  FOR_KEYED_COLLECTION(self, o, k)
    {
      [s appendFormat: @"(%@,%@) ", [k description], [o description]];
    }
  END_FOR_KEYED_COLLECTION(self);
  [s appendFormat: @" :%s\n", object_get_class_name (self)];
  return [s autorelease];
}

@end



@implementation KeyedCollection 

+ (void) initialize
{
  if (self == [KeyedCollection class])
    class_add_behavior(self, [Collection class]);
}

// ADDING;
- (void) putObject: newContentObject atKey: aKey
{
  [self subclassResponsibility: _cmd];
}


// REPLACING AND SWAPPING;

- (void) replaceObjectAtKey: aKey with: newContentObject
{
  [self subclassResponsibility: _cmd];
}

- (void) swapObjectsAtKeys: key1 : key2
{
  [self subclassResponsibility: _cmd];
}


// REMOVING;
- (void) removeObjectAtKey: aKey
{
  [self subclassResponsibility: _cmd];
}

@end

