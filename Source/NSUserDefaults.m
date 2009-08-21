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

#include "config.h"
#include "GNUstepBase/preface.h"
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

#include "Foundation/NSUserDefaults.h"
#include "Foundation/NSArchiver.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSDistributedLock.h"
#include "Foundation/NSException.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSPropertyList.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSSet.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSTimer.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSDebug.h"
#include "GNUstepBase/GSLocale.h"
#include "GNUstepBase/GSLock.h"

#if	defined(__MINGW32__)
@class	NSUserDefaultsWin32;
#endif

#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif

#include "GSPrivate.h"

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

static NSString		*defaultsFile = @".GNUstepDefaults";

static NSUserDefaults	*sharedDefaults = nil;
static NSMutableString	*processName = nil;
static NSMutableArray	*userLanguages = nil;
static BOOL		invalidatedLanguages = NO;
static NSRecursiveLock	*classLock = nil;

/*
 * Caching some defaults.
 */
static BOOL	flags[GSUserDefaultMaxFlag] = { 0 };

static void updateCache(NSUserDefaults *self)
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
      flags[NSWriteOldStylePropertyLists]
	= [self boolForKey: @"NSWriteOldStylePropertyLists"];
    }
}

static BOOL
writeDictionary(NSDictionary *dict, NSString *file)
{
  if (dict == nil)
    {
      NSLog(@"Defaults database is nil when writing");
    }
  else if ([file length] == 0)
    {
      NSLog(@"Defaults database filename is empty when writing");
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
	  return YES;
	}
    }
  return NO;
}

/*************************************************************************
 *** Local method definitions
 *************************************************************************/
@interface NSUserDefaults (__local_NSUserDefaults)
- (NSDictionary*) __createArgumentDictionary;
- (void) __changePersistentDomain: (NSString*)domainName;
- (NSMutableDictionary*) readDefaults;
- (BOOL) writeDefaults: (NSDictionary*)defaults oldData: (NSDictionary*)oldData;
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
 *   <term><code>GSConfigDomain</code> ... volatile</term>
 *   <desc>
 *     Information retrieved from the GNUstep configuration system.
 *     Usually the system wide and user specific GNUstep.conf files,
 *     or from information compiled in when the base library was
 *     built.<br />
 *     In addition to this standard configuration information, this
 *     domain contains all values from the GlobalDefaults.plist file
 *     stored in the same directory as the system widw GNUstep.conf
 *     file.  The GlobalDefaults.plist allows packagers and system
 *     administrators to provide global defaults settings for all
 *     users of a particular GNUstep installation.
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

static BOOL setSharedDefaults = NO;     /* Flag to prevent infinite recursion */

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
    }
}

+ (void) resetStandardUserDefaults
{
  [classLock lock];
  NS_DURING
    {
      if (sharedDefaults != nil)
        {
          NSDictionary	*regDefs;
    
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
    
          regDefs = RETAIN([sharedDefaults->_tempDomains
	    objectForKey: NSRegistrationDomain]);
          setSharedDefaults = NO;
          DESTROY(sharedDefaults);
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
  NS_HANDLER
    {
      [classLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
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
  BOOL added_lang, added_locale;
  id lang;
  NSArray *uL;
  NSEnumerator *enumerator;

  /*
   * Calling +standardUserDefaults and +userLanguages is horribly interrelated.
   * Messing with the order of assignments and calls within these methods can
   * break things very easily ... take care.
   *
   * If +standardUserDefaults is called first, it sets up initial information
   * in sharedDefaults then calls +userLanguages to get language information.
   * +userLanguages then calls +standardUserDefaults to read NSLanguages
   * and returns the language information.
   * +standardUserDefaults then sets up language domains and loads localisation
   * information before returning.
   *
   * If +userLanguages is called first, it calls +standardUserDefaults
   * to obtain the NSLanguages array.
   * +standardUserDefaults loads basic information initialising the
   * sharedDefaults variable, then calls back to +userLanguages to set up
   * its search list.
   * +userLanguages calls +standardUserDefaults again to get NSLanguages.
   * +standardUserDefaults returns the partially initialised sharedDefaults.
   * +userLanguages uses this to create and return the user languages.
   * +standardUserDefaults uses the languages to update the search list
   * and load in localisation information then returns sharedDefaults.
   * +userLanguages uses this to rebuild language information and return it.
   */

  /* Return the sharedDefaults without locking in the simple case.
   * We need to lock and check again before CREATING sharedDefaults if it doesn't exist,
   * so that two threads can't create it at once (or call resetStandardUserDefaults at
   * the same time).
   * By not locking here, we avoid a deadlock that can occur between classLock and _lock. */  
  if (setSharedDefaults == YES)
    {
      IF_NO_GC([sharedDefaults retain];)
      return AUTORELEASE(sharedDefaults);
    }

  [classLock lock];

  /*
   * NB. The use of the setSharedDefaults flag ensures that a recursive
   * call to this method is quietly suppressed ... so we get a more
   * manageable problem.
   */
  if (setSharedDefaults == YES)
    {
      IF_NO_GC([sharedDefaults retain];)
      [classLock unlock];
      return AUTORELEASE(sharedDefaults);
    }
  setSharedDefaults = YES;

  NS_DURING
    {
      // Create new sharedDefaults (NOTE: Not added to the autorelease pool!)
#if	defined(__MINGW32__)
      {
        NSString	*path = GSDefaultsRootForUser(NSUserName());
        NSRange	r = [path rangeOfString: @":REGISTRY:"];
    
        if (r.length > 0)
          {
	    sharedDefaults = [[NSUserDefaultsWin32 alloc] init];
          }
        else
          {
	    sharedDefaults = [[self alloc] init];
          }
      }
#else
      sharedDefaults = [[self alloc] init];
#endif
      if (sharedDefaults == nil)
        {
          NSLog(@"WARNING - unable to create shared user defaults!\n");
          [classLock unlock];
          NS_VALRETURN(nil);
        }

      /*
       * Set up search list (excluding language list, which we don't know yet)
       */
      [sharedDefaults->_searchList addObject: NSArgumentDomain];
      [sharedDefaults->_searchList addObject: processName];
      [sharedDefaults->_searchList addObject: NSGlobalDomain];
      [sharedDefaults->_searchList addObject: GSConfigDomain];
      [sharedDefaults->_searchList addObject: NSRegistrationDomain];

      /*
       * Look up user languages list and insert language specific domains
       * into search list before NSRegistrationDomain
       */
      uL = [self userLanguages];
      enumerator = [uL objectEnumerator];
      while ((lang = [enumerator nextObject]))
        {
          unsigned	index = [sharedDefaults->_searchList count] - 1;

          [sharedDefaults->_searchList insertObject: lang atIndex: index];
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
        NSArray *paths = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
							      NSAllDomainsMask, YES);
        
        added_lang = NO;
        added_locale = NO;
        enumerator = [uL objectEnumerator];
        while ((lang = [enumerator nextObject]))
          {
	    NSDictionary	*dict = nil;
	    NSString	*path = nil;
	    NSEnumerator *pathEnumerator = [paths objectEnumerator];

	    while ((path = [pathEnumerator nextObject]) != nil)
	      {
	        path = [[path stringByAppendingPathComponent: tail]
		             stringByAppendingPathComponent: lang];

	        if ([fm fileExistsAtPath: path])
	          {
		    /* Path found!  */
		    break;
	          }
	      }
	    
	    if (path != nil)
	      {
	        dict = [NSDictionary dictionaryWithContentsOfFile: path];
	      }
	    if (dict != nil)
	      {
	        [sharedDefaults setVolatileDomain: dict forName: lang];
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
	        NSString	*locale = nil;
	        
#ifdef HAVE_LOCALE_H
#ifdef LC_MESSAGES
	        locale = GSSetLocale(LC_MESSAGES, nil);
#endif
#endif
	        if (locale != nil)
	          {
		    /* See if we can get the dictionary from i18n
		     * functions.  I don't think that the i18n routines
		     * can handle more than one locale, so we don't try to
		     * look 'lang' up but just get what we get and use it
		     * if it matches 'lang' ... but tell me if I'm wrong
		     * ...
		     */
		    if ([lang isEqualToString: GSLanguageFromLocale (locale)])
		      {
		        /* We set added_locale to YES to avoid so that we
		         * won't do this C library locale lookup again
		         * later on.
		         */
		        added_locale = YES;
		        
		        dict = GSDomainFromDefaultLocale ();
		        if (dict != nil)
		          {
			    [sharedDefaults setVolatileDomain: dict forName: lang];
			
			    /* We do not set added_lang to YES here
			     * because we want the improper installation
			     * warning to be printed below if our own
			     * English language dictionary is not found,
			     * and we want the basic hardcoded defaults to
			     * be used in that case.  (FIXME: Review this
			     * decision).
			     */
		          }
		      }
	          }
	      }
          }
      }
    
      if (added_lang == NO)
        {
          /* Ack! We should never get here.  */
          NSWarnMLog(@"Improper installation: No language locale found");
    
          /* FIXME - should we set this as volatile domain for English ? */
          [sharedDefaults registerDefaults: [self _unlocalizedDefaults]];
        }
      IF_NO_GC([sharedDefaults retain];)
      updateCache(sharedDefaults);
      [classLock unlock];
    }
  NS_HANDLER
    {
      [classLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(sharedDefaults);
}

+ (NSArray*) userLanguages
{
  NSArray	*result = nil;

  /*
   * Calling +standardUserDefaults and +userLanguages is horribly interrelated.
   * Messing with the order of assignments and calls within these methods can
   * break things very easily ... take care.
   *
   * If +standardUserDefaults is called first, it sets up initial information
   * in sharedDefaults then calls +userLanguages to get language information.
   * +userLanguages then calls +standardUserDefaults to read NSLanguages
   * and returns the language information.
   * +standardUserDefaults then sets up language domains and loads localisation
   * information before returning.
   *
   * If +userLanguages is called first, it calls +standardUserDefaults
   * to obtain the NSLanguages array.
   * +standardUserDefaults loads basic information initialising the
   * sharedDefaults variable, then calls back to +userLanguages to set up
   * its search list.
   * +userLanguages calls +standardUserDefaults again to get NSLanguages.
   * +standardUserDefaults returns the partially initialised sharedDefaults.
   * +userLanguages uses this to create and return the user languages.
   * +standardUserDefaults uses the languages to update the search list
   * and load in localisation information then returns sharedDefaults.
   * +userLanguages uses this to rebuild language information and return it.
   */

  [classLock lock];
  NS_DURING
    {
      if (invalidatedLanguages == YES)
        {
          invalidatedLanguages = NO;
          DESTROY(userLanguages);
        }
      if (userLanguages == nil)
        {
          NSArray	*currLang = nil;
          NSString	*locale = nil;

#ifdef HAVE_LOCALE_H
#ifdef LC_MESSAGES
          locale = GSSetLocale(LC_MESSAGES, nil);
#endif
#endif
          currLang = [[NSUserDefaults standardUserDefaults]
              stringArrayForKey: @"NSLanguages"];

          userLanguages = [[NSMutableArray alloc] initWithCapacity: 5];

          if (currLang == nil && locale != nil && GSLanguageFromLocale(locale))
	    {
	      currLang = [NSArray arrayWithObject: GSLanguageFromLocale(locale)];
	    }
#ifdef __MINGW32__
          if (currLang == nil && locale != nil)
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
	      NSString	*env;

	      env = [[[NSProcessInfo processInfo] environment]
	        objectForKey: @"LANGUAGES"];
	      if (env != nil)
	        {
	          currLang = [env componentsSeparatedByString: @";"];
	        }
	    }

          if (currLang != nil)
	    {
	      NSMutableArray	*a = [currLang mutableCopy];
	      unsigned		c = [a count];

	      while (c-- > 0)
	        {
	          NSString	*s = [[a objectAtIndex: c] stringByTrimmingSpaces];

	          if ([s length] == 0)
		    {
		      [a removeObjectAtIndex: c];
		    }
	          else
		    {
		      [a replaceObjectAtIndex: c withObject: s];
		    }
	        }
	      [userLanguages addObjectsFromArray: a];
	      RELEASE(a);
	    }

          /* Check if "English" is included. We do this to make sure all the
	     required language constants are set somewhere if they aren't set
	     in the default language */
          if ([userLanguages containsObject: @"English"] == NO)
	    {
	      [userLanguages addObject: @"English"];
	    }
        }
      result = RETAIN(userLanguages);
      [classLock unlock];
    }
  NS_HANDLER
    {
      [classLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(result);
}

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
}

- (id) init
{
  return [self initWithUser: NSUserName()];
}

- (id) initWithUser: (NSString*)userName
{
  NSString	*path;

  path = [GSDefaultsRootForUser(userName)
    stringByAppendingPathComponent: defaultsFile];
  return [self initWithContentsOfFile: path];
}

- (id) initWithContentsOfFile: (NSString*)path
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSRange	r;
  BOOL		loadReadonly = NO;
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
#if	defined(__MINGW32__)
  if (r.length == 0)
    {
      r = [path rangeOfString: @":REGISTRY:"];
    }
#endif
  if (r.length == 0)
    {
      _defaultsDatabase = [[path stringByStandardizingPath] copy];
      path = [_defaultsDatabase stringByDeletingLastPathComponent];
      if ([mgr isWritableFileAtPath: path] == YES
	&& [mgr fileExistsAtPath: path isDirectory: &flag] == YES
	&& flag == YES
	&& [mgr fileExistsAtPath: _defaultsDatabase] == YES
	&& [mgr isReadableFileAtPath: _defaultsDatabase] == YES)
	{
	  _fileLock = [[NSDistributedLock alloc] initWithPath:
	    [_defaultsDatabase stringByAppendingPathExtension: @"lck"]];
	}
      else if ([mgr isReadableFileAtPath: _defaultsDatabase] == YES)
        {
	  loadReadonly = YES;
	}
    }

  _lock = [GSLazyRecursiveLock new];

  // Create an empty search list
  _searchList = [[NSMutableArray alloc] initWithCapacity: 10];

  if (loadReadonly == YES)
    {
      // Load read-only defaults.
      ASSIGN(_lastSync, [NSDateClass date]);
      ASSIGN(_persDomains, [self readDefaults]);
      updateCache(self);
      [[NSNotificationCenter defaultCenter]
	postNotificationName: NSUserDefaultsDidChangeNotification
		      object: self];
    }
  else
    {
      // Initialize _persDomains from the archived user defaults (persistent)
      _persDomains = [[NSMutableDictionaryClass alloc] initWithCapacity: 10];
      if ([self synchronize] == NO)
	{
	  DESTROY(self);
	  return self;
	}
    }

  // Check and if not existent add the Application and the Global domains
  if ([_persDomains objectForKey: processName] == nil)
    {
      [_persDomains
	setObject: [NSMutableDictionaryClass dictionaryWithCapacity: 10]
	forKey: processName];
      [self __changePersistentDomain: processName];
    }
  if ([_persDomains objectForKey: NSGlobalDomain] == nil)
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
  [_tempDomains setObject: GNUstepConfig(nil) forKey: GSConfigDomain];

  [[NSNotificationCenter defaultCenter] addObserver: self
           selector: @selector(synchronize)
               name: @"GSHousekeeping"
             object: nil];

  return self;
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
      [desc appendFormat: @" Persistant: %@", _persDomains];
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
  unsigned	index;

  if (aName == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to add suite with nil name"];
    }
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      if (self == sharedDefaults) invalidatedLanguages = YES;
      [_searchList removeObject: aName];
      index = [_searchList indexOfObject: processName];
      index = (index == NSNotFound) ? 0 : (index + 1);
      aName = [aName copy];
      [_searchList insertObject: aName atIndex: index];
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
          NSDictionary	*dict;
    
          dict = (*pImp)(_persDomains, objectForKeySel, dN);
          if (dict != nil && (object = [dict objectForKey: defaultName]))
	    break;
          dict = (*tImp)(_tempDomains, objectForKeySel, dN);
          if (dict != nil && (object = [dict objectForKey: defaultName]))
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
  id	obj;

  [_lock lock];
  NS_DURING
    {
      obj = [_persDomains objectForKey: processName];
      obj = [(NSDictionary*)obj objectForKey: defaultName];
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
  NSMutableDictionary	*dict;
  id			obj;

  if (value == nil)
    {
      [self removeObjectForKey: defaultName];
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
      DESTROY(_dictionaryRep);
      if (self == sharedDefaults) invalidatedLanguages = YES;
      RELEASE(_searchList);
      _searchList = [newList mutableCopy];
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
      copy = [[_persDomains objectForKey: domainName] copy];
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
      if ([_persDomains objectForKey: domainName])
        {
          [_persDomains removeObjectForKey: domainName];
          [self __changePersistentDomain: domainName];
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
      dict = [_tempDomains objectForKey: domainName];
      if (dict != nil)
        {
          [NSException raise: NSInvalidArgumentException
		      format: @"a volatile domain called %@ exists", domainName];
        }
      domain = [domain mutableCopy];
      [_persDomains setObject: domain forKey: domainName];
      RELEASE(domain);
      [self __changePersistentDomain: domainName];
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

  if (_fileLock == nil)
    {
      return NO;	// Database did not exist on startup.
    }
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

static BOOL isLocked = NO;
- (BOOL) lockDefaultsFile: (BOOL*)wasLocked
{
  BOOL	firstTime = NO;

  if (_fileLock == nil)
    {
      NSFileManager	*mgr;
      NSString		*path;
      unsigned		desired;
      NSDictionary	*attr;
      BOOL		isDir;

      path = [_defaultsDatabase stringByDeletingLastPathComponent];

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
	  if ([mgr createDirectoryAtPath: path attributes: attr] == NO)
	    {
	      NSLog(@"Defaults path '%@' does not exist - failed to create it.",
		path);
	      return NO;
	    }
	  else
	    {
	      NSLog(@"Defaults path '%@' did not exist - created it", path);
	      isDir = YES;
	    }
	}
      if (isDir == NO)
	{
	  NSLog(@"ERROR - Defaults path '%@' is not a directory!", path);
	  return NO;
	}
      _fileLock = [[NSDistributedLock alloc] initWithPath:
	[_defaultsDatabase stringByAppendingPathExtension: @"lck"]];
      firstTime = YES;
    }

  *wasLocked = isLocked;
  if (isLocked == NO && _fileLock != nil)
    {
      NSDate	*started = [NSDateClass date];

      while ([_fileLock tryLock] == NO)
	{
	  CREATE_AUTORELEASE_POOL(arp);
	  NSDate	*when;
	  NSDate	*lockDate;

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
	  RELEASE(arp);
	}
      isLocked = YES;

      if (firstTime == YES)
        {
	  NSFileManager	*mgr = [NSFileManager defaultManager];
	  NSDictionary	*attr;
	  uint32_t	desired;
	  uint32_t	attributes;

	  /*
	   * If the lock did not exist ... make sure the database exists.
	   */
	  if ([mgr isReadableFileAtPath: _defaultsDatabase] == NO)
	    {
	      NSDictionary	*empty = [NSDictionary new];

NSLog(@"Creating empty user defaults database");
	      /*
	       * Create empty database.
	       */
	      if (writeDictionary(empty, _defaultsDatabase) == NO)
		{
		  NSLog(@"Failed to create defaults database file %@",
		    _defaultsDatabase);
		}
	      RELEASE(empty);
	    }

	  attr = [mgr fileAttributesAtPath: _defaultsDatabase
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
		[mgr fileAttributesAtPath: _defaultsDatabase
			     traverseLink: YES]];

	      permissions = [NSNumberClass numberWithUnsignedLong: desired];
	      [enforced_attributes setObject: permissions
				      forKey: NSFilePosixPermissions];

	      [mgr changeFileAttributes: enforced_attributes
				 atPath: _defaultsDatabase];
	    }
        }
    }
   return YES;
}

- (void) unlockDefaultsFile
{
  NS_DURING
    {
      [_fileLock unlock];
    }
  NS_HANDLER
    {
      NSLog(@"Warning ... someone broke our lock (%@) ... and may have"
        @" interfered with updating defaults data in file.", 
        [_defaultsDatabase stringByAppendingPathExtension: @"lck"]);
    }
  NS_ENDHANDLER
  isLocked = NO;
}

- (NSMutableDictionary*) readDefaults
{
  NSMutableDictionary	*newDict = nil;

  // Read the changes if we have an external database file
  if (_defaultsDatabase != nil)
    {
      NSFileManager	*mgr = [NSFileManager defaultManager];

      if ([mgr isReadableFileAtPath: _defaultsDatabase] == YES)
	{
	  newDict = AUTORELEASE([[NSMutableDictionaryClass allocWithZone:
	    [self zone]] initWithContentsOfFile: _defaultsDatabase]);
	}
      if (newDict == nil)
	{
	  newDict = AUTORELEASE([[NSMutableDictionaryClass allocWithZone:
	    [self zone]] initWithCapacity: 10]);
	}
    }
  return newDict;
}

- (BOOL) writeDefaults: (NSDictionary*)defaults oldData: (NSDictionary*)oldData
{
  // Save the changes if we have an external database file
  if (_fileLock != nil)
    {
      return writeDictionary(defaults, _defaultsDatabase);
    }
  return YES;
}

- (BOOL) synchronize
{
  NSMutableDictionary	*newDict;
  BOOL			wasLocked;

  [_lock lock];
  NS_DURING
    {
      /*
       *	If we haven't changed anything, we only need to synchronise if
       *	the on-disk database has been changed by someone else.
       */
   
      if (_changedDomains == nil)
        {
          if ([self wantToReadDefaultsSince: _lastSync] == NO)
	    {
	      [_lock unlock];
	      NS_VALRETURN(YES);
	    }
        }

      DESTROY(_dictionaryRep);
      if (self == sharedDefaults)
        {
          invalidatedLanguages = YES;
        }
      
      if ([self lockDefaultsFile: &wasLocked] == NO)
        {
          [_lock unlock];
          NS_VALRETURN(NO);
        }
  
      newDict = [self readDefaults];
  
      if (newDict == nil)
        {
          if (wasLocked == NO)
	    {
	      [self unlockDefaultsFile];
	    }
          [_lock unlock];
          NS_VALRETURN(NO);
        }

      if (_changedDomains != nil)
        {           // Synchronize both dictionaries
          NSEnumerator	*enumerator = [_changedDomains objectEnumerator];
          NSString		*domainName;
          NSDictionary	*domain;
          NSDictionary	*oldData = AUTORELEASE([newDict copy]);

          DESTROY(_changedDomains);	// Retained by enumerator.
          while ((domainName = [enumerator nextObject]) != nil)
	    {
	      domain = [_persDomains objectForKey: domainName];
	      if (domain != nil)	// Domain was added or changed
	        {
	          [newDict setObject: domain forKey: domainName];
	        }
	      else			// Domain was removed
	        {
	          [newDict removeObjectForKey: domainName];
	        }
	    }
          ASSIGN(_persDomains, newDict);
          if ([self writeDefaults: _persDomains oldData: oldData] == NO)
	    {
	      if (wasLocked == NO)
	        {
	          [self unlockDefaultsFile];
	        }
	      [_lock unlock];
	      NS_VALRETURN(NO);
	    }
          ASSIGN(_lastSync, [NSDateClass date]);
        }
      else
        {
          ASSIGN(_lastSync, [NSDateClass date]);
          if ([_persDomains isEqual: newDict] == NO)
	    {
	      ASSIGN(_persDomains, newDict);
	      updateCache(self);
	      [[NSNotificationCenter defaultCenter]
	        postNotificationName: NSUserDefaultsDidChangeNotification
			      object: self];
	    }
        }

      if (wasLocked == NO)
        {
          [self unlockDefaultsFile];
        }
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return YES;
}


- (void) removeVolatileDomainForName: (NSString*)domainName
{
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      if (self == sharedDefaults) invalidatedLanguages = YES;
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
      if (self == sharedDefaults) invalidatedLanguages = YES;
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
  NSDictionary	*rep = nil;

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

          dictRep = [NSMutableDictionaryClass allocWithZone: NSDefaultMallocZone()];
          dictRep = [dictRep initWithCapacity: 512];
          addImp = [dictRep methodForSelector: addSel];

          while ((obj = (*nImp)(enumerator, nextObjectSel)) != nil)
	    {
	      if ((dict = (*pImp)(_persDomains, objectForKeySel, obj)) != nil
	        || (dict = (*tImp)(_tempDomains, objectForKeySel, obj)) != nil)
                {
                  (*addImp)(dictRep, addSel, dict);
                }
	    }
          _dictionaryRep = [dictRep makeImmutableCopyOnFail: NO];
        }
      rep = RETAIN(_dictionaryRep);
      [_lock unlock];
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return AUTORELEASE(rep);
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
      if (self == sharedDefaults) invalidatedLanguages = YES;
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
      if (self == sharedDefaults) invalidatedLanguages = YES;
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

/*************************************************************************
 *** Accessing the User Defaults database
 *************************************************************************/

- (NSDictionary*) __createArgumentDictionary
{
  NSArray	*args;
  NSEnumerator	*enumerator;
  NSMutableDictionary *argDict = nil;
  BOOL		done;
  id		key, val;

  [_lock lock];
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
	      else if ([val hasPrefix: @"-"] == YES && [val isEqual: @"-"] == NO)
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
    }
  NS_HANDLER
    {
      [_lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  return argDict;
}

- (void) __changePersistentDomain: (NSString*)domainName
{
  [_lock lock];
  NS_DURING
    {
      DESTROY(_dictionaryRep);
      if (self == sharedDefaults) invalidatedLanguages = YES;
      if (_changedDomains == nil)
        {
          _changedDomains = [[NSMutableArray alloc] initWithObjects: &domainName
							      count: 1];
          updateCache(self);
          [[NSNotificationCenter defaultCenter]
	    postNotificationName: NSUserDefaultsDidChangeNotification
		          object: self];
        }
      else if ([_changedDomains containsObject: domainName] == NO)
        {
          [_changedDomains addObject: domainName];
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
@end

BOOL
GSPrivateDefaultsFlag(GSUserDefaultFlagType type)
{
  if (sharedDefaults == nil)
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

