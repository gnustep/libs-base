/* Implementation of Objective C NeXT-compatible Storage object
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Kresten Krab Thorup <krab@iesd.auc.dk>
   Dept. of Mathematics and Computer Science, Aalborg U., Denmark

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

#include <objc/Storage.h>
#include <gnustep/base/preface.h>
#include <assert.h>
/* memcpy() and memcmp() are gcc builtin's */

/* Deal with bzero: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define index strchr
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */


#define GNU_STORAGE_NTH(x,N)                          \
  ({ GNUStorageId* __s=(GNUStorageId*)(x);            \
     (void*)(((char*)__s->dataPtr)+(__s->elementSize*(N))); })
#define STORAGE_NTH(N) GNU_STORAGE_NTH (self, N)

typedef struct {
    @defs(Storage)
} GNUStorageId;

@implementation Storage

+ initialize
{
  if (self == [Storage class])
    [self setVersion:0];	/* beta release */
  return self;
}

// INITIALIZING, FREEING;

- initCount: (unsigned)numSlots
  elementSize: (unsigned)sizeInBytes
  description: (const char*)elemDesc;
{
  [super init];
  numElements = numSlots;
  maxElements = (numSlots > 0) ? numSlots : 1;
  elementSize = sizeInBytes;
  description = elemDesc;
  dataPtr = (void*) (*objc_malloc)(maxElements * elementSize);
  bzero(dataPtr, numElements * elementSize);
  return self;
}

- init
{
  return [self initCount:1 
	       elementSize:sizeof(id) 
	       description:@encode(id)];
}


- free
{
  if (dataPtr)
    free(dataPtr);
  return [super free];
}

- (const char*) description
{
  return description;
}


// COPYING;

- shallowCopy
{
  Storage *c = [super shallowCopy];
  c->dataPtr = (void*) (*objc_malloc)(maxElements * elementSize);
  memcpy(c->dataPtr, dataPtr, numElements * elementSize);
  return c;
}

// COMPARING TWO STORAGES;

- (BOOL)isEqual: anObject
{
  if ([anObject isKindOf: [Storage class]]
      && [anObject count] == [self count]
      && !memcmp(((GNUStorageId*)anObject)->dataPtr,
		 dataPtr, numElements*elementSize))
    return YES;
  else
    return NO;
}
  
// MANAGING THE STORAGE CAPACITY;

static inline void _makeRoomForAnotherIfNecessary(Storage *self)
{
  if (self->numElements == self->maxElements) 
    {
      assert(self->maxElements);
      self->maxElements *= 2;
      self->dataPtr = (void*) 
	(*objc_realloc)(self->dataPtr, self->maxElements*self->elementSize);
    }
}

static inline void _shrinkIfDesired(Storage *self)
{
  if (self->numElements < (self->maxElements / 2)) 
    {
      self->maxElements /= 2;
      self->dataPtr = (void *) 
	(*objc_realloc)(self->dataPtr, self->maxElements*self->elementSize);
    }
}

- setAvailableCapacity:(unsigned)numSlots
{
  if (numSlots > numElements) 
    {
      maxElements = numSlots;
      dataPtr = (void*) (*objc_realloc)(dataPtr, maxElements * elementSize);
    }
  return self;
}

- setNumSlots:(unsigned)numSlots
{
  if (numSlots > numElements) 
    {
      maxElements = numSlots;
      dataPtr = (void*) (*objc_realloc)(dataPtr, maxElements * elementSize);
      bzero(STORAGE_NTH(numElements), (maxElements-numElements)*elementSize);
    }
  else if (numSlots < numElements) 
    {
      numElements = numSlots;
      _shrinkIfDesired (self);
    }
  return self;
}

/* Manipulating objects by index */

#define CHECK_INDEX(IND)  if (IND >= numElements) return 0

- (unsigned) count
{
  return numElements;
}

- (void*) elementAt: (unsigned)index
{
  CHECK_INDEX(index);
  return STORAGE_NTH (index);
}

- addElement: (void*)anElement
{
  _makeRoomForAnotherIfNecessary(self);
  memcpy(STORAGE_NTH(numElements), anElement, elementSize);
  numElements++;
  return self;
}

- insertElement: (void*)anElement at: (unsigned)index
{
  int i;

  CHECK_INDEX(index);
  _makeRoomForAnotherIfNecessary(self);
#ifndef STABLE_MEMCPY    
  for (i = numElements; i >= index; i--)
    memcpy (STORAGE_NTH(i+1), STORAGE_NTH(i), elementSize);
#else
  memcpy (STORAGE_NTH (index+1),
	  STORAGE_NTH (index),
	  elementSize*(numElements-index));
#endif    
  memcpy(STORAGE_NTH(i), anElement, elementSize);
  numElements++;
  return self;
}

- removeElementAt: (unsigned)index
{
    int i;

    CHECK_INDEX(index);
    numElements--;
#ifndef STABLE_MEMCPY
    for (i = index; i < numElements; i++)
      memcpy(STORAGE_NTH(i), 
	     STORAGE_NTH(i+1), 
	     elementSize);
#else
    memcpy (STORAGE_NTH (index),
	    STORAGE_NTH (index+1),
	    elementSize*(numElements-index-1));
#endif    
    _shrinkIfDesired(self);
    return self;
}

- removeLastElement
{
  if (numElements) 
    {
      numElements--;
      _shrinkIfDesired(self);
    }
  return self;
}

- replaceElementAt:(unsigned)index with:(void*)newElement
{
    CHECK_INDEX(index);
    memcpy(STORAGE_NTH(index), newElement, elementSize);
    return self;
}

/* Emptying the Storage */

- empty
{
  numElements = 0;
  maxElements = 1;
  dataPtr = (void*) (*objc_realloc)(dataPtr, maxElements * elementSize);
  return self;
}

/* Archiving */

- write: (TypedStream*)aStream
{
  int i;

  [super write:aStream];
  objc_write_types(aStream, "III*", 
		   &numElements, &maxElements, &elementSize, &description);
  for (i = 0; i < numElements; i++)
    objc_write_type(aStream, description, STORAGE_NTH(i));
  return self;
}

- read: (TypedStream*)aStream
{
  int i;

  [super read:aStream];
  objc_read_types(aStream, "III*", 
		  &numElements, &maxElements, &elementSize, &description);
  dataPtr = (void*) (*objc_malloc)(maxElements * elementSize);
  for (i = 0; i < numElements; i++)
    objc_read_type(aStream, description, STORAGE_NTH(i));
  return self;
}

+ new
{
  return [[self alloc] init];
}

+ newCount:(unsigned)count elementSize:(unsigned)sizeInBytes 
 description:(const char *)descriptor
{
  return [[self alloc] initCount:count elementSize:sizeInBytes
	  description:descriptor];
}

@end
