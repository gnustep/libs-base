/* Definition of elt union, a union of various primitive C types
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

#ifndef __elt_h_INCLUDE_GNU
#define __elt_h_INCLUDE_GNU

#include <objc/objc.h>

/* Uncomment this #define to include double's if you really need them, 
   but on most architectures you'll be increasing sizeof(elt) by a 
   factor of two! */

/* #define ELT_INCLUDES_DOUBLE 1 */
/* NOTE:  This doesn't work yet. */

typedef union _elt
{
  id id_u;
  SEL SEL_u; 
  int int_u;
  unsigned int unsigned_int_u;
  char char_u;
  unsigned char unsigned_char_u;
  short int short_int_u;
  unsigned short int unsigned_short_int_u;
  long int long_int_u;
  unsigned long int unsigned_long_int_u;
  float float_u;
#if (ELT_INCLUDES_DOUBLE)
  double double_u;
#endif
  const void *void_ptr_u;
  char *char_ptr_u;		/* change this to const char * */
} elt;

#endif /* __elt_h_INCLUDE_GNU */
