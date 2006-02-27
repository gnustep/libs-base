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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
 
   AutogsdocSource:	NSPathUtilities.m
   */ 

#ifndef __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE
#define __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSString.h>

#ifndef	NO_GNUSTEP
@class	NSDictionary;
@class	NSMutableDictionary;
/**
 * This extension permits a change of username from that specified in the
 * LOGNAME environment variable.  Using it will almost certainly cause
 * trouble if the process does not posses the file access privileges of the
 * new name.  This is provided primarily for use by processes that run as
 * system-manager and need to act as particular users.  It uses the
 * [NSUserDefaults +resetUserDefaults] extension to reset the defaults system
 * to use the defaults belonging to the new user.
 */
GS_EXPORT void
GSSetUserName(NSString *aName);

/**
 * Returns a mutable copy of the system-wide configuration used to
 * determine paths to locate files etc.<br />
 * If the newConfig argument is non-nil it is used to set the config
 * overriding any other version.  You should not change the config
 * after the user defaults system has been initialised as the new
 * config will not be picked up by the defaults system.<br />
 * <br />
 * A typical sequence of operation might be to<br />
 * Call the function with a nil argument to obtain the configuration
 * information currently in use (usually obtained from the main GNUstep
 * configuration file).<br />
 * Modify the dictionary contents.<br />
 * Call the function again passing back in the modified config.<br />
 * <br />
 * If you call this function with a non-nil argument before the system
 * configuration file has been read, you will prevent the file from
 * being read.  However, you must take care doing this that creation
 * of the config dictionary you are going to pass in to the function
 * does not have any side-effects which would cause the config file
 * to be read earlier.<br />
 * If you want to prevent the user specific config file from being
 * read, you must set the GNUSTEP_USER_CONFIG_FILE value in the
 * dictionary to be an empty string.
 */
GS_EXPORT NSMutableDictionary*
GNUstepConfig(NSDictionary *newConfig);

/**
 * Returns the location of the defaults database for the specified user.
 * This uses the same information you get from GNUstepConfig() and
 * GNUstepUserConfig() and builds the path to the defaults database
 * fromm it.
 */
GS_EXPORT NSString*
GSDefaultsRootForUser(NSString *userName);

/**
 * The config dictionary passed to this function should be a
 * system-wide config as provided by GNUstepConfig() ... and
 * this function merges in user specific configuration file
 * information if such a file exists and is owned by the user.<br />
 * NB. If the GNUSTEP_USER_CONFIG_FILE value in the system-wide
 * config is an empty string, no user-specifc config will be
 * read.
 */
GS_EXPORT void
GNUstepUserConfig(NSMutableDictionary *config, NSString *userName);

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
