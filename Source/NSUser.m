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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSUserDefaults.h>

#include <stdlib.h>		// for getenv()
#if !defined(__WIN32__)
#include <unistd.h>		// for getlogin()
#endif
#if	HAVE_PWD_H
#include <pwd.h>		// for getpwnam()
#endif
#include <sys/types.h>
#include <stdio.h>

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
NSUserName(void)
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
NSHomeDirectory(void)
{
  return NSHomeDirectoryForUser (NSUserName ());
}

/* Return LOGIN_NAME's home directory as an NSString object. */
NSString *
NSHomeDirectoryForUser(NSString *login_name)
{
#if !defined(__MINGW__)
  struct passwd *pw;

  [gnustep_global_lock lock];
  pw = getpwnam ([login_name cString]);
  [gnustep_global_lock unlock];
  return [NSString stringWithCString: pw->pw_dir];
#else
  /* Then environment variable HOMEPATH holds the home directory
     for the user on Windows NT; Win95 has no concept of home. */
  char buf[1024], *nb;
  DWORD n;
  NSString *s;

  [gnustep_global_lock lock];
  n = GetEnvironmentVariable("HOMEPATH", buf, 1024);
  if (n > 1024)
    {
      /* Buffer not big enough, so dynamically allocate it */
      nb = (char *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(char)*(n+1));
      n = GetEnvironmentVariable("HOMEPATH", nb, n+1);
      nb[n] = '\0';
      s = [NSString stringWithCString: nb];
      NSZoneFree(NSDefaultMallocZone(), nb);
    }
  else if (n > 0)
    {
      /* null terminate it and return the string */
      buf[n] = '\0';
      s = [NSString stringWithCString: buf];
    }
  else
    s = nil;
  [gnustep_global_lock unlock];
  return s;
#endif
}

NSString *
NSFullUserName(void)
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

NSArray *
GSStandardPathPrefixes(void)
{
  NSDictionary	*env;
  NSString	*prefixes;
  NSArray	*prefixArray;
    
  env = [[NSProcessInfo processInfo] environment];
  prefixes = [env objectForKey: @"GNUSTEP_PATHPREFIX_LIST"];
  if (prefixes)
    {
#if	defined(__WIN32__)
      prefixArray = [prefixes componentsSeparatedByString: @";"];
#else
      prefixArray = [prefixes componentsSeparatedByString: @":"];
#endif
    }
  else
    {
      NSString	*strings[3];
      NSString	*str;
      unsigned	count = 0;

      str = [env objectForKey: @"GNUSTEP_USER_ROOT"];
      if (str != nil)
	strings[count++] = str;

      str = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
      if (str != nil)
	strings[count++] = str;

      str = [env objectForKey: @"GNUSTEP_SYSTEM_ROOT"];
      if (str != nil)
	strings[count++] = str;

      if (count)
	prefixArray = [NSArray arrayWithObjects: strings count: count];
      else
	prefixArray = [NSArray array];
    }
  return prefixArray;
}

NSArray *
NSStandardApplicationPaths(void)
{
  NSArray	*prefixArray = GSStandardPathPrefixes();
  unsigned	numPrefixes = [prefixArray count];
    
  if (numPrefixes > 0)
    {
      NSString	*paths[numPrefixes];
      unsigned	count;

      [prefixArray getObjects: paths];
      for (count = 0; count < numPrefixes; count++)
	{
	  paths[count]
	    = [paths[count] stringByAppendingPathComponent: @"Apps"];
	}
      return [NSArray arrayWithObjects: paths count: count];
    }
  return prefixArray;	/* An empty array */
}

NSArray *
NSStandardLibraryPaths(void)
{
  NSArray	*prefixArray = GSStandardPathPrefixes();
  unsigned	numPrefixes = [prefixArray count];
    
  if (numPrefixes > 0)
    {
      NSString	*paths[numPrefixes];
      unsigned	count;

      [prefixArray getObjects: paths];
      for (count = 0; count < numPrefixes; count++)
	{
	  paths[count]
	    = [paths[count] stringByAppendingPathComponent: @"Library"];
	}
      return [NSArray arrayWithObjects: paths count: count];
    }
  return prefixArray;	/* An empty array */
}

NSString *
NSTemporaryDirectory(void)
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

NSString *
NSOpenStepRootDirectory(void)
{
  NSString	*root = [[[NSProcessInfo processInfo] environment]
		     objectForKey: @"GNUSTEP_ROOT"];

  if (root == nil)
#if	defined(__MINGW__)
    root = @"C:\\";
#else
    root = @"/";
#endif
  return root;
}

NSArray *
NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directoryKey,
                                    NSSearchPathDomainMask domainMask,
                                    BOOL expandTilde)
{
  NSDictionary *env;
  NSString *gnustep_user_root;
  NSString *gnustep_local_root;
  NSString *gnustep_network_root;
  NSString *gnustep_system_root;
  NSString *appsDir = @"Apps";
  NSString *libraryDir = @"Library";
  NSString *docDir = @"Documentation";
  NSMutableArray *paths = [NSMutableArray new];
  NSString *path;
  NSFileManager *fm;
  int i;

  env = [[NSProcessInfo processInfo] environment];
  gnustep_user_root = [env objectForKey: @"GNUSTEP_USER_ROOT"];
  gnustep_local_root = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
  gnustep_network_root = [env objectForKey: @"GNUSTEP_NETWORK_ROOT"];
  gnustep_system_root = [env objectForKey: @"GNUSTEP_SYSTEM_ROOT"];

  if (directoryKey == NSApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      if (domainMask & NSUserDomainMask)
        [paths addObject:
             [gnustep_user_root stringByAppendingPathComponent: appsDir]];
      if (domainMask & NSLocalDomainMask)
        [paths addObject:
             [gnustep_local_root stringByAppendingPathComponent: appsDir]];
      if (domainMask & NSNetworkDomainMask)
        [paths addObject:
             [gnustep_network_root stringByAppendingPathComponent: appsDir]];
      if (domainMask & NSSystemDomainMask)
        [paths addObject:
             [gnustep_system_root stringByAppendingPathComponent: appsDir]];
    }
/*
  if (directoryKey == NSDemoApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory);
  if (directoryKey == NSDeveloperApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory);
  if (directoryKey == NSAdminApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory);
*/
  if (directoryKey == NSLibraryDirectory
    || directoryKey == NSAllLibrariesDirectory)
    {
      if (domainMask & NSUserDomainMask)
        [paths addObject:
             [gnustep_user_root stringByAppendingPathComponent: libraryDir]];
      if (domainMask & NSLocalDomainMask)
        [paths addObject:
             [gnustep_local_root stringByAppendingPathComponent: libraryDir]];
      if (domainMask & NSNetworkDomainMask)
        [paths addObject:
             [gnustep_network_root stringByAppendingPathComponent: libraryDir]];
      if (domainMask & NSSystemDomainMask)
        [paths addObject:
             [gnustep_system_root stringByAppendingPathComponent: libraryDir]];
    }
  if (directoryKey == NSDeveloperDirectory
    || directoryKey == NSAllLibrariesDirectory)
    {
      // GNUstep doesn't have a 'Developer' subdirectory (yet?)
      if (domainMask & NSUserDomainMask)
        [paths addObject: gnustep_user_root];
      if (domainMask & NSLocalDomainMask)
        [paths addObject: gnustep_local_root];
      if (domainMask & NSNetworkDomainMask)
        [paths addObject: gnustep_network_root];
      if (domainMask & NSSystemDomainMask)
        [paths addObject: gnustep_system_root];
    }
  if (directoryKey == NSUserDirectory)
    {
      if (domainMask & NSUserDomainMask)
        [paths addObject: NSHomeDirectory()];
    }
  if (directoryKey == NSDocumentationDirectory)
    {
      if (domainMask & NSUserDomainMask)
        [paths addObject:
             [gnustep_user_root stringByAppendingPathComponent: docDir]];
      if (domainMask & NSLocalDomainMask)
        [paths addObject:
             [gnustep_local_root stringByAppendingPathComponent: docDir]];
      if (domainMask & NSNetworkDomainMask)
        [paths addObject:
             [gnustep_network_root stringByAppendingPathComponent: docDir]];
      if (domainMask & NSSystemDomainMask)
        [paths addObject:
             [gnustep_system_root stringByAppendingPathComponent: docDir]];
    }

  fm = [NSFileManager defaultManager];
  for (i = 0; i < [paths count]; i++)
    {
      path = [paths objectAtIndex: i];
      // remove bad paths
      if (![fm fileExistsAtPath: path])
        {
          [paths removeObject: path];
          i--;  // mutable arrays move objects up a slot when you remove one
        }
      // this may look like a performance hit at first glance, but if these
      // string methods don't alter the string, they return the receiver
      else if (expandTilde)
        [paths replaceObjectAtIndex: i
                         withObject: [path stringByExpandingTildeInPath]];
      else
        [paths replaceObjectAtIndex: i
                      withObject: [path stringByAbbreviatingWithTildeInPath]];
    }

  return paths;
}
