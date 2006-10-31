/* Interface for <NSUserDefaults> for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:   Georg Tuparev, EMBL & Academia Naturalis, 
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   
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

   $Date$ $Revision$
*/

#ifndef __NSUserDefaults_h_OBJECTS_INCLUDE
#define __NSUserDefaults_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSData;
@class NSTimer;
@class NSRecursiveLock;
@class NSDistributedLock;

/* Standard domains */

/**
 *  User defaults domain for process arguments.  Command-line arguments
 *  (attribute-value pairs, as in "-NSFoo bar") are placed into this domain.
 */
GS_EXPORT NSString* const NSArgumentDomain;

/**
 *  User defaults domain for system defaults.
 */
GS_EXPORT NSString* const NSGlobalDomain;

/**
 *  User defaults domain for application-registered "default defaults".
 */
GS_EXPORT NSString* const NSRegistrationDomain;

#ifndef NO_GNUSTEP
/**
 *  User defaults domain for GNUstep config file.
 */
GS_EXPORT NSString* const GSConfigDomain;
#endif


/* Public notification */

/**
 *  Notification posted when a defaults synchronize has been performed (see
 *  [NSUserDefaults-synchronize]) and changes have been loaded in from disk.
 */
GS_EXPORT NSString* const NSUserDefaultsDidChangeNotification;

/* Backwards compatibility */
#define	NSUserDefaultsChanged NSUserDefaultsDidChangeNotification

/* Keys for language-dependent information */

/** Key for locale dictionary: names of days of week. */
GS_EXPORT NSString* const NSWeekDayNameArray;

/** Key for locale dictionary: abbreviations of days of week. */
GS_EXPORT NSString* const NSShortWeekDayNameArray;

/** Key for locale dictionary: names of months of year. */
GS_EXPORT NSString* const NSMonthNameArray;

/** Key for locale dictionary: abbreviations of months of year. */
GS_EXPORT NSString* const NSShortMonthNameArray;

/** Key for locale dictionary: format string for feeding to [NSDateFormatter].*/
GS_EXPORT NSString* const NSTimeFormatString;

/** Key for locale dictionary: format string for feeding to [NSDateFormatter].*/
GS_EXPORT NSString* const NSDateFormatString;

/** Key for locale dictionary: format string for feeding to [NSDateFormatter].*/
GS_EXPORT NSString* const NSShortDateFormatString;

/** Key for locale dictionary: format string for feeding to [NSDateFormatter].*/
GS_EXPORT NSString* const NSTimeDateFormatString;

/** Key for locale dictionary: format string for feeding to [NSDateFormatter].*/
GS_EXPORT NSString* const NSShortTimeDateFormatString;

/** Key for locale dictionary: currency symbol. */
GS_EXPORT NSString* const NSCurrencySymbol;

/** Key for locale dictionary: decimal separator. */
GS_EXPORT NSString* const NSDecimalSeparator;

/** Key for locale dictionary: thousands separator. */
GS_EXPORT NSString* const NSThousandsSeparator;

/** Key for locale dictionary: three-letter ISO 4217 currency abbreviation. */
GS_EXPORT NSString* const NSInternationalCurrencyString;

/** Key for locale dictionary: text formatter string for monetary amounts. */
GS_EXPORT NSString* const NSCurrencyString;

/** Key for locale dictionary: array of strings for 0-9. */
GS_EXPORT NSString* const NSDecimalDigits;

/** Key for locale dictionary: array of strings for AM and PM. */
GS_EXPORT NSString* const NSAMPMDesignation;

#ifndef	STRICT_OPENSTEP

/**
 *  Array of arrays of NSStrings, first member of each specifying a time,
 *  followed by one or more colloquial names for the time, as in "(0,
 *  midnight), (12, noon, lunch)".
 */
GS_EXPORT NSString* const NSHourNameDesignations;

/** Strings for "year", "month", "week". */
GS_EXPORT NSString* const NSYearMonthWeekDesignations;

/** Key for locale dictionary: adjectives that modify values in
    NSYearMonthWeekDesignations, as in "last", "previous", etc.. */
GS_EXPORT NSString* const NSEarlierTimeDesignations;

/** Key for locale dictionary: adjectives that modify values in
    NSYearMonthWeekDesignations, as in "next", "subsequent", etc.. */
GS_EXPORT NSString* const NSLaterTimeDesignations;

/** Key for locale dictionary: one or more strings designating the current
    day, such as "today". */
GS_EXPORT NSString* const NSThisDayDesignations;

/** Key for locale dictionary: one or more strings designating the next
    day, such as "tomorrow". */
GS_EXPORT NSString* const NSNextDayDesignations;

/** Key for locale dictionary: one or more strings designating the next
    day, such as "day after tomorrow". */
GS_EXPORT NSString* const NSNextNextDayDesignations;

/** Key for locale dictionary: one or more strings designating the previous
    day, such as "yesterday". */
GS_EXPORT NSString* const NSPriorDayDesignations;

/** Key for locale dictionary: string with 'Y', 'M', 'D', and 'H' designating
    the default method of writing dates, as in "MDYH" for the U.S.. */
GS_EXPORT NSString* const NSDateTimeOrdering;

/** Key for locale dictionary: name of language. */
GS_EXPORT NSString* const NSLanguageName;

/** Key for locale dictionary: two-letter ISO code. */
GS_EXPORT NSString* const NSLanguageCode;

/** Key for locale dictionary: formal name of language. */
GS_EXPORT NSString* const NSFormalName;
#ifndef NO_GNUSTEP
/** Key for locale dictionary: name of locale. */
GS_EXPORT NSString* const NSLocale;
#endif
#endif

/* General implementation notes: 

   OpenStep spec currently is neither complete nor consistent. Therefore
   we had to make several implementation decisions which may vary in
   other OpenStep implementations.
  
  - We add a new instance method initWithFile:  as a designated 
    initialization method because it allows to create user defaults
    database from a "default user" and also it will work for various 
    non-posix implementations. 

  - We add two new class methods for getting and setting a list of 
    user languages (userLanguages and setUserLanguages: ). They are 
    somehow equivalent to the NS3.x Application's systemLanguages 
    method.

  - Definition of argument (command line parameters)
  	(-GSxxxx || --GSxxx) [value]
	
    Note:  As far as I know, there is nothing like home directory for 
    the M$ hell. God help the Win95/WinNT users of NSUserDefaults ;-)
  
  To Do: 
	- polish & optimize;
	- when tested, fix NSBundle (the system languages stuff);
	- write docs : -(
	*/

@interface NSUserDefaults:  NSObject
{
@private
  NSMutableArray	*_searchList;    // Current search list;
  NSMutableDictionary	*_persDomains;   // Contains persistent defaults info;
  NSMutableDictionary	*_tempDomains;   // Contains volatile defaults info;
  NSMutableArray	*_changedDomains; /* ..after first time that persistent 
					    user defaults are changed */
  NSDictionary		*_dictionaryRep; // Cached dictionary representation
  NSString		*_defaultsDatabase;
  NSDate		*_lastSync;
  NSRecursiveLock	*_lock;
  NSDistributedLock	*_fileLock;
}

/* Getting the Shared Instance */
+ (NSUserDefaults*) standardUserDefaults;
#ifndef	STRICT_OPENSTEP
/*
 * Called by GSSetUserName() to get the defaults system to use the defaults
 * of a new user.
 */
+ (void) resetStandardUserDefaults;
#endif
#ifndef	STRICT_OPENSTEP
#ifndef	STRICT_MACOS_X
+ (NSArray*) userLanguages;
+ (void) setUserLanguages: (NSArray*)languages;
#endif
#endif

/* Initializing the User Defaults */
- (id) init;
- (id) initWithUser: (NSString*)userName;
- (id) initWithContentsOfFile: (NSString*)path;     // This is a new method

/* Getting and Setting a Default */
- (NSArray*) arrayForKey: (NSString*)defaultName;
- (BOOL) boolForKey: (NSString*)defaultName;
- (NSData*) dataForKey: (NSString*)defaultName;
- (NSDictionary*) dictionaryForKey: (NSString*)defaultName;
- (float) floatForKey: (NSString*)defaultName;
- (int) integerForKey: (NSString*)defaultName;
- (id) objectForKey: (NSString*)defaultName;
- (void) removeObjectForKey: (NSString*)defaultName;
- (void) setBool: (BOOL)value forKey: (NSString*)defaultName;
- (void) setFloat: (float)value forKey: (NSString*)defaultName;
- (void) setInteger: (int)value forKey: (NSString*)defaultName;
- (void) setObject: (id)value forKey: (NSString*)defaultName;
- (NSArray*) stringArrayForKey: (NSString*)defaultName;
- (NSString*) stringForKey: (NSString*)defaultName;

/* Returning the Search List */
- (NSArray*) searchList;
- (void) setSearchList: (NSArray*)newList;
#ifndef	STRICT_OPENSTEP
- (void) addSuiteNamed: (NSString*)aName;
- (void) removeSuiteNamed: (NSString*)aName;
#endif

/* Maintaining Persistent Domains */
- (NSDictionary*) persistentDomainForName: (NSString*)domainName;
- (NSArray*) persistentDomainNames;
- (void) removePersistentDomainForName: (NSString*)domainName;
- (void) setPersistentDomain: (NSDictionary*)domain 
        forName: (NSString*)domainName;
- (BOOL) synchronize;

/* Maintaining Volatile Domains */
- (void) removeVolatileDomainForName: (NSString*)domainName;
- (void) setVolatileDomain: (NSDictionary*)domain 
        forName: (NSString*)domainName;
- (NSDictionary*) volatileDomainForName: (NSString*)domainName;
- (NSArray*) volatileDomainNames;

/* Making Advanced Use of Defaults */
- (NSDictionary*) dictionaryRepresentation;
- (void) registerDefaults: (NSDictionary*)newVals;
@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSUserDefaults_h_OBJECTS_INCLUDE */
