/** Implementation for NSUserDefaults for GNUstep
   Copyright (C) 1995-2001 Free Software Foundation, Inc.

   Written by:  Georg Tuparev <Tuparev@EMBL-Heidelberg.de>
   		EMBL & Academia Naturalis,
                Heidelberg, Germany
   Modified by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSUserDefaults class reference</title>
   $Date$ $Revision$
*/

#import "common.h"
#define	EXPOSE_NSUserDefaults_IVARS	1
#include <sys/stat.h>
#include <sys/types.h>

#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSArchiver.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSDistributedLock.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSPropertyList.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSLocale.h"
#import "GNUstepBase/GSLock.h"
#import "GNUstepBase/NSProcessInfo+GNUstepBase.h"
#import "GNUstepBase/NSString+GNUstepBase.h"

#if	defined(__MINGW__)
@class	NSUserDefaultsWin32;
#endif

#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif

#import "GSPrivate.h"

/* Wait for access */
#define _MAX_COUNT 5          /* Max 10 sec. */

/*************************************************************************
 *** Class variables
 *************************************************************************/
static SEL	nextObjectSel;
static SEL	objectForKeySel;
static SEL	addSel;

static Class	NSArrayClass;
static Class	NSDataClass;
static Class	NSDateClass;
static Class	NSDictionaryClass;
static Class	NSNumberClass;
static Class	NSMutableDictionaryClass;
static Class	NSStringClass;

static NSString		*GSPrimaryDomain = @"GSPrimaryDomain";
static NSString		*defaultsFile = @".GNUstepDefaults";

static NSUserDefaults	*sharedDefaults = nil;
static NSMutableString	*processName = nil;
static NSRecursiveLock	*classLock = nil;

/* Flag to say whether the sharedDefaults variable has been set up by a
 * call to the +standardUserDefaults method.  If this is YES but the variable
 * is nil then there was a problem initialising the shared object and we
 * have no defaults available.
 */
static BOOL		hasSharedDefaults = NO;
/*
 * Caching some defaults.
 */
static BOOL     parsingArguments = NO;
static BOOL	flags[GSUserDefaultMaxFlag] = { 0 };

/* An instance of the GSPersistentDomain class is used to encapsulate
 * a single persistent domain (represented as a property list file in
 * the defaults directory.
 * Instances are generally created without contents, and the contents
 * are lazily loaded from disk when the domain is needed (either because
 * it is in the defaults system search list, or because the method to
 * obtain a copy of the domain contents is called).
 */
@interface	GSPersistentDomain : NSObject
{
  NSString		*name;
  NSUserDefaults	*owner;
  NSDate		*updated;
@public
  BOOL			modified;
  NSMutableDictionary	*contents;
}
- (NSMutableDictionary*) contents;
- (id) initWithName: (NSString*)n
	      owner: (NSUserDefaults*)o;
- (NSString*) name;
- (void) setContents: (NSDictionary*)domain;
- (BOOL) synchronize;
- (NSDate*) updated;
@end

static NSString *
lockPath(NSString *defaultsDatabase, BOOL verbose)
{
  NSString	*path;
  NSFileManager	*mgr;
  unsigned	desired;
  NSDictionary	*attr;
  BOOL		isDir;

  /* We use a subdirectory (.lck) of the defaults directory in which to
   * create/destroy the distributed lock used to ensure that defaults
   * are not simultanously updated by multiple processes.
   * The use of a subdirectory means that locking/unlocking the distributed
   * lock will not change the timestamp on the defaults database directory
   * itsself, so we can use that date to see if any defaults files have
   * been added or removed.
   */
  path = defaultsDatabase;

  mgr = [NSFileManager defaultManager];
#if	!(defined(S_IRUSR) && defined(S_IWUSR) && defined(S_IXUSR) \
  && defined(S_IRGRP) && defined(S_IXGRP) \
  && defined(S_IROTH) && defined(S_IXOTH))
  desired = 0755;
#else
  desired = (S_IRUSR|S_IWUSR|S_IXUSR|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH);
#endif
  attr = [NSDictionary dictionaryWithObjectsAndKeys:
    NSUserName(), NSFileOwnerAccountName,
    [NSNumberClass numberWithUnsignedLong: desired], NSFilePosixPermissions,
    nil];

  if ([mgr fileExistsAtPath: path isDirectory: &isDir] == NO)
    {
      if ([mgr createDirectoryAtPath: path
         withIntermediateDirectories: YES
                          attributes: attr
                               error: NULL] == NO)
	{
	  if (verbose)
	    NSLog(@"Defaults path '%@' does not exist - failed to create it.",
	    path);
	  return nil;
	}
      else
	{
	  if (verbose)
	    NSLog(@"Defaults path '%@' did not exist - created it", path);
	  isDir = YES;
	}
    }
  if (isDir == NO)
    {
      if (verbose)
	NSLog(@"ERROR - Defaults path '%@' is not a directory!", path);
      return nil;
    }
  path = [path stringByAppendingPathComponent: @".lck"];
  if ([mgr fileExistsAtPath: path isDirectory: &isDir] == NO)
    {
      if ([mgr createDirectoryAtPath: path
         withIntermediateDirectories: YES
                          attributes: attr
                               error: NULL] == NO)
	{
	  if (verbose)
	    NSLog(@"Defaults path '%@' does not exist - failed to create it.",
	    path);
	  return nil;
	}
      else
	{
	  if (verbose)
	    NSLog(@"Defaults path '%@' did not exist - created it", path);
	  isDir = YES;
	}
    }
  if (isDir == NO)
    {
      if (verbose)
	NSLog(@"ERROR - Defaults path '%@' is not a directory!", path);
      return nil;
    }

  path = [path stringByAppendingPathComponent: defaultsFile];
  path = [path stringByAppendingPathExtension: @"lck"];
  return path;
}

static void
updateCache(NSUserDefaults *self)
{
  if (self == sharedDefaults)
    {
      NSArray	*debug;

      /**
       * If there is an array NSUserDefault called GNU-Debug,
       * we add its contents to the set of active debug levels.
       */
      debug = [self arrayForKey: @"GNU-Debug"];
      if (debug != nil)
        {
	  unsigned	c = [debug count];
	  NSMutableSet	*s;

	  s = [[NSProcessInfo processInfo] debugSet];
	  while (c-- > 0)
	    {
	      NSString	*level = [debug objectAtIndex: c];

	      [s addObject: level];
	    }
	}

      flags[GSMacOSXCompatible]
	= [self boolForKey: @"GSMacOSXCompatible"];
      flags[GSOldStyleGeometry]
	= [self boolForKey: @"GSOldStyleGeometry"];
      flags[GSLogSyslog]
	= [self boolForKey: @"GSLogSyslog"];
      flags[GSLogThread]
	= [self boolForKey: @"GSLogThread"];
      flags[GSLogOffset]
	= [self boolForKey: @"GSLogOffset"];
      flags[NSWriteOldStylePropertyLists]
	= [self boolForKey: @"NSWriteOldStylePropertyLists"];
    }
}

static void
setPermissions(NSString *file)
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSDictionary	*attr;
  uint32_t	desired;
  uint32_t	attributes;

  attr = [mgr fileAttributesAtPath: file
		      traverseLink: YES];
  attributes = [attr filePosixPermissions];
#if	!(defined(S_IRUSR) && defined(S_IWUSR))
  desired = 0600;
#else
  desired = (S_IRUSR|S_IWUSR);
#endif
  if (attributes != desired)
    {
      NSMutableDictionary	*enforced_attributes;
      NSNumber			*permissions;

      enforced_attributes
	= [NSMutableDictionary dictionaryWithDictionary:
	[mgr fileAttributesAtPath: file
		     traverseLink: YES]];

      permissions = [NSNumberClass numberWithUnsignedLong: desired];
      [enforced_attributes setObject: permissions
			      forKey: NSFilePosixPermissions];

      [mgr changeFileAttributes: enforced_attributes
			 atPath: file];
    }
}

static BOOL
writeDictionary(NSDictionary *dict, NSString *file)
{
  if ([file length] == 0)
    {
      NSLog(@"Defaults database filename is empty when writing");
    }
  else if (nil == dict)
    {
      NSFileManager	*mgr = [NSFileManager defaultManager];

      return [mgr removeFileAtPath: file handler: nil];
    }
  else
    {
      NSData	*data;
      NSString	*err;

      err = nil;
      data = [NSPropertyListSerialization dataFromPropertyList: dict
	       format: NSPropertyListXMLFormat_v1_0
	       errorDescription: &err];
      if (data == nil)
	{
	  NSLog(@"Failed to serialize defaults database for writing: %@", err);
	}
      else if ([data writeToFile: file atomically: YES] == NO)
	{
	  NSLog(@"Failed to write defaults database to file: %@", file);
	}
      else
	{
	  setPermissions(file);
	  return YES;
	}
    }
  return NO;
}

/**
 * Returns the list of languages retrieved from the operating system, in
 * decreasing order of preference. Returns an empty array if the information
 * could not be retrieved.
 */
static NSArray *
systemLanguages()
{
  NSMutableArray *names = [NSMutableArray arrayWithCapacity: 10];

  // Add the languages listed in the LANGUAGE environment variable
  // (a non-POSIX GNU extension)
  {
    NSString	*env = [[[NSProcessInfo processInfo] environment]
				 objectForKey: @"LANGUAGE"];
    if (env != nil && [env length] > 0)
      {
	NSArray *array = [env componentsSeparatedByString: @":"];
	NSEnumerator *enumerator = [array objectEnumerator];
	NSString *locale;
	while (nil != (locale = [enumerator nextObject]))
	  {
	    [names addObjectsFromArray: GSLanguagesFromLocale(locale)];
	  }
      }
  }	
  
  // If LANGUAGES did not yield any languages, try LC_MESSAGES

  if ([names count] == 0)
    {
      NSString *locale = GSDefaultLanguageLocale();

      if (locale != nil)
	{
	  [names addObjectsFromArray: GSLanguagesFromLocale(locale)];
	}
    }

  return names;
}

static NSMutableArray *
newLanguages(NSArray *oldNames)
{
  NSMutableArray	*newNames;
  NSEnumerator		*enumerator;
  NSString		*language;

  newNames = [NSMutableArray arrayWithCapacity: 5];

  if (oldNames == nil || [oldNames count] == 0)
    {
      oldNames = systemLanguages();
    }

  // If the user default was not set, and the system languages couldn't
  // be retrieved, try the GNUstep environment variable LANGUAGES

  if (oldNames == nil || [oldNames count] == 0)
    {
      NSString	*env;

      env = [[[NSProcessInfo processInfo] environment]
	objectForKey: @"LANGUAGES"];
      if (env != nil)
	{
	  oldNames = [env componentsSeparatedByString: @";"];
	}
    }

  enumerator = [oldNames objectEnumerator];
  while (nil != (language = [enumerator nextObject]))
    {
      language = [language stringByTrimmingSpaces];
      if ([language length] > 0 && NO == [newNames containsObject: language])
	{
	  [newNames addObject: language];
	}
    }

  /* Check if "English" is included. We do this to make sure all the
   * required language constants are set somewhere if they aren't set
   * in the default language.
   */
  if (NO == [newNames containsObject: @"English"])
    {
      [newNames addObject: @"English"];
    }
  return newNames;
}

/*************************************************************************
 *** Private method definitions
 *************************************************************************/
@interface NSUserDefaults (Private)
- (NSDictionary*) _createArgumentDictionary;
- (void) _changePersistentDomain: (NSString*)domainName;
- (NSString*) _directory;
- (BOOL) _lockDefaultsFile: (BOOL*)wasLocked;
- (BOOL) _readDefaults;
- (BOOL) _readOnly;
- (void) _unlockDefaultsFile;
@end

/**
 * <p>
 *   NSUserDefaults provides an interface to the defaults system,
 *   which allows an application access to global and/or application
 *   specific defaults set by the user. A particular instance of
 *   NSUserDefaults, standardUserDefaults, is provided as a
 *   convenience. Most of the information described below
 *   pertains to the standardUserDefaults. It is unlikely
 *   that you would want to instantiate your own userDefaults
 *   object, since it would not be set up in the same way as the
 *   standardUserDefaults.
 * </p>
 * <p>
 *   Defaults are managed based on <em>domains</em>. Certain
 *   domains, such as <code>NSGlobalDomain</code>, are
 *   persistent. These domains have defaults that are stored
 *   externally. Other domains are volatile. The defaults in
 *   these domains remain in effect only during the existence of
 *   the application and may in fact be different for
 *   applications running at the same time. When asking for a
 *   default value from standardUserDefaults, NSUserDefaults
 *   looks through the various domains in a particular order.
 * </p>
 * <deflist>
 *   <term><code>GSPrimaryDomain</code> ... volatile</term>
 *   <desc>
 *     Contains values set at runtime and intended to supercede any values
 *     set in other domains.  This should be used with great care since it
 *     overrides values which may have been set explicitly by the user.
 *   </desc>
 *   <term><code>NSArgumentDomain</code> ... volatile</term>
 *   <desc>
 *     Contains defaults read from the arguments provided
 *     to the application at startup.<br />
 *     Pairs of arguments are used for this, with the first argument in
 *     each pair being the name of a default (with a hyphen prepended)
 *     and the second argument of the pair being the value of the default.<br />
 *     NB. In GNUstep special arguments of the form <code>--GNU-Debug=...</code>
 *     are used to enable debugging.  Despite beginning with a hyphen, these
 *     are not treated as default keys.
 *   </desc>
 *   <term>Application (name of the current process) ... persistent</term>
 *   <desc>
 *     Contains application specific defaults, such as window positions.
 *     This is the domain used by the -setObject:forKey: method and is
 *     the domain normally used when setting preferences for an application.
 *   </desc>
 *   <term><code>NSGlobalDomain</code> ... persistent</term>
 *   <desc>
 *     Global defaults applicable to all applications.
 *   </desc>
 *   <term>Language (name based on users's language) ... volatile</term>
 *   <desc>
 *     Constants that help with localization to the users's
 *     language.
 *   </desc>
 *   <term><code>GSConfigDomain</code> ... volatile</term>
 *   <desc>
 *     Information retrieved from the GNUstep configuration system.
 *     Usually the system wide and user specific GNUstep.conf files,
 *     or from information compiled in when the base library was
 *     built.<br />
 *     In addition to this standard configuration information, this
 *     domain contains all values from property lists store in the
 *     GlobalDefaults subdirectory or from the GlobalDefaults.plist file
 *     stored in the same directory as the system wide GNUstep.conf
 *     file.
 *   </desc>
 *   <term><code>NSRegistrationDomain</code> ... volatile</term>
 *   <desc>
 *     Temporary defaults set up by the application.
 *   </desc>
 * </deflist>
 * <p>
 *   The <em>NSLanguages</em> default value is used to set up the
 *   constants for localization. GNUstep will also look for the
 *   <code>LANGUAGES</code> environment variable if it is not set
 *   in the defaults system. If it exists, it consists of an
 *   array of languages that the user prefers. At least one of
 *   the languages should have a corresponding localization file
 *   (typically located in the <file>Languages</file> directory
 *   of the GNUstep resources).
 * </p>
 * <p>
 *   As a special extension, on systems that support locales
 *   (e.g. GNU/Linux and Solaris), GNUstep will use information
 *   from the user specified locale, if the <em>NSLanguages</em>
 *   default value is not found. Typically the locale is
 *   specified in the environment with the <code>LANG</code>
 *   environment variable.
 * </p>
 * <p>
 *   The first change to a persistent domain after a -synchronize
 *   will cause an NSUserDefaultsDidChangeNotification to be posted
 *   (as will any change caused by reading new values from disk),
 *   so your application can keep track of changes made to the
 *   defaults by other software.
 * </p>
 * <p>
 *   NB. The GNUstep implementation differs from the Apple one in
 *   that it is thread-safe while Apple's (as of MacOS-X 10.1) is not.
 * </p>
 */
@implementation NSUserDefaults: NSObject

+ (void) atExit
{
  DESTROY(sharedDefaults);
  DESTROY(processName);
  DESTROY(classLock);
}

+ (void) initialize
{
  if (self == [NSUserDefaults class])
    {
      nextObjectSel = @selector(nextObject);
      objectForKeySel = @selector(objectForKey:);
      addSel = @selector(addEntriesFromDictionary:);
      /*
       * Cache class info for more rapid testing of the types of defaults.
       */
      NSArrayClass = [NSArray class];
      NSDataClass = [NSData class];
      NSDateClass = [NSDate class];
      NSDictionaryClass = [NSDictionary class];
      NSNumberClass = [NSNumber class];
      NSMutableDictionaryClass = [NSMutableDictionary class];
      NSStringClass = [NSString class];
      classLock = [GSLazyRecursiveLock new];
      [self registerAtExit];
    }
}

+ (void) resetStandardUserDefaults
{
  NSDictionary *regDefs = nil;

  [classLock lock];
  NS_DURING
    {
      if (nil != sharedDefaults)
        {
	  /* Extract the registration domain from the old defaults.
	   */
	  regDefs = [[[sharedDefaults->_tempDomains
	    objectForKey: NSRegistrationDomain] retain] autorelease];
	  [sharedDefaults->_tempDomains
	    removeObjectForKey: NSRegistrationDomain];

          /* To ensure that we don't try to synchronise the old defaults to disk
           * after creating the new ones, remove as housekeeping notification
           * observer.
           */
          [[NSNotificationCenter defaultCenter] removeObserver: sharedDefaults];

          /* Ensure changes are written, and no changes left so we can't end up
           * writing old changes to the new defaults.
           */
          [sharedDefaults synchronize];
          DESTROY(sharedDefaults->_changedDomains);
          DESTROY(sharedDefaults);
	}
      hasSharedDefaults = NO;
      [classLock unlock];
    }
  NS_HANDLER
    {
      [classLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  if (nil != regDefs)
    {
      [self standardUserDefaults];
      if (sharedDefaults != nil)
	{
	  [sharedDefaults->_tempDomains setObject: regDefs
	    forKey: NSRegistrationDomain];
	}
    }
}

/* Create a locale dictionary when we have absolutely no information
   about the locale. This method should go away, since it will never
   be called in a properly installed system. */
+ (NSDictionary *) _unlocalizedDefaults
{
  NSDictionary   *registrationDefaults;
  NSArray	 *ampm;
  NSArray	 *long_day;
  NSArray	 *long_month;
  NSArray	 *short_day;
  NSArray	 *short_month;
  NSArray	 *earlyt;
  NSArray	 *latert;
  NSArray	 *hour_names;
  NSArray	 *ymw_names;

  ampm = [NSArray arrayWithObjects: @"AM", @"PM", nil];

  short_month = [NSArray arrayWithObjects:
    @"Jan",
    @"Feb",
    @"Mar",
    @"Apr",
    @"May",
    @"Jun",
    @"Jul",
    @"Aug",
    @"Sep",
    @"Oct",
    @"Nov",
    @"Dec",
    nil];

  long_month = [NSArray arrayWithObjects:
    @"January",
    @"February",
    @"March",
    @"April",
    @"May",
    @"June",
    @"July",
    @"August",
    @"September",
    @"October",
    @"November",
    @"December",
    nil];

  short_day = [NSArray arrayWithObjects:
    @"Sun",
    @"Mon",
    @"Tue",
    @"Wed",
    @"Thu",
    @"Fri",
    @"Sat",
    nil];

  long_day = [NSArray arrayWithObjects:
    @"Sunday",
    @"Monday",
    @"Tuesday",
    @"Wednesday",
    @"Thursday",
    @"Friday",
    @"Saturday",
    nil];

  earlyt = [NSArray arrayWithObjects:
    @"prior",
    @"last",
    @"past",
    @"ago",
    nil];

  latert = [NSArray arrayWithObjects: @"next", nil];

  ymw_names = [NSArray arrayWithObjects: @"year", @"month", @"week", nil];

  hour_names = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects: @"0", @"midnight", nil],
    [NSArray arrayWithObjects: @"12", @"noon", @"lunch", nil],
    [NSArray arrayWithObjects: @"10", @"morning", nil],
    [NSArray arrayWithObjects: @"14", @"afternoon", nil],
    [NSArray arrayWithObjects: @"19", @"dinner", nil],
    nil];

  registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
    ampm, NSAMPMDesignation,
    long_month, NSMonthNameArray,
    long_day, NSWeekDayNameArray,
    short_month, NSShortMonthNameArray,
    short_day, NSShortWeekDayNameArray,
    @"DMYH", NSDateTimeOrdering,
    [NSArray arrayWithObject: @"tomorrow"], NSNextDayDesignations,
    [NSArray arrayWithObject: @"nextday"], NSNextNextDayDesignations,
    [NSArray arrayWithObject: @"yesterday"], NSPriorDayDesignations,
    [NSArray arrayWithObject: @"today"], NSThisDayDesignations,
    earlyt, NSEarlierTimeDesignations,
    latert, NSLaterTimeDesignations,
    hour_names, NSHourNameDesignations,
    ymw_names, NSYearMonthWeekDesignations,
    nil];
  return registrationDefaults;
}

+ (NSUserDefaults*) standardUserDefaults
{
  NSUserDefaults	*defs;
  BOOL		added_lang;
  BOOL		added_locale;
  BOOL		setup;
  BOOL		flag;
  id		lang;
  NSArray	*nL;
  NSArray	*uL;
  NSEnumerator	*enumerator;

  /* If the shared instance is already available ... return it.
   */
  [classLock lock];
  defs = [sharedDefaults retain];
  setup = hasSharedDefaults;
  [classLock unlock];
  if (YES == setup)
    {
      return [defs autorelease];
    }
 
  NS_DURING
    {
      /* Create new NSUserDefaults (NOTE: Not added to the autorelease pool!)
       * NB. The following code avoids deadlocks by creating a minimally
       * initialised instance, locking that instance, locking the class-wide
       * lock, installing the instance as the new shared defaults, unlocking
       * the class wide lock, completing the setup of the instance, and then
       * unlocking the instance.  This means we already have the shared
       * instance locked ourselves at the point when it first becomes
       * visible to other threads.
       */
#if	defined(__MINGW__)
      {
        NSString	*path = GSDefaultsRootForUser(NSUserName());
        NSRange		r = [path rangeOfString: @":REGISTRY:"];

        if (r.length > 0)
          {
	    defs = [[NSUserDefaultsWin32 alloc] init];
          }
        else
          {
	    defs = [[self alloc] init];
          }
      }
#else
      defs = [[self alloc] init];
#endif

      /* Install the new defaults as the shared copy, but lock it so that
       * we can complete setup without other threads interfering.
       */
      if (nil != defs)
	{
	  [defs->_lock lock];
	  [classLock lock];
	  if (NO == hasSharedDefaults)
	    {
	      hasSharedDefaults = YES;
	      sharedDefaults = [defs retain];
	    }
          else
	    {
	      /* Already set up by another thread.
	       */
	      [defs->_lock unlock];
	      [defs release];
	      defs = nil;
	    }
	  [classLock unlock];
	}

      if (nil == defs)
	{
	  NSLog(@"WARNING - unable to create shared user defaults!\n");
	  NS_VALRETURN(nil);
	}

      if (NO == [defs _readOnly]
	&& YES == [defs _lockDefaultsFile: &flag])
	{
	  NSFileManager	*mgr = [NSFileManager defaultManager];
	  NSString	*path;

	  path = [defs _directory];
	  path = [path stringByAppendingPathComponent: defaultsFile];
	  if (YES == [mgr isReadableFileAtPath: path])
	    {
	      NSString	*bck = [path stringByAppendingPathExtension: @"bck"];

	      if (NO == [mgr isReadableFileAtPath: bck])
		{
		  NSData	*data;
		  NSDictionary	*d = nil;

		  /* An old style defaults file was found,
		   * and no backup had been made of it, so
		   * we make a backup and convert it to a
		   * new style collection of files.
		   */
		  data = [NSData dataWithContentsOfFile: path];
		  if (nil != data)
		    {
		      d = [NSPropertyListSerialization
			propertyListWithData: data
			options: NSPropertyListImmutable
			format: 0
			error: 0];
		    }
		  if ([d isKindOfClass: [NSDictionary class]])
		    {
		      NSEnumerator	*e;
		      NSString	*name;

		      [mgr movePath: path toPath: bck handler: nil];
		      e = [d keyEnumerator];
		      while (nil != (name = [e nextObject]))
			{
			  NSDictionary	*domain = [d objectForKey: name];

			  path = [[defs _directory]
			    stringByAppendingPathComponent: name];
			  path = [path
			    stringByAppendingPathExtension: @"plist"];
			  if ([domain isKindOfClass: [NSDictionary class]]
			    && [domain count] > 0
			    && NO == [mgr fileExistsAtPath: path])
			    {
			      writeDictionary(domain, path);
			    }
			}
		    }
		  else
		    {
		      fprintf(stderr, "Found unparseable file at '%s'\n",
			[path UTF8String]);
		    }
		}
	    }
	  if (NO == flag)
	    {
	      [defs _unlockDefaultsFile];
	    }
	}

      /*
       * Set up search list (excluding language list, which we don't know yet)
       */
      [defs->_searchList addObject: GSPrimaryDomain];
      [defs->_searchList addObject: NSArgumentDomain];
      [defs->_searchList addObject: processName];
      [defs persistentDomainForName: processName];
      [defs->_searchList addObject: NSGlobalDomain];
      [defs persistentDomainForName: NSGlobalDomain];
      [defs->_searchList addObject: GSConfigDomain];
      [defs->_searchList addObject: NSRegistrationDomain];

      /* Load persistent data into the new instance.
       */
      [defs synchronize];

      /*
       * Look up user languages list and insert language specific domains
       * into search list before NSRegistrationDomain
       */
      uL = [defs stringArrayForKey: @"NSLanguages"];
      nL = newLanguages(uL);
      if (NO == [uL isEqual: nL])
	{
	  [self setUserLanguages: nL];
	}
      enumerator = [nL objectEnumerator];
      while ((lang = [enumerator nextObject]))
        {
          unsigned	index = [defs->_searchList count] - 1;

          [defs->_searchList insertObject: lang atIndex: index];
        }

      /* Set up language constants */

      /* We lookup gnustep-base resources manually here to prevent
       * bootstrap problems.  NSBundle's lookup routines depend on having
       * NSUserDefaults already bootstrapped, but we're still
       * bootstrapping here!  So we can't really use NSBundle without
       * incurring massive bootstrap complications (btw, most of the times
       * we're here as a consequence of [NSBundle +initialize] creating
       * the gnustep-base bundle!  So trying to use the gnustep-base
       * bundle here wouldn't really work.).
       */
      /*
       * We are looking for:
       *
       * GNUSTEP_LIBRARY/Libraries/gnustep-base/Versions/<interfaceVersion>/Resources/Languages/<language>
       *
       * We iterate over <language>, and for each <language> we iterate over GNUSTEP_LIBRARY.
       */

      {
        /* These variables are reused for all languages so we set them up
         * once here and then reuse them.
         */
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tail = [[[[[@"Libraries"
	  stringByAppendingPathComponent: @"gnustep-base"]
	  stringByAppendingPathComponent: @"Versions"]
	  stringByAppendingPathComponent:
	  OBJC_STRINGIFY(GNUSTEP_BASE_MAJOR_VERSION.GNUSTEP_BASE_MINOR_VERSION)]
	  stringByAppendingPathComponent: @"Resources"]
	  stringByAppendingPathComponent: @"Languages"];
        NSArray *paths = NSSearchPathForDirectoriesInDomains
	  (NSLibraryDirectory, NSAllDomainsMask, YES);

        added_lang = NO;
        added_locale = NO;
        enumerator = [nL objectEnumerator];
        while ((lang = [enumerator nextObject]))
          {
	    NSDictionary	*dict = nil;
	    NSString		*path = nil;
	    NSString		*alt;
	    NSEnumerator	*pathEnumerator;

	    /* The language name could be an ISO language identifier rather
	     * than an OpenStep name (OSX has moved to using them), so we
	     * try converting as an alternative key for lookup.
	     */
	    alt = GSLanguageFromLocale(lang);
	    pathEnumerator = [paths objectEnumerator];
	    while ((path = [pathEnumerator nextObject]) != nil)
	      {
	        path = [[path stringByAppendingPathComponent: tail]
		              stringByAppendingPathComponent: lang];
	        if ([fm fileExistsAtPath: path])
	          {
		    break;	/* Path found!  */
	          }
	        if (nil != alt)
		  {
		    path = [[path stringByAppendingPathComponent: tail]
				  stringByAppendingPathComponent: alt];
		    if ([fm fileExistsAtPath: path])
		      {
			break;	/* Path found!  */
		      }
		  }
	      }

	    if (path != nil)
	      {
	        dict = [NSDictionary dictionaryWithContentsOfFile: path];
	      }
	    if (dict != nil)
	      {
	        [defs setVolatileDomain: dict forName: lang];
	        added_lang = YES;
	      }
	    else if (added_locale == NO)
	      {
	        /* The resources for the language that we were looking for
	         * were not found.  If this was the currently set locale
	         * in the C library, try to get the same information from
	         * the C library.  This would usually happen for the
	         * language that was added to the list of languages
	         * precisely because it is the currently set locale in the
	         * C library.
	         */
	        NSString	*locale = GSDefaultLanguageLocale();

	        if (locale != nil)
	          {
		    NSString	*i18n = GSLanguageFromLocale(locale);

		    /* See if we can get the dictionary from i18n
		     * functions.  I don't think that the i18n routines
		     * can handle more than one locale, so we don't try to
		     * look 'lang' up but just get what we get and use it
		     * if it matches 'lang' ... but tell me if I'm wrong
		     * ...
		     */
		    if ([lang isEqual: i18n] || [alt isEqualToString: i18n])
		      {
		        /* We set added_locale to YES to avoid so that we
		         * won't do this C library locale lookup again
		         * later on.
		         */
		        added_locale = YES;

		        dict = GSDomainFromDefaultLocale ();
		        if (dict != nil)
		          {
			    [defs setVolatileDomain: dict forName: lang];

			    /* We do not set added_lang to YES here
			     * because we want the basic hardcoded defaults
			     * to be used in that case.
			     */
		          }
		      }
	          }
	      }
          }
      }

      if (added_lang == NO)
        {
          /* No language information found ... probably because the base
	   * library is being used 'standalone' without resources.
	   * We need to use hard-coded defaults.
	   */
          /* FIXME - should we set this as volatile domain for English ? */
          [defs registerDefaults: [self _unlocalizedDefaults]];
        }
      updateCache(sharedDefaults);
      [defs->_lock unlock];
    }
  NS_HANDLER
    {
      if (nil != defs)
	{
	  [defs->_lock unlock];
	  [defs release];
	}
      [localException raise];
    }
  NS_ENDHANDLER
  return [defs autorelease];
}

+ (NSArray*) userLanguages
{
  return [[self standardUserDefaults] stringArrayForKey: @"NSLanguages"];
}

+ (void) setUserLanguages: (NSArray*)languages
{
  NSUserDefaults	*defs;
  NSMutableDictionary	*dict;

  defs = [self standardUserDefaults];
  dict = [[defs volatileDomainForName: GSPrimaryDomain] mutableCopy];
  if (languages == nil)          // Remove the entry
    {
      [dict removeObjectForKey: @"NSLanguages"];
    }
  else
    {
      if (nil == dict)
        {
	  dict = [NSMutableDictionary new];
        }
      languages = newLanguages(languages);
      [dict setObject: languages forKey: @"NSLanguages"];
    }
  [defs removeVolatileDomainForName: GSPrimaryDomain];
  [defs setVolatileDomain: dict forName: GSPrimaryDomain];
  [dict release];
}

- (id) init
{
  return [self initWithUser: NSUserName()];
}

/* Deprecated method ... which shoudl be merged into - initWithUser:
 */
- (id) initWithContentsOfFile: (NSString*)path
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSRange	r;
  BOOL		flag;

  self = [super init];

  /*
   * Global variable.
   */
  if (processName == nil)
    {
      NSString	*s = [[NSProcessInfo processInfo] processName];

      processName = [s copy];
    }

  if (path == nil || [path isEqual: @""] == YES)
    {
      path = [GSDefaultsRootForUser(NSUserName())
	stringByAppendingPathComponent: defaultsFile];
    }

  r = [path rangeOfString: @":INTERNAL:"];
#if	defined(__MINGW__)
  if (r.length == 0)
    {
      r = [path rangeOfString: @":REGISTRY:"];
    }
#endif
  if (r.length == 0)
    {
      path = [path stringByStandardizingPath];
      _defaultsDatabase = [[path stringByDeletingLastPathComponent] copy];
      if (YES == [mgr fileExistsAtPath: _defaultsDatabase isDirectory: &flag]
	&& YES == flag)
	{
	  path = lockPath(_defaultsDatabase, NO);
	  if (nil != path)
	    {
	      _fileLock = [[NSDistributedLock alloc] initWithPath: path];
	    }
	}
    }

  _lock = [GSLazyRecursiveLock new];

  if (YES == [self _readOnly])
    {
      // Load read-only defaults.
      ASSIGN(_lastSync, [NSDateClass date]);
      [self _readDefaults];
      updateCache(self);
    }

  // Create an empty search list
  _searchList = [[NSMutableArray alloc] initWithCapacity: 10];
  _persDomains = [[NSMutableDictionaryClass alloc] initWithCapacity: 10];

  // Create volatile defaults and add the Argument and the Registration domains
  _tempDomains = [[NSMutableDictionaryClass alloc] initWithCapacity: 10];
  [_tempDomains setObject: [self _createArgumentDictionary]
		   forKey: NSArgumentDomain];
  [_tempDomains
    setObject: [NSMutableDictionaryClass dictionaryWithCapacity: 10]
    forKey: NSRegistrationDomain];
  [_tempDomains setObject: GNUstepConfig(nil) forKey: GSConfigDomain];

  [[NSNotificationCenter defaultCenter] addObserver: self
           selector: @selector(synchronize)
               name: @"GSHousekeeping"
             object: nil];

  return self;
}

- (id) initWithUser: (NSString*)userName
{
  NSString	*path;

  path = [GSDefaultsRootForUser(userName)
    stringByAppendingPathComponent: defaultsFile];
  return [self initWithContentsOfFile: path];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(_lastSync);
  RELEASE(_searchList);
  RELEASE(_persDomains);
  RELEASE(_tempDomains);
  RELEASE(_changedDomains);
  RELEASE(_dictionaryRep);
  RELEASE(_fileLock);
  RELEASE(_lock);
  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *desc = nil;

  [_lock lock];
  NS_DURING
    {
      desc = [NSMutableString stringWithFormat: @"%@", [super description]];
      [desc appendFormat: @" SearchList: %@", _searchList];
      [desc appendFormat: @" Persistent: %@", _persDomains];
      [desc appendFormat: @" Temporary: %@", _tempDomains];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return desc;
}

- (void) addSuiteNamed: (NSString*)aName
{
  NSUInteger	index;

  if (aName == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to add suite with nil name"];
    }
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      [_searchList removeObject: aName];
      index = [_searchList indexOfObject: processName];
      index = (index == NSNotFound) ? 0 : (index + 1);
      aName = [aName copy];
      [_searchList insertObject: aName atIndex: index];
      // Ensure that any persistent domain with the specified name is loaded.
      [self persistentDomainForName: aName];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  RELEASE(aName);
}

- (NSArray*) arrayForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && [obj isKindOfClass: NSArrayClass])
    return obj;
  return nil;
}

- (BOOL) boolForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && ([obj isKindOfClass: NSStringClass]
    || [obj isKindOfClass: NSNumberClass]))
    {
      return [obj boolValue];
    }
  return NO;
}

- (NSData*) dataForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && [obj isKindOfClass: NSDataClass])
    return obj;
  return nil;
}

- (NSDictionary*) dictionaryForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && [obj isKindOfClass: NSDictionaryClass])
    {
      return obj;
    }
  return nil;
}

- (double) doubleForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && ([obj isKindOfClass: NSStringClass]
    || [obj isKindOfClass: NSNumberClass]))
    {
      return [obj doubleValue];
    }
  return 0.0;
}

- (float) floatForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && ([obj isKindOfClass: NSStringClass]
    || [obj isKindOfClass: NSNumberClass]))
    {
      return [obj floatValue];
    }
  return 0.0;
}

- (NSInteger) integerForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && ([obj isKindOfClass: NSStringClass]
    || [obj isKindOfClass: NSNumberClass]))
    {
      return [obj integerValue];
    }
  return 0;
}

- (id) objectForKey: (NSString*)defaultName
{
  NSEnumerator	*enumerator;
  IMP		nImp;
  id		object = nil;
  id		dN;
  IMP		pImp;
  IMP		tImp;

  [_lock lock];
  NS_DURING
    {
      enumerator = [_searchList objectEnumerator];
      nImp = [enumerator methodForSelector: nextObjectSel];
      object = nil;
      pImp = [_persDomains methodForSelector: objectForKeySel];
      tImp = [_tempDomains methodForSelector: objectForKeySel];

      while ((dN = (*nImp)(enumerator, nextObjectSel)) != nil)
        {
	  GSPersistentDomain	*pd;
          NSDictionary		*td;

          pd = (*pImp)(_persDomains, objectForKeySel, dN);
          if (pd != nil && (object = [pd->contents objectForKey: defaultName]))
	    break;
          td = (*tImp)(_tempDomains, objectForKeySel, dN);
          if (td != nil && (object = [td objectForKey: defaultName]))
	    break;
        }
      IF_NO_GC([object retain];)
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(object);
}

- (void) removeObjectForKey: (NSString*)defaultName
{
  [_lock lock];
  NS_DURING
    {
      GSPersistentDomain	*pd = [_persDomains objectForKey: processName];

      if (nil != pd)
	{
	  id	obj = [pd->contents objectForKey: defaultName];

	  if (nil != obj)
	    {
	      pd->modified = YES;
	      [pd->contents removeObjectForKey: defaultName];
	      [self _changePersistentDomain: processName];
	    }
	}
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (void) setBool: (BOOL)value forKey: (NSString*)defaultName
{
  if (value == YES)
    {
      [self setObject: @"YES" forKey: defaultName];
    }
  else
    {
      [self setObject: @"NO" forKey: defaultName];
    }
}

- (void) setDouble: (double)value forKey: (NSString*)defaultName
{
  NSNumber	*n = [NSNumberClass numberWithDouble: value];

  [self setObject: n forKey: defaultName];
}

- (void) setFloat: (float)value forKey: (NSString*)defaultName
{
  NSNumber	*n = [NSNumberClass numberWithFloat: value];

  [self setObject: n forKey: defaultName];
}

- (void) setInteger: (NSInteger)value forKey: (NSString*)defaultName
{
  NSNumber	*n = [NSNumberClass numberWithInteger: value];

  [self setObject: n forKey: defaultName];
}

static BOOL isPlistObject(id o)
{
  if ([o isKindOfClass: NSStringClass] == YES)
    {
      return YES;
    }
  if ([o isKindOfClass: NSDataClass] == YES)
    {
      return YES;
    }
  if ([o isKindOfClass: NSDateClass] == YES)
    {
      return YES;
    }
  if ([o isKindOfClass: NSNumberClass] == YES)
    {
      return YES;
    }
  if ([o isKindOfClass: NSArrayClass] == YES)
    {
      NSEnumerator	*e = [o objectEnumerator];
      id		tmp;

      while ((tmp = [e nextObject]) != nil)
	{
	  if (isPlistObject(tmp) == NO)
	    {
	      return NO;
	    }
	}
      return YES;
    }
  if ([o isKindOfClass: NSDictionaryClass] == YES)
    {
      NSEnumerator	*e = [o keyEnumerator];
      id		tmp;

      while ((tmp = [e nextObject]) != nil)
	{
	  if (isPlistObject(tmp) == NO)
	    {
	      return NO;
	    }
	  tmp = [(NSDictionary*)o objectForKey: tmp];
	  if (isPlistObject(tmp) == NO)
	    {
	      return NO;
	    }
	}
      return YES;
    }
  return NO;
}

- (void) setObject: (id)value forKey: (NSString*)defaultName
{
  if (nil == value)
    {
      [self removeObjectForKey: defaultName];
      return;
    }
  if ([defaultName isKindOfClass: [NSString class]] == NO
    || [defaultName length] == 0)
    {
      [NSException raise: NSInvalidArgumentException
	format: @"attempt to set object with bad key (%@)", defaultName];
    }
  if (isPlistObject(value) == NO)
    {
      [NSException raise: NSInvalidArgumentException
	format: @"attempt to set non property list object (%@) for key (%@)",
	value, defaultName];
    }

  value = [value copy];
  [_lock lock];
  NS_DURING
    {
      GSPersistentDomain	*pd;

      pd = [_persDomains objectForKey: processName];
      if (nil == pd)
	{
	  pd = [[GSPersistentDomain alloc] initWithName: processName
						  owner: self];
          [_persDomains setObject: pd forKey: processName];
	  [pd release];
	}
      pd->modified = YES;
      [pd->contents setObject: value forKey: defaultName];
      [self _changePersistentDomain: processName];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  RELEASE(value);
}

- (void) setValue: (id)value forKey: (NSString*)defaultName
{
  [self setObject: value forKey: (NSString*)defaultName];
}

- (NSArray*) stringArrayForKey: (NSString*)defaultName
{
  id	arr = [self arrayForKey: defaultName];

  if (arr != nil)
    {
      NSEnumerator	*enumerator = [arr objectEnumerator];
      id		obj;

      while ((obj = [enumerator nextObject]))
	{
	  if ([obj isKindOfClass: NSStringClass] == NO)
	    {
	      return nil;
	    }
	}
      return arr;
    }
  return nil;
}

- (NSString*) stringForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];

  if (obj != nil && [obj isKindOfClass: NSStringClass])
    return obj;
  return nil;
}

- (NSArray*) searchList
{
  NSArray	*copy = nil;

  [_lock lock];
  NS_DURING
    {
      copy = [_searchList copy];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(copy);
}

- (void) setSearchList: (NSArray*)newList
{
  [_lock lock];
  NS_DURING
    {
      NSEnumerator	*e;
      NSString		*n;

      DESTROY(_dictionaryRep);
      RELEASE(_searchList);
      _searchList = [newList mutableCopy];
      /* Ensure that any domains we need are loaded.
       */
      e = [_searchList objectEnumerator];
      while (nil != (n = [e nextObject]))
	{
	  [self persistentDomainForName:  n];
	}
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (NSDictionary*) persistentDomainForName: (NSString*)domainName
{
  NSDictionary	*copy = nil;

  [_lock lock];
  NS_DURING
    {
      GSPersistentDomain	*pd;

      pd = [_persDomains objectForKey: domainName];
      if (nil != pd)
	{
	  copy = [[pd contents] copy];
	}
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(copy);
}

- (NSArray*) persistentDomainNames
{
  NSArray	*keys = nil;

  [_lock lock];
  NS_DURING
    {
      keys = [_persDomains allKeys];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return keys;
}

- (void) removePersistentDomainForName: (NSString*)domainName
{
  [_lock lock];
  NS_DURING
    {
      GSPersistentDomain	*pd;

      pd = [_persDomains objectForKey: domainName];
      if (nil != pd)
        {
	  if (YES == [domainName isEqualToString: NSGlobalDomain])
	    {
	      /* Don't remove the global domain, just its contents.
	       */
	      [pd->contents removeAllObjects];
	      pd->modified = YES;
	    }
	  else
	    {
	      /* Remove the domain entirely.
	       */
	      [_persDomains removeObjectForKey: domainName];
	    }
          [self _changePersistentDomain: domainName];
        }
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (void) setPersistentDomain: (NSDictionary*)domain
		     forName: (NSString*)domainName
{
  NSDictionary	*dict;

  [_lock lock];
  NS_DURING
    {
      GSPersistentDomain	*pd;

      dict = [_tempDomains objectForKey: domainName];
      if (dict != nil)
        {
          [NSException raise: NSInvalidArgumentException
	    format: @"a volatile domain called %@ exists", domainName];
        }
      pd = [_persDomains objectForKey: domainName];
      if (nil == pd)
	{
	  pd = [[GSPersistentDomain alloc] initWithName: domainName
						  owner: self];
          [_persDomains setObject: pd forKey: domainName];
	  [pd release];
	}
      [pd setContents: domain];
      [self _changePersistentDomain: domainName];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (id) valueForKey: (NSString*)aKey
{
  return [self objectForKey: aKey];
}

- (BOOL) wantToReadDefaultsSince: (NSDate*)lastSyncDate
{
  NSFileManager *mgr;
  NSDictionary	*attr;

  mgr = [NSFileManager defaultManager];
  attr = [mgr fileAttributesAtPath: _defaultsDatabase traverseLink: YES];
  if (lastSyncDate == nil)
    {
      return YES;
    }
  else
    {
      if (attr == nil)
	{
	  return YES;
	}
      else
	{
	  NSDate	*mod;

	  /*
	   * If the database was modified since the last synchronisation
	   * we need to read it.
	   */
	  mod = [attr objectForKey: NSFileModificationDate];
	  if (mod != nil && [lastSyncDate laterDate: mod] != lastSyncDate)
	    {
	      return YES;
	    }
	}
    }
  return NO;
}

- (BOOL) synchronize
{
  NSDate		*saved;
  BOOL			wasLocked;
  BOOL			result = YES;
  BOOL			haveChange = NO;

  [_lock lock];
  saved = _lastSync;
  _lastSync = [NSDate new];	// Record timestamp of this sync.
  NS_DURING
    {
      /* If we haven't changed anything, we only need to synchronise if
       * the on-disk database has been changed by someone else.
       */
      if (_changedDomains != nil
        || YES == [self wantToReadDefaultsSince: saved])
	{
          /* If we want to write but are currently read-only, try to
	   * create the path to make things writable.
	   */
	  if (_changedDomains != nil && YES == [self _readOnly])
	    {
	      NSString	*path = lockPath(_defaultsDatabase, NO);

	      if (nil != path)
		{
		  _fileLock = [[NSDistributedLock alloc] initWithPath: path];
		}
	    }
	  if ([self _lockDefaultsFile: &wasLocked] == NO)
	    {
	      result = NO;
	    }
	  else
	    {
	      NSEnumerator		*enumerator;
	      NSString			*domainName;

	      haveChange = [self _readDefaults];
	      if (YES == haveChange)
		{
		  DESTROY(_dictionaryRep);
		}

	      if (_changedDomains != nil)
                {
                  haveChange = YES;

                  if (NO == [self _readOnly])
                    {
                      GSPersistentDomain	*domain;
                      NSFileManager		*mgr;

                      mgr = [NSFileManager defaultManager];
                      enumerator = [_changedDomains objectEnumerator];
                      DESTROY(_changedDomains);	// Retained by enumerator.
                      while ((domainName = [enumerator nextObject]) != nil)
                        {
                          domain = [_persDomains objectForKey: domainName];
                          if (domain != nil)	// Domain was added or changed
                            {
                              [domain synchronize];
                            }
                          else			// Domain was removed
                            {
                              NSString	*path;

                              path = [[_defaultsDatabase
                                stringByAppendingPathComponent: domainName]
                                stringByAppendingPathExtension: @"plist"];
                              [mgr removeFileAtPath: path handler: nil];
                            }
                        }
                    }
                }

	      if (YES == haveChange)
		{
		  updateCache(self);
		}
	      if (NO == wasLocked)
		{
		  [self _unlockDefaultsFile];
		}
	    }
	}
    }
  NS_HANDLER
    {
      [_lastSync release];
      _lastSync = saved;
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  
  if (YES == result)
    {
      [saved release];
    }
  else
    {
      [_lastSync release];
      _lastSync = saved;
    }
  // Check and if not existent add the Application and the Global domains
  if ([_persDomains objectForKey: processName] == nil)
    {
      GSPersistentDomain	*pd;

      pd = [[GSPersistentDomain alloc] initWithName: processName
					      owner: self];
      [_persDomains setObject: pd forKey: processName];
      [pd release];
      [self _changePersistentDomain: processName];
    }
  if ([_persDomains objectForKey: NSGlobalDomain] == nil)
    {
      GSPersistentDomain	*pd;

      pd = [[GSPersistentDomain alloc] initWithName: NSGlobalDomain
					      owner: self];
      [_persDomains setObject: pd forKey: NSGlobalDomain];
      [pd release];
      [self _changePersistentDomain: NSGlobalDomain];
    }
  [_lock unlock];
  if (YES == haveChange)
    {
      [[NSNotificationCenter defaultCenter]
	postNotificationName: NSUserDefaultsDidChangeNotification
		      object: self];
    }
  return result;
}


- (void) removeVolatileDomainForName: (NSString*)domainName
{
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      [_tempDomains removeObjectForKey: domainName];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (void) setVolatileDomain: (NSDictionary*)domain
		   forName: (NSString*)domainName
{
  id	dict;

  [_lock lock];
  NS_DURING
    {
      dict = [_persDomains objectForKey: domainName];
      if (dict != nil)
        {
          [NSException raise: NSInvalidArgumentException
	    format: @"a persistent domain called %@ exists", domainName];
        }
      dict = [_tempDomains objectForKey: domainName];
      if (dict != nil)
        {
          [NSException raise: NSInvalidArgumentException
	    format: @"the volatile domain %@ already exists", domainName];
        }

      DESTROY(_dictionaryRep);
      domain = [domain mutableCopy];
      [_tempDomains setObject: domain forKey: domainName];
      RELEASE(domain);
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (NSDictionary*) volatileDomainForName: (NSString*)domainName
{
  NSDictionary	*copy = nil;

  [_lock lock];
  NS_DURING
    {
      copy = [[_tempDomains objectForKey: domainName] copy];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(copy);
}

- (NSArray*) volatileDomainNames
{
  NSArray	*keys = nil;

  [_lock lock];
  NS_DURING
    {
      keys = [_tempDomains allKeys];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return keys;
}

- (NSDictionary*) dictionaryRepresentation
{
  NSDictionary	*rep;

  [_lock lock];
  NS_DURING
    {
      if (_dictionaryRep == nil)
        {
          NSEnumerator		*enumerator;
          NSMutableDictionary	*dictRep;
          id			obj;
          id			dict;
          IMP			nImp;
          IMP			pImp;
          IMP			tImp;
          IMP			addImp;

          pImp = [_persDomains methodForSelector: objectForKeySel];
          tImp = [_tempDomains methodForSelector: objectForKeySel];

          enumerator = [_searchList reverseObjectEnumerator];
          nImp = [enumerator methodForSelector: nextObjectSel];

          dictRep = [NSMutableDictionaryClass alloc];
          dictRep = [dictRep initWithCapacity: 512];
          addImp = [dictRep methodForSelector: addSel];

          while ((obj = (*nImp)(enumerator, nextObjectSel)) != nil)
	    {
	      GSPersistentDomain	*pd;

	      pd = (*pImp)(_persDomains, objectForKeySel, obj);
	      if (nil != pd)
		{
		  dict = pd->contents;
		}
	      else
		{
	          dict = (*tImp)(_tempDomains, objectForKeySel, obj);
		}
	      if (nil != dict)
                {
                  (*addImp)(dictRep, addSel, dict);
                }
	    }
          [dictRep makeImmutableCopyOnFail: NO];
          _dictionaryRep = dictRep;
        }
      rep = [[_dictionaryRep retain] autorelease];
      [_lock unlock];
    }
  NS_HANDLER
    {
      rep = nil;
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return rep;
}

- (void) registerDefaults: (NSDictionary*)newVals
{
  NSMutableDictionary	*regDefs;

  [_lock lock];
  NS_DURING
    {
      regDefs = [_tempDomains objectForKey: NSRegistrationDomain];
      if (regDefs == nil)
        {
          regDefs = [NSMutableDictionaryClass
	    dictionaryWithCapacity: [newVals count]];
          [_tempDomains setObject: regDefs forKey: NSRegistrationDomain];
        }
      DESTROY(_dictionaryRep);
      [regDefs addEntriesFromDictionary: newVals];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (void) removeSuiteNamed: (NSString*)aName
{
  if (aName == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to remove suite with nil name"];
    }
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      [_searchList removeObject: aName];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

@end

BOOL
GSPrivateDefaultsFlag(GSUserDefaultFlagType type)
{
  if (nil == sharedDefaults && NO == parsingArguments)
    {
      [NSUserDefaults standardUserDefaults];
    }
  return flags[type];
}

/* Slightly faster than
 * [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
 * Avoiding the autorelease of the standard defaults turns out to be
 * a modest but significant gain when making heavy use of methods which
 * need localisation.
 */
NSDictionary *GSPrivateDefaultLocale()
{
  NSDictionary	        *locale = nil;
  NSUserDefaults        *defs = nil;

  if (classLock == nil)
    {
      [NSUserDefaults standardUserDefaults];
    }
  [classLock lock];
  NS_DURING
    {
      if (sharedDefaults == nil)
        {
          [NSUserDefaults standardUserDefaults];
        }
      defs = [sharedDefaults retain];
      [classLock unlock];
    }
  NS_HANDLER
    {
      [classLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  locale = [defs dictionaryRepresentation];
  [defs release];
  return locale;
}

@implementation NSUserDefaults (Private)

- (NSDictionary*) _createArgumentDictionary
{
  NSArray	*args;
  NSEnumerator	*enumerator;
  NSMutableDictionary *argDict = nil;
  BOOL		done;
  id		key, val;

  [_lock lock];
  if (YES == parsingArguments)
    {
      [_lock unlock];
      return nil;       // Prevent recursion
    }
  parsingArguments = YES;
  NS_DURING
    {
      args = [[NSProcessInfo processInfo] arguments];
      enumerator = [args objectEnumerator];
      argDict = [NSMutableDictionaryClass dictionaryWithCapacity: 2];
      [enumerator nextObject];	// Skip process name.
      done = ((key = [enumerator nextObject]) == nil) ? YES : NO;

      while (done == NO)
        {
          if ([key hasPrefix: @"-"] == YES && [key isEqual: @"-"] == NO)
	    {
	      NSString	*old = nil;

	      /* anything beginning with a '-' is a defaults key and we
               * must strip the '-' from it.
               * As a special case, we leave the '- in place for '-GS...'
               * and '--GS...' for backward compatibility.
               */
	      if ([key hasPrefix: @"-GS"] == YES
                || [key hasPrefix: @"--GS"] == YES)
	        {
	          old = key;
	        }
	      key = [key substringFromIndex: 1];
	      val = [enumerator nextObject];
	      if (val == nil)
	        {            // No more args
	          [argDict setObject: @"" forKey: key];		// arg is empty.
	          if (old != nil)
		    {
		      [argDict setObject: @"" forKey: old];
		    }
	          done = YES;
	          continue;
	        }
	      else if ([val hasPrefix: @"-"] == YES
                && [val isEqual: @"-"] == NO)
	        {  // Yet another argument
	          [argDict setObject: @"" forKey: key];		// arg is empty.
	          if (old != nil)
		    {
		      [argDict setObject: @"" forKey: old];
		    }
	          key = val;
	          continue;
	        }
	      else
	        {                            // Real parameter
	          /* Parsing the argument as a property list is very
		     delicate.  We *MUST NOT* crash here just because a
		     strange parameter (such as `(load "test.scm")`) is
		     passed, otherwise the whole library is useless in a
		     foreign environment. */
	          NSObject *plist_val;

	          NS_DURING
		    {
		      plist_val = [val propertyList];
		    }
	          NS_HANDLER
		    {
		      plist_val = val;
		    }
	          NS_ENDHANDLER

	          /* Make sure we don't crash being caught adding nil to
                     a dictionary. */
	          if (plist_val == nil)
		    {
		      plist_val = val;
		    }

	          [argDict setObject: plist_val  forKey: key];
	          if (old != nil)
		    {
		      [argDict setObject: plist_val  forKey: old];
		    }
	        }
	    }
          done = ((key = [enumerator nextObject]) == nil);
        }
      parsingArguments = NO;
      [_lock unlock];
    }
  NS_HANDLER
    {
      parsingArguments = NO;
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return argDict;
}

- (void) _changePersistentDomain: (NSString*)domainName
{
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      if (_changedDomains == nil)
        {
          _changedDomains = [[NSMutableArray alloc] initWithObjects: &domainName
							      count: 1];
          updateCache(self);
        }
      else if ([_changedDomains containsObject: domainName] == NO)
        {
          [_changedDomains addObject: domainName];
        }
      [[NSNotificationCenter defaultCenter]
	postNotificationName: NSUserDefaultsDidChangeNotification
		      object: self];
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
}

- (NSString*) _directory
{
  return _defaultsDatabase;
}

static BOOL isLocked = NO;
- (BOOL) _lockDefaultsFile: (BOOL*)wasLocked
{
  *wasLocked = isLocked;
  if (isLocked == NO && _fileLock != nil)
    {
      NSDate	*started = [NSDateClass date];

      while ([_fileLock tryLock] == NO)
	{
	  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
	  NSDate		*when;
	  NSDate		*lockDate;

	  lockDate = [_fileLock lockDate];
	  when = [NSDateClass dateWithTimeIntervalSinceNow: 0.1];

	  /*
	   * In case we have tried and failed to break the lock,
	   * we give up after a while ... 16 seconds should give
	   * us three lock breaks if we do them at 5 second
	   * intervals.
	   */
	  if ([when timeIntervalSinceDate: started] > 16.0)
	    {
	      NSLog(@"Failed to lock user defaults database even after "
		@"breaking old locks!");
	      [arp drain];
	      return NO;
	    }

	  /*
	   * If lockDate is nil, we should be able to lock again ... but we
	   * wait a little anyway ... so that in the case of a locking
	   * problem we do an idle wait rather than a busy one.
	   */
	  if (lockDate != nil && [when timeIntervalSinceDate: lockDate] > 5.0)
	    {
	      [_fileLock breakLock];
	    }
	  else
	    {
	      [NSThread sleepUntilDate: when];
	    }
	  [arp drain];
	}
      isLocked = YES;
    }
   return YES;
}

- (BOOL) _readDefaults
{
  NSEnumerator		*enumerator;
  NSString		*domainName;
  NSFileManager		*mgr;
  BOOL			haveChange = NO;

  mgr = [NSFileManager defaultManager];

  enumerator
    = [[mgr directoryContentsAtPath: _defaultsDatabase] objectEnumerator];
  while (nil != (domainName = [enumerator nextObject]))
    {
      if (NO == [[domainName pathExtension] isEqual: @"plist"])
	{
	  /* We only treat files with a .plist extension as being
	   * defaults domain files.
	   */
	  continue;
	}
      domainName = [domainName stringByDeletingPathExtension];

      /* We only look at files which do not represent domains in the
       * _changedDomains list, since our internal information on the
       * domains in that list overrides anything on disk.
       */
      if (NO == [_changedDomains containsObject: domainName])
	{
	  GSPersistentDomain	*pd;

	  pd = [_persDomains objectForKey: domainName];
	  if (nil == pd)
	    {
	      /* We had no record of this domain, so we create a new
	       * instance for it and add it to the dictionary of all
	       * persistent domains.
	       */
	      pd = [GSPersistentDomain alloc];
	      pd = [pd initWithName: domainName
			      owner: self];
	      [_persDomains setObject: pd forKey: domainName];
	      [pd release];
	      haveChange = YES;
	    }
	  if (YES == [_searchList containsObject: domainName])
	    {
	      /* This domain is in the search list ... so we must
	       * synchronize to load the domain contents into memory
	       * so a lookup will work.
	       */
              if (YES == [pd synchronize])
                {
                  haveChange = YES;
                }
	    }
	}
    }
  return haveChange;
}

- (BOOL) _readOnly
{
  return (nil == _fileLock) ? YES : NO;
}

- (void) _unlockDefaultsFile
{
  NS_DURING
    {
      [_fileLock unlock];
    }
  NS_HANDLER
    {
      NSLog(@"Warning ... someone broke our lock (%@) ... and may have"
        @" interfered with updating defaults data in file.",
        lockPath(_defaultsDatabase, NO));
    }
  NS_ENDHANDLER
  isLocked = NO;
}

@end

@implementation	GSPersistentDomain

- (NSMutableDictionary*) contents
{
  if (nil == updated)
    {
      [self synchronize];
    }
  return contents;
}

- (void) dealloc
{
  DESTROY(contents);
  DESTROY(updated);
  DESTROY(name);
  [super dealloc];
}

- (id) initWithName: (NSString*)n
	      owner: (NSUserDefaults*)o
{
  if (nil != (self = [super init]))
    {
      name = [n copy];
      owner = o;	// Not retained
      contents = [NSMutableDictionary new];
    }
  return self;
}

- (NSString*) name
{
  return name;
}

- (void) setContents: (NSDictionary*)domain
{
  if (NO == [contents isEqual: domain])
    {
      NSMutableDictionary	*m = [domain mutableCopy];

      if (nil == m)
	{
	  m = [NSMutableDictionary new];
	}
      [contents release];
      contents = m;
      updated = [NSDate new];
      modified = YES;
    }
}

- (BOOL) synchronize
{
  BOOL  wasLocked;
  BOOL	hadChange = NO; // Have we read a change from disk?

  if (NO == [owner _lockDefaultsFile: &wasLocked])
    {
      hadChange = NO;
      wasLocked = NO;
    }
  else
    {
      NSString	*path;

      path = [[[owner _directory] stringByAppendingPathComponent: name]
	stringByAppendingPathExtension: @"plist"];

      if (YES == modified && NO == [owner _readOnly])
	{
	  NSDate	*mod;
          BOOL          result;

          mod = [NSDate date];
	  if (0 == [contents count])
	    {
	      /* Remove empty defaults dictionary.
	       */
	      result = writeDictionary(nil, path);
	    }
	  else
	    {
	      /* Write dictionary to file.
	       */
	      result = writeDictionary(contents, path);
	    }
	  if (YES == result)
	    {
	      ASSIGN(updated, mod);
	      modified = NO;
	    }
	}
      else
	{
	  NSFileManager	*mgr = [NSFileManager defaultManager];
	  NSDate	*mod;
	  
	  /* If the database was modified since the last refresh
	   * we need to read it.
	   */
	  mod = [[mgr fileAttributesAtPath: path traverseLink: YES]
	    objectForKey: NSFileModificationDate];
	  if (nil == updated
	    || (nil != mod && [updated laterDate: mod] != updated))
	    {
	      ASSIGN(updated, mod);
	      if (nil != updated)
		{
		  NSData	*data;

		  data = [NSData dataWithContentsOfFile: path];
		  if (nil != data)
		    {
		      id	o;

		      o = [NSPropertyListSerialization
			propertyListWithData: data
			options: NSPropertyListImmutable
			format: 0
			error: 0];
		      if ([o isKindOfClass: [NSDictionary class]])
			{
			  [contents release];
			  contents = [o mutableCopy];
			}
		    }
		}
              hadChange = YES;
	    }
	}
      if (NO == wasLocked)
	{
	  [owner _unlockDefaultsFile];
	}
    }
  return hadChange;
}

- (NSDate*) updated
{
  return updated;
}

@end

