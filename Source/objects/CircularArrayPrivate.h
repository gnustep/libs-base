/* CircularArray definitions for the use of subclass implementations
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

#ifndef __CircularArrayPrivate_h_INCLUDE_GNU
#define __CircularArrayPrivate_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/ArrayPrivate.h>

#define CIRCULAR_TO_BASIC(INDEX) \
  ((INDEX + self->_start_index) % self->_capacity)

#define BASIC_TO_CIRCULAR(INDEX) \
  ((INDEX + self->_capacity - self->_start_index) % self->_capacity)

#define NEXT_CIRCULAR_INDEX(INDEX) \
  ((INDEX + 1) % self->_capacity)

#define PREV_CIRCULAR_INDEX(INDEX) \
  ((INDEX + self->_capacity - 1) % self->_capacity)

static inline void
circularMakeHoleAt(CircularArray *self, unsigned basicIndex)
{
  int i;
  if (self->_start_index && basicIndex > self->_start_index)
    {
      for (i = self->_start_index; i < basicIndex; i++)
	self->_contents_array[i-1] = self->_contents_array[i];
    }
  else
    {
      for (i = CIRCULAR_TO_BASIC(self->_count-1); i >= basicIndex; i--)
	self->_contents_array[i+1] = self->_contents_array[i];
    }
  /* This is never called with _count == 0 */
}

static inline void
circularFillHoleAt(CircularArray *self, unsigned basicIndex)
{
  int i;
  if (basicIndex > self->_start_index)
    {
      for (i = basicIndex; i > self->_start_index; i--)
	self->_contents_array[i] = self->_contents_array[i-1];
    }
  else
    {
      for (i = basicIndex; i < CIRCULAR_TO_BASIC(self->_count-1); i++)
	self->_contents_array[i] = self->_contents_array[i+1];
    }
}

#endif /* __CircularArrayPrivate_h_INCLUDE_GNU */
