/* Interface for Objective-C Bag collection object
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

#ifndef __Bag_h_INCLUDE_GNU
#define __Bag_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/Set.h>

@interface Bag : Set
{
  unsigned int _count;		// the number of elements;
}

// ADDING;
- addObject: newObject withOccurrences: (unsigned)count;

// REMOVING AND REPLACING;
- removeObject: oldObject occurrences: (unsigned)count;
- removeObject: oldObject occurrences: (unsigned)count
    ifAbsentCall: (id(*)(arglist_t))excFunc;

// TESTING;
- (unsigned) uniqueCount;


// NON-OBJECT ELEMENT METHOD NAMES;

// INITIALIZING AND FREEING;
- initWithType: (const char *)contentEncoding
    capacity: (unsigned)aCapacity;

// ADDING;
- addElement: (elt)newElement withOccurrences: (unsigned)count;

// REMOVING AND REPLACING;
- (elt) removeElement:(elt)oldElement occurrences: (unsigned)count;
- (elt) removeElement:(elt)oldElement occurrences: (unsigned)count
    ifAbsentCall: (elt(*)(arglist_t))excFunc;

@end

#endif /* __Bag_h_INCLUDE_GNU */
