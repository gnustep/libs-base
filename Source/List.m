/* Implementation of Objective-C NeXT-compatible List object
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.
   
   This file is part of the GNU Objective C Class Library.

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

#include <objects/stdobjects.h>
#include <objc/List.h>

/* Change this #define to 0 if you want -makeObjectsPerform: and 
   -makeObjectsPerform:with: to access content objects in order
   from lower indices to higher indices.
   If you want the NeXTSTEP behavior, leave the #define as 1. */
#define LIST_PERFORM_REVERSE_ORDER_DEFAULT 1

#define LIST_GROW_FACTOR 2

#if !defined(NX_MALLOC)
#define NX_MALLOC(VAR,TYPE,NUM ) \
  ((VAR) = (TYPE *) malloc((unsigned)(NUM)*sizeof(TYPE)))
#endif
#if !defined(NX_REALLOC)
#define NX_REALLOC(VAR,TYPE,NUM ) \
  ((VAR) = (TYPE *) realloc((VAR), (unsigned)(NUM)*sizeof(TYPE)))
#endif
#if !defined(NX_FREE)
#define NX_FREE(VAR) free(VAR)
#endif

/* memcpy() is a gcc builtin */


/* Do this before adding an element */
static inline void 
incrementCount(List *self)
{
  (self->numElements)++;
  if (self->numElements >= self->maxElements)
    {
      [self setAvailableCapacity:(self->numElements) * LIST_GROW_FACTOR];
    }
}

/* Do this after removing an element */
static inline void
decrementCount(List *self)
{
  (self->numElements)--;
  if (self->numElements < (self->maxElements) / LIST_GROW_FACTOR)
    {
      [self setAvailableCapacity:(self->maxElements) / LIST_GROW_FACTOR];
    }
}

@implementation List
  
+ initialize
{
  if (self == [List class])
    [self setVersion:0];	/* beta release */
  return self;
}

// INITIALIZING, FREEING;

- initCount:(unsigned)numSlots;
{
  [super init];
  numElements = 0;
  maxElements = numSlots;
  OBJC_MALLOC(dataPtr, id, maxElements);
  return self;
}

- init
{
  return [self initCount:2];
}


- free
{
  if (dataPtr)
    OBJC_FREE(dataPtr);
  return [super free];
}

- freeObjects
{
  [self makeObjectsPerform:@selector(free)];
  [self empty];
  return self;
}

// COPYING;

- copy
{
  return [self shallowCopy];
}

- shallowCopy
{
  List *c = [super shallowCopy];
  OBJC_MALLOC(c->dataPtr, id, maxElements);
  memcpy(c->dataPtr, dataPtr, numElements * sizeof(id *));
  return c;
}

- deepen
{
  int i;
  
  for (i = 0; i < numElements; i++) 
    {
      dataPtr[i] = [dataPtr[i] deepCopy];
    }
  return self;
}

// COMPARING TWO LISTS;

- (BOOL)isEqual: anObject
{
  int i;
  
  if ( (![anObject isKindOf:[List class]])
      || ([self count] != [anObject count]))
    return NO;
  for (i = 0; i < numElements; i++)
    /* NeXT documentation says to compare id's. */
    if ( dataPtr[i] != [anObject objectAt:i] )
      return NO;
  return YES;
}

// MANAGING THE STORAGE CAPACITY;

- (unsigned)capacity
{
  return maxElements;
}

- setAvailableCapacity:(unsigned)numSlots
{
  if (numSlots > numElements) 
    {
      maxElements = numSlots;
      OBJC_REALLOC(dataPtr, id, maxElements);
      return self;
    }
  return nil;
}


/* Manipulating objects by index */

#define CHECK_INDEX(IND)  if ((IND) >= numElements) return nil 
#define CHECK_OBJECT(OBJ)  if (!(OBJ)) return nil
  
- (unsigned)count
{
  return numElements;
}

- objectAt:(unsigned)index
{
  CHECK_INDEX(index);
  return dataPtr[index];
}

- lastObject
{
  if (numElements)
    return dataPtr[numElements-1];
  else
    return nil;
}

- addObject:anObject
{
  [self insertObject:anObject at:numElements];
  return self;
}

- insertObject:anObject at:(unsigned)index
{
  int i;
  
  if (index > 0) {
    CHECK_INDEX(index-1);
  }
  CHECK_OBJECT(anObject);
  incrementCount(self);
  for (i = numElements-1; i > index; i--)
    dataPtr[i] = dataPtr[i-1];
  dataPtr[i] = anObject;
  return self;
}

- removeObjectAt:(unsigned)index
{
  id oldObject;
  int i;
  
  CHECK_INDEX(index);
  oldObject = dataPtr[index];
  for (i = index; i < numElements-1; i++)
    dataPtr[i] = dataPtr[i+1];
  decrementCount(self);
  return oldObject;
}

- removeLastObject
{
  if (numElements) 
    return [self removeObjectAt:numElements-1];
  return nil;
}

- replaceObjectAt:(unsigned)index with:newObject
{
  id oldObject;

  CHECK_INDEX(index);
  CHECK_OBJECT(newObject);
  oldObject = dataPtr[index];
  dataPtr[index] = newObject;
  return oldObject;
}

/* Inefficient to send objectAt: each time, but it handles subclasses 
   of List nicely. */
- appendList: (List *)otherList
{
  int i, c;
  
  c = [otherList count];
  /* Should we do something like this for efficiency?
     [self setCapacity:numElements+c]; */
  for (i = 0; i < c; i++)
    [self addObject:[otherList objectAt:i]];
  return self;
}

/* Manipulating objects by id */

- (unsigned) indexOf:anObject
{
  int i;
  
  for (i = 0; i < numElements; i++)
    if ([dataPtr[i] isEqual:anObject])
      return i;
  return NX_NOT_IN_LIST;
}

- addObjectIfAbsent:anObject
{
  CHECK_OBJECT(anObject);
  if ([self indexOf:anObject] == NX_NOT_IN_LIST)
    [self addObject:anObject];
  return self;
}

- removeObject:anObject
{
  CHECK_OBJECT(anObject);
  return [self removeObjectAt:[self indexOf:anObject]];
}

- replaceObject:anObject with:newObject
{
  return [self replaceObjectAt:[self indexOf:anObject]
	       with:newObject];
}

/* Emptying the list */

- empty
{
  int i;

  for (i = 0; i < numElements; i++)
    dataPtr[i] = nil;
  numElements = 0;
  return self;
}

/* Archiving */

- write: (TypedStream*)aStream
{
  [super write: aStream];
  objc_write_types (aStream, "II", &numElements, &maxElements);
  objc_write_array (aStream, "@", numElements, dataPtr);
  return self;
}

- read: (TypedStream*)aStream
{
  [super read: aStream];
  objc_read_types (aStream, "II", &numElements, &maxElements);
  OBJC_MALLOC(dataPtr, id, maxElements);
  objc_read_array (aStream, "@", numElements, dataPtr);
  return self;
}

/* Sending messages to elements of the list */

- makeObjectsPerform:(SEL)aSel
{
  int i;

  /* For better interaction with List subclasses, we could use
     objectAt: instead of accessing dataPtr directly. */
#if (LIST_PERFORM_REVERSE_ORDER_DEFAULT)
  for (i = numElements-1; i >= 0; i--)
    [dataPtr[i] perform:aSel];
#else
  for (i = 0; i < numElements; i++)
    [dataPtr[i] perform:aSel];
#endif /* LIST_PERFORM_REVERSE_ORDER_DEFAULT */
  return self;
}

- makeObjectsPerform:(SEL)aSel with:anObject
{
  int i;

  /* For better interaction with List subclasses, we could use
     objectAt: instead of accessing dataPtr directly. */
#if (LIST_PERFORM_REVERSE_ORDER_DEFAULT)
  for (i = numElements-1; i >= 0; i--)
    [dataPtr[i] perform:aSel with:anObject];
#else
  for (i = 0; i < numElements; i++)
    [dataPtr[i] perform:aSel with:anObject];
#endif /* LIST_PERFORM_REVERSE_ORDER_DEFAULT */
  return self;
}


/* Old-style creation */

+ newCount:(unsigned)numSlots
{
  return [[self alloc] initCount:numSlots];
}

@end
