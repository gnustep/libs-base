/* Implementation of release pools for delayed disposal
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
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

#include <gnustep/base/prefix.h>
#include <gnustep/base/AutoreleasePool.h>
#include <gnustep/base/objc-malloc.h>
#include <gnustep/base/ObjectRetaining.h>

/* Doesn't handle multi-threaded stuff.
   Doesn't handle exceptions. */

/* Put the stuff from initialize into a runtime init function. 
   This class should be made more efficient, especially:
     [[Autorelease alloc] init]
     [current_pool addObject:o] (REALLOC-case)
   */

static AutoreleasePool *current_pool = nil;

#define DEFAULT_SIZE 64

@implementation AutoreleasePool

+ initialize
{
  if (self == [AutoreleasePool class])
    autorelease_class = self;
  return self;
}

+ currentPool
{
  return current_pool;
}

+ (void) autoreleaseObject: anObj
{
  [current_pool autoreleaseObject:anObj];
}

- (void) autoreleaseObject: anObj
{
  released_count++;
  if (released_count == released_size)
    {
      released_size *= 2;
      OBJC_REALLOC(released, id, released_size);
    }
  released[released_count] = anObj;
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
  [self error:"Don't call `-retain' on a AutoreleasePool"];
  return self;
}

- (oneway void) release
{
  [self dealloc];
}

- (void) dealloc
{
  int i;
  if (parent)
    current_pool = parent;
  else
    current_pool = [[AutoreleasePool alloc] init];
  for (i = 0; i < released_count; i++)
    [released[i] release];
  OBJC_FREE(released);
  object_dispose(self);
}

- autorelease
{
  [self error:"Don't call `-autorelease' on a AutoreleasePool"];
  return self;
}

@end
