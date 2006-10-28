/* Useful support functions for GNUstep under MS-Windows
   Copyright (C) 2004-2006 Free Software Foundation, Inc.

   Author:  Sheldon Gill <sheldon@westnet.net.au>
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>Win32 Utilities function reference</title>
  */

#include "Foundation/NSLock.h"
#include "Foundation/NSException.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSData.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSPathUtilities.h"

#include "GSPrivate.h"

#include "GNUstepBase/Win32_Utilities.h"

#include <lm.h>

/* ------------------ */
/* Global Variables   */
/* ------------------ */

/* We save on space and code uglies by having utility key strings */
NSString *curWindowsKey = @"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\";
NSString *curWinNTKey = @"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\";

/* ------------------ */
/* Internal Variables */
/* ------------------ */

/* ============================= */
/* Internal function prototypes. */
/* ============================= */

BOOL IsHiveRoot(HKEY);

void Win32_Utilities_init();
void Win32_Utilities_fini();
/* ============================= */

BOOL IsHiveRoot( HKEY hive_key)
{
  if (hive_key == HKEY_CLASSES_ROOT)
      return YES;
  if (hive_key == HKEY_CURRENT_USER)
      return YES;
  if (hive_key == HKEY_LOCAL_MACHINE)
      return YES;
  if (hive_key == HKEY_USERS)
      return YES;
  if (hive_key == HKEY_CURRENT_CONFIG)
      return YES;
  return NO;
}

/*
 *  Module initialisation
 */
void Win32_Utilities_init()
{
    return;
}

/*
 * Module finalisation
 */
void Win32_Utilities_fini()
{
  return; // Nothing to do yet...
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<General utility functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<Registry functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Returns a hive key or 0 if unable to do so.<br/ >
 * The key must be released after use with RegCloseKey().
 */
HKEY
Win32OpenRegistry(HKEY hive, NSString *keyName)
{
  HKEY regkey;

  NSCParameterAssert( IsHiveRoot(hive) );

  if (ERROR_SUCCESS == RegOpenKeyExW(hive, [keyName UTF16String], 0, KEY_READ, &regkey))
    {
      return regkey;
    }

  return 0;
}

/**
 * Returns an NSString as read from a registry STRING value. ie REG_SZ
 */
NSString *
Win32NSStringFromRegistry(HKEY regkey, NSString *regValue)
{
  WCHAR buf[MAX_PATH];
  DWORD bufsize=MAX_PATH+1;
  DWORD type;

  NSCParameterAssert( regkey != NULL );
  NSCParameterAssert( regValue != nil );

  if (ERROR_SUCCESS == RegQueryValueExW(regkey, [regValue UTF16String], 0,
                                      &type, (LPBYTE)buf, &bufsize))
    {
      /* Check type is correct! */
      if (type != REG_SZ)
          return nil;

      bufsize=wcslen(buf);
      while (bufsize && isspace(buf[bufsize-1]))
        {
          bufsize--;
        }
      return [NSString stringWithCharacters:buf length:bufsize];
    }
  return nil;
}

/**
 * Returns an NSNumber as read from a registry DWORD value. ie REG_DWORD
 */
NSNumber *
Win32NSNumberFromRegistry(HKEY regkey, NSString *regValue)
{
  DWORD buf;
  DWORD bufsize = sizeof(DWORD);
  DWORD type;

  NSCParameterAssert( regkey != NULL );
  NSCParameterAssert( regValue != nil );

  if (ERROR_SUCCESS == RegQueryValueExW(regkey, [regValue UTF16String], 0,
                                      &type, (LPBYTE)&buf, &bufsize))
    {
      /* Check type is correct! */
      if (type != REG_DWORD)
          return nil;

      return [NSNumber numberWithUnsignedLong: buf];
    }
  return nil;
}

/**
 * Returns an NSData as read from a registry BINARY value. ie REG_BINARY
 */
NSData *
Win32NSDataFromRegistry(HKEY regkey, NSString *regValue)
{
  DWORD *buf = NULL;
  DWORD bufsize = 0;
  DWORD type;

  NSCParameterAssert( regkey != NULL );
  NSCParameterAssert( regValue != nil );

  if (ERROR_SUCCESS == RegQueryValueExW(regkey, [regValue UTF16String], 0,
                                      &type, NULL, &bufsize))
    {
      if (type != REG_BINARY)
          return nil;

      buf = objc_malloc(bufsize);
      if (ERROR_SUCCESS == RegQueryValueExW(regkey, [regValue UTF16String],
                                  0, &type, (LPBYTE)buf, &bufsize))
        {
            return [NSData dataWithBytesNoCopy: buf
                                        length: bufsize
                                  freeWhenDone: YES];
        }
      objc_free(buf);
    }
  return nil;
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<User information functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Locates the users home directory, roughly equivalent to ~/ on unix
 */
NSString *
Win32GetUserHomeDirectory(NSString *loginName)
{
  NSString *s = nil;

  if ([loginName isEqual: NSUserName()] == YES)
    {
      /*
       * The environment variables are easiest
       * for the user on Windows NT;
       */
      s = [[[NSProcessInfo processInfo] environment]
               objectForKey: @"USERPROFILE"];
      if (s == nil)
        {
          s = [[[NSProcessInfo processInfo] environment]
                   objectForKey: @"HOMEPATH"];
        }
      if (s != nil && ([s length] < 2 || [s characterAtIndex: 1] != ':'))
        {
          s = [[[[NSProcessInfo processInfo] environment]
                   objectForKey: @"HOMEPATH"]
                     stringByAppendingString: s];
        }
    }

  /*
   * loginName is not current user so we need account info
   */
  if (s == nil)
    {
      struct _USER_INFO_2 *user_info;

       /* Talk to the NET API and get the home dir */
      if (NetUserGetInfo( NULL, [loginName UTF16String], 2, (LPBYTE*)&user_info) == NERR_Success)
        {
          if ( user_info->usri2_home_dir && user_info->usri2_home_dir[0] )
            {
              s = [NSString stringWithCharacters: user_info->usri2_home_dir
                                          length: wcslen(user_info->usri2_home_dir)];
            }
        }
      /* That didn't work? We hack at paths instead */
      if (s == nil)
        {
          NSMutableString *basePath;
          NSRange namePart;

          basePath = [NSMutableString stringWithString: NSHomeDirectory()];
          namePart = [basePath rangeOfString: NSUserName()
                                     options: NSBackwardsSearch];
          [basePath replaceCharactersInRange: namePart
                                  withString: loginName];
          s = [NSString stringWithString: basePath];
        }
    }

  if ([s length] == 0 && [loginName length] != 0)
    {
      s = nil;
      NSWarnLog(@"NSHomeDirectoryForUser(%@) failed", loginName);
    }

  return s;
}

/**
 * Returns the login name for the current user
 */
NSString *
Win32UserName(void)
{
  WCHAR buf[1024];
  DWORD n = 1024;

  /* The GetUserName function returns the current user name */
  if (GetUserNameW(buf, &n) != 0 && buf[0] != '\0')
    {
      return [NSString stringWithCharacters: buf length: (n-1)];
    }
  return NULL;
}

/**
 * Returns the user's Full name as set in the system account
 */
NSString *
Win32FullUserName( NSString *userName )
{
  struct _USER_INFO_2 *user_info;

  NSCParameterAssert(userName != nil);

  if (NetUserGetInfo( NULL, [userName UTF16String], 2, (LPBYTE*)&user_info))
    {
      NSLog(@"Couldn't get user information for %@",userName);
      return nil;
    }
  return [NSString stringWithCharacters: user_info->usri2_full_name
                                 length: wcslen(user_info->usri2_full_name)];
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<Path functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Returns the Windows directory. eg C:\WinNT
 */
NSString *
Win32WindowsDirectory( void )
{
  WCHAR buf[MAX_PATH+1];
  DWORD bufsize = MAX_PATH+1;
  DWORD len;

    len = GetWindowsDirectoryW(buf,bufsize);
    if ((len == 0)||(len > MAX_PATH))
      {
        return nil;
      }
    return [NSString stringWithCharacters: buf length: len];
}

/* <EOF> */
