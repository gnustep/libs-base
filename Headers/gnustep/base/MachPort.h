/* Interface for Mach-port based object for use with Connection
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

#ifndef __MachPort_h_GNUSTEP_BASE_INCLUDE
#define __MachPort_h_GNUSTEP_BASE_INCLUDE

#if __mach__

#include <gnustep/base/preface.h>
#include <gnustep/base/Port.h>

@interface MachInPort : InPort
@end

@interface MachOutPort : OutPort
@end

#endif /* __mach__ */

#endif /* __MachPort_h_GNUSTEP_BASE_INCLUDE */
