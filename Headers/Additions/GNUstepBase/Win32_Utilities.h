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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

    AutogsdocSource: Win32_Utilities.m
*/

#ifndef __Win32_Utilities_h_GNUSTEP_BASE_INCLUDE
#define __Win32_Utilities_h_GNUSTEP_BASE_INCLUDE

#if	defined(__cplusplus)
extern "C" {
#endif

#if defined(__MINGW32__)

#ifndef __NSNumber_h_GNUSTEP_BASE_INCLUDE
#include "Foundation/NSValue.h"
#endif

/* TODO:
-Win32NSDataFromRegistry()
NOT IMPLEMENTED YET!
*/

/* Useful strings for Registry Keys */
extern NSString *curWindowsKey; // "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\"
extern NSString *curWinNTKey;   // "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\"

/* ---- Init Functions ---- */
void Win32_Utilities_init(void);
void Win32_Utilities_fini(void);

/* ---- Environment ---- */
NSString     *Win32NSStringFromEnvironmentVariable(const WCHAR *envVar);
//NSString     *Win32OperatingSystemName(void);
//unsigned int  Win32OperatingSystemVersion(void);

/* ---- Working with the Registry ---- */
HKEY          Win32OpenRegistry(HKEY hive, NSString *keyName);
NSString     *Win32NSStringFromRegistry(HKEY regkey, NSString *regValue);
NSNumber     *Win32NSNumberFromRegistry(HKEY regkey, NSString *regValue);
NSData       *Win32NSDataFromRegistry(HKEY regkey, NSString *regValue);
// close key using RegCloseKey(KEY)

/* ---- User information ---- */
NSString     *Win32UserName(void);
NSString     *Win32FullUserName( NSString *userName );
NSString     *Win32GetUserHomeDirectory(NSString *userName);

/* ---- Path discovery ---- */
NSString     *Win32SystemDirectory(void );
NSString     *Win32TemporaryDirectory(void );

#endif /* defined(__WIN32__) */

#if	defined(__cplusplus)
}
#endif

#endif /* __Win32_Utilities_h_GNUSTEP_BASE_INCLUDE */
