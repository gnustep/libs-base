/* Implementation of auto release pool for delayed disposal
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995
   
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

#include <objects/stdobjects.h>
#include <Foundation/NSAutoreleasePool.h>
#include <objects/objc-malloc.h>
#include <limits.h>

/* Doesn't handle multi-threaded stuff.
   Doesn't handle exceptions. */

/* Put the stuff from initialize into a runtime init function. 
   This class should be made more efficient, especially:
     [[NSAutorelease alloc] init]
     [current_pool addObject:o] (REALLOC-case)
   */

static NSAutoreleasePool *current_pool = nil;

/* When this is `NO', autoreleased objects are never actually sent a 
   `release' message.  Memory use grows, and grows, and... */
static BOOL autorelease_enabled = YES;

/* When the released_count gets over this value, we call error:.
   In the future, I may change this to raise an exception or call 
   a function instead. */
static unsigned pool_count_warning_threshhold = UINT_MAX;

#define DEFAULT_SIZE 64

@implementation NSAutoreleasePool

/* This method not in OpenStep */
- parentAutoreleasePool
{
  return parent;
}

/* This method not in OpenStep */
- (unsigned) autoreleaseCount
{
  return released_count;
}

/* This method not in OpenStep */
- (unsigned) autoreleaseCountForObject: anObject
{
  unsigned count = 0;
  int i;

  for (i = 0; i < released_count; i++)
    if (released[i] == anObject)
      count++;
  return count;
}

/* This method not in OpenStep */
+ (unsigned) autoreleaseCountForObject: anObject
{
  unsigned count = 0;
  id pool = current_pool;
  while (pool)
    {
      count += [pool autoreleaseCountForObject:anObject];
      pool = [pool parentAutoreleasePool];
    }
  return count;
}

+ currentPool
{
  return current_pool;
}

+ (void) addObject: anObj
{
  [current_pool addObject:anObj];
}

- (void) addObject: anObj
{
  if (!autorelease_enabled)
    return;

  if (released_count >= pool_count_warning_threshhold)
    [self error:"AutoreleasePool count threshhold exceeded."];

  if (released_count == released_size)
    {
      released_size *= 2;
      OBJC_REALLOC(released, id, released_size);
    }
  released[released_count] = anObj;
  released_count++;
}

- init
{
  parent = current_pool;
  current_pool = self;
  OBJC_MALLOC(released, id, DEFAULT_SIZE);
  released_size = DEFAULT_SIZE;
  released_count = 0;
  return self;
}

- (id) retain
{
  [self error:"Don't call `-retain' on a NSAutoreleasePool"];
  return self;
}

- (oneway void) release
{
  [self dealloc];
}

- (void) dealloc
{
  int i;

  /* Make debugging easier by checking to see if we already dealloced the
     object before trying to release it.  Also, take the object out of the
     released list just before releasing it, so if we are doing 
     "double_release_check"ing, then autoreleaseCountForObject: won't find the 
     object we are currently releasing. */
  for (i = 0; i < released_count; i++)
    {
      id anObject = released[i];
      if (object_get_class(anObject) == (void*) 0xdeadface)
	[self error:"Autoreleasing deallocated object. Debug after setting [NSObject enableDoubleReleaseCheck:YES] to check for release errors."];
      released[i]=0;
      [anObject release];
    }
  OBJC_FREE(released);
  if (parent)
    current_pool = parent;
  else
    current_pool = [[NSAutoreleasePool alloc] init];
  NSDeallocateObject(self);
}

- autorelease
{
  [self error:"Don't call `-autorelease' on a NSAutoreleasePool"];
  return self;
}

+ (void) enableRelease: (BOOL)enable
{
  autorelease_enabled = enable;
}

+ (void) setPoolCountThreshhold: (unsigned)c
{
  pool_count_warning_threshhold = c;
}

@end
