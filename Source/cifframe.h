/* cifframe - Wrapper/Objective-C interface for ffi function interface

   Copyright (C) 1999, Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@gnu.org>
   Created: Feb 2000
   
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

#ifndef cifframe_h_INCLUDE
#define cifframe_h_INCLUDE

#include <ffi.h>
#include <base/preface.h>

typedef struct _cifframe_t {
  ffi_cif cif;
  int nargs;
  ffi_type *rtype;
  ffi_type **args;
  void **values;
} cifframe_t;

extern cifframe_t *cifframe_from_sig (const char *typePtr, void **retval);
extern void cifframe_free(cifframe_t *cframe);
extern void cifframe_set_arg(cifframe_t *cframe, int index, void *buffer);
extern void cifframe_get_arg(cifframe_t *cframe, int index, void *buffer);
extern void *cifframe_arg_addr(cifframe_t *cframe, int index);
extern BOOL cifframe_decode_return (const char *type, void* buffer);

extern void cifframe_do_call (DOContext *ctxt,
		void(*decoder)(DOContext*),
		void(*encoder)(DOContext*));
#endif
