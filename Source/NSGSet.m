/* Concrete implementation of NSSet based on GNU Set class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: Sep 1995
   
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

#include <Foundation/NSGSet.h>
#include <objects/NSSet.h>
#include <objects/behavior.h>
#include <objects/Set.h>
#include <objects/eltfuncs.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSString.h>

@interface NSGSetEnumerator : NSEnumerator
{
  NSSet *set;
  void *enum_state;
}
@end

@implementation NSGSetEnumerator

- initWithSet: (NSSet*)d
{
  [super init];
  set = d;
  [set retain];
  enum_state = 0;
  return self;
}

- nextObject
{
  elt e;
  if ([set getNextElement:&e withEnumState:&enum_state])
    return e.id_u;
  else
    return nil;
}

- (void) dealloc
{
  [set release];
  [super dealloc];
}

@end


@implementation NSGSet

+ (void) initialize
{
  static int done = 0;

  /* xxx This class not yet ready for action. */
  [self notImplemented:_cmd];

  if (!done)
    {
      done = 1;
      class_add_behavior([NSGSet class], [Set class]);
    }
}

#if 0

/* This is the designated initializer */
- initWithObjects: (id*)objects
	  forKeys: (NSString**)keys
	    count: (unsigned)count
{
  char * content_encoding = @encode(id);
  char * key_encoding = @encode(id);
  CALL_METHOD_IN_CLASS([KeyedCollection class], initWithType:keyType:,
		       content_encoding, key_encoding);
  _contents_hash = 
    coll_hash_new(POWER_OF_TWO(count),
		  elt_get_hash_function(key_encoding),
		  elt_get_comparison_function(key_encoding));
  _comparison_function = elt_get_comparison_function(content_encoding);
  while (count--)
    {
      [keys[count] retain];
      [objects[count] retain];
      coll_hash_add(&_contents_hash, keys[count], objects[count]);
    }
  return self;
}

/* 
   Comes from Set.m 
   - (unsigned) count 
   */

- objectForKey: (NSString*)aKey
{
  elt ret_nil(arglist_t a)
    {
      return nil;
    }
  return [self elementAtKey:aKey ifAbsentCall:ret_nil].id_u;
}

- (NSEnumerator*) keyEnumerator
{
  return [[NSGSetKeyEnumerator alloc] initWithSet:self];
}

- (NSEnumerator*) objectEnumerator
{
  return [[NSGSetObjectEnumerator alloc] initWithSet:self];
}
#endif

@end

@implementation NSGMutableSet

+ (void) initialize
{
  static int done = 0;

  /* xxx This class not yet ready for action. */
  [self notImplemented:_cmd];

  if (!done)
    {
      done = 1;
      class_add_behavior([NSGMutableSet class], [NSGSet class]);
    }
}

#if 0

/* This is the designated initializer */
/* Comes from Set.m
   - initWithCapacity: (unsigned)numItems
   */

- (void) setObject:anObject forKey:(NSString *)aKey
{
  [self putElement:anObject atKey:aKey];
}

- (void) removeObjectForKey:(NSString *)aKey
{
  elt do_nothing (arglist_t a)
    {
      return 0;
    }
  [self removeElementAtKey:aKey ifAbsentCall:do_nothing];
}

#endif

@end
