/* Implementation of filesystem & path-related functions for GNUstep
   Copyright (C) 1996-2004 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <address@hidden>
   Created: May 1996
   Rewrite by:  Sheldon Gill
   Date:    Jan 2004

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
   On windows, the paths are initialised by reading information from the
   windows registry.
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
//#define OPTION_COMPILED_PATHS    // Only use compile time path information
//#define OPTION_NO_ENVIRONMENT    // Don't use environment vars for path info

#define lowlevelstringify(X) #X
#define stringify(X) lowlevelstringify(X)

/* The global configuration file. The real value is read from config.h */
#ifndef GNUSTEP_CONFIGURATION_FILE
#define   GNUSTEP_CONFIGURATION_FILE  /etc/GNUstep/GNUstep.conf
#endif
/* The name of the user-specific configuration file */
#define   DEFAULT_STEPRC_FILE         @".GNUsteprc"
/* The standard path for user Defaults files */
#define   DEFAULT_DEFAULTS_PATH       @"Defaults"
/* The standard path to user GNUstep resources */
#define   DEFAULT_USER_ROOT           @"GNUstep"

/* ------------------ */
/* Internal variables */
/* ------------------ */
static NSFileManager	*file_mgr = 0;

/* names for the environment or conf-file variables */
//static NSString *USER_ROOT    = @"GNUSTEP_USER_ROOT";
static NSString *LOCAL_ROOT   = @"GNUSTEP_LOCAL_ROOT";
static NSString *NETWORK_ROOT = @"GNUSTEP_NETWORK_ROOT";
static NSString *SYSTEM_ROOT  = @"GNUSTEP_SYSTEM_ROOT";

#ifdef OPTION_COMPILED_PATHS
static NSString *gnustep_user_root    = nil;
static NSString *gnustep_local_root   = GNUSTEP_LOCAL_ROOT;
static NSString *gnustep_network_root = GNUSTEP_NETWORK_ROOT;
static NSString *gnustep_system_root  = GNUSTEP_INSTALL_PREFIX;

static NSString *gnustep_rc_filename  = nil;
static NSString *gnustep_defaultspath = DEFAULT_STEPRC_FILE;
static NSString *gnustep_userpath     = DEFAULT_USER_ROOT;
#else
/* We read these four paths only once */
static NSString *gnustep_user_root = nil;        /*    GNUSTEP_USER_ROOT path */
static NSString *gnustep_local_root = nil;       /*   GNUSTEP_LOCAL_ROOT path */
static NSString *gnustep_network_root = nil;     /* GNUSTEP_NETWORK_ROOT path */
static NSString *gnustep_system_root = nil;      /*  GNUSTEP_SYSTEM_ROOT path */

static NSString *gnustep_rc_filename = nil;           /* .GNUsteprc file name */
static NSString *gnustep_defaultspath = nil;          /* Defaults dir in home */
static NSString *gnustep_userpath = nil;              /* dir in home for user */

#endif /* OPTION_COMPILED_PATHS else */

static NSString *theUserName = nil;             /*      The user's login name */
static NSString *tempDir = nil;                 /* user's temporary directory */

#ifdef OPTION_PLATFORM_SUPPORT
static NSString *os_sys_prefs = nil;
static NSString *os_sys_apps  = nil;
static NSString *os_sys_libs  = nil;
static NSString *os_sys_admin = nil;

static NSString *platform_resources = nil;
static NSString *platform_apps  = nil;
static NSString *platform_libs  = nil;
static NSString *platform_admin = nil;

static NSString *local_resources = nil;
static NSString *local_apps  = nil;
static NSString *local_libs  = nil;

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
static NSString* internalise_path(NSString *s);
static NSString* internalise_path_Cstring(const char *c);

static void set_file_mgr(void);
static NSString *set_user_gnustep_path(NSString *userName,
				       NSString **defaultspath,
				       NSString **userpath);

static NSDictionary *GSReadStepConfFile(NSString *name);

void InitialisePathUtilities(void);
void ShutdownPathUtilities(void);
/* ============================= */

/* make sure that the path 'path' is in internal format (unix-style) */
static inline NSString*
internalise_path_Cstring(const char *path)
{
  unsigned int  len;

  if (file_mgr == nil)
    set_file_mgr();
  NSCAssert(file_mgr != nil, @"No file manager!\n");

  if (path == 0)
    {
      return nil;
    }

  len = strlen(path);
  return [file_mgr stringWithFileSystemRepresentation: path length: len];
}

/* make sure that the path 's' is in internal format (unix-style) */
static inline NSString*
internalise_path(NSString *s)
{
  const char    *ptr;
  unsigned int  len;

  if (file_mgr == nil)
    set_file_mgr();
  NSCAssert(file_mgr != nil, @"No file manager!\n");

  if (s == nil)
    {
      return nil;
    }

  ptr = [s cString];
  len = strlen(ptr);
  return [file_mgr stringWithFileSystemRepresentation: ptr length: len];
}

/* Convenience MACRO to ease legibility and coding */
/* Conditionally assign lval to var */
#define test_assign(var, lval)     \
  if ((var == nil)&&(lval != nil))  \
    {                               \
      var = lval;                   \
    }

/* Get a path string from a dictionary */
static inline NSString *
get_pathconfig(NSDictionary *dict, NSString *key)
{
  NSString *path;

  NSCParameterAssert(dict!=nil);

  path = [dict objectForKey: key];
  if (path != nil)
    {
      path = internalise_path(path);
    }
  TEST_RETAIN(path);

  return path;
}

/*
 * Set up the file_mgr global. May be called by InitialisePathUtilities
 * or by NSUserDirectory depending on what function is called first.
 */
static void set_file_mgr(void)
{
  /* Set our file manager (and keep it around) */
  file_mgr = [NSFileManager defaultManager];
  if (file_mgr == nil)
    {
      [NSException raise: NSInternalInconsistencyException
                  format: @"Unable to create default file manager!"];
    }
  RETAIN(file_mgr);
}

static NSString *
remove_tilde (NSString *home, NSString *val)
{
  if ([val isEqual: @"~"])
    {
      val = @"";
    }
  else if ([val length] > 1 && [val characterAtIndex: 0] == '~')
    {
      val = [val substringFromIndex: 2];
    }
  return val;
}

/*
 * Read .GNUsteprc file for user and set paths accordingly
 */
static NSString *set_user_gnustep_path(NSString *userName,
				       NSString **defaultspath,
				       NSString **userpath)
{
  NSDictionary *dict, *attributes;
  NSString     *home, *path;
  NSString     *steprc_file;
  NSString     *user_root;

  NSCAssert(file_mgr != nil, @"No file manager\n");

  /* Look for rc file (".GNUsteprc") file in user's home directory */
  home = NSHomeDirectoryForUser(userName);
  if (home == nil)
    {
      /* It's OK if path is nil. We're might be running as user nobody in
         which case we don't want to access user stuff. Possibly it's a
         misconfigured Windows environment, though... */
      return nil;
    }
  steprc_file = [home stringByAppendingPathComponent: gnustep_rc_filename];

  if ([file_mgr isReadableFileAtPath: steprc_file])
    {
      dict = GSReadStepConfFile(steprc_file);
      if (dict != nil)
        {
          path = [dict objectForKey: @"GNUSTEP_DEFAULTS_ROOT"];
          if (path != nil)
            {
	      path = remove_tilde(home, path);
              test_assign(*defaultspath, path);
            }
          path = [dict objectForKey: @"GNUSTEP_USER_ROOT"];
          if (path != nil)
            {
	      path = remove_tilde(home, path);
              test_assign(*userpath, path);
            }
        }
      [dict release];
    }

  /* Look at the .GNUsteprc file in GNUSTEP_SYSTEM_ROOT.  This is obsolete
     now that we are using the GNUstep conf file, but is kept in for
     transition purposes.
  */
  steprc_file = [gnustep_system_root stringByAppendingPathComponent: @".GNUsteprc"];
  attributes = [file_mgr fileAttributesAtPath: steprc_file traverseLink: YES];
  if (([attributes filePosixPermissions] & 022) != 0)
    {
      fprintf(stderr, "The file '%s' is writable by someone other than"
	" its owner.\nIgnoring it.\n", [steprc_file fileSystemRepresentation]);
    }
  else if ([file_mgr isReadableFileAtPath: steprc_file] == YES)
    {
      BOOL	forceD = NO;
      BOOL	forceU = NO;
      fprintf(stderr, "Warning: Configuration: The file %s has been deprecated. Please use the \nconfiguration file %s to set standard paths.\n",
	      [steprc_file fileSystemRepresentation],
	      stringify(GNUSTEP_CONFIGURATION_FILE));
      dict = GSReadStepConfFile(steprc_file);
      if (dict != nil)
        {
	  forceD = [[dict objectForKey: @"FORCE_DEFAULTS_ROOT"]
	  		isEqualToString: @"YES"];
	  forceU = [[dict objectForKey: @"FORCE_USER_ROOT"]
	  		isEqualToString: @"YES"];
          path = [dict objectForKey: @"GNUSTEP_DEFAULTS_ROOT"];
          if (path != nil)
            {
	      path = remove_tilde(home, path);
	      if (forceD)
		*defaultspath = path;
	      else
		test_assign(*defaultspath, path);
            }
          path     = [dict objectForKey: @"GNUSTEP_USER_ROOT"];
          if (path != nil)
            {
	      path = remove_tilde(home, path);
	      if (forceU)
		*userpath = path;
	      else
		test_assign(*userpath, path);
            }
        }
    }

  /* set the user path and defaults directory to default values if needed */
  test_assign(*defaultspath, DEFAULT_DEFAULTS_PATH);
  test_assign(*userpath, DEFAULT_USER_ROOT);

  /* Now we set the user's root path for the gnustep files. Note that the
  GNUsteprc files have the convention of specifying the defaults as an absolute
  path. This differs from the config file defaults. Ugh.   */
  if ([*userpath isAbsolutePath])
    user_root = *userpath;
  else
    user_root = [home stringByAppendingPathComponent: *userpath];
  return user_root;
}

/* Initialise all things required by this module */
void InitialisePathUtilities(void)
{
  NSDictionary  *env;
  NSDictionary  *dict = nil;

  /* Set up our root paths */
  NS_DURING
    {
#if defined(__WIN32__)
      HKEY regkey;
#else
      NSString *config_file;
#endif
      /* Set the file manager */
      if (file_mgr == nil)
        set_file_mgr();

      /* Initialise Win32 things if on that platform */
      Win32Initialise();   // should be called by DLL_PROCESS_ATTACH

      [gnustep_global_lock lock];

#ifndef OPTION_NO_ENVIRONMENT
      /* First we look at the environment */
      env = [[NSProcessInfo processInfo] environment];

      test_assign(gnustep_system_root , [env objectForKey: SYSTEM_ROOT]);
      test_assign(gnustep_network_root, [env objectForKey: NETWORK_ROOT]);
      test_assign(gnustep_local_root  , [env objectForKey: LOCAL_ROOT]);
#endif /* !OPTION_NO_ENVIRONMENT */
#if defined(__WIN32__)
      regkey = Win32OpenRegistry(HKEY_LOCAL_MACHINE,
				 "\\Software\\GNU\\GNUstep");
      if (regkey != (HKEY)NULL)
        {
          test_assign(gnustep_system_root,
		      Win32NSStringFromRegistry(regkey, SYSTEM_ROOT));
          test_assign(gnustep_network_root,
		      Win32NSStringFromRegistry(regkey, NETWORK_ROOT));
          test_assign(gnustep_local_root,
		      Win32NSStringFromRegistry(regkey, LOCAL_ROOT));
          RegCloseKey(regkey);
        }

#if 0
      // Not implemented yet
      platform_apps   = Win32FindDirectory(CLSID_APPS);
      platform_libs   = Win32FindDirectory(CLSID_LIBS);
#endif
#else
      /* Now we source the configuration file if it exists */
      config_file = [NSString stringWithCString: stringify(GNUSTEP_CONFIGURATION_FILE)];
      if ([file_mgr fileExistsAtPath: config_file])
        {
          dict = GSReadStepConfFile(config_file);
        }
      if (dict != nil)
        {
          test_assign(gnustep_system_root , [dict objectForKey: SYSTEM_ROOT]);
          test_assign(gnustep_network_root, [dict objectForKey: NETWORK_ROOT]);
          test_assign(gnustep_local_root  , [dict objectForKey: LOCAL_ROOT]);

          gnustep_rc_filename  = [dict objectForKey: @"USER_GNUSTEP_RC"];
          gnustep_defaultspath = [dict objectForKey: @"USER_GNUSTEP_DEFAULTS"];
          gnustep_userpath = [dict objectForKey: @"USER_GNUSTEP_DIR"];

#ifdef OPTION_PLATFORM_SUPPORT
          os_sys_prefs = get_pathconfig(dict, SYS_PREFS);
          os_sys_apps  = get_pathconfig(dict, SYS_APPS);
          os_sys_libs  = get_pathconfig(dict, SYS_LIBS);
          os_sys_admin = get_pathconfig(dict, SYS_ADMIN);

          platform_resources = get_pathconfig(dict, PLATFORM_RESOURCES);
          platform_apps      = get_pathconfig(dict, PLATFORM_APPS);
          platform_libs      = get_pathconfig(dict, PLATFORM_LIBS);
          platform_admin     = get_pathconfig(dict, PLATFORM_ADMIN);

          local_resources = get_pathconfig(dict, PLATFORM_LOCAL_RESOURCES);
          local_apps      = get_pathconfig(dict, PLATFORM_LOCAL_APPS);
          local_libs      = get_pathconfig(dict, PLATFORM_LOCAL_LIBS);
#endif /* OPTION_PLATFORM SUPPORT */

          [dict release];
        }
#endif /* defined(__WIN32__) else */

      /* Omitting the following line would mean system admins could force
         the user and defaults paths by leaving USER_GNUSTEP_RC blank. */
      test_assign(gnustep_rc_filename,  DEFAULT_STEPRC_FILE);

      /* If the user has an rc file we need to source it */
      gnustep_user_root = set_user_gnustep_path(NSUserName(),
						&gnustep_defaultspath,
						&gnustep_userpath);

      /* Make sure that they're in path internal format */
      internalise_path(gnustep_system_root);
      internalise_path(gnustep_network_root);
      internalise_path(gnustep_local_root);
      internalise_path(gnustep_user_root);

      /* Finally we check and report problems... */
      if (gnustep_system_root == nil)
        {
          gnustep_system_root = internalise_path_Cstring(\
                                  STRINGIFY(GNUSTEP_INSTALL_PREFIX));
          fprintf (stderr, "Warning - GNUSTEP_SYSTEM_ROOT is not set " \
                    "- using %s\n", [gnustep_system_root lossyCString]);
        }
      if (gnustep_network_root == nil)
        {
          gnustep_network_root = internalise_path_Cstring(\
                                  STRINGIFY(GNUSTEP_NETWORK_ROOT));
          fprintf (stderr, "Warning - GNUSTEP_NETWORK_ROOT is not set " \
                    "- using %s\n", [gnustep_network_root lossyCString]);
        }
      if (gnustep_local_root == nil)
        {
          gnustep_local_root = internalise_path_Cstring(\
                                  STRINGIFY(GNUSTEP_LOCAL_ROOT));
          fprintf (stderr, "Warning - GNUSTEP_LOCAL_ROOT is not set " \
                    "- using %s\n", [gnustep_local_root lossyCString]);
        }

      /* We're keeping these strings... */
      TEST_RETAIN(gnustep_system_root);
      TEST_RETAIN(gnustep_network_root);
      TEST_RETAIN(gnustep_local_root);
      TEST_RETAIN(gnustep_user_root);

      TEST_RETAIN(gnustep_rc_filename);
      TEST_RETAIN(gnustep_defaultspath);
      TEST_RETAIN(gnustep_userpath);

      [gnustep_global_lock unlock];
    }
  NS_HANDLER
    {
      if (dict != nil)
        [dict release];

      /* unlock then re-raise the exception */
      [gnustep_global_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

/*
 * Close down and release all things allocated.
 */
void ShutdownPathUtilities(void)
{
  TEST_RELEASE(gnustep_system_root);
  TEST_RELEASE(gnustep_network_root);
  TEST_RELEASE(gnustep_local_root);
  TEST_RELEASE(gnustep_user_root);

  TEST_RELEASE(gnustep_rc_filename);
  TEST_RELEASE(gnustep_defaultspath);
  TEST_RELEASE(gnustep_userpath);

#ifdef OPTION_PLATFORM_SUPPORT
  TEST_RELEASE(os_sys_prefs);
  TEST_RELEASE(os_sys_apps);
  TEST_RELEASE(os_sys_libs);
  TEST_RELEASE(os_sys_admin);

  TEST_RELEASE(platform_resources);
  TEST_RELEASE(platform_apps);
  TEST_RELEASE(platform_libs);
  TEST_RELEASE(platform_admin);

  TEST_RELEASE(local_resources);
  TEST_RELEASE(local_apps);
  TEST_RELEASE(local_libs);
#endif /* OPTION_PLATFORM SUPPORT */

  TEST_RELEASE(tempDir);
  RELEASE(file_mgr);

  /* Shutdown Win32 support */
  Win32Finalise();
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<GNUstep specific>-
---------+---------+---------+---------+---------+---------+---------+------- */

/**
 * Reads a file and expects it to be in basic unix "conf" style format with
 * one key = value per line. Sometimes referred to as "strings" format.<br/ >
 * Creates a dictionary of the (key,value) pairs.<br/ >
 * Lines beginning with a hash '#' are deemed comment lines and ignored.<br/ >
 * The value is all characters from the first non-whitespace after the '='
 * until the end of line '\n' which will include any internal spaces.<br/ >
 * NB. This is <em>VERY</em> non-standard in that it returns an object which is
 * <em>NOT</em> autoreleased.
 */
static NSDictionary *
GSReadStepConfFile(NSString *fileName)
{
  NSMutableDictionary *dict;
  NSString      *file;
  NSArray       *lines;
  unsigned      count;

  dict = [NSMutableDictionary new];
  if (dict == nil)
    {
      return nil; // should throw an exception??
    }

  file = [NSString stringWithContentsOfFile: fileName];
  lines = [file componentsSeparatedByString: @"\n"];
  count = [lines count];

  while (count-- > 0)
    {
      NSRange	r;
      NSString	*line;
      NSString	*key;
      NSString	*val;

      line = [[lines objectAtIndex: count] stringByTrimmingSpaces];

      if (([line length]) && ([line characterAtIndex: 0] != '#'))
        {
          r = [line rangeOfString: @"="];
          if (r.length == 1)
            {
              key = [line substringToIndex: r.location];
              val = [line substringFromIndex: NSMaxRange(r)];

              key = [key stringByTrimmingSpaces];
              val = [val stringByTrimmingSpaces];

              if ([key length] > 0)
                [dict setObject: val forKey: key];
            }
          else
            {
              key = [line stringByTrimmingSpaces];
              val = nil;
            }
        }
    }
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

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<User name and path>-
---------+---------+---------+---------+---------+---------+---------+------- */

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
#if !defined(__MINGW__)
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
  s = internalise_path(s);
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

/** Returns a string containing the path to the GNUstep system
    installation directory. This function is guarenteed to return a non-nil
    answer (unless something is seriously wrong, in which case the application
    will probably crash anyway) */
NSString *
GSSystemRootDirectory(void)
{
  GSOnceFLog(@"Deprecated function");
  if (gnustep_system_root == nil)
    {
      InitialisePathUtilities();
    }
  return gnustep_system_root;
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
  NSString *defaultspath = nil;
  NSString *userpath = nil;

  NSCParameterAssert([userName length] > 0);

  if (gnustep_system_root == nil)
    InitialisePathUtilities();

  if ([userName isEqual: NSUserName()])
    {
      home = gnustep_user_root;
      defaultspath = gnustep_defaultspath;
    }
  else
    {
      home = set_user_gnustep_path(userName, &defaultspath, &userpath);
    }

  if ([defaultspath isAbsolutePath])
    {
      home = defaultspath;
    }
  else if (home != nil)
    {
      home = [home stringByAppendingPathComponent: defaultspath];
    }

  return internalise_path(home);
}

/* ------+---------+---------+---------+---------+---------+---------+---------+
#pragma mark -
#pragma mark -<Path discovery>-
---------+---------+---------+---------+---------+---------+---------+------- */

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

  GSOnceFLog(@"Deprecated function");
  env = [[NSProcessInfo processInfo] environment];
  prefixes = [env objectForKey: @"GNUSTEP_PATHPREFIX_LIST"];
  if (prefixes != nil)
    {
      unsigned	c;

#if	defined(__WIN32__)
      prefixArray = [prefixes componentsSeparatedByString: @";"];
#else
      prefixArray = [prefixes componentsSeparatedByString: @":"];
#endif
      if ((c = [prefixArray count]) <= 1)
	{
	  /* This probably means there was some parsing error, but who
	     knows. Play it safe though... */
	  prefixArray = nil;
	}
      else
	{
	  NSString	*a[c];
	  unsigned	i;

	  [prefixArray getObjects: a];
	  for (i = 0; i < c; i++)
	    {
	      a[c] = internalise_path(a[c]);
	    }
	  prefixArray = [NSArray arrayWithObjects: a count: c];
	}
    }
  if (prefixes == nil)
    {
      NSString	*strings[4];
      NSString	*str;
      unsigned	count = 0;

      if (gnustep_system_root == nil)
	{
	  InitialisePathUtilities();
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
      baseTempDirName = internalise_path_Cstring(buffer);
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
#if	defined(__MINGW__)
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
#ifndef __MINGW__

#if	defined(__MINGW__)
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
	      [NSException raise: NSGenericException
			  format: @"Attempt to create a secure temporary directory (%@) failed.",
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
		      format: @"Attempt to create a secure temporary directory (%@) failed.",
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
#if	defined(__MINGW__)
#ifdef  __CYGWIN__
      root = @"/cygdrive/c/";
#else
      root = @"~c/";
#endif
#else
      root = @"/";
#endif
    }
  else
    {
      root = internalise_path(root);
    }
  return root;
}

/**
 * Returns an array of search paths to look at for resources.<br/ >
 * The paths are returned in domain order: LOCAL, NETWORK then SYSTEM.
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

  if (gnustep_system_root == nil)
      InitialisePathUtilities();

  NSCAssert(gnustep_system_root!=nil,@"Path utilities without initialisation!");
  NSCAssert(file_mgr != nil,@"Path utilities without file manager!");

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
   * SHELDON: Have a fix pending...
   */

#define ADD_PATH(mask, base_dir, add_dir) \
if (domainMask & mask) \
{ \
  path = [base_dir stringByAppendingPathComponent: add_dir]; \
  if (path != nil) \
    [paths addObject: path]; \
}
#ifdef OPTION_PLATFORM_SUPPORT
#define ADD_PLATFORM_PATH(mask, add_dir) \
if (domainMask & mask) \
{ \
  if (add_dir != nil) \
    [paths addObject: add_dir]; \
}
#else
#define ADD_PLATFORM_PATH(mask, add_dir)
#endif /* OPTION_PLATFORM_SUPPORT */

  if (directoryKey == NSApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      ADD_PATH(NSUserDomainMask, gnustep_user_root, appsDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, appsDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, appsDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, appsDir);

      ADD_PLATFORM_PATH(NSLocalDomainMask, local_apps);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_apps);
      ADD_PLATFORM_PATH(NSSystemDomainMask, os_sys_apps);
    }
  if (directoryKey == NSDemoApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      NSString *devDemosDir = [devDir stringByAppendingPathComponent: demosDir];
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, devDemosDir);
    }
  if (directoryKey == NSDeveloperApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      NSString *devAppsDir = [devDir stringByAppendingPathComponent: appsDir];

      ADD_PATH(NSUserDomainMask, gnustep_user_root, devAppsDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, devAppsDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, devAppsDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, devAppsDir);
    }
  if (directoryKey == NSAdminApplicationDirectory
    || directoryKey == NSAllApplicationsDirectory)
    {
      NSString *devAdminDir;

      devAdminDir = [devDir stringByAppendingPathComponent: adminDir];
      /* NSUserDomainMask - users have no Administrator directory */
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, devAdminDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, devAdminDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, devAdminDir);

      ADD_PLATFORM_PATH(NSSystemDomainMask, os_sys_admin);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_admin);
    }
  if (directoryKey == NSLibraryDirectory
    || directoryKey == NSAllLibrariesDirectory)
    {
      ADD_PATH(NSUserDomainMask, gnustep_user_root, libraryDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, libraryDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, libraryDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, libraryDir);

      ADD_PLATFORM_PATH(NSLocalDomainMask,  local_resources);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_resources);
    }
  if (directoryKey == NSDeveloperDirectory)
    {
      ADD_PATH(NSUserDomainMask, gnustep_user_root, devDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, devDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, devDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, devDir);
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
      NSString *gsdocDir = [libraryDir stringByAppendingPathComponent: docDir];

      ADD_PATH(NSUserDomainMask, gnustep_user_root, gsdocDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, gsdocDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, gsdocDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, gsdocDir);
    }
  /* Now the GNUstep additions */
  if (directoryKey == GSApplicationSupportDirectory)
    {
      NSString *appSupDir;

      appSupDir = [libraryDir stringByAppendingPathComponent: supportDir];
      ADD_PATH(NSUserDomainMask, gnustep_user_root, appSupDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, appSupDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, appSupDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, appSupDir);
    }
  if (directoryKey == GSFrameworksDirectory)
    {
      NSString *frameDir;

      frameDir = [libraryDir stringByAppendingPathComponent: frameworkDir];
      ADD_PATH(NSUserDomainMask, gnustep_user_root, frameDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, frameDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, frameDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, frameDir);
    }
  if (directoryKey == GSFontsDirectory)
    {
      NSString *fontDir = [libraryDir stringByAppendingPathComponent: fontsDir];

      ADD_PATH(NSUserDomainMask, gnustep_user_root, fontDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, fontDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, fontDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, fontDir);
    }
  if (directoryKey == GSLibrariesDirectory)
    {
      NSString *gslibsDir;

      gslibsDir = [libraryDir stringByAppendingPathComponent: libsDir];
      ADD_PATH(NSUserDomainMask, gnustep_user_root, gslibsDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, gslibsDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, gslibsDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, gslibsDir);

      ADD_PLATFORM_PATH(NSLocalDomainMask, local_libs);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_libs);
      ADD_PLATFORM_PATH(NSSystemDomainMask, os_sys_libs);
    }
  if (directoryKey == GSToolsDirectory)
    {
      ADD_PATH(NSUserDomainMask, gnustep_user_root, toolsDir);
      ADD_PATH(NSLocalDomainMask, gnustep_local_root, toolsDir);
      ADD_PATH(NSNetworkDomainMask, gnustep_network_root, toolsDir);
      ADD_PATH(NSSystemDomainMask, gnustep_system_root, toolsDir);

      ADD_PLATFORM_PATH(NSLocalDomainMask, local_apps);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_apps);
      ADD_PLATFORM_PATH(NSSystemDomainMask, os_sys_apps);
      ADD_PLATFORM_PATH(NSSystemDomainMask, platform_admin);
      ADD_PLATFORM_PATH(NSSystemDomainMask, os_sys_admin);
    }

#undef ADD_PATH
#undef ADD_PLATFORM_PATH

  count = [paths count];
  for (i = 0; i < count; i++)
    {
      path = [paths objectAtIndex: i];

      /* remove paths which don't exist on this system */
      if ([file_mgr fileExistsAtPath: path] == NO)
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
