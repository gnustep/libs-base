/* Interface for Objective C NeXT-compatible HashTable object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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
   Does not implement -freeKeys:values:.
******************************************************************/

#ifndef __HashTable_h_INCLUDE_GNU
#define __HashTable_h_INCLUDE_GNU

#include <objc/Object.h>
#include <gnustep/base/preface.h>
#include <objc/hash.h>

typedef node_ptr NXHashState;

@interface HashTable: Object
{
    unsigned    count;          /* Current number of associations */
    const char  *keyDesc;       /* Description of keys */
    const char  *valueDesc;     /* Description of values */
    unsigned    _nbBuckets;     /* Current size of the array */
    cache_ptr   _buckets;       /* Data array */
}
/* We include some instance vars we don't need so we are compatible
   with NeXT programs that expect them to be there */


/* Initializing */

- init;
- initKeyDesc: (const char *)aKeyDesc;
- initKeyDesc:(const char *)aKeyDesc 
    valueDesc:(const char *)aValueDesc;
- initKeyDesc: (const char *) aKeyDesc 
    valueDesc: (const char *)aValueDesc 
    capacity: (unsigned) aCapacity;

/* Freeing */

- free;
- freeObjects;
- freeKeys:(void (*) (void *))keyFunc 
    values:(void (*) (void *))valueFunc;
- empty;

/* Copying */

- shallowCopy;
- deepen;
  
/* Manipulating */

- (unsigned)count;
- (BOOL)isKey:(const void *)aKey;
- (void *)valueForKey:(const void *)aKey;
- (void *)insertKey:(const void *)aKey value:(void *)aValue;
- (void *)removeKey:(const void *)aKey;

/* Iterating */

- (NXHashState)initState;
- (BOOL)nextState:(NXHashState *)aState 
    key:(const void **)aKey 
    value:(void **)aValue;

/* Archiving */

- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;

/* Old-style creation */

+ newKeyDesc: (const char *)aKeyDesc;
+ newKeyDesc:(const char *)aKeyDesc 
    valueDesc:(const char *)aValueDesc;
+ newKeyDesc:(const char *)aKeyDesc 
    valueDesc:(const char *)aValueDesc
    capacity:(unsigned)aCapacity;

/* Sending messages to elements of the hashtable */

- makeObjectsPerform:(SEL)aSel;
- makeObjectsPerform:(SEL)aSel with:anObject;

@end

#endif /* __HashTable_h_INCLUDE_GNU */
