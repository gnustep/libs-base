/* Interface for NSAutoreleasePool for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the Gnustep Base Library.

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

#ifndef __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE
#define __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

struct autorelease_array_list
{
  struct autorelease_array_list *next;
  unsigned size;
  unsigned count;
  id objects[0];
};

@interface NSAutoreleasePool : NSObject 
{
  /* For re-setting the current pool when we are dealloc'ed. */
  NSAutoreleasePool *_parent;
  /* This necessary for co-existing with exceptions. */
  NSAutoreleasePool *_child;
  /* An collection of the objects to be released. */
  struct autorelease_array_list *_released;
  struct autorelease_array_list *_released_head;
  /* The total number of objects autoreleased in this pool. */
  unsigned _released_count;
}

+ (void)addObject: anObject;
- (void)addObject: anObject;

+ (void) enableRelease: (BOOL)enable;
+ (void) setPoolCountThreshhold: (unsigned)c;
+ (unsigned) autoreleaseCountForObject: anObject;
+ (void) resetTotalAutoreleasedObjects;
+ (unsigned) totalAutoreleasedObjects;

@end

#endif /* __NSAutoreleasePool_h_GNUSTEP_BASE_INCLUDE */
