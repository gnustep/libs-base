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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
  */
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSProcessInfo.h>

#include "GNUstepBase/Win32_Utilities.h"

/* ------------------ */
/* Internal Variables */
/* ------------------ */

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<Registry functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Returns a hive key or 0 if unable.
 */
HKEY
Win32OpenRegistry(HKEY hive, const char *key)
{
  HKEY regkey;
  
  if (ERROR_SUCCESS == RegOpenKeyEx(hive, key, 0, KEY_READ, &regkey))
    {
      return regkey;
    }

  return 0;
}

/**
 * Returns an NSString as read from a registry STRING value.
 */
NSString *
Win32NSStringFromRegistry(HKEY regkey, NSString *regValue)
{
  char buf[MAX_PATH];
  DWORD bufsize=MAX_PATH;
  DWORD type;

  if (ERROR_SUCCESS==RegQueryValueEx(regkey, [regValue cString], 0, &type, buf, &bufsize))
    {
      // FIXME: Check type is correct!
      
      bufsize=strlen(buf);
      while (bufsize && isspace(buf[bufsize-1]))
        {
          bufsize--;
        }
      return [NSString stringWithCString:buf length:bufsize];
    }
  return nil;
}

// NSNumber *Win32NSNumberFromRegistry(HKEY regkey, NSString *regValue);
// NSData   *Win32NSDataFromRegistry(HKEY regkey, NSString *regValue);

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<Environment functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Obtains an NSString for the environment variable named envVar.
 */
NSString *
Win32NSStringFromEnvironmentVariable(const char * envVar)
{
  char buf[1024], *nb;
  DWORD n;
  NSString *s = nil;

  [gnustep_global_lock lock];
  n = GetEnvironmentVariable(envVar, buf, 1024);
  if (n > 1024)
    {
      /* Buffer not big enough, so dynamically allocate it */
      nb = (char *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(char)*(n+1));
      if (nb != NULL)
        {
          n = GetEnvironmentVariable(envVar, nb, n+1);
          nb[n] = '\0';
          s = [NSString stringWithCString: nb];
          NSZoneFree(NSDefaultMallocZone(), nb);
        }
    }
  else if (n > 0)
    {
      /* null terminate it and return the string */
      buf[n] = '\0';
      s = [NSString stringWithCString: buf];
    }
  [gnustep_global_lock unlock];
  return s;
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<Path functions>-
---------+---------+---------+---------+---------+---------+---------+------- */
/**
 * Locates the users profile directory, roughly equivalent to ~/ on unix
 */
NSString *
Win32GetUserProfileDirectory(NSString *loginName)
{
  NSString *s;
  if ([loginName isEqual: NSUserName()] == YES)
    {
      [gnustep_global_lock lock];
      /*
       * The environment variable HOMEPATH holds the home directory
       * for the user on Windows NT;
       * For OPENSTEP compatibility (and because USERPROFILE is usually
       * unusable because it contains spaces), we use HOMEPATH in
       * preference to USERPROFILE.
       */
      s = Win32NSStringFromEnvironmentVariable("HOMEPATH");
      if (s != nil && ([s length] < 2 || [s characterAtIndex: 1] != ':'))
        {
          s = [Win32NSStringFromEnvironmentVariable("HOMEDRIVE")
            stringByAppendingString: s];
        }
      if (s == nil)
        {
          s = Win32NSStringFromEnvironmentVariable("USERPROFILE");
        }

      if (s == nil)
        {
          ; // FIXME: Talk to the NET API and get the profile path
        }

      [gnustep_global_lock unlock];
    }
  else
    {
      s = nil;
      NSLog(@"Not implemented! Can't determine other user home directories in Win32.");    
    }
  
  if ([s length] == 0 && [loginName length] != 1)
    {
      s = nil;
      NSLog(@"NSHomeDirectoryForUser(%@) failed", loginName);
    }

  return s;
}

/**
 * Locates specified directory on Win32 systems
 */
NSString *
Win32FindDirectory( DWORD DirCSIDL)
{
  [NSException raise: NSInternalInconsistencyException
              format: @"Not implemented! Can't find directories in Win32."];    
  return nil;
}

/**
 * Initialises resources required by utilities
 */
void 
Win32_Utilities_init(void)
{
  /*
   * Initialise the COM sub-system for this application
   */
  //CoCreateInstance();

  /*
   * Look for the libraries we need
   */
// GetDLLVersion

  /*
   * Get pointers to the Explorer Shell memory functions
   */
//  IShellMalloc, IShellFree
//  SHGetFolder
}

/**
 * Closes down and releases resources
 */
void 
Win32_Utilities_fini(void)
{
  /*
   * Release the pointers for Explorer Shell functions
   */
}
