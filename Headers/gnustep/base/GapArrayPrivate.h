/* GapArray definitions for the use of subclass implementations
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   Copyright (C) 1993,1994 Kresten Krab Thorup <krab@iesd.auc.dk>
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

#ifndef __GapArrayPrivate_h_GNUSTEP_BASE_INCLUDE
#define __GapArrayPrivate_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/ArrayPrivate.h>
#include <assert.h>

#define GAP_TO_BASIC(INDEX)              \
  ({ unsigned int __idx = (INDEX);       \
       __idx >= self->_gap_start         \
	 ? __idx+self->_gap_size : __idx; })

#define BASIC_TO_GAP(INDEX)              \
  ({ unsigned int __idx = (INDEX);       \
       __idx < self->_gap_start          \
	 ? __idx : __idx-self->_gap_size; })

static inline void
gapMoveGapTo (GapArray* self, unsigned index)
{
  int i;
  assert (index <= self->_capacity);
  if (index < self->_gap_start)
    {
#ifndef STABLE_MEMCPY      
      int b = index + self->_gap_size;
      for (i = self->_gap_start + self->_gap_size - 1; i >= b; i--)
	self->_contents_array[i] = self->_contents_array[i - self->_gap_size];
#else
      memcpy (self->_contents_array + index + self->_gap_size,
	      self->_contents_array + index,
	      self->_gap_start - index)
#endif
    }
  else
    {
#ifndef STABLE_MEMCPY
      for(i = self->_gap_start; i != index; i++)
	self->_contents_array[i] = self->_contents_array[i - self->_gap_size];
#else
      memcpy (self->_contents_array + self->_gap_start,
	      self->_contents_array + self->_gap_start + self->_gap_size,
	      index - self->_gap_start);
#endif
    }
  self->_gap_start = index;
}

static inline void
gapMakeHoleAt(GapArray *self, unsigned index)
{
  gapMoveGapTo (self, index);
  self->_gap_start += 1;
  self->_gap_size -= 1;
}

static inline void
gapFillHoleAt(GapArray *self, unsigned index)
{
  gapMoveGapTo (self, index);
  self->_gap_size += 1;
}

#endif /* __GapArrayPrivate_h_GNUSTEP_BASE_INCLUDE */
