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
    {
      theUserName = RETAIN(name);
    }
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
#if	HAVE_GETPWNAM
      /*
       * Check that LOGNAME contained legal name.
       */
      if (login_name != 0 && getpwnam(login_name) == 0)
	{
	  login_name = 0;
	}
#endif	/* HAVE_GETPWNAM */
#if	HAVE_GETLOGIN
      /*
       * Try getlogin() if LOGNAME environmentm variable didn't work.
       */
      if (login_name == 0)
	{
	  login_name = getlogin();
	}
#endif	/* HAVE_GETLOGIN */
#if HAVE_GETPWUID
      /*
       * Try getting the name of the effective user as a last resort.
       */
      if (login_name == 0)
	{
#if HAVE_GETEUID
	  int uid = geteuid();
#else
	  int uid = getuid();
#endif /* HAVE_GETEUID */
	  struct passwd *pwent = getpwuid (uid);
	  login_name = pwent->pw_name;
	}
#endif /* HAVE_GETPWUID */
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
    {
      s = nil;
    }

  if (s != nil)
    {
      n = GetEnvironmentVariable("HOMEDRIVE", buf, 1024);
      buf[n] = '\0';
      s = [[NSString stringWithCString: buf] stringByAppendingString: s];
    }
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


/* We read these four only once */
static NSString	*gnustep_user_root = nil;    /* GNUSTEP_USER_ROOT */
static NSString	*gnustep_local_root = nil;   /* GNUSTEP_LOCAL_ROOT */
static NSString	*gnustep_network_root = nil; /* GNUSTEP_NETWORK_ROOT */
static NSString	*gnustep_system_root = nil;  /* GNUSTEP_SYSTEM_ROOT */

static void
setupPathNames()
{
  if (gnustep_system_root == nil)
    {
      NS_DURING
	{
	  NSDictionary	*env;
	  
	  [gnustep_global_lock lock];

	  /* Double-Locking Pattern */
	  if (gnustep_system_root == nil)
	    {
	      BOOL	warned = NO;

	      env = [[NSProcessInfo processInfo] environment];
	      /* Any of the following might be nil */
	      gnustep_system_root = [env objectForKey: @"GNUSTEP_SYSTEM_ROOT"];
	      TEST_RETAIN (gnustep_system_root);
	      if (gnustep_system_root == nil)
		{
		  /*
		   * This is pretty important as we need it to load
		   * character sets, language settings and similar
		   * resources.  Use fprintf to avoid recursive calls.
		   */
		  warned = YES;
		  fprintf (stderr, 
		    "Warning - GNUSTEP_SYSTEM_ROOT is not set "
		    "- using /usr/GNUstep/System as a default\n");
		  gnustep_system_root = @"/usr/GNUstep/System";
		}

	      gnustep_local_root = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
	      TEST_RETAIN (gnustep_local_root);
	      if (gnustep_local_root == nil)
		{
		  if ([[gnustep_system_root lastPathComponent] isEqual:
		    @"System"] == YES)
		    {
		      gnustep_local_root = [[gnustep_system_root
			stringByDeletingLastPathComponent]
			stringByAppendingPathComponent: @"Local"];
		      TEST_RETAIN (gnustep_local_root);
		    }
		  else
		    {
		      gnustep_local_root = @"/usr/GNUstep/Local";
		    }
#ifndef	NDEBUG
		  if (warned == NO)
		    {
		      warned = YES;
		      fprintf (stderr, 
			"Warning - GNUSTEP_LOCAL_ROOT is not set "
			"- using %s\n", [gnustep_local_root lossyCString]);
		    }
#endif
		}

	      gnustep_network_root = [env objectForKey: 
		@"GNUSTEP_NETWORK_ROOT"];
	      TEST_RETAIN (gnustep_network_root);
	      if (gnustep_network_root == nil)
		{
		  if ([[gnustep_system_root lastPathComponent] isEqual:
		    @"System"] == YES)
		    {
		      gnustep_network_root = [[gnustep_system_root
			stringByDeletingLastPathComponent]
			stringByAppendingPathComponent: @"Network"];
		      TEST_RETAIN (gnustep_network_root);
		    }
		  else
		    {
		      gnustep_network_root = @"/usr/GNUstep/Network";
		    }
#ifndef	NDEBUG
		  if (warned == NO)
		    {
		      warned = YES;
		      fprintf (stderr, 
			"Warning - GNUSTEP_NETWORK_ROOT is not set "
			"- using %s\n", [gnustep_network_root lossyCString]);
		    }
#endif
		}

	      gnustep_user_root = [env objectForKey: @"GNUSTEP_USER_ROOT"];
	      TEST_RETAIN (gnustep_user_root);
	      if (gnustep_user_root == nil)
		{
		  gnustep_user_root = [NSHomeDirectory()
		    stringByAppendingPathComponent: @"GNUstep"];
		  TEST_RETAIN (gnustep_user_root);
		  if (warned == NO)
		    {
		      warned = YES;
		      fprintf (stderr, 
			"Warning - GNUSTEP_USER_ROOT is not set "
			"- using %s\n", [gnustep_user_root lossyCString]);
		    }
		}
	    }

	  [gnustep_global_lock unlock];
	}
      NS_HANDLER
	{
	  // unlock then re-raise the exception
	  [gnustep_global_lock unlock];
	  [localException raise];
	}
      NS_ENDHANDLER
    }
}


NSArray *
GSStandardPathPrefixes(void)
{
  NSDictionary	*env;
  NSString	*prefixes;
  NSArray	*prefixArray;
    
  env = [[NSProcessInfo processInfo] environment];
  prefixes = [env objectForKey: @"GNUSTEP_PATHPREFIX_LIST"];
  if (prefixes != 0)
    {
#if	defined(__WIN32__)
      prefixArray = [prefixes componentsSeparatedByString: @";"];
#else
      prefixArray = [prefixes componentsSeparatedByString: @":"];
#endif
    }
  else
    {
      NSString	*strings[4];
      NSString	*str;
      unsigned	count = 0;

      if (gnustep_system_root == nil)
	{
	  setupPathNames();
	}
      str = gnustep_user_root;
      if (str != nil)
	strings[count++] = str;

      str = gnustep_local_root;
      if (str != nil)
	strings[count++] = str;

      str = gnustep_network_root;
      if (str != nil)
        strings[count++] = str;

      str = gnustep_system_root;
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
  return NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory,
                                             NSAllDomainsMask, YES);
}

NSArray *
NSStandardLibraryPaths(void)
{
  return NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
                                             NSAllDomainsMask, YES);
}

NSString *
NSTemporaryDirectory(void)
{
  NSFileManager	*manager;
  NSString	*tempDirName;
  NSString	*baseTempDirName = nil;
  NSDictionary	*attr;
  int		perm;
  BOOL		flag;
#if	defined(__WIN32__)
  char buffer[1024];

  if (GetTempPath(1024, buffer))
    {
      baseTempDirName = [NSString stringWithCString: buffer];
    }
#endif

  /*
   * If the user has supplied a directory name in the TEMP or TMP
   * environment variable, attempt to use that unless we already
   * have a tem porary directory specified.
   */
  if (baseTempDirName == nil)
    {
      NSDictionary	*env = [[NSProcessInfo processInfo] environment];

      baseTempDirName = [env objectForKey: @"TEMP"];
      if (baseTempDirName == nil)
	{
	  baseTempDirName = [env objectForKey: @"TMP"];
	  if (baseTempDirName == nil)
	    {
#if	defined(__WIN32__)
	      baseTempDirName = @"C:\\";
#else
	      baseTempDirName = @"/tmp";
#endif
	    }
	}
    }

  /*
   * Check that the base directory exists ... if it doesn't we can't
   * go any further.
   */
  tempDirName = baseTempDirName;
  manager = [NSFileManager defaultManager];
  if ([manager fileExistsAtPath: tempDirName isDirectory: &flag] == NO
    || flag == NO)
    {
      NSLog(@"Temporary directory (%@) does not seem to exist", tempDirName);
      return nil;
    }

  /*
   * Check that the directory owner (presumably us) has access to it,
   * and nobody else.  If other people have access, try to create a
   * secure subdirectory.
   */
  attr = [manager fileAttributesAtPath: tempDirName traverseLink: YES];
  perm = [[attr objectForKey: NSFilePosixPermissions] intValue];
  perm = perm & 0777;
  if (perm != 0700 && perm != 0600)
    {
      /*
      NSLog(@"Temporary directory (%@) may be insecure ... attempting to "
	@"add secure subdirectory", tempDirName);
      */

      tempDirName
	= [baseTempDirName stringByAppendingPathComponent: NSUserName()];
      if ([manager fileExistsAtPath: tempDirName] == NO)
	{
	  NSNumber	*p = [NSNumber numberWithInt: 0700];

	  attr = [NSDictionary dictionaryWithObject: p
					     forKey: NSFilePosixPermissions];
	  if ([manager createDirectoryAtPath: tempDirName
				  attributes: attr] == NO)
	    {
	      tempDirName = baseTempDirName;
	      NSLog(@"Temporary directory (%@) may be insecure", tempDirName);
	    }
	}
    }

  if ([manager isWritableFileAtPath: tempDirName] == NO)
    {
      NSLog(@"Temporary directory (%@) is not writable", tempDirName);
      return nil;
    }
  return tempDirName;
}

NSString *
NSOpenStepRootDirectory(void)
{
  NSString	*root;

  root = [[[NSProcessInfo processInfo] environment]
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
  NSSearchPathDomainMask domainMask, BOOL expandTilde)
{
  NSFileManager		*fm;
  NSString		*adminDir = @"Administrator";
  NSString		*appsDir = @"Apps";
  NSString		*demosDir = @"Demos";
  NSString		*devDir = @"Developer";
  NSString		*libraryDir = @"Library";
  NSString		*libsDir = @"Libraries";
  NSString		*toolsDir = @"Tools";
  NSString		*docDir = @"Documentation";
  NSMutableArray	*paths = [NSMutableArray new];
  NSString		*path;
  unsigned		i;
  unsigned		count;

  if (gnustep_system_root == nil)
    {
      setupPathNames();
    }

  /*
   * The order in which we return paths is important - user must come
   * first, followed by local, followed by network, followed by system.
   * The calling code can then loop on the returned paths, and stop as
   * soon as it finds something.  So things in user automatically
   * override things in system etc.
   */

  /*
   * FIXME - The following code will not respect this order for
   * NSAllApplicationsDirectory.  This should be fixed I think.
   */
  
#define ADD_PATH(mask, base_dir, add_dir) \
if (domainMask & mask) \
{ \
  path = [base_dir stringByAppendingPathComponent: add_dir]; \
  if (path != nil) \
    [paths addObject: path]; \
}

  if (directoryKey == NSApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_user_root, appsDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, appsDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, appsDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, appsDir);
    }
  if (directoryKey == NSDemoApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory);
    {
      NSString *devDemosDir = [devDir stringByAppendingPathComponent: demosDir];
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, devDemosDir);
    }
  if (directoryKey == NSDeveloperApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      NSString *devAppsDir = [devDir stringByAppendingPathComponent: appsDir];

      ADD_PATH (NSUserDomainMask, gnustep_local_root, devAppsDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, devAppsDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, devAppsDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, devAppsDir);
    }
  if (directoryKey == NSAdminApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      NSString *devAdminDir = [devDir stringByAppendingPathComponent: adminDir];

      /* FIXME - NSUserDomainMask ? - users have no Administrator directory */
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, devAdminDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, devAdminDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, devAdminDir);
    }
  if (directoryKey == NSLibraryDirectory
    || directoryKey == NSAllLibrariesDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_user_root, libraryDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, libraryDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, libraryDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, libraryDir);
    }
  if (directoryKey == NSDeveloperDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_local_root, devDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, devDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, devDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, devDir);
    }
  if (directoryKey == NSUserDirectory)
    {
      if (domainMask & NSUserDomainMask)
	{
	  path = [NSHomeDirectory() stringByAppendingPathComponent: 
	    @"GNUstep"];
	  [paths addObject: path];
	}
    }
  if (directoryKey == NSDocumentationDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_user_root, docDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, docDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, docDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, docDir);
    }
  if (directoryKey == GSLibrariesDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_user_root, libsDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, libsDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, libsDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, libsDir);
    }
  if (directoryKey == GSToolsDirectory)
    {
      ADD_PATH (NSUserDomainMask, gnustep_user_root, toolsDir);
      ADD_PATH (NSLocalDomainMask, gnustep_local_root, toolsDir);
      ADD_PATH (NSNetworkDomainMask, gnustep_network_root, toolsDir);
      ADD_PATH (NSSystemDomainMask, gnustep_system_root, toolsDir);
    }
#undef ADD_PATH

  fm = [NSFileManager defaultManager];

  count = [paths count];

  for (i = 0; i < count; i++)
    {
      path = [paths objectAtIndex: i];
      // remove bad paths
      if ([fm fileExistsAtPath: path] == NO)
        {
          [paths removeObjectAtIndex: i];
	  i--;
	  count--;
        }
      /*
       * this may look like a performance hit at first glance, but if these
       * string methods don't alter the string, they return the receiver
       */
      else if (expandTilde == YES)
	{
	  [paths replaceObjectAtIndex: i
			   withObject: [path stringByExpandingTildeInPath]];
	}
      else
	{
	  [paths replaceObjectAtIndex: i
	    withObject: [path stringByAbbreviatingWithTildeInPath]];
	}
    }

  AUTORELEASE (paths);
  return paths;
}
