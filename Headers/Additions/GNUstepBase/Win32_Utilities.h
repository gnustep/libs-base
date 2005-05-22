/** Win32 Utility support functions for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Sheldon Gill <address@hidden>
   Date: 2004
   
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

    AutogsdocSource: Win32_Utilities.m
*/

#ifndef __Win32_Utilities_h_GNUSTEP_BASE_INCLUDE
#define __Win32_Utilities_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

/* TODO:
- Win32GetUserProfileDirectory()
Find profile directory for non-current user.
- Win32FindDirectory()
NOT IMPLEMENTED YET!
-Win32NSNumberFromRegistry()
NOT IMPLEMENTED YET!
-Win32NSDataFromRegistry()
NOT IMPLEMENTED YET!
*/

#if defined(__WIN32__)
/* ---- Init Functions ---- */
void Win32_Utilities_init(void);
void Win32_Utilities_fini(void);

/* ---- Environment Functions ---- */
NSString     *Win32NSStringFromEnvironmentVariable(const char * envVar);

/* ---- Registry Functions ---- */
HKEY          Win32OpenRegistry(HKEY hive, const char *key);
NSString     *Win32NSStringFromRegistry(HKEY regkey, NSString *regValue);
// NSNumber     *Win32NSNumberFromRegistry(HKEY regkey, NSString *regValue);
// NSData       *Win32NSDataFromRegistry(HKEY regkey, NSString *regValue);

/* ---- Path Functions ---- */
NSString     *Win32GetUserProfileDirectory(NSString *userName);
NSString     *Win32FindDirectory(DWORD DirCLSID);
#endif /* defined(__WIN32__) */

#endif /* */
