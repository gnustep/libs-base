/* Implementation for Objective-C Queue object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.
   
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
#include <base/Queue.h>
#include <base/ArrayPrivate.h>

@implementation Queue
  
- (void) enqueueObject: newObject
{
  [self prependObject: newObject];
}

- dequeueObject
{
  id ret = [[self lastObject] retain];
  [self removeLastObject];
  return [ret autorelease];
}

/* Overriding */
- (void) addObject: newObject
{
  [self enqueueObject: newObject];
}

@end
