/* Interface for Objective C NeXT-compatible Storage object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Kresten Krab Thorup <krab@iesd.auc.dk>
   Dept. of Mathematics and Computer Science, Aalborg U., Denmark

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

/******************************************************************
  TODO:
   Does not implement methods for archiving itself.
******************************************************************/

#ifndef __Storage_h_INCLUDE_GNU
#define __Storage_h_INCLUDE_GNU

#include <objc/Object.h>

@interface Storage : Object
{
@public
    void 	*dataPtr;	/* data of the Storage object */
    const char  *description;	/* Element description */
    unsigned 	numElements;	/* Actual number of elements */
    unsigned 	maxElements;	/* Total allocated elements */
    unsigned    elementSize;	/* Element size */
}

/* Creating, freeing, initializing, and emptying */

- init;
- initCount:(unsigned)numSlots elementSize:(unsigned)sizeInBytes
  description:(const char*)elemDesc;
- free;
- empty;
- shallowCopy;

/* Manipulating the elements */

- (BOOL)isEqual: anObject;
- (const char *)description; 
- (unsigned)count; 
- (void *)elementAt:(unsigned)index; 
- replaceElementAt:(unsigned)index with:(void *)anElement;
- setNumSlots:(unsigned)numSlots; 
- setAvailableCapacity:(unsigned)numSlots;
- addElement:(void *)anElement; 
- removeLastElement; 
- insertElement:(void *)anElement at:(unsigned)index; 
- removeElementAt:(unsigned)index; 

/* Archiving */

- write:(TypedStream *)stream;
- read:(TypedStream *)stream;

/* old-style creation */

+ new; 
+ newCount:(unsigned)count elementSize:(unsigned)sizeInBytes 
 description:(const char *)descriptor; 

@end

typedef struct {
    @defs(Storage)
  } NXStorageId;


#endif /* __Storage_h_INCLUDE_GNU */
