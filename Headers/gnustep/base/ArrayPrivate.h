/* Array definitions for the use of subclass implementations only
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __ArrayPrivate_h_GNUSTEP_BASE_INCLUDE
#define __ArrayPrivate_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/IndexedCollectionPrivate.h>

#define DEFAULT_ARRAY_CAPACITY 2
#define DEFAULT_ARRAY_GROW_FACTOR 2


/* Routines that help with inserting and removing elements */

/* Assumes that _count has already been incremented to make room
   for the hole.  The data at _contents_array[_count-1] is not part
   of the collection). */
static inline void
makeHoleAt(Array *self, unsigned index)
{
  int i;

  for (i = (self->_count)-1; i > index; i--)
    self->_contents_array[i] = self->_contents_array[i-1];
}

/* Assumes that _count has not yet been decremented.  The data at
   _contents_array[_count-1] is part of the collection. */
static inline void
fillHoleAt(Array *self, unsigned index)
{
  int i;

  for (i = index; i < (self->_count)-1; i++)
    self->_contents_array[i] = self->_contents_array[i+1];
}

/* These are the only two routines that change the value of the instance 
   variable _count, except for "-initWithType:capacity:" and "-empty" */

/* Should these be methods instead of functions?  Doing so would make 
   them slower. */

/* Do this before adding an element */
static inline void 
incrementCount(Array *self)
{
  (self->_count)++;
  if (self->_count == self->_capacity)
    {
      [self setCapacity:(self->_capacity) * ABS(self->_grow_factor)];
    }
}

/* Do this after removing an element */
static inline void
decrementCount(Array *self)
{
  (self->_count)--;
  if (self->_grow_factor > 0
      && self->_count < (self->_capacity / self->_grow_factor))
    {
      [self setCapacity:(self->_capacity) / self->_grow_factor];
    }
}

#endif /* __ArrayPrivate_h_GNUSTEP_BASE_INCLUDE */
