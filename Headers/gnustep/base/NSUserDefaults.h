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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#ifndef __NSUserDefaults_h_OBJECTS_INCLUDE
#define __NSUserDefaults_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDistributedLock.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSData;
@class NSTimer;

/* Standard domains */
extern NSString* const NSArgumentDomain;
extern NSString* const NSGlobalDomain;
extern NSString* const NSRegistrationDomain;

/* Public notification */
extern NSString* const NSUserDefaultsDidChangeNotification;
/* Backwards compatibility */
#define	NSUserDefaultsChanged NSUserDefaultsDidChangeNotification

/* Keys for language-dependent information */
extern NSString* const NSWeekDayNameArray;
extern NSString* const NSShortWeekDayNameArray;
extern NSString* const NSMonthNameArray;
extern NSString* const NSShortMonthNameArray;
extern NSString* const NSTimeFormatString;
extern NSString* const NSDateFormatString;
extern NSString* const NSTimeDateFormatString;
extern NSString* const NSShortTimeDateFormatString;
extern NSString* const NSCurrencySymbol;
extern NSString* const NSDecimalSeparator;
extern NSString* const NSThousandsSeparator;
extern NSString* const NSInternationalCurrencyString;
extern NSString* const NSCurrencyString;
extern NSString* const NSDecimalDigits;
extern NSString* const NSAMPMDesignation;

#ifndef	STRICT_OPENSTEP
extern NSString* const NSHourNameDesignations;
extern NSString* const NSYearMonthWeekDesignations;
extern NSString* const NSEarlierTimeDesignations;
extern NSString* const NSLaterTimeDesignations;
extern NSString* const NSThisDayDesignations;
extern NSString* const NSNextDayDesignations;
extern NSString* const NSNextNextDayDesignations;
extern NSString* const NSPriorDayDesignations;
extern NSString* const NSDateTimeOrdering;
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
  	- Add writeToFile:  instance method;
	- implement the description method;
	- test for UNIX  (write test app);
	- ask somebody to test it for M$;
	- polish & optimize;
	- when tested, fix NSBundle (the system languages stuff);
	- write docs : -(
	*/

@interface NSUserDefaults:  NSObject
{
@private
  NSMutableArray	*searchList;    // Current search list;
  NSMutableDictionary	*persDomains;   // Contains persistent defaults info;
  NSMutableDictionary	*tempDomains;   // Contains volatile defaults info;
  NSMutableArray	*changedDomains; /* ..after first time that persistent 
					    user defaults are changed */
  NSDictionary		*dictionaryRep;	// Cached dictionary representation
  NSMutableString	*defaultsDatabase;
  NSMutableString	*defaultsDatabaseLockName;
  NSDistributedLock	*defaultsDatabaseLock;
  NSTimer		*tickingTimer;   // for synchronization
}

/* Getting the Shared Instance */
+ (NSUserDefaults*) standardUserDefaults;
#ifndef	NO_GNUSTEP
/*
 * Called by GSSetUserName() to get the defaults system to use the defaults
 * of a new user.
 */
+ (void) resetUserDefaults;
#endif
+ (NSArray*) userLanguages;
+ (void) setUserLanguages: (NSArray*)languages;

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
- (void) registerDefaults: (NSDictionary*)dictionary;
@end

#endif /* __NSUserDefaults_h_OBJECTS_INCLUDE */
