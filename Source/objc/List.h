/* Interface for Objective-C NeXT-compatible List object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __List_h_INCLUDE_GNU
#define __List_h_INCLUDE_GNU

#include <objc/Object.h>

@interface List : Object
{
  @public
  id 		*dataPtr;	/* data of the List object */
  unsigned 	numElements;	/* Actual number of elements */
  unsigned 	maxElements;	/* Total allocated elements */
}

/* Creating, copying, freeing */

- free;
- freeObjects;
- shallowCopy;
- deepen;
  
/* Initializing */

- init;
- initCount:(unsigned)numSlots;

/* Comparing two lists */

- (BOOL)isEqual: anObject;
  
/* Managing the storage capacity */

- (unsigned)capacity;
- setAvailableCapacity:(unsigned)numSlots;

/* Manipulating objects by index */

- (unsigned)count;
- objectAt:(unsigned)index;
- lastObject;
- addObject:anObject;
- insertObject:anObject at:(unsigned)index;
- removeObjectAt:(unsigned)index;
- removeLastObject;
- replaceObjectAt:(unsigned)index with:newObject;
- appendList: (List *)otherList;

/* Manipulating objects by id */

- (unsigned)indexOf:anObject;
- addObjectIfAbsent:anObject;
- removeObject:anObject;
- replaceObject:anObject with:newObject;

/* Emptying the list */

- empty;

/* Archiving */

- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;

/* Sending messages to elements of the list */

- makeObjectsPerform:(SEL)aSel;
- makeObjectsPerform:(SEL)aSel with:anObject;

/* old-style creation */

+ newCount:(unsigned)numSlots;

@end

typedef struct {
    @defs(List)
} NXListId;

#define NX_ADDRESS(x) (((NXListId *)(x))->dataPtr)

#define NX_NOT_IN_LIST	0xffffffff

#endif /* __List_h_INCLUDE_GNU */
