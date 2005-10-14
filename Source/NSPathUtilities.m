/* Implementation of filesystem & path-related functions for GNUstep
   Copyright (C) 1996-2004 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <address@hidden>
   Created: May 1996
   Rewrite by:  Sheldon Gill
   Date:    Jan 2004
   Rewrites by:  Richard Frith-Macdonald
   Date:    2004-2005

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

   <title>NSPathUtilities function reference</title>
   $Date$ $Revision$
   */

/**
   <unit>
   <heading>Path Utility Functions</heading>
   <p>
   Path utilities provides functions to dynamically discover paths
   for the platform the application is running on.
   This avoids the need for hard coding paths, making porting easier
   and also allowing for places to change without breaking
   applications.
   (why do this? Well imagine we're running GNUstep 1 and the new
   wonderful GNUstep 2 becomes available but we're not sure of it
   yet. You could install /GNUstep/System2/ and have applications
   use which ever System you wanted at the time...)
   </p>
   <p>
   On unix systems, the paths are initialised by reading a configuration
   file. Something like "/etc/GNUstep/GNUstep.conf". This provides the basic
   information required by the library to establish all locations required.
   </p>
   <p>
   On windows, the paths may also (as a fallback) be initialised by
   reading information from the windows registry.
   HKEY_LOCAL_MACHINE\Software\GNU\GNUstep contains the machine wide
   definititions for system paths.
   </p>
   <p>
   See <REF "filesystem.pdf">GNUstep File System Heirarchy</REF> document
   for more information and detailed descriptions.</p>
   </unit>
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSObjCRuntime.h"
#include "Foundation/NSString.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSException.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSString.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSUserDefaults.h"
#include "GNUstepBase/GSCategories.h"
#if defined(__WIN32__)
#include "GNUstepBase/Win32_Utilities.h"
#endif

#include "GSPrivate.h"
#include "GNUstepBase/Win32Support.h"

#ifdef HAVE_UNISTD_H
#include <unistd.h>		// for getuid()
#endif
#ifdef	HAVE_PWD_H
#include <pwd.h>		// for getpwnam()
#endif
#include <sys/types.h>
#include <stdio.h>

/* Defines used to highlight design decisions. It's possible these could
   be made compile time or even user configurable.
*/
#define OPTION_PLATFORM_SUPPORT  // To find platform specific things

#define lowlevelstringify(X) #X
#define stringify(X) lowlevelstringify(X)

/* The global configuration file. The real value is read from config.h */
#ifndef GNUSTEP_CONFIGURATION_FILE
# define   GNUSTEP_CONFIGURATION_FILE  /etc/GNUstep/GNUstep.conf
#endif
/* The name of the user-specific configuration file */
#define   DEFAULT_STEPRC_FILE         @".GNUsteprc"
/* The standard path for user Defaults files */
#define   DEFAULT_DEFAULTS_PATH       @"Defaults"
/* The standard path to user GNUstep resources */
#define   DEFAULT_USER_ROOT           @"GNUstep"


static NSString	*gnustep_target_cpu =
#ifdef GNUSTEP_TARGET_CPU
  @GNUSTEP_TARGET_CPU;
#else
  nil;
#endif
static NSString	*gnustep_target_os =
#ifdef GNUSTEP_TARGET_OS
  @GNUSTEP_TARGET_OS;
#else
  nil;
#endif
static NSString	*library_combo =
#ifdef LIBRARY_COMBO
  @LIBRARY_COMBO;
#else
  nil;
#endif
static NSString	*gnustep_flattened =
#ifdef GNUSTEP_FLATTENED
  @GNUSTEP_FLATTENED;
#else
  nil;
#endif

#define	MGR()	[NSFileManager defaultManager]

/*
 * NB. use fprintf() rather than NSLog() to avoid possibility of recursion
 * when features of NSLog() cause patrh utilities to be used.
 */
#define PrintOnce(format, args...) \
  do { static BOOL beenHere = NO; if (beenHere == NO) {\
    beenHere = YES; \
    fprintf(stderr, format, ## args); }} while (0)

/* ------------------ */
/* Internal variables */
/* ------------------ */

static NSString	*configFile;

/* We read these four paths only once */
static NSString *gnustepUserRoot = nil;        /*    GNUSTEP_USER_ROOT path */
static NSString *gnustepLocalRoot = nil;       /*   GNUSTEP_LOCAL_ROOT path */
static NSString *gnustepNetworkRoot = nil;     /* GNUSTEP_NETWORK_ROOT path */
static NSString *gnustepSystemRoot = nil;      /*  GNUSTEP_SYSTEM_ROOT path */

static NSString *gnustepRcFileName = nil;
static NSString *gnustepDefaultsPath = nil;
static NSString *gnustepUserPath = nil;

static NSString *theUserName = nil;             /*      The user's login name */
static NSString *tempDir = nil;                 /* user's temporary directory */

#ifdef OPTION_PLATFORM_SUPPORT
static NSString *osSysPrefs = nil;
static NSString *osSysApps  = nil;
static NSString *osSysLibs  = nil;
static NSString *osSysAdmin = nil;

static NSString *platformResources = nil;
static NSString *platformApps  = nil;
static NSString *platformLibs  = nil;
static NSString *platformAdmin = nil;

static NSString *localResources = nil;
static NSString *localApps  = nil;
static NSString *localLibs  = nil;

/* Keys for Platform support in conf-file. */
#define SYS_APPS    @"SYS_APPS"
#define SYS_LIBS    @"SYS_LIBS"
#define SYS_PREFS   @"SYS_PREFS"
#define SYS_ADMIN   @"SYS_ADMIN"
#define SYS_RESOURCES @"SYS_RESOURCES"

#define PLATFORM_APPS    @"PLATFORM_APPS"
#define PLATFORM_LIBS    @"PLATFORM_LIBS"
#define PLATFORM_ADMIN   @"PLATFORM_ADMIN"
#define PLATFORM_RESOURCES @"PLATFORM_RESOURCES"

#define PLATFORM_LOCAL_APPS    @"PLATFORM_LOCAL_APPS"
#define PLATFORM_LOCAL_LIBS    @"PLATFORM_LOCAL_LIBS"
#define PLATFORM_LOCAL_ADMIN   @"PLATFORM_LOCAL_ADMIN"
#define PLATFORM_LOCAL_RESOURCES @"PLATFORM_LOCAL_RESOURCES"
#endif /* OPTION_PLATFORM_SUPPORT */

/* ============================= */
/* Internal function prototypes. */
/* ============================= */

static NSString *setUserGNUstepPath(NSString *userName,
				       NSString **defaultsPath,
				       NSString **userPath);

static NSDictionary *ParseConfigurationFile(NSString *name);

static void InitialisePathUtilities(void);
static void ShutdownPathUtilities(void);

/* Conditionally assign an object from a dictionary to var
 * We don't need to retain val before releasing var, because we
 * can be sure that if var is val it is retained by the dictionary
 * as well as being retained when it was first placed in var.
 */
#define ASSIGN_IF_SET(var, dictionary, key) ({\
  id val = [dictionary objectForKey: key];\
  if (val != nil)\
    {\
      RELEASE(var);\
      var = RETAIN(val);\
    }\
  })

/* Conditionally assign lval to var only if var is nil */
#define TEST_ASSIGN(var, lval) ({\
  if ((var == nil)&&(lval != nil))\
    {\
      var = RETAIN(lval);\
    }\
  })

/* Get a path string from a dictionary */
static inline NSString *
getPathConfig(NSDictionary *dict, NSString *key)
{
  NSString *path;

  NSCParameterAssert(dict!=nil);

  path = [dict objectForKey: key];
  TEST_RETAIN(path);

  return path;
}

/*
 * Read .GNUsteprc file for user and set paths accordingly
 */
static NSString *setUserGNUstepPath(NSString *userName,
				       NSString **defaultsPath,
				       NSString **userPath)
{
  NSDictionary	*dict;
  NSString	*home;
  NSString	*path;
  NSString	*steprcFile;
  NSString	*userRoot;

  /* Look for rc file (".GNUsteprc") file in user's home directory */
  home = NSHomeDirectoryForUser(userName);
  if (home == nil)
    {
      /* It's OK if path is nil. We're might be running as user nobody in
       * which case we don't want to access user stuff. Possibly it's a
       * misconfigured Windows environment, though...
       */
      return nil;
    }

  if ([gnustepRcFileName length] > 0)
    {
      steprcFile = [home stringByAppendingPathComponent: gnustepRcFileName];

      dict = ParseConfigurationFile(steprcFile);
      if (dict != nil)
	{
	  path = [dict objectForKey: @"GNUSTEP_DEFAULTS_ROOT"];
	  if (path != nil)
	    {
	      /*
	       * Special case for defaults root ... expand leading '~'
	       */
	      if ([path hasPrefix: @"~"])
		{
GSOnceFLog(@"Use of '~' in GNUSTEP_DEFAULTS_ROOT is deprecated");
		  path = [path substringFromIndex: 1];
		  while ([path hasPrefix: @"/"] || [path hasPrefix: @"\\"])
		    {
		      path = [path substringFromIndex: 1];
		    }
		  path = [home stringByAppendingPathComponent: path];
		}
	      ASSIGN(*defaultsPath, path);
	    }
	  path = [dict objectForKey: @"GNUSTEP_USER_ROOT"];
	  if (path != nil)
	    {
	      /*
	       * For backward compatibility, remove leading '~' component
	       * we will prepend the home directory later.
	       */
	      if ([path hasPrefix: @"~"])
		{
GSOnceFLog(@"Use of '~' in GNUSTEP_USER_ROOT is deprecated");
		  path = [path substringFromIndex: 1];
		  while ([path hasPrefix: @"/"] || [path hasPrefix: @"\\"])
		    {
		      path = [path substringFromIndex: 1];
		    }
		}
	      ASSIGN(*userPath, path);
	    }
	}
    }

  /* set the user path and defaults directory to default values if needed */
  TEST_ASSIGN(*defaultsPath, DEFAULT_DEFAULTS_PATH);
  TEST_ASSIGN(*userPath, DEFAULT_USER_ROOT);

  /* Now we set the user's root path for the gnustep files. */
  if ([*userPath isAbsolutePath])
    userRoot = *userPath;
  else
    userRoot = [home stringByAppendingPathComponent: *userPath];
  return userRoot;
}

/* Initialise all things required by this module */
static void InitialisePathUtilities(void)
{
  if (gnustepSystemRoot != nil)
    {
      return;	// Protect from multiple calls
    }

  /* Set up our root paths */
  NS_DURING
    {
      NSDictionary  *env = [[NSProcessInfo processInfo] environment];
#if defined(__WIN32__)
      HKEY regkey;
#endif

      /* Initialise Win32 things if on that platform */
      Win32Initialise();   // should be called by DLL_PROCESS_ATTACH

      [gnustep_global_lock lock];

#ifndef OPTION_NO_ENVIRONMENT
      /* First we look at the environment */
      TEST_ASSIGN(gnustepSystemRoot,
	[env objectForKey: @"GNUSTEP_SYSTEM_ROOT"]);
      TEST_ASSIGN(gnustepNetworkRoot,
	[env objectForKey: @"GNUSTEP_NETWORK_ROOT"]);
      TEST_ASSIGN(gnustepLocalRoot,
	[env objectForKey: @"GNUSTEP_LOCAL_ROOT"]);
#endif /* !OPTION_NO_ENVIRONMENT */

#if defined(__WIN32__)
      regkey = Win32OpenRegistry(HKEY_LOCAL_MACHINE,
				 "\\Software\\GNU\\GNUstep");
      if (regkey != (HKEY)NULL)
	{
	  TEST_ASSIGN(gnustepSystemRoot,
	    Win32NSStringFromRegistry(regkey, @"GNUSTEP_SYSTEM_ROOT"));
	  TEST_ASSIGN(gnustepNetworkRoot,
	    Win32NSStringFromRegistry(regkey, @"GNUSTEP_NETWORK_ROOT"));
	  TEST_ASSIGN(gnustepLocalRoot,
	    Win32NSStringFromRegistry(regkey, @"GNUSTEP_LOCAL_ROOT"));
	  RegCloseKey(regkey);
	}

#if 0
      // Not implemented yet
      platformApps   = Win32FindDirectory(CLSID_APPS);
      platformLibs   = Win32FindDirectory(CLSID_LIBS);
#endif
#else
      /* Now we source the configuration file if it exists */
      configFile = [env objectForKey: @"GNUSTEP_CONFIGURATION_FILE"];
      if (configFile == nil)
	{
	  configFile
	    = [NSString stringWithCString:
	    stringify(GNUSTEP_CONFIGURATION_FILE)];
	}
      configFile = RETAIN([configFile stringByStandardizingPath]);
      if ([MGR() fileExistsAtPath: configFile])
	{
	  NSDictionary  *d = ParseConfigurationFile(configFile);

	  if (d != nil)
	    {
	      ASSIGN_IF_SET(gnustepSystemRoot, d, @"GNUSTEP_SYSTEM_ROOT");
	      ASSIGN_IF_SET(gnustepNetworkRoot, d, @"GNUSTEP_NETWORK_ROOT");
	      ASSIGN_IF_SET(gnustepLocalRoot, d, @"GNUSTEP_LOCAL_ROOT");

	      ASSIGN_IF_SET(gnustepRcFileName, d, @"USER_GNUSTEP_RC");
	      ASSIGN_IF_SET(gnustepDefaultsPath, d, @"USER_GNUSTEP_DEFAULTS");
	      ASSIGN_IF_SET(gnustepUserPath, d, @"USER_GNUSTEP_DIR");

#ifdef OPTION_PLATFORM_SUPPORT
	      ASSIGN_IF_SET(osSysPrefs, d, SYS_PREFS);
	      ASSIGN_IF_SET(osSysApps, d, SYS_APPS);
	      ASSIGN_IF_SET(osSysLibs, d, SYS_LIBS);
	      ASSIGN_IF_SET(osSysAdmin, d, SYS_ADMIN);

	      ASSIGN_IF_SET(platformResources, d, PLATFORM_RESOURCES);
	      ASSIGN_IF_SET(platformApps, d, PLATFORM_APPS);
	      ASSIGN_IF_SET(platformLibs, d, PLATFORM_LIBS);
	      ASSIGN_IF_SET(platformAdmin, d, PLATFORM_ADMIN);

	      ASSIGN_IF_SET(localResources, d, PLATFORM_LOCAL_RESOURCES);
	      ASSIGN_IF_SET(localApps, d, PLATFORM_LOCAL_APPS);
	      ASSIGN_IF_SET(localLibs, d, PLATFORM_LOCAL_LIBS);
#endif /* OPTION_PLATFORM SUPPORT */
	    }
	}
#endif

      /* System admins may force the user and defaults paths by
       * setting USER_GNUSTEP_RC to be an empty string.
       * If they simply don't define it at all, we assign a default
       * value here.
       */
      TEST_ASSIGN(gnustepRcFileName,  DEFAULT_STEPRC_FILE);

      /* If the user has an rc file we need to source it */
      gnustepUserRoot = setUserGNUstepPath(NSUserName(),
	&gnustepDefaultsPath, &gnustepUserPath);

      /* Finally we check and report problems... */
      if (gnustepSystemRoot == nil)
	{
	  gnustepSystemRoot = [NSString stringWithCString:\
	    STRINGIFY(GNUSTEP_INSTALL_PREFIX)];
	  fprintf (stderr, "Warning - GNUSTEP_SYSTEM_ROOT is not set " \
	    "- using %s\n", [gnustepSystemRoot lossyCString]);
	}
      if (gnustepNetworkRoot == nil)
	{
	  gnustepNetworkRoot = [NSString stringWithCString:\
	    STRINGIFY(GNUSTEP_NETWORK_ROOT)];
	  fprintf (stderr, "Warning - GNUSTEP_NETWORK_ROOT is not set " \
	    "- using %s\n", [gnustepNetworkRoot lossyCString]);
	}
      if (gnustepLocalRoot == nil)
	{
	  gnustepLocalRoot = [NSString stringWithCString:\
	    STRINGIFY(GNUSTEP_LOCAL_ROOT)];
	  fprintf (stderr, "Warning - GNUSTEP_LOCAL_ROOT is not set " \
	    "- using %s\n", [gnustepLocalRoot lossyCString]);
	}

      [gnustep_global_lock unlock];
    }
  NS_HANDLER
    {
      /* unlock then re-raise the exception */
      [gnustep_global_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

/*
 * Close down and release all things allocated.
 */
static void ShutdownPathUtilities(void)
{
  DESTROY(gnustepSystemRoot);
  DESTROY(gnustepNetworkRoot);
  DESTROY(gnustepLocalRoot);
  DESTROY(gnustepUserRoot);

  DESTROY(gnustepRcFileName);
  DESTROY(gnustepDefaultsPath);
  DESTROY(gnustepUserPath);

#ifdef OPTION_PLATFORM_SUPPORT
  DESTROY(osSysPrefs);
  DESTROY(osSysApps);
  DESTROY(osSysLibs);
  DESTROY(osSysAdmin);

  DESTROY(platformResources);
  DESTROY(platformApps);
  DESTROY(platformLibs);
  DESTROY(platformAdmin);

  DESTROY(localResources);
  DESTROY(localApps);
  DESTROY(localLibs);
#endif /* OPTION_PLATFORM SUPPORT */

  DESTROY(tempDir);

  /* Shutdown Win32 support */
  Win32Finalise();
}


/**
 * Reads a file and expects it to be in basic unix "conf" style format with
 * one key = value per line (the format a unix shell can 'source' in order
 * to define shell variables).<br />
 * Attempts to mimic the escape sequence and quoting conventions of standard
 * shells, so that a config file sourced by the make package will produce
 * the same results as one parsed by this function.<br />
 * The value may be any quoted string (or an unquoted string containing no
 * white space).<br />
 * Lines beginning with a hash '#' are deemed comment lines and ignored.<br/ >
 * The backslash character may be used as an escape character anywhere
 * in the file  except within a singly quoted string
 * (where it is taken literally).<<br />
 * A backslash followed immediately by a newline (except in a singly
 * quoted string) is removed completely along with the newline ... it
 * thus serves to join lines so that they are treated as a single line.<br />
 * NB. Since windows uses backslash characters in paths, it is a good
 * idea to specify path values in the config file as singly quoted
 * strings to avoid having to double all occurrances of the backslash.<br />
 * Returns a dictionary of the (key,value) pairs.<br/ >
 */
static NSDictionary *
ParseConfigurationFile(NSString *fileName)
{
  NSMutableDictionary *dict;
  NSDictionary	*attributes;
  NSString      *file;
  unsigned	l;
  unichar	*src;
  unichar	*dst;
  unichar	*end;
  unichar	*spos;
  unichar	*dpos;
  BOOL		newLine = YES;
  NSString	*key = nil;
  NSString	*lastToken = nil;

  if ([MGR() isReadableFileAtPath: fileName] == NO)
    {
      return nil;
    }

  attributes = [MGR() fileAttributesAtPath: fileName traverseLink: YES];
  if (([attributes filePosixPermissions] & 022) != 0)
    {
#if defined(__WIN32__)
      fprintf(stderr, "The file '%S' is writable by someone other than"
	" its owner.\nIgnoring it.\n",
	(const unichar*)[fileName fileSystemRepresentation]);
#else
      fprintf(stderr, "The file '%s' is writable by someone other than"
	" its owner.\nIgnoring it.\n", [fileName fileSystemRepresentation]);
#endif
      return nil;
    }

  dict = [NSMutableDictionary dictionaryWithCapacity: 16];
  if (dict == nil)
    {
      return nil; // should throw an exception??
    }

  file = [NSString stringWithContentsOfFile: fileName];
  l = [file length];
  src = (unichar*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(unichar) * l);
  spos = src;
  end = src + l;
  dst = (unichar*)NSZoneMalloc(NSDefaultMallocZone(), sizeof(unichar) * l);
  dpos = dst;
  [file getCharacters: src];

  while (spos < end)
    {
      /*
       * Step past any whitespace ... including blank lines
       */
      while (spos < end)
	{
	  if (*spos == '\\')
	    {
	      spos++;
	      if (spos >= end)
		{
		  break;	// At end of file ... odd but not fatal
		}
	    }
	  if (*spos > ' ')
	    {
	      break;		// OK ... found a non space character.
	    }
	  if (*spos == '\r' || *spos == '\n')
	    {
	      newLine = YES;
	    }
	  spos++;
	}

      /*
       * Handle any comments .. hash on a new line.
       */
      if (newLine == YES)
	{
	  if (key != nil)
	    {
	      /*
	       * On a newline ...so the last key had no value set.
	       * Put an empty cvalue in the dictionary.
	       */
	      [dict setObject: @"" forKey: key];
	      DESTROY(key);
	    }
	  if (spos < end && *spos == '#')
	    {
	      // Got a comment ... ignore remainder of line.
	      while (spos < end && *spos != '\n' && *spos != '\r')
		{
		  spos++;
		}
	      continue;	// restart loop ... skip space at start of line
	    }
	  newLine = NO;
	}

      if (*spos == '=')
	{
	  if (key != nil)
	    {
	      [dict setObject: @"" forKey: key];
	      DESTROY(key);
	    }
	  key = lastToken;
	  lastToken = nil;
	  spos++;
	}
      else if (*spos == '\'')
	{
	  spos++;
	  while (spos < end)
	    {
	      if (*spos == '\'')
		{
		  spos++;
		  break;
		}
	      *dpos++ = *spos++;
	    }
	  DESTROY(lastToken);
	  lastToken = [NSString alloc];
	  lastToken = [lastToken initWithCharacters: dst length: dpos - dst];
	  if (key != nil)
	    {
	      [dict setObject: lastToken forKey: key];
	      DESTROY(key);
	      DESTROY(lastToken);
	    }
	  dpos = dst;	// reset output buffer
	}
      else if (*spos == '"')
	{
	  spos++;
	  while (spos < end)
	    {
	      BOOL	escaped = NO;

	      if (*spos == '\\')
		{
		  spos++;
		  if (spos >= end)
		    {
		      break;	// Unexpected end of file
		    }
		  if (*spos == '\n')
		    {
		      spos++;
		      continue;	// escaped newline is removed.
		    }
		  if (*spos == '\r')
		    {
		      spos++;
		      if (spos < end && *spos == '\n')
			{
			  spos++;
			}
		      continue;	// escaped newline is removed.
		    }
		  escaped = YES;
		}
	      if (*spos == '"' && escaped == NO)
		{
		  spos++;
		  break;
		}
	      *dpos++ = *spos++;
	    }
	  DESTROY(lastToken);
	  lastToken = [NSString alloc];
	  lastToken = [lastToken initWithCharacters: dst length: dpos - dst];
	  if (key != nil)
	    {
	      [dict setObject: lastToken forKey: key];
	      DESTROY(key);
	      DESTROY(lastToken);
	    }
	  dpos = dst;	// reset output buffer
	}
      else
	{
	  while (spos < end)
	    {
	      if (*spos == '\\')
		{
		  spos++;
		  if (spos >= end)
		    {
		      break;	// Unexpected end of file
		    }
		  if (*spos == '\n')
		    {
		      spos++;
		      continue;	// escaped newline is removed.
		    }
		  if (*spos == '\r')
		    {
		      spos++;
		      if (spos < end && *spos == '\n')
			{
			  spos++;
			}
		      continue;	// escaped newline is removed.
		    }
		}
	      if (*spos <= ' ' || *spos == '=')
		{
		  break;
		}
	      *dpos++ = *spos++;
	    }

	  DESTROY(lastToken);
	  lastToken = [NSString alloc];
	  lastToken = [lastToken initWithCharacters: dst length: dpos - dst];
	  if (key != nil)
	    {
	      [dict setObject: lastToken forKey: key];
	      DESTROY(key);
	      DESTROY(lastToken);
	    }
	  dpos = dst;	// reset output buffer
	}
    }
  if (key != nil)
    {
      [dict setObject: @"" forKey: key];
      DESTROY(key);
    }
  DESTROY(lastToken);
  NSZoneFree(NSDefaultMallocZone(), src);
  NSZoneFree(NSDefaultMallocZone(), dst);

  return dict;
}

/* See NSPathUtilities.h for description */
void
GSSetUserName(NSString *aName)
{
  NSCParameterAssert([aName length] > 0);

  /*
   * Do nothing if it's not a different user.
   */
  if ([theUserName isEqualToString: aName])
    {
      return;
    }

  /*
   * Release the memory
   */
  [gnustep_global_lock lock];
  ShutdownPathUtilities();

  /*
   * Reset things as new user
   */
  ASSIGN(theUserName, aName);
  InitialisePathUtilities();
  [NSUserDefaults resetStandardUserDefaults];

  [gnustep_global_lock unlock];
}

/**
 * Return the caller's login name as an NSString object.<br/ >
 * Under unix-like systems, the name associated with the current
 * effective user ID is used.<br/ >
 * Under ms-windows, the 'LOGNAME' environemnt is used, or if that fails, the
 * GetUserName() call is used to find the user name.
 */
/* NOTE FOR DEVELOPERS.
 * If you change the behavior of this method you must also change
 * user_home.c in the makefiles package to match.
 */
NSString *
NSUserName(void)
{
#if defined(__WIN32__)
  if (theUserName == nil)
    {
      const char *loginName = 0;
      /* The GetUserName function returns the current user name */
      char buf[1024];
      DWORD n = 1024;

      if (GetEnvironmentVariable("LOGNAME", buf, 1024) != 0 && buf[0] != '\0')
	loginName = buf;
      else if (GetUserName(buf, &n) != 0 && buf[0] != '\0')
	loginName = buf;
      if (loginName)
	theUserName = [[NSString alloc] initWithCString: loginName];
      else
	[NSException raise: NSInternalInconsistencyException
		    format: @"Unable to determine current user name"];
    }
#else
  /* Set olduid to some invalid uid that we could never start off running
     as.  */
  static int	olduid = -1;
#ifdef HAVE_GETEUID
  int uid = geteuid();
#else
  int uid = getuid();
#endif /* HAVE_GETEUID */

  if (theUserName == nil || uid != olduid)
    {
      const char *loginName = 0;
#ifdef HAVE_GETPWUID
      struct passwd *pwent = getpwuid (uid);
      loginName = pwent->pw_name;
#endif /* HAVE_GETPWUID */
      olduid = uid;
      if (loginName)
	theUserName = [[NSString alloc] initWithCString: loginName];
      else
	[NSException raise: NSInternalInconsistencyException
		    format: @"Unable to determine current user name"];
    }
#endif
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

/**
 * Returns loginName's home directory as an NSString object.
 */
/* NOTE FOR DEVELOPERS.
 * If you change the behavior of this method you must also change
 * user_home.c in the makefiles package to match.
 */
NSString *
NSHomeDirectoryForUser(NSString *loginName)
{
  NSString	*s = nil;
#if !defined(__MINGW32__)
  struct passwd *pw;

  [gnustep_global_lock lock];
  pw = getpwnam ([loginName cString]);
  if (pw != 0  && pw->pw_dir != NULL)
    {
      s = [NSString stringWithCString: pw->pw_dir];
    }
  [gnustep_global_lock unlock];
#else
  s = Win32GetUserProfileDirectory(loginName);
#endif
  return s;
}

/**
 * Returns the full username of the current user.
 * If unable to determine this, returns the standard user name.
 */
NSString *
NSFullUserName(void)
{
#if defined(__WIN32__)
  /* FIXME: Win32 way to get full user name via Net API */
  return NSUserName();
#else
#ifdef  HAVE_PWD_H
  struct passwd	*pw;

  pw = getpwnam([NSUserName() cString]);
  return [NSString stringWithCString: pw->pw_gecos];
#else
  NSLog(@"Warning: NSFullUserName not implemented\n");
  return NSUserName();
#endif /* HAVE_PWD_H */
#endif /* defined(__Win32__) else */
}

/**
 * Return the path of the defaults directory for userName.<br />
 * This examines the .GNUsteprc file in the home directory of the
 * user for the GNUSTEP_DEFAULTS_ROOT or the GNUSTEP_USER_ROOT
 * directory definitions, over-riding those in GNUstep.conf.
 */
NSString *
GSDefaultsRootForUser(NSString *userName)
{
  NSString *home;
  NSString *defaultsPath = nil;
  NSString *userPath = nil;

  if ([userName length] == 0)
    {
      userName = NSUserName();
    }
  InitialisePathUtilities();
  if ([userName isEqual: NSUserName()])
    {
      home = gnustepUserRoot;
      defaultsPath = gnustepDefaultsPath;
    }
  else
    {
      home = setUserGNUstepPath(userName, &defaultsPath, &userPath);
    }

  if ([defaultsPath isAbsolutePath])
    {
      home = defaultsPath;
    }
  else if (home != nil)
    {
      home = [home stringByAppendingPathComponent: defaultsPath];
    }

  return home;
}

/**
 * Returns the standard paths in which applications are stored and
 * should be searched for.  Calls NSSearchPathForDirectoriesInDomains()<br/ >
 * Refer to the GNUstep File System Heirarchy documentation for more info.
 */
NSArray *
NSStandardApplicationPaths(void)
{
  return NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory,
                                             NSAllDomainsMask, YES);
}

/**
 * Returns the standard paths in which resources are stored and
 * should be searched for.  Calls NSSearchPathForDirectoriesInDomains()<br/ >
 * Refer to the GNUstep File System Heirarchy documentation for more info.
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
 * <br />
 * If a suitable directory can't be found or created, this function raises an
 * NSGenericException.
 */
NSString *
NSTemporaryDirectory(void)
{
  NSFileManager	*manager;
  NSString	*tempDirName;
  NSString	*baseTempDirName = nil;
  NSDictionary	*attr;
  int		perm;
  int		owner;
  BOOL		flag;
#if	!defined(__WIN32__)
  int		uid;
#else
  char buffer[1024];

  if (GetTempPath(1024, buffer))
    {
      baseTempDirName = [NSString stringWithCString: buffer];
    }
#endif

  /*
   * If the user has supplied a directory name in the TEMP or TMP
   * environment variable, attempt to use that unless we already
   * have a temporary directory specified.
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
#if	defined(__MINGW32__)
#ifdef  __CYGWIN__
	      baseTempDirName = @"/cygdrive/c/";
#else
	      baseTempDirName = @"/c/";
#endif
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
      [NSException raise: NSGenericException
		  format: @"Temporary directory (%@) does not exist",
			  tempDirName];
      return nil; /* Not reached. */
    }

  /*
   * Check that we are the directory owner, and that we, and nobody else,
   * have access to it. If other people have access, try to create a secure
   * subdirectory.
   */
  attr = [manager fileAttributesAtPath: tempDirName traverseLink: YES];
  owner = [[attr objectForKey: NSFileOwnerAccountID] intValue];
  perm = [[attr objectForKey: NSFilePosixPermissions] intValue];
  perm = perm & 0777;

// Mateu Batle: secure temporary directories don't work in MinGW
#ifndef __MINGW32__

#if	defined(__MINGW32__)
  uid = owner;
#else
#ifdef HAVE_GETEUID
  uid = geteuid();
#else
  uid = getuid();
#endif /* HAVE_GETEUID */
#endif
  if ((perm != 0700 && perm != 0600) || owner != uid)
    {
      NSString	*secure;

      /*
       * The name of the secure subdirectory reflects the user ID rather
       * than the user name, since it is possible to have an account with
       * lots of names on a unix system (ie multiple entries in the password
       * file but a single userid).  The private directory is secure within
       * the account, not to a particular user name.
       */
      secure = [NSString stringWithFormat: @"GNUstepSecure%d", uid];
      tempDirName
	= [baseTempDirName stringByAppendingPathComponent: secure];
      /*
      NSLog(@"Temporary directory (%@) may be insecure ... attempting to "
	@"add secure subdirectory", tempDirName);
      */
      if ([manager fileExistsAtPath: tempDirName] == NO)
	{
	  NSNumber	*p = [NSNumber numberWithInt: 0700];

	  attr = [NSDictionary dictionaryWithObject: p
					     forKey: NSFilePosixPermissions];
	  if ([manager createDirectoryAtPath: tempDirName
				  attributes: attr] == NO)
	    {
	      [NSException raise: NSGenericException
			  format:
		@"Attempt to create a secure temporary directory (%@) failed.",
				  tempDirName];
	      return nil; /* Not reached. */
	    }
	}

      /*
       * Check that the new directory is really secure.
       */
      attr = [manager fileAttributesAtPath: tempDirName traverseLink: YES];
      owner = [[attr objectForKey: NSFileOwnerAccountID] intValue];
      perm = [[attr objectForKey: NSFilePosixPermissions] intValue];
      perm = perm & 0777;
      if ((perm != 0700 && perm != 0600) || owner != uid)
	{
	  [NSException raise: NSGenericException
		      format:
	    @"Attempt to create a secure temporary directory (%@) failed.",
			      tempDirName];
	  return nil; /* Not reached. */
	}
    }
#endif

  if ([manager isWritableFileAtPath: tempDirName] == NO)
    {
      [NSException raise: NSGenericException
		  format: @"Temporary directory (%@) is not writable",
			  tempDirName];
      return nil; /* Not reached. */
    }
  return tempDirName;
}

/**
 * Deprecated function. Returns the location of the <em>root</em>
 * directory of the GNUstep file heirarchy.  Don't assume that /System,
 * /Network etc exist in this path! Use other path utility functions for that.
 * Refer to the GNUstep File System Heirarchy documentation for more info.
 */
NSString *
NSOpenStepRootDirectory(void)
{
  NSString	*root;

  root = [[[NSProcessInfo processInfo] environment]
    objectForKey: @"GNUSTEP_ROOT"];
  if (root == nil)
    {
#if	defined(__MINGW32__)
#ifdef  __CYGWIN__
      root = @"/cygdrive/c/";
#else
      root = @"~c/";
#endif
#else
      root = @"/";
#endif
    }
  return root;
}

/**
 * Returns an array of search paths to look at for resources.<br/ >
 * The paths are returned in domain order: USER, LOCAL, NETWORK then SYSTEM.
 */
NSArray *
NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directoryKey,
  NSSearchPathDomainMask domainMask, BOOL expandTilde)
{
  static NSString *adminDir   = @"Administrator";
  static NSString *appsDir    = @"Applications";
  static NSString *devDir     = @"Developer";
  static NSString *demosDir     =   @"Demos";
  static NSString *libraryDir = @"Library";
  static NSString *supportDir   =   @"ApplicationSupport";
  static NSString *docDir       =   @"Documentation";
  static NSString *fontsDir     =   @"Fonts";
  static NSString *frameworkDir =   @"Frameworks";
  static NSString *libsDir      =   @"Libraries";
  static NSString *toolsDir = @"Tools";
  NSMutableArray  *paths = [NSMutableArray new];
  NSString        *path;
  unsigned        i;
  unsigned        count;

  InitialisePathUtilities();

  NSCAssert(gnustepSystemRoot!=nil,@"Path utilities without initialisation!");

  /*
   * The order in which we return paths is important - user must come
   * first, followed by local, followed by network, followed by system.
   * The calling code can then loop on the returned paths, and stop as
   * soon as it finds something.  So things in user automatically
   * override things in system etc.
   */

#define ADD_PATH(mask, base_dir, add_dir) \
if (domainMask & mask) \
{ \
  path = [base_dir stringByAppendingPathComponent: add_dir]; \
  if (path != nil && [paths containsObject: path] == NO) \
    [paths addObject: path]; \
}
#ifdef OPTION_PLATFORM_SUPPORT
#define ADD_PLATFORM_PATH(mask, add_dir) \
if (domainMask & mask) \
{ \
  if (add_dir != nil && [paths containsObject: add_dir] == NO) \
    [paths addObject: add_dir]; \
}
#else
#define ADD_PLATFORM_PATH(mask, add_dir)
#endif /* OPTION_PLATFORM_SUPPORT */

  switch (directoryKey)
    {
      case NSAllApplicationsDirectory:
	{
	  NSString *devDemosDir;
	  NSString *devAppsDir;
	  NSString *devAdminDir;

	  devDemosDir = [devDir stringByAppendingPathComponent: demosDir];
	  devAppsDir = [devDir stringByAppendingPathComponent: appsDir];
	  devAdminDir = [devDir stringByAppendingPathComponent: adminDir];

	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, appsDir);
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, devAppsDir);

	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, appsDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, devAppsDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, devAdminDir);

	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, appsDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, devAppsDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, devAdminDir);

	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, appsDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devAppsDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devAdminDir);

	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devDemosDir);

	  ADD_PLATFORM_PATH(NSLocalDomainMask, localApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysAdmin);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformAdmin);
	}
	break;

      case NSApplicationDirectory:
	{
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, appsDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, appsDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, appsDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, appsDir);

	  ADD_PLATFORM_PATH(NSLocalDomainMask, localApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysApps);
	}
	break;

      case NSDemoApplicationDirectory:
	{
	  NSString *devDemosDir;

	  devDemosDir = [devDir stringByAppendingPathComponent: demosDir];
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devDemosDir);
	}
	break;

      case NSDeveloperApplicationDirectory:
	{
	  NSString *devAppsDir;

	  devAppsDir = [devDir stringByAppendingPathComponent: appsDir];
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, devAppsDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, devAppsDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, devAppsDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devAppsDir);
	}
	break;

      case NSAdminApplicationDirectory:
	{
	  NSString *devAdminDir;

	  devAdminDir = [devDir stringByAppendingPathComponent: adminDir];
	  /* NSUserDomainMask - users have no Administrator directory */
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, devAdminDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, devAdminDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devAdminDir);

	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysAdmin);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformAdmin);
	}
	break;

      case NSAllLibrariesDirectory:
	{
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, libraryDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, libraryDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, libraryDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, libraryDir);

	  ADD_PLATFORM_PATH(NSLocalDomainMask,  localResources);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformResources);
	}
	break;

      case NSLibraryDirectory:
	{
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, libraryDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, libraryDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, libraryDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, libraryDir);

	  ADD_PLATFORM_PATH(NSLocalDomainMask,  localResources);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformResources);
	}
	break;

      case NSDeveloperDirectory:
	{
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, devDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, devDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, devDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, devDir);
	}
	break;

      case NSUserDirectory:
	{
	  if (domainMask & NSUserDomainMask)
	    {
	      [paths addObject: gnustepUserRoot];
	    }
	}
	break;

      case NSDocumentationDirectory:
	{
	  NSString *gsdocDir;

	  gsdocDir = [libraryDir stringByAppendingPathComponent: docDir];
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, gsdocDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, gsdocDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, gsdocDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, gsdocDir);
	}
	break;

      /* Now the GNUstep additions */
      case GSApplicationSupportDirectory:
	{
	  NSString *appSupDir;

	  appSupDir = [libraryDir stringByAppendingPathComponent: supportDir];
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, appSupDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, appSupDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, appSupDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, appSupDir);
	}
	break;

      case GSFrameworksDirectory:
	{
	  NSString *frameDir;

	  frameDir = [libraryDir stringByAppendingPathComponent: frameworkDir];
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, frameDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, frameDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, frameDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, frameDir);
	}
	break;

      case GSFontsDirectory:
	{
	  NSString *fontDir;

	  fontDir = [libraryDir stringByAppendingPathComponent: fontsDir];
	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, fontDir);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, fontDir);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, fontDir);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, fontDir);
	}
	break;

      case GSLibrariesDirectory:
	{
	  NSString *gslibsDir;
	  NSString *full = nil;
	  NSString *part = nil;

	  gslibsDir = [libraryDir stringByAppendingPathComponent: libsDir];
	  if ([gnustep_flattened boolValue] == NO
	    && gnustep_target_cpu != nil && gnustep_target_os != nil)
	    {
	      part = [gnustep_target_cpu stringByAppendingPathComponent:
		gnustep_target_os];
	      if (library_combo != nil)
		{
		  full = [part stringByAppendingPathComponent: library_combo];
		  full = [gslibsDir stringByAppendingPathComponent: full];
		}
	      part = [gslibsDir stringByAppendingPathComponent: part];
	    }

	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, gslibsDir);
	  if (full) ADD_PATH(NSUserDomainMask, gnustepUserRoot, full);
	  if (part) ADD_PATH(NSUserDomainMask, gnustepUserRoot, part);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, gslibsDir);
	  if (full) ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, full);
	  if (part) ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, part);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, gslibsDir);
	  if (full) ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, full);
	  if (part) ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, part);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, gslibsDir);
	  if (full) ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, full);
	  if (part) ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, part);

	  ADD_PLATFORM_PATH(NSLocalDomainMask, localLibs);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformLibs);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysLibs);
	}
	break;

      case GSToolsDirectory:
	{
	  NSString	*full = nil;
	  NSString	*part = nil;

	  if ([gnustep_flattened boolValue] == NO
	    && gnustep_target_cpu != nil && gnustep_target_os != nil)
	    {
	      part = [gnustep_target_cpu stringByAppendingPathComponent:
		gnustep_target_os];
	      if (library_combo != nil)
		{
		  full = [part stringByAppendingPathComponent: library_combo];
		  full = [toolsDir stringByAppendingPathComponent: full];
		}
	      part = [toolsDir stringByAppendingPathComponent: part];
	    }

	  ADD_PATH(NSUserDomainMask, gnustepUserRoot, toolsDir);
	  if (full) ADD_PATH(NSUserDomainMask, gnustepUserRoot, full);
	  if (part) ADD_PATH(NSUserDomainMask, gnustepUserRoot, part);
	  ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, toolsDir);
	  if (full) ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, full);
	  if (part) ADD_PATH(NSLocalDomainMask, gnustepLocalRoot, part);
	  ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, toolsDir);
	  if (full) ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, full);
	  if (part) ADD_PATH(NSNetworkDomainMask, gnustepNetworkRoot, part);
	  ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, toolsDir);
	  if (full) ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, full);
	  if (part) ADD_PATH(NSSystemDomainMask, gnustepSystemRoot, part);

	  ADD_PLATFORM_PATH(NSLocalDomainMask, localApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysApps);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, platformAdmin);
	  ADD_PLATFORM_PATH(NSSystemDomainMask, osSysAdmin);
	}
	break;

      case GSPreferencesDirectory:
	{
	  // Not used
	}
	break;
    }

#undef ADD_PATH
#undef ADD_PLATFORM_PATH

  count = [paths count];
  for (i = 0; i < count; i++)
    {
      path = [paths objectAtIndex: i];

      /* remove paths which don't exist on this system */
      if ([MGR() fileExistsAtPath: path] == NO)
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
