/* Useful support functions for GNUstep under MS-Windows
   Copyright (C) 2004 Free Software Foundation, Inc.
   
   Written by:  Sheldon Gill <address@hidden>
   Created: Dec 2003

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

#ifndef __Win32Support_h_GNUSTEP_BASE_INCLUDE
#define __Win32Support_h_GNUSTEP_BASE_INCLUDE

#if defined(__WIN32__)

void Win32Initialise(void);
void Win32Finalise(void);

#else
#define Win32Initialise()
#define Win32Finalise()
#endif /* defined(__WIN32__) else */

#endif /* __WIN32Support_h_GNUSTEP_BASE_INCLUDE */
