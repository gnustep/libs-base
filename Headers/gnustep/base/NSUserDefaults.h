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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __NSUserDefaults_h_OBJECTS_INCLUDE
#define __NSUserDefaults_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSData;
@class NSTimer;
@class NSRecursiveLock;

/* Standard domains */
GS_EXPORT NSString* const NSArgumentDomain;
GS_EXPORT NSString* const NSGlobalDomain;
GS_EXPORT NSString* const NSRegistrationDomain;

/* Public notification */
GS_EXPORT NSString* const NSUserDefaultsDidChangeNotification;
/* Backwards compatibility */
#define	NSUserDefaultsChanged NSUserDefaultsDidChangeNotification

/* Keys for language-dependent information */
GS_EXPORT NSString* const NSWeekDayNameArray;
GS_EXPORT NSString* const NSShortWeekDayNameArray;
GS_EXPORT NSString* const NSMonthNameArray;
GS_EXPORT NSString* const NSShortMonthNameArray;
GS_EXPORT NSString* const NSTimeFormatString;
GS_EXPORT NSString* const NSDateFormatString;
GS_EXPORT NSString* const NSShortDateFormatString;
GS_EXPORT NSString* const NSTimeDateFormatString;
GS_EXPORT NSString* const NSShortTimeDateFormatString;
GS_EXPORT NSString* const NSCurrencySymbol;
GS_EXPORT NSString* const NSDecimalSeparator;
GS_EXPORT NSString* const NSThousandsSeparator;
GS_EXPORT NSString* const NSInternationalCurrencyString;
GS_EXPORT NSString* const NSCurrencyString;
GS_EXPORT NSString* const NSDecimalDigits;
GS_EXPORT NSString* const NSAMPMDesignation;

#ifndef	STRICT_OPENSTEP
GS_EXPORT NSString* const NSHourNameDesignations;
GS_EXPORT NSString* const NSYearMonthWeekDesignations;
GS_EXPORT NSString* const NSEarlierTimeDesignations;
GS_EXPORT NSString* const NSLaterTimeDesignations;
GS_EXPORT NSString* const NSThisDayDesignations;
GS_EXPORT NSString* const NSNextDayDesignations;
GS_EXPORT NSString* const NSNextNextDayDesignations;
GS_EXPORT NSString* const NSPriorDayDesignations;
GS_EXPORT NSString* const NSDateTimeOrdering;

GS_EXPORT NSString* const NSLanguageName;
GS_EXPORT NSString* const NSLanguageCode;
GS_EXPORT NSString* const NSFormalName;
#ifndef NO_GNUSTEP
GS_EXPORT NSString* const NSLocale;
#endif
#endif

/* General implementation notes: 

   OpenStep spec currently is either complete nor consitent. Therefor
   we had to take several implementation decisions which make vary in
   different OpenStep implementations.
  
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
	- ask somebody to test it for M$;
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
  NSTimer		*_tickingTimer;   // for synchronization
  NSRecursiveLock	*_lock;
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
- (NSMutableArray*) searchList;
- (void)setSearchList: (NSArray*)newList;

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

#endif /* __NSUserDefaults_h_OBJECTS_INCLUDE */
