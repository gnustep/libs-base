/* Interface to concrete implementation of NSArray based on GNU Array
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
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

#ifndef __NSGArray_h_OBJECTS_INCLUDE
#define __NSGArray_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <foundation/NSArray.h>
#include <objects/elt.h>

@interface NSGArray : NSArray
{
  /* For now, these must match the instance variables in objects/Array.h.
     This will change. */
  int (*_comparison_function)(elt,elt);
  elt *_contents_array;
  unsigned int _count;
  unsigned int _capacity;
  unsigned int _grow_factor;
}

@end

@interface NSGMutableArray : NSMutableArray
{
  /* For now, these must match the instance variables in objects/Array.h.
     This will change. */
  int (*_comparison_function)(elt,elt);
  elt *_contents_array;
  unsigned int _count;
  unsigned int _capacity;
  unsigned int _grow_factor;
}

@end

#endif /* __NSGArray_h_OBJECTS_INCLUDE */
