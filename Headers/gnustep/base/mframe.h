/* Interface for functions that dissect/make method calls 
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: Oct 1994
   
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

#include <objects/stdobjects.h>

BOOL
dissect_method_call(arglist_t frame, const char *type,
		    void (*f)(int,void*,const char*,int));

retval_t 
dissect_method_return(arglist_t frame, const char *type, 
		      BOOL out_parameters,
		      void(*f)(int,void*,const char*,int));

void
make_method_call(const char *forward_type,
		 void(*fd)(int,void*,const char*),
		 void(*fe)(int,void*,const char*,int));

#endif /* __mframe_h_OBJECTS_INCLUDE */
