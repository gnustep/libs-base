/* Implementation of login-related functions for GNUstep
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <config.h>
#include <objc/objc-api.h>
#include <base/preface.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSUserDefaults.h>

#include <stdlib.h>		// for getenv()
#if !defined(__WIN32__)
#include <unistd.h>		// for getlogin()
#endif
#if	HAVE_PWD_H
#include <pwd.h>		// for getpwnam()
#endif
#include <sys/types.h>

static NSString	*theUserName = nil;

void
GSSetUserName(NSString* name)
{
  if (theUserName == nil)
    theUserName = RETAIN(name);
  else if ([theUserName isEqualToString: name] == NO)
    {
      ASSIGN(theUserName, name);
      [NSUserDefaults resetUserDefaults];
    }
}

/*
 * Return the caller's login name as an NSString object.
 * The 'LOGNAME' environment variable is our primary source, but we use
 * other system-dependent sources if LOGNAME is not set.
 */
NSString *
NSUserName ()
{
  if (theUserName == nil)
    {
      const char *login_name = 0;
#if defined(__WIN32__)
      /* The GetUserName function returns the current user name */
      char buf[1024];
      DWORD n = 1024;

      if (GetEnvironmentVariable("LOGNAME", buf, 1024))
	login_name = buf;
      else if (GetUserName(buf, &n))
	login_name = buf;
#else
      login_name = getenv("LOGNAME");
      if (login_name == 0 || getpwnam(login_name) == 0)
	{
#  if __SOLARIS__ || defined(BSD)
	  int uid = geteuid(); // get the effective user id
	  struct passwd *pwent = getpwuid (uid);
	  login_name = pwent->pw_name;
#  else
	  login_name = getlogin();
	  if (!login_name)
	    login_name = cuserid(NULL);
#  endif
	}
#endif
      if (login_name)
	GSSetUserName([NSString stringWithCString: login_name]);
      else
	[NSException raise: NSInternalInconsistencyException
		    format: @"Unable to determine curren user name"];
    }
  return theUserName;
}

/* Return the caller's home directory as an NSString object. */
NSString *
NSHomeDirectory ()
{
  return NSHomeDirectoryForUser (NSUserName ());
}

/* Return LOGIN_NAME's home directory as an NSString object. */
NSString *
NSHomeDirectoryForUser (NSString *login_name)
{
#if !defined(__WIN32__)
  struct passwd *pw;
  pw = getpwnam ([login_name cString]);
  return [NSString stringWithCString: pw->pw_dir];
#else
  /* Then environment variable HOMEPATH holds the home directory
     for the user on Windows NT; Win95 has no concept of home. */
  char buf[1024], *nb;
  DWORD n;
  NSString *s;

  n = GetEnvironmentVariable("HOMEPATH", buf, 1024);
  if (n > 1024)
    {
      /* Buffer not big enough, so dynamically allocate it */
      nb = (char *)objc_malloc(sizeof(char)*(n+1));
      n = GetEnvironmentVariable("HOMEPATH", nb, n+1);
      nb[n] = '\0';
      s = [NSString stringWithCString: nb];
      free(nb);
      return s;
    }
  else
    {
      /* null terminate it and return the string */
      buf[n] = '\0';
      return [NSString stringWithCString: buf];
    }
#endif
}

NSString *NSFullUserName(void)
{
#if HAVE_PWD_H
  struct passwd	*pw;

  pw = getpwnam([NSUserName() cString]);
  return [NSString stringWithCString: pw->pw_gecos];
#else
  NSLog(@"Warning: NSFullUserName not implemented\n");
  return NSUserName();
#endif
}

NSArray *NSStandardApplicationPaths(void)
{
  NSLog(@"Warning: NSStandardApplicationPaths not implemented\n");
  return [NSArray array];
}

NSArray *NSStandardLibraryPaths(void)
{
  NSLog(@"Warning: NSStandardLibraryPaths not implemented\n");
  return [NSArray array];
}

NSString *NSTemporaryDirectory(void)
{
  NSFileManager *manager;
  NSString *tempDirName, *baseTempDirName;
#if	defined(__WIN32__)
  char buffer[1024];
  if (GetTempPath(1024, buffer))
    baseTempDirName = [NSString stringWithCString: buffer];
  else 
    baseTempDirName = @"C:\\";
#else
  baseTempDirName = @"/tmp";
#endif

  tempDirName = [baseTempDirName stringByAppendingPathComponent: NSUserName()];
  manager = [NSFileManager defaultManager];
  if ([manager fileExistsAtPath: tempDirName] == NO)
    {
      NSDictionary *attr;
      attr = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0700]
			   forKey: NSFilePosixPermissions];
      if ([manager createDirectoryAtPath: tempDirName attributes: attr] == NO)
	tempDirName = baseTempDirName;
    }

  return tempDirName;
}

NSString *NSOpenStepRootDirectory(void)
{
  NSString* root = [[[NSProcessInfo processInfo] environment]
		     objectForKey:@"GNUSTEP_SYSTEM_ROOT"];

  if (!root)
#if	defined(__WIN32__)
    root = @"C:\\";
#else
    root = @"/";
#endif
  return root;
}


