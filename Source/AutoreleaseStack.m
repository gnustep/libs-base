/* Implementation of release stack for delayed disposal
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
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

#include <gnustep/base/preface.h>
#include <gnustep/base/AutoreleaseStack.h>
#include <gnustep/base/ObjectRetaining.h>
#include <gnustep/base/collhash.h>
#include <assert.h>

/* The initial size of the released_objects array */
#define DEFAULT_SIZE 64

/* Array of objects to be released later */
static unsigned released_capacity = 0;
static unsigned released_index = 0;
static id *released_objects = NULL;
static void **released_frame_pointers = NULL;

static inline void
grow_released_arrays()
{
  assert(released_objects);
  if (released_index == released_capacity)
    {
      released_capacity *= 2;
      OBJC_REALLOC(released_objects, id, released_capacity);
      OBJC_REALLOC(released_frame_pointers, void*, released_capacity);
    }
}

void
objc_release_stack_o_to_frame_address(void *frame_address)
{
  assert(released_objects);
  /* xxx This assumes stack grows up */
  while ((released_frame_pointers[released_index] 
	  > frame_address)
	 && released_index)
    {
      [released_objects[released_index] release];
      released_index--;
    }
}

void
objc_release_stack_objects()
{
  assert(released_objects);
  objc_release_stack_o_to_frame_address(__builtin_frame_address(1));
}

void
objc_stack_release_object_with_address (id o, void *a)
{
  released_index++;
  grow_released_arrays();
  released_objects[released_index] = o;
  released_frame_pointers[released_index] = a;
}

/* The object will not be released until after the function that is 3
   stack frames up exits.  One frame for this function, one frame for
   the "stackRelease" method that calls this, and one for the method
   that called "stackRelease". 
   Careful, if you try to call this too few stack frames away from main,
   you get a seg fault
*/
void
objc_stack_release_object(id anObj)
{
  void *s;

  /* assert(__builtin_frame_address(2)); */
  s = __builtin_frame_address(3);

  /* Do the pending releases of other objects */
  objc_release_stack_o_to_frame_address(s);

  /* Queue this object for later release */
  objc_stack_release_object_with_address(anObj, s);
}

unsigned
objc_stack_release_count()
{
  return released_index;
}

@implementation AutoreleaseStack

+ initialize
{
  static init_done = 0;

  /* Initialize if we haven't done it yet */
  if (!init_done)
    {
      init_done = 1;

      autorelease_class = self;
      
      released_capacity = DEFAULT_SIZE;
      OBJC_MALLOC(released_objects, id, released_capacity);
      OBJC_MALLOC(released_frame_pointers, void*, released_capacity);
    }
  return self;
}

- init
{
  objc_stack_release_object_with_address(self, 0);
  return self;
}

- (void) dealloc
{
  while (released_objects[released_index] != self)
    {
      [released_objects[released_index] release];
      released_index--;
    }
  released_index--;
  [super dealloc];
}

- (void) autoreleaseObject: anObject
{
  objc_stack_release_object(anObject);
}

+ (void) autoreleaseObject: anObject
{
  objc_stack_release_object(anObject);
}

@end
