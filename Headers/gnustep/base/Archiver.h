/* Interface for GNU Objective-C Archiver object for use serializing
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: January 1996
   
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

#ifndef __Archiver_h_GNUSTEP_BASE_INCLUDE
#define __Archiver_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Coder.h>

/* Eventually some functionality may be moved out of Coder and
   into these objects.  

   These class should be used as concrete classes, not the Coder class. */


@interface Archiver : Encoder
@end

@interface Unarchiver : Decoder
@end

#endif /* __Archiver_h_GNUSTEP_BASE_INCLUDE */
