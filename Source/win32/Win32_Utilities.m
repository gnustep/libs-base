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

/* Use this definition to hand an NSString to a Win32 API call */
#define  UniBuf( nsstr_ptr )    ((WCHAR *)[nsstr_ptr unicharString])
#define  UniBufLen( nsstr_ptr ) ([nsstr_ptr length])

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

/**
 * Translates a Win32 error into a text equivalent
 *
 */
void Win32PrintError( DWORD ErrorCode )
{
  LPVOID lpMsgBuf;

  FormatMessageW( FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
                  NULL, ErrorCode,
                  MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                  (LPWSTR) &lpMsgBuf, 0, NULL );
  wprintf(L"WinERROR: %s\n", lpMsgBuf );
  LocalFree( lpMsgBuf );
}

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

  if (ERROR_SUCCESS == RegOpenKeyExW(hive, UniBuf(keyName), 0, KEY_READ, &regkey))
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

//  if (ERROR_SUCCESS==RegQueryValueExW(regkey, [regValue unicharString], 0,
  if (ERROR_SUCCESS==RegQueryValueExW(regkey, UniBuf(regValue), 0,
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

  if (ERROR_SUCCESS==RegQueryValueExW(regkey, UniBuf(regValue), 0,
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
  NSCParameterAssert( regkey != NULL );
  NSCParameterAssert( regValue != nil );

  [NSException raise: NSInternalInconsistencyException
              format: @"Not implemented! Can't read binary data from the registry.."];
  return nil;
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<Environment functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Obtains an NSString for the environment variable named envVar.
 */
NSString *
Win32NSStringFromEnvironmentVariable(const WCHAR *envVar)
{
  WCHAR buf[1024], *nb;
  DWORD n;
  NSString *s = nil;

  NSCParameterAssert( envVar != NULL );

  [gnustep_global_lock lock];
  n = GetEnvironmentVariableW(envVar, buf, 1024);
  if (n > 1024)
    {
      /* Buffer not big enough, so dynamically allocate it */
      nb = (WCHAR *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(WCHAR)*(n+1));
      if (nb != NULL)
        {
          n = GetEnvironmentVariableW(envVar, nb, n+1);
          nb[n] = '\0';
          s = [NSString stringWithCharacters: nb length: n];
          NSZoneFree(NSDefaultMallocZone(), nb);
        }
    }
  else if (n > 0)
    {
      /* null terminate it and return the string */
      buf[n] = '\0';
      s = [NSString stringWithCharacters: buf length: n];
    }
  [gnustep_global_lock unlock];
  return s;
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
       * The environment variable HOMEPATH holds the home directory
       * for the user on Windows NT;
       */
      s = Win32NSStringFromEnvironmentVariable(L"USERPROFILE");
      if (s == nil)
        {
          s = Win32NSStringFromEnvironmentVariable(L"HOMEPATH");
        }
      if (s != nil && ([s length] < 2 || [s characterAtIndex: 1] != ':'))
        {
          s = [Win32NSStringFromEnvironmentVariable(L"HOMEDRIVE")
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
      if (NetUserGetInfo( NULL, UniBuf(loginName), 2, (LPBYTE*)&user_info) == NERR_Success)
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
  return Win32NSStringFromEnvironmentVariable(L"LOGNAME");
}

/**
 * Returns the user's Full name as set in the system account
 */
NSString *
Win32FullUserName( NSString *userName )
{
  struct _USER_INFO_2 *user_info;

  NSCParameterAssert(userName != nil);

  if (NetUserGetInfo( NULL, UniBuf(userName), 2, (LPBYTE*)&user_info))
    {
      /* FIXME: Issue warning */
      return nil;
    }
  return [NSString stringWithCharacters: user_info->usri2_full_name
                                 length: wcslen(user_info->usri2_full_name)];
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
*** -<Path functions>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Returns the Windows system directory. eg C:\WinNT\System32
 */
NSString *
Win32SystemDirectory( void )
{
  WCHAR buf[MAX_PATH+1];
  DWORD bufsize = MAX_PATH+1;
  DWORD len;

    len = GetSystemDirectoryW(buf,bufsize);
    if ((len == 0)||(len > MAX_PATH))
      {
        return nil;
      }
    return [NSString stringWithCharacters: buf length: len];
}

/**
 * Returns the temporary directory on windows. This is the per-user
 *   temporary directory on OS versions which support it.
 */
NSString *
Win32TemporaryDirectory( void )
{
  WCHAR buf[MAX_PATH+1];
  DWORD bufsize = MAX_PATH+1;
  DWORD len;

    len = GetTempPathW(bufsize,buf);
    if ((len == 0)||(len > MAX_PATH))
      {
        return nil;
      }
    return [NSString stringWithCharacters: buf length: len];
}

/* <EOF> */
