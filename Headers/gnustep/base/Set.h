/* Interface for Objective-C Set collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

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

#ifndef __Set_h_OBJECTS_INCLUDE
#define __Set_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Collection.h>

@interface Set : Collection
{
  coll_cache_ptr _contents_hash;	// a hashtable to hold the contents;
}

// MANAGING CAPACITY;
+ (unsigned) defaultCapacity;

// INITIALIZING AND FREEING;
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity;
- initWithCapacity: (unsigned)aCapacity;

// SET OPERATIONS;
- intersectWithCollection: (id <Collecting>)aCollection;
- unionWithCollection: (id <Collecting>)aCollection;
- differenceWithCollection: (id <Collecting>)aCollection;

- shallowCopyIntersectWithCollection: (id <Collecting>)aCollection;
- shallowCopyUnionWithCollection: (id <Collecting>)aCollection;
- shallowCopyDifferenceWithCollection: (id <Collecting>)aCollection;

@end

#endif /* __Set_h_OBJECTS_INCLUDE */
