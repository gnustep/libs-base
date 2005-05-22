/* Useful support functions for GNUstep under MS-Windows
   Copyright (C) 2004-2005 Free Software Foundation, Inc.
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
  */

#include "GNUstepBase/Win32_Utilities.h"
//#include "GNUstepBase/Win32_FileManagement.h"

/*
 * Perform any and all necessary initialisation for supporting Win32
 * Called after first part of library initialisation so some Obj-C is okay
 */
void 
Win32Initialise(void)
{
  /* We call the initialisation routines of all support modules in turn */
  Win32_Utilities_init();
// Win32_FileManagement_init();
}

/*
 * Free and finalise all things for supporting Win32
 */
void 
Win32Finalise(void)
{
  /* We call the finalisation routines of all support modules in turn */
  Win32_Utilities_fini();
// Win32_FileManagement_fini();
}
