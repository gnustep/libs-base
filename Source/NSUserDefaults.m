/** Implementation for NSUserDefaults for GNUstep
   Copyright (C) 1995-2001 Free Software Foundation, Inc.

   Written by:  Georg Tuparev <Tuparev@EMBL-Heidelberg.de>
   		EMBL & Academia Naturalis, 
                Heidelberg, Germany
   Modified by:  Richard Frith-Macdonald <rfm@gnu.org>
  
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

   <title>NSUserDefaults class reference</title>
   $Date$ $Revision$
*/ 

#include <config.h>
#include <base/preface.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSLock.h>
#include <base/GSLocale.h>

#include "GSUserDefaults.h"

/* Wait for access */
#define _MAX_COUNT 5          /* Max 10 sec. */

/*************************************************************************
 *** Class variables
 *************************************************************************/
static SEL	nextObjectSel;
static SEL	objectForKeySel;
static SEL	addSel;

/* User's Defaults database */
static NSString	*GNU_UserDefaultsDatabase = @".GNUstepDefaults";

static Class	NSArrayClass;
static Class	NSDataClass;
static Class	NSDictionaryClass;
static Class	NSMutableDictionaryClass;
static Class	NSStringClass;

static NSUserDefaults	*sharedDefaults = nil;
static NSMutableString	*processName = nil;
static NSMutableArray	*userLanguages = nil;
static NSRecursiveLock	*classLock = nil;

/*
 * Caching some defaults.
 */
static BOOL	flags[GSUserDefaultMaxFlag] = { 0 };

static void updateCache(NSUserDefaults *self)
{
  if (self == sharedDefaults)
    {
      flags[GSMacOSXCompatible]
	= [self boolForKey: @"GSMacOSXCompatible"];
      flags[GSOldStyleGeometry]
	= [self boolForKey: @"GSOldStyleGeometry"];
      flags[GSLogSyslog]
	= [self boolForKey: @"GSLogSyslog"];
      flags[NSWriteOldStylePropertyLists]
	= [self boolForKey: @"NSWriteOldStylePropertyLists"];
    }
}

/*************************************************************************
 *** Local method definitions
 *************************************************************************/
@interface NSUserDefaults (__local_NSUserDefaults)
- (void) __createStandardSearchList;
- (NSDictionary*) __createArgumentDictionary;
- (void) __changePersistentDomain: (NSString*)domainName;
- (void) __timerTicked: (NSTimer*)tim;
@end

/**
 * <p>
 *   NSUserDefaults provides an interface to the defaults system,
 *   which allows an application access to global and/or application
 *   specific defualts set by the user. A particular instance of
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
 *   persistant. These domains have defaults that are stored
 *   externally. Other domains are volitale. The defaults in
 *   these domains remain in effect only during the existance of
 *   the application and may in fact be different for
 *   applications running at the same time. When asking for a
 *   default value from standardUserDefaults, NSUserDefaults
 *   looks through the various domains in a particular order.
 * </p>
 * <deflist>
 *   <term><code>NSArgumentDomain</code> ... volatile</term>
 *   <desc>
 *     Contains defaults read from the arguments provided
 *     to the application at startup.
 *   </desc>
 *   <term>Application (name of the current process) ... persistent</term>
 *   <desc>
 *     Contains application specific defaults,
 *     such as window positions.</desc>
 *   <term><code>NSGlobalDomain</code> ... persistent</term>
 *   <desc>
 *     Global defaults applicable to all applications.
 *   </desc>
 *   <term>Language (name based on users's language) ... volatile</term>
 *   <desc>
 *     Constants that help with localization to the users's
 *     language.
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
 *   that it is thread-safe while Apples (as of MacOS-X 10.1) is not.
 * </p>
 */
@implementation NSUserDefaults: NSObject

static BOOL setSharedDefaults = NO;	/* Flag to prevent infinite recursion */

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
      NSDictionaryClass = [NSDictionary class];
      NSMutableDictionaryClass = [NSMutableDictionary class];
      NSStringClass = [NSString class];
      classLock = [NSRecursiveLock new];
    }
}

/**
 * Resets the shared user defaults object to reflect the current
 * user ID.  Needed by setuid processes which change the user they
 * are running as.<br />
 * In GNUstep you should call GSSetUserName() when changing your
 * effective user ID, and that class will call this function for you.
 */
+ (void) resetStandardUserDefaults
{
  [classLock lock];
  if (sharedDefaults != nil)
    {
      NSDictionary	*regDefs;

      regDefs = RETAIN([sharedDefaults->_tempDomains
	objectForKey: NSRegistrationDomain]);
      setSharedDefaults = NO;
      AUTORELEASE(sharedDefaults);	// Let tother threads keep it.
      sharedDefaults = nil;
      if (regDefs != nil)
	{
	  [self standardUserDefaults];
	  if (sharedDefaults != nil)
	    {
	      [sharedDefaults->_tempDomains setObject: regDefs
					       forKey: NSRegistrationDomain];
	    }
	  RELEASE(regDefs);
	}
    }
  [classLock unlock];
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

/**
 * Returns the shared defaults object. If it doesn't exist yet, it's
 * created. The defaults are initialized for the current user.
 * The search list is guaranteed to be standard only the first time 
 * this method is invoked. The shared instance is provided as a 
 * convenience; other instances may also be created.
 */
+ (NSUserDefaults*) standardUserDefaults
{
  BOOL added_locale, added_lang;
  id lang;
  NSArray *uL;
  NSEnumerator *enumerator;

  [classLock lock];
  if (setSharedDefaults)
    {
      RETAIN(sharedDefaults);
      [classLock unlock];
      return AUTORELEASE(sharedDefaults);
    }
  setSharedDefaults = YES;
  /*
   * Get the user languages *before* setting up sharedDefaults, to avoid
   * the userLanguages method trying to look up languages in a partially
   * constructed user defaults object.
   */
  uL = [[self class] userLanguages];
  // Create new sharedDefaults (NOTE: Not added to the autorelease pool!)
  sharedDefaults = [[self alloc] init];
  if (sharedDefaults == nil)
    {
      NSLog(@"WARNING - unable to create shared user defaults!\n");
      [classLock unlock];
      return nil;
    }
	
  [sharedDefaults __createStandardSearchList];

  /* Set up language constants */
  added_locale = NO;
  added_lang = NO;
  enumerator = [uL objectEnumerator];
  while ((lang = [enumerator nextObject]))
    {
      NSString *path;
      NSDictionary *dict;
      path = [NSBundle pathForGNUstepResource: lang
		                       ofType: nil
		                  inDirectory: @"Resources/Languages"];
      dict = nil;
      if (path)
	dict = [NSDictionary dictionaryWithContentsOfFile: path];
      if (dict)
	{
	  [sharedDefaults setVolatileDomain: dict forName: lang];
	  added_lang = YES;
	}
      else if (added_locale == NO)
	{
	  NSString *locale = GSSetLocale(nil);
	  if (locale == nil)
	    break;
	  /* See if we can get the dictionary from i18n functions.
	     Note that we get the dict from the current locale regardless
	     of what 'lang' is, since it should match anyway. */
	  /* Also, I don't think that the i18n routines can handle more than
	     one locale, but tell me if I'm wrong... */
	  if (GSLanguageFromLocale(locale))
	    lang = GSLanguageFromLocale(locale);
	  dict = GSDomainFromDefaultLocale();
	  if (dict)
	    [sharedDefaults setVolatileDomain: dict forName: lang];
	  added_locale = YES;
	}
    }
  if (added_lang == NO)
    {
      /* Ack! We should never get here */
      NSLog(@"Improper installation: No language locale found");
      [sharedDefaults registerDefaults: [self _unlocalizedDefaults]];
    }
  RETAIN(sharedDefaults);
  updateCache(sharedDefaults);
  [classLock unlock];
  return AUTORELEASE(sharedDefaults);
}

/**
 * Returns the array of user languages preferences.  Uses the
 * <em>NSLanguages</em> user default if available, otherwise
 * tries to infer setup from operating system information etc
 * (in particular, uses the <em>LANGUAGES</em> environment variable).
 */
+ (NSArray*) userLanguages
{
  NSArray	*currLang = nil;
  NSString	*locale;

  [classLock lock];
  if (userLanguages != nil)
    {
      RETAIN(userLanguages);
      [classLock unlock];
      return AUTORELEASE(userLanguages);
    }
  userLanguages = RETAIN([NSMutableArray arrayWithCapacity: 5]);
  locale = GSSetLocale(@"");
  if (sharedDefaults == nil)
    {
      /* Create our own defaults to get "NSLanguages" since sharedDefaults
	 depends on us */
      NSUserDefaults	*tempDefaults;

      tempDefaults = [[self alloc] init];
      if (tempDefaults != nil)
	{	
	  NSMutableArray	*sList;

	  /*
	   * Can't use the standard method to set up a search list,
	   * it would cause mutual recursion as it includes languages.
	   */
	  sList = [[NSMutableArray alloc] initWithCapacity: 4];
	  [sList addObject: NSArgumentDomain];
	  [sList addObject: processName];
	  [sList addObject: NSGlobalDomain];
	  [sList addObject: NSRegistrationDomain];
	  [tempDefaults setSearchList: sList];
	  RELEASE(sList);
	  currLang = [tempDefaults stringArrayForKey: @"NSLanguages"];
	  AUTORELEASE(tempDefaults);
	}
    }
  else
    {
      currLang
	= [[self standardUserDefaults] stringArrayForKey: @"NSLanguages"];
    }
  if (currLang == nil && locale != 0 && GSLanguageFromLocale(locale))
    {
      currLang = [NSArray arrayWithObject: GSLanguageFromLocale(locale)];
    }
#ifdef __MINGW__
  if (currLang == nil && locale != 0)
    {
      /* Check for language as the first part of the locale string */
      NSRange under = [locale rangeOfString: @"_"];
      if (under.location)
        currLang = [NSArray arrayWithObject: 
	             [locale substringToIndex: under.location]];
    }
#endif
  if (currLang == nil)
    { 
      const char	*env_list;
      NSString		*env;

      env_list = getenv("LANGUAGES");
      if (env_list != 0)
	{
	  env = [NSStringClass stringWithCString: env_list];
	  currLang = [env componentsSeparatedByString: @";"];
	}
    }

  if (currLang != nil)
    {
      if ([currLang containsObject: @""] == YES)
	{
	  NSMutableArray	*a = [currLang mutableCopy];

	  [a removeObject: @""];
	  currLang = (NSArray*)AUTORELEASE(a);
	}
      [userLanguages addObjectsFromArray: currLang];
    }

  /* Check if "English" is included. We do this to make sure all the
     required language constants are set somewhere if they aren't set
     in the default language */
  if ([userLanguages containsObject: @"English"] == NO)
    {
      [userLanguages addObject: @"English"];
    }
  RETAIN(userLanguages);
  [classLock unlock];
  return AUTORELEASE(userLanguages);
}

/**
 * Sets the array of user languages preferences.  Places the specified
 * array in the <em>NSLanguages</em> user default.
 */
+ (void) setUserLanguages: (NSArray*)languages
{
  NSMutableDictionary	*globDict;
	
  globDict = [[[self standardUserDefaults] 
    persistentDomainForName: NSGlobalDomain] mutableCopy];
  if (languages == nil)          // Remove the entry
    [globDict removeObjectForKey: @"NSLanguages"];
  else
    [globDict setObject: languages forKey: @"NSLanguages"];
  [[self standardUserDefaults] 
    setPersistentDomain: globDict forName: NSGlobalDomain];
  RELEASE(globDict);
  return;
}

/*************************************************************************
 *** Initializing the User Defaults
 *************************************************************************/
/**
 * Initializes defaults for current user calling initWithUser:
 */
- (id) init
{
  return [self initWithUser: NSUserName()];
}

static NSString	*pathForUser(NSString *user) 
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*home;
  NSString	*path;
  NSString	*old;
  NSString      *libpath;
  unsigned	desired;
  NSDictionary	*attr;
  BOOL		isDir;

  home = GSDefaultsRootForUser(user);
  if (home == nil)
    {  
      /* Probably on MINGW. Where to put it? */
      NSLog(@"Could not get user root. Using NSOpenStepRootDirectory()");
      home = NSOpenStepRootDirectory();
    }
  path = [home stringByAppendingPathComponent: @"Defaults"];

#if	!(defined(S_IRUSR) && defined(S_IWUSR))
  desired = 0755;
#else
  desired = (S_IRUSR|S_IWUSR|S_IXUSR|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH);
#endif
  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
    NSUserName(), NSFileOwnerAccountName,
    [NSNumber numberWithUnsignedLong: desired], NSFilePosixPermissions,
    nil];

  if ([mgr fileExistsAtPath: home isDirectory: &isDir] == NO)
    {
      if ([mgr createDirectoryAtPath: home attributes: attr] == NO)
	{
	  NSLog(@"Directory '%@' does not exist - failed to create it.", home);
	  return nil;
	}
      else
	{
	  NSLog(@"Directory '%@' did not exist - created it", home);
	  isDir = YES;
	}
    }
  if (isDir == NO)
    {
      NSLog(@"ERROR - '%@' is not a directory!", home);
      return nil;
    }

  if ([mgr fileExistsAtPath: path isDirectory: &isDir] == NO)
    {
      if ([mgr createDirectoryAtPath: path attributes: attr] == NO)
	{
	  NSLog(@"Directory '%@' does not exist - failed to create it.", path);
	  return nil;
	}
      else
	{
	  NSLog(@"Directory '%@' did not exist - created it", path);
	  isDir = YES;
	}
    }
  if (isDir == NO)
    {
      NSLog(@"ERROR - '%@' is not a directory!", path);
      return nil;
    }

  /* Create this path also. The GUI/font cache depends on it being there */
  libpath = [home stringByAppendingPathComponent: @"Library"];
  if ([mgr fileExistsAtPath: libpath isDirectory: &isDir] == NO)
    [mgr createDirectoryAtPath: libpath attributes: attr];

  path = [path stringByAppendingPathComponent: GNU_UserDefaultsDatabase];
  old = [home stringByAppendingPathComponent: GNU_UserDefaultsDatabase];
  if ([mgr fileExistsAtPath: path] == NO)
    {
      if ([mgr fileExistsAtPath: old] == YES)
	{
	  if ([mgr movePath: old toPath: path handler: nil] == YES)
	    {
	      NSLog(@"Moved defaults database from old location (%@) to %@",
		old, path);
	    }
	}
    }
  if ([mgr fileExistsAtPath: old] == YES)
    {
      NSLog(@"Warning - ignoring old defaults database in %@", old);
    }
  
  return path;
}

/**
 * Initializes defaults for the specified user calling -initWithContentsOfFile:
 */
- (id) initWithUser: (NSString*)userName
{
  NSString	*path = pathForUser(userName);
	
  if (path == nil)
    {  
      RELEASE(self);
      return nil;
    }
  return [self initWithContentsOfFile: path];
}

/**
 * <init />
 * Initializes defaults for the specified path. Returns an object with 
 * an empty search list.
 */
- (id) initWithContentsOfFile: (NSString*)path
{
  [super init];
	
  // Find the user's home folder and build the paths (executed only once)
  if (_defaultsDatabase == nil)
    {
      if (path != nil && [path isEqual: @""] == NO)
	{
	  _defaultsDatabase = [path copy];
	}
      else
	{
	  _defaultsDatabase = [pathForUser(NSUserName()) copy];
	}

      if ([[_defaultsDatabase lastPathComponent] isEqual: 
	GNU_UserDefaultsDatabase] == YES)
	{
	  path = [_defaultsDatabase stringByDeletingLastPathComponent];
	}
      else
	{
	  path = [pathForUser(NSUserName()) stringByDeletingLastPathComponent];
	}
    }
  if (processName == nil)
    {
      processName = RETAIN([[NSProcessInfo processInfo] processName]);
    }

  // Create an empty search list
  _searchList = [[NSMutableArray alloc] initWithCapacity: 10];
	
  // Initialize _persDomains from the archived user defaults (persistent)
  _persDomains = [[NSMutableDictionaryClass alloc] initWithCapacity: 10];
  if ([self synchronize] == NO)
    {
      NSRunLoop	*runLoop = [NSRunLoop currentRunLoop];
      BOOL	done = NO;
      int	attempts;

      // Retry for a couple of seconds in case we are locked out.
      for (attempts = 0; done == NO && attempts < 10; attempts++)
	{
	  [runLoop runMode: NSDefaultRunLoopMode
		beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
	  if ([self synchronize] == YES)
	    {
	      done = YES;
	    }
        }
      if (done == NO)
	{
          DESTROY(self);
          return self;
        }
    }
	
  // Check and if not existent add the Application and the Global domains
  if (![_persDomains objectForKey: processName])
    {
      [_persDomains
	setObject: [NSMutableDictionaryClass dictionaryWithCapacity: 10]
	forKey: processName];
      [self __changePersistentDomain: processName];
    }
  if (![_persDomains objectForKey: NSGlobalDomain])
    {
      [_persDomains
	setObject: [NSMutableDictionaryClass dictionaryWithCapacity: 10]
	forKey: NSGlobalDomain];
      [self __changePersistentDomain: NSGlobalDomain];
    }
	
  // Create volatile defaults and add the Argument and the Registration domains
  _tempDomains = [[NSMutableDictionaryClass alloc] initWithCapacity: 10];
  [_tempDomains setObject: [self __createArgumentDictionary] 
		   forKey: NSArgumentDomain];
  [_tempDomains
    setObject: [NSMutableDictionaryClass dictionaryWithCapacity: 10]
    forKey: NSRegistrationDomain];

  _lock = [NSRecursiveLock new];
  return self;
}

- (void) dealloc
{
  if (_tickingTimer)
    [_tickingTimer invalidate];
  RELEASE(_lastSync);
  RELEASE(_searchList);
  RELEASE(_persDomains);
  RELEASE(_tempDomains);
  RELEASE(_changedDomains);
  RELEASE(_dictionaryRep);
  RELEASE(_lock);
  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *desc;

  [_lock lock];
  desc = [NSMutableString stringWithFormat: @"%@", [super description]];
  [desc appendFormat: @" SearchList: %@", _searchList];
  [desc appendFormat: @" Persistant: %@", _persDomains];
  [desc appendFormat: @" Temporary: %@", _tempDomains];
  [_lock unlock];
  return desc;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is an NSArray object.  Returns nil if it is not.
 */
- (NSArray*) arrayForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];
	
  if (obj != nil && [obj isKindOfClass: NSArrayClass])
    return obj;
  return nil;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is a boolean.  Returns NO if it is not.
 */
- (BOOL) boolForKey: (NSString*)defaultName
{
  id	obj = [self stringForKey: defaultName];
	
  if (obj != nil)
    return [obj boolValue];
  return NO;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is an NSData object.  Returns nil if it is not.
 */
- (NSData*) dataForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];
	
  if (obj != nil && [obj isKindOfClass: NSDataClass])
    return obj;
  return nil;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is an NSDictionary object.  Returns nil if it is not.
 */
- (NSDictionary*) dictionaryForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];
	
  if (obj != nil && [obj isKindOfClass: NSDictionaryClass])
    return obj;
  return nil;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is a float.  Returns 0.0 if it is not.
 */
- (float) floatForKey: (NSString*)defaultName
{
  id	obj = [self stringForKey: defaultName];
	
  if (obj != nil)
    return [obj floatValue];
  return 0.0;
}

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is an integer.  Returns 0 if it is not.
 */
- (int) integerForKey: (NSString*)defaultName
{
  id	obj = [self stringForKey: defaultName];
	
  if (obj != nil)
    return [obj intValue];
  return 0;
}

/**
 * Looks up a value for a specified default using.
 * The lookup is performed by accessing the domains in the order
 * given in the search list.
 * <br />Returns nil if defaultName cannot be found.
 */
- (id) objectForKey: (NSString*)defaultName
{
  NSEnumerator	*enumerator;
  IMP		nImp;
  id		object;
  id		dN;
  IMP		pImp;
  IMP		tImp;
	
  [_lock lock];
  enumerator = [_searchList objectEnumerator];
  nImp = [enumerator methodForSelector: nextObjectSel];
  object = nil;
  pImp = [_persDomains methodForSelector: objectForKeySel];
  tImp = [_tempDomains methodForSelector: objectForKeySel];

  while ((dN = (*nImp)(enumerator, nextObjectSel)) != nil)
    {
      id	dict;
      
      dict = (*pImp)(_persDomains, objectForKeySel, dN);
      if (dict != nil && (object = [dict objectForKey: defaultName]))
	break;
      dict = (*tImp)(_tempDomains, objectForKeySel, dN);
      if (dict != nil && (object = [dict objectForKey: defaultName]))
	break;
    }
  RETAIN(object);
  [_lock unlock];
  return AUTORELEASE(object);
}

/**
 * Removes the default with the specified name from the application
 * domain.
 */
- (void) removeObjectForKey: (NSString*)defaultName
{
  id	obj;
	
  [_lock lock];
  obj = [[_persDomains objectForKey: processName] objectForKey: defaultName];
  if (obj != nil)
    {
      NSMutableDictionary	*dict;
      id			obj = [_persDomains objectForKey: processName];

      if ([obj isKindOfClass: NSMutableDictionaryClass] == YES)
	{
	  dict = obj;
	}
      else
	{
	  dict = [obj mutableCopy];
	  [_persDomains setObject: dict forKey: processName];
	}
      [dict removeObjectForKey: defaultName];
      [self __changePersistentDomain: processName];
    }
  [_lock unlock];
  return;
}

/**
 * Sets a boolean value for defaultName in the application domain.
 * <br />Calls -setObject:forKey: to make the change.
 */
- (void) setBool: (BOOL)value forKey: (NSString*)defaultName
{
  id	obj = (value)?@"YES": @"NO";
	
  [self setObject: obj forKey: defaultName];
  return;
}

/**
 * Sets a float value for defaultName in the application domain.
 * <br />Calls -setObject:forKey: to make the change.
 */
- (void) setFloat: (float)value forKey: (NSString*)defaultName
{	
  char	buf[32];

  sprintf(buf,"%g",value);
  [self setObject: [NSStringClass stringWithCString: buf] forKey: defaultName];
  return;
}

/**
 * Sets an integer value for defaultName in the application domain.
 * <br />Calls -setObject:forKey: to make the change.
 */
- (void) setInteger: (int)value forKey: (NSString*)defaultName
{
  char	buf[32];

  sprintf(buf,"%d",value);
  [self setObject: [NSStringClass stringWithCString: buf] forKey: defaultName];
  return;
}

/**
 * Sets an object value for defaultName in the application domain.
 * <br />Causes a NSUserDefaultsDidChangeNotification to be posted
 * if this is the first change to a persistent-domain since the
 * last -synchronize.
 */
- (void) setObject: (id)value forKey: (NSString*)defaultName
{
  if (value && defaultName && ([defaultName length] > 0))
    {
      NSMutableDictionary	*dict;
      id			obj;

      [_lock lock];
      obj = [_persDomains objectForKey: processName];
      if ([obj isKindOfClass: NSMutableDictionaryClass] == YES)
	{
	  dict = obj;
	}
      else
	{
	  dict = [obj mutableCopy];
	  [_persDomains setObject: dict forKey: processName];
	  RELEASE(dict);
	}
      [dict setObject: value forKey: defaultName];
      [self __changePersistentDomain: processName];
      [_lock unlock];
    }
  return;
}

/**
 * Calls -arrayForKey: to get an array value for defaultName and checks
 * that the array contents are string objects ... if not, returns nil.
 */
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

/**
 * Looks up a value for a specified default using -objectForKey:
 * and checks that it is an NSString.  Returns nil if it is not.
 */
- (NSString*) stringForKey: (NSString*)defaultName
{
  id	obj = [self objectForKey: defaultName];
	
  if (obj != nil && [obj isKindOfClass: NSStringClass])
    return obj;
  return nil;
}

/*************************************************************************
 *** Returning the Search List
 *************************************************************************/
- (NSArray*) searchList
{
  NSArray	*copy;

  [_lock lock];
  copy = [_searchList copy];
  [_lock unlock];
  return AUTORELEASE(copy);
}

- (void) setSearchList: (NSArray*)newList
{
  [_lock lock];
  DESTROY(_dictionaryRep);
  RELEASE(_searchList);
  _searchList = [newList mutableCopy];
  [_lock unlock];
}

/**
 * Returns the persistent domain specified by domainName.
 */
- (NSDictionary*) persistentDomainForName: (NSString*)domainName
{
  NSDictionary	*copy;

  [_lock lock];
  copy = [[_persDomains objectForKey: domainName] copy];
  [_lock unlock];
  return AUTORELEASE(copy);
}

/**
 * Returns an array listing the name of all the persistent domains.
 */
- (NSArray*) persistentDomainNames
{
  NSArray	*keys;

  [_lock lock];
  keys = [_persDomains allKeys];
  [_lock unlock];
  return keys;
}

/**
 * Removes the persistent domain specified by domainName from the
 * user defaults.
 * <br />Causes a NSUserDefaultsDidChangeNotification to be posted
 * if this is the first change to a persistent-domain since the
 * last -synchronize.
 */
- (void) removePersistentDomainForName: (NSString*)domainName
{
  [_lock lock];
  if ([_persDomains objectForKey: domainName])
    {
      [_persDomains removeObjectForKey: domainName];
      [self __changePersistentDomain: domainName];
    }
  [_lock unlock];
  return;
}

/**
 * Replaces the persistent-domain specified by domainname with
 * domain ... a dictionary containing keys and defaults values.
 * <br />Causes a NSUserDefaultsDidChangeNotification to be posted
 * if this is the first change to a persistent-domain since the
 * last -synchronize.
 */
- (void) setPersistentDomain: (NSDictionary*)domain 
		     forName: (NSString*)domainName
{
  id	dict;
	
  [_lock lock];
  dict = [_tempDomains objectForKey: domainName];
  if (dict)
    {
      [_lock unlock];
      [NSException raise: NSInvalidArgumentException 
		   format: @"Persistant domain %@ already exists", domainName];
      return;
    }
  domain = [domain mutableCopy];
  [_persDomains setObject: domain forKey: domainName];
  RELEASE(domain);
  [self __changePersistentDomain: domainName];
  [_lock unlock];
  return;
}

/**
 * Ensures that the in-memory and on-disk representations of the defaults
 * are in sync.  You may call this yourself, but probably don't need to
 * since it is invoked at intervals whenever a runloop is running.<br />
 * If any persistent domain is changed by reading new values from disk,
 * an NSUserDefaultsDidChangeNotification is posted.
 */
- (BOOL) synchronize
{
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSMutableDictionary	*newDict;
  NSDictionary		*attr;

  [_lock lock];

  if (_tickingTimer == nil)
    {
      _tickingTimer = [NSTimer scheduledTimerWithTimeInterval: 30
	       target: self
	       selector: @selector(__timerTicked:)
	       userInfo: nil
	       repeats: NO];
    }

  /*
   *	If we haven't changed anything, we only need to synchronise if
   *	the on-disk database has been changed by someone else.
   */
  attr = [mgr fileAttributesAtPath: _defaultsDatabase
		      traverseLink: YES];
  if (_changedDomains == NO)
    {
      BOOL		wantRead = NO;

      if (_lastSync == nil)
	{
	  wantRead = YES;
	}
      else
	{
	  if (attr == nil)
	    {
	      wantRead = YES;
	    }
	  else
	    {
	      NSDate	*mod;

	      mod = [attr objectForKey: NSFileModificationDate];
	      if ([_lastSync earlierDate: mod] != _lastSync)
		{
		  wantRead = YES;
		}
	    }
	}
      if (wantRead == NO)
	{
	  [_lock unlock];
	  return YES;
	}
    }

  DESTROY(_dictionaryRep);

  // Read the persistent data from the stored database
  if (attr != nil)
    {
      unsigned long desired;
      unsigned long attributes;

      newDict = [[NSMutableDictionaryClass allocWithZone: [self zone]]
        initWithContentsOfFile: _defaultsDatabase];
      if (newDict == nil)
	{
	  NSLog(@"Unable to load defaults from '%@'", _defaultsDatabase);
	  [_lock unlock];
	  return NO;
	}
      
      attributes = [attr filePosixPermissions];
      // We enforce the permission mode 0600 on the defaults database
#if	!(defined(S_IRUSR) && defined(S_IWUSR))
      desired = 0600;
#else
      desired = (S_IRUSR|S_IWUSR);
#endif
      if (attributes != desired)
	{
	  NSMutableDictionary	*enforced_attributes;
	  NSNumber		*permissions;
	  
	  enforced_attributes = [NSMutableDictionary dictionaryWithDictionary:
	    [mgr fileAttributesAtPath: _defaultsDatabase traverseLink: YES]];

	  permissions = [NSNumber numberWithUnsignedLong: desired];
	  [enforced_attributes setObject: permissions
				  forKey: NSFilePosixPermissions];

	  [mgr changeFileAttributes: enforced_attributes 
			     atPath: _defaultsDatabase];
	}
    }
  else
    {
      unsigned long	desired;
      NSNumber		*permissions;

      // We enforce the permission mode 0600 on the defaults database
#if	!(defined(S_IRUSR) && defined(S_IWUSR))
      desired = 0600;
#else
      desired = (S_IRUSR|S_IWUSR);
#endif
      permissions = [NSNumber numberWithUnsignedLong: desired];
      attr = [NSDictionary dictionaryWithObjectsAndKeys: 
	NSUserName(), NSFileOwnerAccountName,
	permissions, NSFilePosixPermissions,
	nil];
      NSLog(@"Creating defaults database file %@", _defaultsDatabase);
      [mgr createFileAtPath: _defaultsDatabase
		   contents: nil
		 attributes: attr];
      newDict = [[NSMutableDictionaryClass allocWithZone: [self zone]]
		  initWithCapacity: 1];
      [newDict writeToFile: _defaultsDatabase atomically: YES];
    }

  if (_changedDomains)
    {           // Synchronize both dictionaries
      NSEnumerator	*enumerator = [_changedDomains objectEnumerator];
      IMP		nextImp;
      IMP		pImp;
      id		obj, dict;
		
      nextImp = [enumerator methodForSelector: nextObjectSel];
      pImp = [_persDomains methodForSelector: objectForKeySel];
      while ((obj = (*nextImp)(enumerator, nextObjectSel)) != nil)
	{
	  dict = (*pImp)(_persDomains, objectForKeySel, obj);
	  if (dict)       // Domain was added or changed
	    {
	      [newDict setObject: dict forKey: obj];
	    }
	  else            // Domain was removed
	    {
	      [newDict removeObjectForKey: obj];
	    }
	}
      RELEASE(_persDomains);
      _persDomains = newDict;
      // Save the changes
      if (![_persDomains writeToFile: _defaultsDatabase atomically: YES])
	{
	  [_lock unlock];
	  return NO;
	}
      ASSIGN(_lastSync, [NSDate date]);
    }
  else
    {
      ASSIGN(_lastSync, [NSDate date]);
      if ([_persDomains isEqual: newDict] == NO)
	{
	  RELEASE(_persDomains);
	  _persDomains = newDict;
	  updateCache(self);
	  [[NSNotificationCenter defaultCenter] 
	    postNotificationName: NSUserDefaultsDidChangeNotification
			  object: self];
	}
      else
	{
	  RELEASE(newDict);
	}
    }

  [_lock unlock];
  return YES;
}


/*************************************************************************
 *** Maintaining Volatile Domains
 *************************************************************************/
- (void) removeVolatileDomainForName: (NSString*)domainName
{
  [_lock lock];
  DESTROY(_dictionaryRep);
  [_tempDomains removeObjectForKey: domainName];
  [_lock unlock];
}

- (void) setVolatileDomain: (NSDictionary*)domain 
		   forName: (NSString*)domainName
{
  id	dict;
	
  [_lock lock];
  dict = [_persDomains objectForKey: domainName];
  if (dict)
    {
      [_lock unlock];
      [NSException raise: NSInvalidArgumentException 
		  format: @"Volatile domain %@ already exists", domainName];
      return;
    }
  DESTROY(_dictionaryRep);
  domain = [domain mutableCopy];
  [_tempDomains setObject: domain forKey: domainName];
  RELEASE(domain);
  [_lock unlock];
  return;
}

- (NSDictionary*) volatileDomainForName: (NSString*)domainName
{
  NSDictionary	*copy;

  [_lock lock];
  copy = [[_tempDomains objectForKey: domainName] copy];
  [_lock unlock];
  return AUTORELEASE(copy);
}

/**
 * Returns an array listing the name of all the volatile domains.
 */
- (NSArray*) volatileDomainNames
{
  NSArray	*keys;

  [_lock lock];
  keys = [_tempDomains allKeys];
  [_lock unlock];
  return keys;
}

/**
 * Returns a dictionary representing the current state of the defaults
 * system ... this is a merged version of all the domains in the
 * search list.
 */
- (NSDictionary*) dictionaryRepresentation
{
  NSDictionary	*rep;

  [_lock lock];
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

      dictRep = [NSMutableDictionaryClass allocWithZone: NSDefaultMallocZone()];
      dictRep = [dictRep initWithCapacity: 512];
      addImp = [dictRep methodForSelector: addSel];

      while ((obj = (*nImp)(enumerator, nextObjectSel)) != nil)
	{
	  if ( (dict = (*pImp)(_persDomains, objectForKeySel, obj)) != nil
	    || (dict = (*tImp)(_tempDomains, objectForKeySel, obj)) != nil)
	    (*addImp)(dictRep, addSel, dict);
	}
      _dictionaryRep = [dictRep copy];
      RELEASE(dictRep);
    }
  rep = RETAIN(_dictionaryRep);
  [_lock unlock];
  return AUTORELEASE(rep);
}

/**
 * Merges the contents of the dictionary newVals into the registration
 * domain.  Registration defaults may be added to or replaced using this
 * method, but may never be removed.  Thus, setting registration defaults
 * at any point in your program guarantees that the defaults will be
 * available thereafter.
 */
- (void) registerDefaults: (NSDictionary*)newVals
{
  NSMutableDictionary	*regDefs;

  [_lock lock];
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

/*************************************************************************
 *** Accessing the User Defaults database
 *************************************************************************/
- (void) __createStandardSearchList
{
  NSArray	*uL;
  NSEnumerator	*enumerator;
  id		object;
	
  [_lock lock];
  // Note: The search list should exist!
	
  // 1. NSArgumentDomain
  [_searchList addObject: NSArgumentDomain];
	
  // 2. Application
  [_searchList addObject: processName];

  // 3. NSGlobalDomain
  [_searchList addObject: NSGlobalDomain];
	
  // 4. User's preferred languages
  uL = [[self class] userLanguages];
  enumerator = [uL objectEnumerator];
  while ((object = [enumerator nextObject]))
    {
      [_searchList addObject: object];
    }
	
  // 5. NSRegistrationDomain
  [_searchList addObject: NSRegistrationDomain];
	
  [_lock unlock];
  return;
}

- (NSDictionary*) __createArgumentDictionary
{
  NSArray	*args;
  NSEnumerator	*enumerator;
  NSMutableDictionary *argDict;
  BOOL		done;
  id		key, val;

  [_lock lock];
  args = [[NSProcessInfo processInfo] arguments];
  enumerator = [args objectEnumerator];
  argDict = [NSMutableDictionaryClass dictionaryWithCapacity: 2];
  [enumerator nextObject];	// Skip process name.
  done = ((key = [enumerator nextObject]) == nil);
	
  while (!done)
    {
      if ([key hasPrefix: @"-"])
	{
	  NSString	*old = nil;

	  /* anything beginning with a '-' is a defaults key and we must strip
	      the '-' from it.  As a special case, we leave the '- in place
	      for '-GS...' and '--GS...' for backward compatibility. */
	  if ([key hasPrefix: @"-GS"] == YES || [key hasPrefix: @"--GS"] == YES)
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
	  else if ([val hasPrefix: @"-"] == YES)
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
  [_lock unlock];
  return argDict;
}

- (void) __changePersistentDomain: (NSString*)domainName
{
  NSEnumerator	*enumerator = nil;
  IMP		nImp;
  id		obj;

  [_lock lock];
  DESTROY(_dictionaryRep);
  if (!_changedDomains)
    {
      _changedDomains = [[NSMutableArray alloc] initWithCapacity: 5];
      updateCache(self);
      [[NSNotificationCenter defaultCenter] 
	postNotificationName: NSUserDefaultsDidChangeNotification
		      object: self];
    }
	
  enumerator = [_changedDomains objectEnumerator];
  nImp = [enumerator methodForSelector: nextObjectSel];
  while ((obj = (*nImp)(enumerator, nextObjectSel)) != nil)
    {
      if ([obj isEqualToString: domainName])
	{
	  [_lock unlock];
	  return;
	}
    }
  [_changedDomains addObject: domainName];
  [_lock unlock];
  return;
}

- (void) __timerTicked: (NSTimer*)tim
{
  if (tim == _tickingTimer)
    _tickingTimer = nil;

  [self synchronize];
}
@end

NSDictionary*
GSUserDefaultsDictionaryRepresentation()
{
  NSDictionary	*defs;

  if (sharedDefaults == nil)
    {
      [NSUserDefaults standardUserDefaults];
    }
  [classLock lock];
  defs = [sharedDefaults dictionaryRepresentation];
  [classLock unlock];
  return defs;
}

/*
 * Get one of several potentially useful flags.
 */
BOOL
GSUserDefaultsFlag(GSUserDefaultFlagType type)
{
  if (sharedDefaults == nil)
    {
      [NSUserDefaults standardUserDefaults];
    }
  return flags[type];
}

