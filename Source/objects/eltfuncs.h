/* Declarations of functions for dealing with elt unions
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

#ifndef __eltfuncs_h_INCLUDE_GNU
#define __eltfuncs_h_INCLUDE_GNU

#include <objects/stdobjects.h>
#include <objects/elt.h>
#include <stdio.h>

extern unsigned int elt_hash_int (elt key);
extern int elt_compare_ints (elt k1, elt k2);

extern unsigned int elt_hash_unsigned_int (elt key);
extern int elt_compare_unsigned_ints (elt k1, elt k2);

extern unsigned int elt_hash_long_int (elt key);
extern int elt_compare_long_ints (elt k1, elt k2);

extern unsigned int elt_hash_unsigned_long_int (elt key);
extern int elt_compare_unsigned_long_ints (elt k1, elt k2);

extern unsigned int elt_hash_char (elt key);
extern int elt_compare_chars (elt k1, elt k2);

extern unsigned int elt_hash_unsigned_char (elt key);
extern int elt_compare_unsigned_chars (elt k1, elt k2);

extern unsigned int elt_hash_short (elt key);
extern int elt_compare_shorts (elt k1, elt k2);

extern unsigned int elt_hash_unsigned_short (elt key);
extern int elt_compare_unsigned_shorts (elt k1, elt k2);

extern unsigned int elt_hash_float (elt key);
extern int elt_compare_floats (elt k1, elt k2);

#if (ELT_INCLUDES_DOUBLE)
extern unsigned int elt_hash_double (elt key);
extern int elt_compare_doubles (elt k1, elt k2);
#endif

extern int elt_compare_strings (elt k1, elt k2);
extern unsigned int elt_hash_string (elt key);

extern int elt_compare_void_ptrs (elt k1, elt k2);
extern unsigned int elt_hash_void_ptr (elt key);

extern unsigned int elt_hash_object (elt key);
extern int elt_compare_objects (elt k1, elt k2);


/* This returns a (int(*)(elt,elt)) */
extern int (*(elt_get_comparison_function(const char *encoding)))(elt,elt);

/* This returns a (unsigned int (*)(elt)) */
extern unsigned int (*(elt_get_hash_function(const char *encoding)))(elt);

extern const char *elt_get_encoding(int(*comparison_function)(elt,elt));

extern void *elt_get_ptr_to_member(const char *encoding, elt *anElement);

extern void elt_fprintf_elt(FILE *fp, const char *encoding, elt anElement);

#endif /* __eltfuncs_h_INCLUDE_GNU */
