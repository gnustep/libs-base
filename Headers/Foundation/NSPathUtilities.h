/** Interface to file path utilities for GNUStep
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 
   AutogsdocSource:	NSPathUtilities.m
   */ 

#ifndef __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE
#define __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

#ifndef	NO_GNUSTEP
/**
 * Function to return a mutable copy of the GNUstep configuration
 * file contents.<br />
 * If newConfig is not nil, it is used to set a new system wide
 * configuration.<br />
 * This function is provided to allow a program to override the
 * configuration information which tells GNUstep applications where
 * all paths to resources/libraries etc in the system are located.<br />
 * Keys and values in the newConfig dictionary must match those normally
 * expected in the configuration file (GNUstep.conf).
 */
NSMutableDictionary* GNUstepConfig(NSDictionary *newConfig);

/**
 * This extension permits a change of username from that specified in the
 * LOGNAME environment variable.  Using it will almost certainly cause
 * trouble if the process does not posses the file access privileges of the
 * new name.  This is provided primarily for use by processes that run as
 * system-manager and need to act as particular users.  It uses the
 * [NSUserDefaults +resetUserDefaults] extension to reset the defaults system
 * to use the defaults belonging to the new user.
 */
GS_EXPORT void  GSSetUserName(NSString *aName);

GS_EXPORT NSString *GSDefaultsRootForUser(NSString *userName);

#endif
GS_EXPORT NSString *NSUserName(void);
GS_EXPORT NSString *NSHomeDirectory(void);
GS_EXPORT NSString *NSHomeDirectoryForUser(NSString *loginName);

#ifndef STRICT_OPENSTEP
/**
 * Enumeration of possible requested directory type specifiers for
 * NSSearchPathForDirectoriesInDomains() function.  These correspond to the
 * subdirectories that may be found under, e.g., $GNUSTEP_SYSTEM_ROOT, such
 * as "Library" and "Applications".
 <example>
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
  NSAllLibrariesDirectory,
  GSLibrariesDirectory,
  GSToolsDirectory,
  GSApplicationSupportDirectory
}
 </example>
 */
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
  
/* Apple Reserved Directory Identifiers */

  NSAllApplicationsDirectory,
  NSAllLibrariesDirectory,

/*  GNUstep Directory Identifiers */

  //GSApplicationSupportDirectory = 150,
  //GSFontsDirectory,
  //GSFrameworksDirectory,
  GSLibrariesDirectory,
  GSToolsDirectory,
  GSApplicationSupportDirectory,
  GSPreferencesDirectory,
  
  GSFontsDirectory,
  GSFrameworksDirectory
 } NSSearchPathDirectory;

/**
 * Mask type for NSSearchPathForDirectoriesInDomains() function.  A bitwise OR
 * of one or more of <code>NSUserDomainMask, NSLocalDomainMask,
 * NSNetworkDomainMask, NSSystemDomainMask, NSAllDomainsMask</code>.
 */
typedef enum
{
  NSUserDomainMask = 1,
  NSLocalDomainMask = 2,
  NSNetworkDomainMask = 4,
  NSSystemDomainMask = 8,
  NSAllDomainsMask = 0xffffffff,
} NSSearchPathDomainMask;

GS_EXPORT NSArray *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directoryKey, NSSearchPathDomainMask domainMask, BOOL expandTilde);
GS_EXPORT NSString *NSFullUserName(void);
GS_EXPORT NSArray *NSStandardApplicationPaths(void);
GS_EXPORT NSArray *NSStandardLibraryPaths(void);
GS_EXPORT NSString *NSTemporaryDirectory(void);
GS_EXPORT NSString *NSOpenStepRootDirectory(void);
#endif /* !STRICT_OPENSTEP */

#endif /* __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE */
