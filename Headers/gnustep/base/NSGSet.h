/* Interface to concrete implementation of NSSet based on GNU Array
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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

#ifndef __NSGSet_h_OBJECTS_INCLUDE
#define __NSGSet_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <Foundation/NSSet.h>
#include <objects/Set.h>
#include <objects/Bag.h>
#include <objects/elt.h>

@interface NSGSet : NSSet
{
  /* For now, these must match the instance variables in objects/Set.h.
     This will change. */
  coll_cache_ptr _contents_hash;	// a hashtable to hold the contents;
  int (*_comparison_function)(elt,elt);
}

@end

@interface NSGMutableSet : NSMutableSet
{
  /* For now, these must match the instance variables in objects/Set.h.
     This will change. */
  coll_cache_ptr _contents_hash;	// a hashtable to hold the contents;
  int (*_comparison_function)(elt,elt);
}

@end

@interface NSGCountedSet : NSCountedSet
{
  /* For now, these must match the instance variables in objects/Bag.h.
     This will change. */
  coll_cache_ptr _contents_hash;	// a hashtable to hold the contents;
  int (*_comparison_function)(elt,elt);
  unsigned int count;
}

@end


#endif /* __NSGSet_h_OBJECTS_INCLUDE */
