/* Interface for Objective-C GapArray collection object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Kresten Krab Thorup <krab@iesd.auc.dk>
   Dept. of Mathematics and Computer Science, Aalborg U., Denmark

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __GapArray_h_GNUSTEP_BASE_INCLUDE
#define __GapArray_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Array.h>

@interface GapArray : Array
{
  @public
  unsigned _gap_start;		/* start of gap */
  unsigned _gap_size;		/* size of gap */
}

@end

#endif /* __GapArray_h_GNUSTEP_BASE_INCLUDE */
