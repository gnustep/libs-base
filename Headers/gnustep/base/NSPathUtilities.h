/* Interface to file path utilities for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1996
   
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

#ifndef __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE
#define __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

#ifndef	NO_GNUSTEP
/*
 * This extension permits a change of username from that specified in the
 * LOGNAME environment variable.  Using it will almost certainly cause
 * trouble if the process does not posess the file access priviliges of the
 * new name.  This is provided primarily for use by processes that run as
 * system-manager and need to act as particular users.  If uses the
 * [NSUserDefaults +resetUserDefaults] extension to reset the defaults system
 * to use the defaults belonging to the new user.
 */
GS_EXPORT void	GSSetUserName(NSString *name);
GS_EXPORT NSArray	*GSStandardPathPrefixes(void);
#endif
GS_EXPORT NSString *NSUserName();
GS_EXPORT NSString *NSHomeDirectory();
GS_EXPORT NSString *NSHomeDirectoryForUser(NSString *userName);

#ifndef STRICT_OPENSTEP
typedef enum
{
  NSApplicationDirectory,
  NSDemoApplicationDirectory,
  NSDeveloperApplicationDirectory,
  NSAdminApplicationDirectory,
  NSLibraryDirectory,
  NSDeveloperDirectory,
  NSUserDirectory,
  NSDocumentationDirectory,
  NSAllApplicationsDirectory,
  NSAllLibrariesDirectory
} NSSearchPathDirectory;

typedef unsigned int NSSearchPathDomainMask;
#define NSUserDomainMask	0x00000001
#define NSLocalDomainMask	0x00000002
#define NSNetworkDomainMask	0x00000004
#define NSSystemDomainMask	0x00000008
#define NSAllDomainsMask	0xffffffff

GS_EXPORT NSArray *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);
GS_EXPORT NSString *NSFullUserName(void);
GS_EXPORT NSArray *NSStandardApplicationPaths(void);
GS_EXPORT NSArray *NSStandardLibraryPaths(void);
GS_EXPORT NSString *NSTemporaryDirectory(void);
GS_EXPORT NSString *NSOpenStepRootDirectory(void);
#endif /* !STRICT_OPENSTEP */

#endif /* __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE */
