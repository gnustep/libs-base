/* Support for general purpose definitions for libobjects.
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1993

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

#include <gnustep/base/preface.h>

const char gnustep_base_version[] = STRINGIFY (GNUSTEP_BASE_VERSION);
const char o_gcc_version[] = STRINGIFY (GNUSTEP_BASE_GCC_VERSION);

#if NeXT_cc
const char o_NeXT_cc_version[] = STRINGIFY (NX_CURRENT_COMPILER_RELEASE);
#endif /* NeXT_cc */
