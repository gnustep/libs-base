/** Implementation of login-related functions for GNUstep
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

   <title>NSUser class reference</title>
   $Date$ $Revision$
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
#if HAVE_UNISTD_H
#include <unistd.h>		// for getlogin()
#endif
#if	HAVE_PWD_H
#include <pwd.h>		// for getpwnam()
#endif
#include <sys/types.h>
#include <stdio.h>

#define lowlevelstringify(X) #X
#define stringify(X) lowlevelstringify(X)

static NSString	*theUserName = nil;
/* We read these four only once */
static NSString	*gnustep_user_root = nil;    /* GNUSTEP_USER_ROOT */
static NSString	*gnustep_local_root = nil;   /* GNUSTEP_LOCAL_ROOT */
static NSString	*gnustep_network_root = nil; /* GNUSTEP_NETWORK_ROOT */
static NSString	*gnustep_system_root = nil;  /* GNUSTEP_SYSTEM_ROOT */

static void	setupPathNames();
static NSString	*userDirectory(NSString *name, BOOL defaults);

/**
 * Sets the user name for this process.  This method is supplied to enable
 * setuid programs to run properly as the user indicated by their effective
 * user Id.<br />
 * This function calls [NSUserDefaults+resetStandardUserDefaults] as well
 * as changing the value returned by NSUserName() and modifying the user
 * root directory for the process.
 */
void
GSSetUserName(NSString* name)
{
  if (theUserName == nil)
    {
      NSUserName();	// Ensure we know the old user name.
    }
  if ([theUserName isEqualToString: name] == NO)
    {
      /*
       * We must ensure that userDirectory() has been called to set
       * up the template user paths from the environment variables.
       * Then we can destroy the cached user path so that next time
       * anything wants it, it will be regenerated from the template
       * and the new user details.
       */
      userDirectory(theUserName, YES);
      DESTROY(gnustep_user_root);
      /*
       * Next we can set up the new user name, and reset the user defaults
       * system so that standard user defaults will be those of the new
       * user.
       */
      ASSIGN(theUserName, name);
      [NSUserDefaults resetStandardUserDefaults];
    }
}

/**
 * Return the caller's login name as an NSString object.
 * The 'LOGNAME' environment variable is our primary source, but we use
 * other system-dependent sources if LOGNAME is not set.  This function
 * is intended to return the name under which the user logged in rather
 * than the name associated with their numeric user ID (though the two
 * are usually the same).  If you have a setuid program and want to
 * change the user to reflect the uid, use GSSetUserName()
 */
NSString *
NSUserName(void)
{
  if (theUserName == nil)
    {
      const char *loginName = 0;
#if defined(__WIN32__)
      /* The GetUserName function returns the current user name */
      char buf[1024];
      DWORD n = 1024;

      if (GetEnvironmentVariable("LOGNAME", buf, 1024))
	loginName = buf;
      else if (GetUserName(buf, &n))
	loginName = buf;
#else
      loginName = getenv("LOGNAME");
#if	HAVE_GETPWNAM
      /*
       * Check that LOGNAME contained legal name.
       */
      if (loginName != 0 && getpwnam(loginName) == 0)
	{
	  loginName = 0;
	}
#endif	/* HAVE_GETPWNAM */
#if	HAVE_GETLOGIN
      /*
       * Try getlogin() if LOGNAME environmentm variable didn't work.
       */
      if (loginName == 0)
	{
	  loginName = getlogin();
	}
#endif	/* HAVE_GETLOGIN */
#if HAVE_GETPWUID
      /*
       * Try getting the name of the effective user as a last resort.
       */
      if (loginName == 0)
	{
#if HAVE_GETEUID
	  int uid = geteuid();
#else
	  int uid = getuid();
#endif /* HAVE_GETEUID */
	  struct passwd *pwent = getpwuid (uid);
	  loginName = pwent->pw_name;
	}
#endif /* HAVE_GETPWUID */
#endif
      if (loginName)
	theUserName = [[NSString alloc] initWithCString: loginName];
      else
	[NSException raise: NSInternalInconsistencyException
		    format: @"Unable to determine current user name"];
    }
  return theUserName;
}

/**
 * Return the caller's home directory as an NSString object.
 * Calls NSHomeDirectoryForUser() to do this.
 */
NSString *
NSHomeDirectory(void)
{
  return NSHomeDirectoryForUser (NSUserName ());
}

#if defined(__MINGW__)
NSString *
GSStringFromWin32EnvironmentVariable(const char * envVar)
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
      n = GetEnvironmentVariable(envVar, nb, n+1);
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
  [gnustep_global_lock unlock];
  return s;
}
#endif

/**
 * Returns loginName's home directory as an NSString object.
 */
NSString *
NSHomeDirectoryForUser(NSString *loginName)
{
  NSString	*s;
#if !defined(__MINGW__)
  struct passwd *pw;

  [gnustep_global_lock lock];
  pw = getpwnam ([loginName cString]);
  if (pw == 0)
    {
      NSLog(@"Unable to locate home directory for '%@'", loginName);
      s = nil;
    }
  else
    {
      s = [NSString stringWithCString: pw->pw_dir];
    }
  [gnustep_global_lock unlock];
  return s;
#else
  /* Then environment variable HOMEPATH holds the home directory
     for the user on Windows NT; Win95 has no concept of home. */
  [gnustep_global_lock lock];
  s = GSStringFromWin32EnvironmentVariable("HOMEPATH");
  if (s != nil)
    {
      s = [GSStringFromWin32EnvironmentVariable("HOMEDRIVE")
        stringByAppendingString: s];
    }
  [gnustep_global_lock unlock];
  return s;
#endif
}

/**
 * Returns the full username of the current user.
 * If unable to determine this, returns the standard user name.
 */
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

static void
setupPathNames()
{
#if defined (__MINGW32__)
  NSString *systemDrive = GSStringFromWin32EnvironmentVariable("SystemDrive");
#endif
  if (gnustep_user_root == nil)
    {
      NS_DURING
	{
	  BOOL	warned = NO;
	  NSDictionary	*env;
	  
	  [gnustep_global_lock lock];

	  /* Double-Locking Pattern */
	  if (gnustep_system_root == nil)
	    {
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
		  gnustep_system_root = [NSString stringWithCString:
					  stringify(GNUSTEP_INSTALL_PREFIX)];
#if defined (__MINGW32__)
                  gnustep_system_root = [systemDrive stringByAppendingString:
                                          gnustep_system_root];
#endif

		  RETAIN(gnustep_system_root);
		  fprintf (stderr, 
		    "Warning - GNUSTEP_SYSTEM_ROOT is not set "
		    "- using %s\n", [gnustep_system_root lossyCString]);
		}
	    }
	  if (gnustep_local_root == nil)
	    {
	      gnustep_local_root = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
	      TEST_RETAIN (gnustep_local_root);
	      if (gnustep_local_root == nil)
		{
		  gnustep_local_root = [NSString stringWithCString:
					  stringify(GNUSTEP_LOCAL_ROOT)];
#if defined (__MINGW32__)
                  gnustep_local_root = [systemDrive stringByAppendingString:
                                         gnustep_local_root];
#endif
		  if ([gnustep_local_root length] == 0)
		    gnustep_local_root = nil;
		  else
		    RETAIN(gnustep_local_root);
		}
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
	    }
	  if (gnustep_network_root == nil)
	    {
	      gnustep_network_root = [env objectForKey: 
		@"GNUSTEP_NETWORK_ROOT"];
	      TEST_RETAIN (gnustep_network_root);
	      if (gnustep_network_root == nil)
		{
		  gnustep_network_root = [NSString stringWithCString:
					  stringify(GNUSTEP_NETWORK_ROOT)];
#if defined (__MINGW32__)
                  gnustep_network_root = [systemDrive stringByAppendingString:
                                           gnustep_network_root];
#endif
		  if ([gnustep_network_root length] == 0)
		    gnustep_network_root = nil;
		  else
		    RETAIN(gnustep_network_root);
		}
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
	    }
	  if (gnustep_user_root == nil)
	    {
	      gnustep_user_root = [userDirectory(NSUserName(), NO) copy];
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

/** Returns a string containing the path to the GNUstep system
    installation directory. This function is guarenteed to return a non-nil
    answer (unless something is seriously wrong, in which case the application
    will probably crash anyway) */
NSString *
GSSystemRootDirectory(void)
{
  if (gnustep_system_root == nil)
    {
      setupPathNames();
    }
  return gnustep_system_root;
}

/**
 * Return the path of the defaults directory for name.<br />
 * This uses the GNUSTEP_DEFAULTS_ROOT or the GNUSTEP_USER_ROOT
 * environment variable to determine the directory.  If the user
 * has changed, the path for the new user will be based on a template
 * derived from the path for the original user, substituting in
 * the values returned by NSHomeDirectory() and NSUser()
 */
NSString*
GSDefaultsRootForUser(NSString *userName)
{
  return userDirectory(userName, YES);
}

static NSString *
userDirectory(NSString *name, BOOL defaults)
{
  /*
   * Marker objects should be something which will never
   * appear in a normal path
   */
  static NSString	*uMarker = @"[{<USER>}]";
  static NSString	*hMarker = @"[{<HOME>}]";
  static NSString	*fileTemplate = nil;
  static NSString	*defsTemplate = nil;
  NSString		*template;
  NSString		*home;
  NSString		*path = nil;
  NSRange		r;

  NSCAssert([name length] > 0, NSInvalidArgumentException);

  /**
   * If we don't have templates set up, ensure that it's set up for
   * the original user by pre-calling ourself for that user.
   */
  if ([name isEqual: NSUserName()] == NO)
    {
      if (defsTemplate == nil)
	{
	  userDirectory(NSUserName(), YES);
	}
      if (fileTemplate == nil)
	{
	  userDirectory(NSUserName(), NO);
	}
    }

  if (defaults == YES)
    {
      template = defsTemplate;
    }
  else
    {
      template = fileTemplate;
    }
  home = NSHomeDirectoryForUser(name);

  [gnustep_global_lock lock];
  NS_DURING
    {
      if (template == nil)
	{
	  NSString	*old;

	  if (defaults == YES)
	    {
	      path = [[[NSProcessInfo processInfo] environment]
		objectForKey: @"GNUSTEP_DEFAULTS_ROOT"];
	    }
	  if (path == nil)
	    {
	      path = [[[NSProcessInfo processInfo] environment]
		objectForKey: @"GNUSTEP_USER_ROOT"];
	    }
	  if (path == nil)
	    {
	      path = [NSHomeDirectoryForUser(name)
		stringByAppendingPathComponent: @"GNUstep"];
	      fprintf (stderr, 
		"Warning - GNUSTEP_USER_ROOT is not set "
		"- using %s\n", [path lossyCString]);
	    }
	  else
	    {
	      path = [path stringByExpandingTildeInPath];
	    }
	  /*
	   * We build a template for the user root path by replacing
	   * the user name and home directory in the original string.
	   */
	  old = path;
	  if ([old hasPrefix: home] == YES)
	    {
	      old = [old substringFromIndex: [home length]];
	      template = hMarker;
	    }
	  else
	    {
	      template = @"";
	    }
	  r = [old rangeOfString: name];
	  while (r.length > 0)
	    {
	      template = [template stringByAppendingFormat:
		@"%@%@", [old substringToIndex: r.location], uMarker];
	      old = [old substringFromIndex: NSMaxRange(r)];
	      r = [old rangeOfString: name];
	    }
	  template = [template stringByAppendingString: old];
	  RETAIN(template);
	  if (defaults == YES)
	    {
	      defsTemplate = template;
	    }
	  else
	    {
	      fileTemplate = template;
	    }
	}
      else
	{
	  NSMutableString	*m;

	  /*
	   * Use an existing template to create the user root
	   * for the current user.
	   */
	  m = [template mutableCopy];
	  r = [m rangeOfString: uMarker];
	  while (r.length > 0)
	    {
	      [m replaceCharactersInRange: r withString: name];
	      r.location += [name length];
	      r.length = [m length] - r.location;
	      r = [m rangeOfString: uMarker
			   options: NSLiteralSearch
			     range: r];
	    }
	  r = [m rangeOfString: hMarker];
	  if (r.location == 0)
	    {
	      [m replaceCharactersInRange: r withString: home];
	    }
	  path = m;
	  AUTORELEASE(path);
	}
    }
  NS_HANDLER
    {
      [gnustep_global_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [gnustep_global_lock unlock];
  return path;
}

/** Returns an array of strings which contain paths that should be in
    the standard search order for resources, etc. If the environment
    variable GNUSTEP_PATHPREFIX_LIST is set. It returns the list of
    paths set in that variable. Otherwise, it returns the user, local,
    network, and system paths, in that order.  This function is
    guarenteed to return a non-nil answer (unless something is
    seriously wrong, in which case the application will probably crash
    anyway) */
NSArray *
GSStandardPathPrefixes(void)
{
  NSDictionary	*env;
  NSString	*prefixes;
  NSArray	*prefixArray;
    
  env = [[NSProcessInfo processInfo] environment];
  prefixes = [env objectForKey: @"GNUSTEP_PATHPREFIX_LIST"];
  if (prefixes != nil)
    {
#if	defined(__WIN32__)
      prefixArray = [prefixes componentsSeparatedByString: @";"];
#else
      prefixArray = [prefixes componentsSeparatedByString: @":"];
#endif
      if ([prefixArray count] <= 1)
	{
	  /* This probably means there was some parsing error, but who
	     knows. Play it safe though... */
	  prefixArray = nil;
	}
    }
  if (prefixes == nil)
    {
      NSString	*strings[4];
      NSString	*str;
      unsigned	count = 0;

      if (gnustep_user_root == nil)
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

/**
 * Returns the standard paths in which applications are stored and
 * should be searched for.  Calls NSSearchPathForDirectoriesInDomains()
 */
NSArray *
NSStandardApplicationPaths(void)
{
  return NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory,
                                             NSAllDomainsMask, YES);
}

/**
 * Returns the standard paths in which libraries are stored and
 * should be searched for.  Calls NSSearchPathForDirectoriesInDomains()
 */
NSArray *
NSStandardLibraryPaths(void)
{
  return NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
                                             NSAllDomainsMask, YES);
}

/**
 * Returns the name of a directory in which temporary files can be stored.
 * Under GNUstep this is a location which is not readable by other users.
 */
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

/**
 * Returns the root directory for the OpenStep (GNUstep) installation.
 * This si determined by the GNUSTEP_ROOT environment variable if available.
 */
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

/**
 * Returns an array of search paths to look at for resources.
 */
NSArray *
NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directoryKey,
  NSSearchPathDomainMask domainMask, BOOL expandTilde)
{
  NSFileManager		*fm;
  NSString		*adminDir = @"Administrator";
  NSString		*appsDir = @"Applications";
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

  if (gnustep_user_root == nil)
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
	  [paths addObject: gnustep_user_root];
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
