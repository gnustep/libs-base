/* Interface for functions that dissect/make method calls 
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: Oct 1994
   
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

#ifndef __mframe_h_OBJECTS_INCLUDE
#define __mframe_h_OBJECTS_INCLUDE

#include <gnustep/base/preface.h>

/* These functions are used to pull apart method calls, and put them
   back together again.  They are useful for things like distributed
   objects, and cross-language communication glue between Objective C
   and other languages. */

/* xxx Currently these function only work with the GNU Objective C
   runtime, not the NeXT runtime. */


/* Extract the arguments to a method call, as found in ARGFRAME,
   according to type string TYPES, and encode them by calling ENCODER.
   Return YES if and only if the method has some pass-by-reference
   arguments. */

BOOL
mframe_dissect_call (arglist_t argframe, const char *types,
		     void (*encoder)(int,void*,const char*,int));

/* Decode the arguments to a method call by calling DECODER, knowing
   what to decode by looking at type string ENCODED_TYPES.  Build an
   argframe of type arglist_t, and invoke the method.  Then encode the
   return value and the pass-by-reference values using ENCODER. */

void
mframe_do_call (const char *encoded_types,
		void(*decoder)(int,void*,const char*),
		void(*encoder)(int,void*,const char*,int));

/* Decode the return value and pass-by-reference arguments using
   DECODER, knowning what to decode by looking at type string TYPES
   and OUT_PARAMETERS, and put then into ARGFRAME.  Return the
   retval_t structure that can be passed to __builtin_return(). */

retval_t 
mframe_build_return (arglist_t argframe, const char *types, 
		     BOOL out_parameters,
		     void(*decoder)(int,void*,const char*,int));

#endif /* __mframe_h_OBJECTS_INCLUDE */
