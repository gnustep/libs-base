/* Implementation for NSUserDefaults for GNUstep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL & Academia Naturalis, 
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

#include <config.h>
#include <base/preface.h>
#if 0 
/* My Linux doesn't have <libc.h>.  Why is this necessary? 
   What is a work-around that will work for all?  -mccallum*/
#include <libc.h>
/* If POSIX then:  #include <unistd.h> */
#endif /* 0 */
#if	!defined(__WIN32__)
#include <pwd.h>
#endif
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
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSRunLoop.h>

/* Wait for access */
#define _MAX_COUNT 5          /* Max 10 sec. */

/* User's Defauls database */
static NSString* GNU_UserDefaultsDatabase = @"GNUstep/.GNUstepDefaults";
static NSString* GNU_UserDefaultsDatabaseLock = @"GNUstep/.GNUstepUDLock";

/*************************************************************************
 *** Local method definitions
 *************************************************************************/
@interface NSUserDefaults (__local_NSUserDefaults)
- (void)__createStandardSearchList;
- (NSDictionary *)__createArgumentDictionary;
- (void)__changePersistentDomain: (NSString *)domainName;
- (void)__timerTicked: (NSTimer*)tim;
@end

@implementation NSUserDefaults: NSObject
/*************************************************************************
 *** Class variables
 *************************************************************************/
static NSUserDefaults    *sharedDefaults = nil;
static NSMutableString   *processName = nil;

/*************************************************************************
 *** Getting the Shared Instance
 *************************************************************************/
static BOOL setSharedDefaults = NO;	/* Flag to prevent infinite recursion */

+ (void) resetUserDefaults
{
  id	defs = sharedDefaults;

  setSharedDefaults = NO;
  sharedDefaults = nil;
  RELEASE(defs);
}

+ (NSUserDefaults *)standardUserDefaults
  /*
    Returns the shared defaults object. If it doesn't exist yet, it's
    created. The defaults are initialized for the current user.
    The search list is guaranteed to be standard only the first time 
    this method is invoked. The shared instance is provided as a 
    convenience; other instances may also be created.
    */
{
  if (setSharedDefaults)
    return sharedDefaults;
  setSharedDefaults = YES;
  // Create new sharedDefaults (NOTE: Not added to the autorelease pool!)
  sharedDefaults = [[self alloc] init];
	
  [sharedDefaults __createStandardSearchList];

  if (sharedDefaults)
    {
      NSUserDefaults	*defs;
      NSDictionary	*registrationDefaults;
      NSArray		*ampm;
      NSArray		*long_day;
      NSArray		*long_month;
      NSArray		*short_day;
      NSArray		*short_month;
      NSArray		*earlyt;
      NSArray		*latert;
      NSArray		*hour_names;
      NSArray		*ymw_names;

      defs = [NSUserDefaults standardUserDefaults];
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
      latert = [NSArray arrayWithObjects: 
					  @"next",
					  nil];
      ymw_names = [NSArray arrayWithObjects: 
					      @"year",
					      @"month",
					      @"week",
					      nil];
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
		@"tomorrow", NSNextDayDesignations,
		@"nextday", NSNextNextDayDesignations,
		@"yesterday", NSPriorDayDesignations,
		@"today", NSThisDayDesignations,
		earlyt, NSEarlierTimeDesignations,
		latert, NSLaterTimeDesignations,
		hour_names, NSHourNameDesignations,
		ymw_names, NSYearMonthWeekDesignations,
		nil];
      [sharedDefaults registerDefaults: registrationDefaults];
    }
  else
    {
      NSLog(@"WARNING - unable to create shared user defaults!\n");
    }
  return sharedDefaults;
}


+ (NSArray *)userLanguages
{
  NSMutableArray *uL = [NSMutableArray arrayWithCapacity: 5];
  NSArray *currLang = [[self standardUserDefaults] 
			stringArrayForKey: @"Languages"];
  NSEnumerator *enumerator;
  id obj;
	
  if (!currLang)
    {                    // Try to build it from the env 
      const char *env_list;
      NSString *env;
      env_list = getenv("LANGUAGES");
      if (env_list)
	{
	  env = [NSString stringWithCString: env_list];
	  currLang = RETAIN([env componentsSeparatedByString: @";"]);
	}
    }
  if (currLang)
    [uL addObjectsFromArray: currLang];

  // Check if "English" is includet
  enumerator = [uL objectEnumerator];
  while ((obj = [enumerator nextObject]))
    {
      if ([obj isEqualToString: @"English"])
	return uL;
    }
  [uL addObject: @"English"];
	
  return uL;
}

+ (void)setUserLanguages: (NSArray *)languages
{
  NSMutableDictionary *globDict = [[self standardUserDefaults] 
				    persistentDomainForName: NSGlobalDomain];
	
  if (!languages)          // Remove the entry
    [globDict removeObjectForKey: @"Languages"];
  else
    [globDict setObject: languages forKey: @"Languages"];
  [[self standardUserDefaults] 
    setPersistentDomain: globDict forName: NSGlobalDomain];
  return;
}

/*************************************************************************
 *** Initializing the User Defaults
 *************************************************************************/
- (id)init
  /* Initializes defaults for current user calling initWithUser: . */
{
  return [self initWithUser: NSUserName()];
}

/* Initializes defaults for the specified user calling initWithFile: . */
- (id)initWithUser: (NSString *)userName
{
  NSString* userHome = NSHomeDirectoryForUser(userName);
  NSString *filename;
	
  // Either userName is empty or it's wrong
  if (!userHome)
    {  
      RELEASE(self);
      return nil;
    }
  filename = [NSString stringWithFormat: @"%@/%@",
	userHome, GNU_UserDefaultsDatabase];
  return [self initWithContentsOfFile: filename];
}

- (id)initWithContentsOfFile: (NSString *)path
  /* Initializes defaults for the specified path. Returns an object with 
     an empty search list. */
{
  [super init];
	
  // Find the user's home folder and build the paths (executed only once)
  if (!_defaultsDatabase)
    {
      if (path != nil && [path isEqual: @""] == NO)
        _defaultsDatabase = (NSMutableString*)[path mutableCopy];
      else
	{
	  _defaultsDatabase =
	    (NSMutableString*)[NSMutableString stringWithFormat: @"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabase];
	  RETAIN(_defaultsDatabase);
	}

      if ([[_defaultsDatabase lastPathComponent] isEqual: 
	[GNU_UserDefaultsDatabase lastPathComponent]] == YES)
	_defaultsDatabaseLockName =
	  (NSMutableString*)[NSMutableString stringWithFormat: @"%@/%@",
			  [_defaultsDatabase stringByDeletingLastPathComponent],
			  [GNU_UserDefaultsDatabaseLock lastPathComponent]];
      else
        _defaultsDatabaseLockName =
	  (NSMutableString*)[NSMutableString stringWithFormat: @"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabaseLock];
      RETAIN(_defaultsDatabaseLockName);
      _defaultsDatabaseLock =
	RETAIN([NSDistributedLock lockWithPath: _defaultsDatabaseLockName]);
  }
  if (processName == nil)
    processName = RETAIN([[NSProcessInfo processInfo] processName]);

  // Create an empty search list
  _searchList = [[NSMutableArray alloc] initWithCapacity: 10];
	
  // Initialize _persDomains from the archived user defaults (persistent)
  _persDomains = [[NSMutableDictionary alloc] initWithCapacity: 10];
  if ([self synchronize] == NO)
    {
      NSRunLoop	*runLoop = [NSRunLoop currentRunLoop];
      BOOL	done = NO;
      int	attempts;

      // Retry for a couple of seconds in case we are locked out.
      for (attempts = 0; done == NO && attempts < 10; attempts++)
	{
	  [runLoop runMode: [runLoop currentMode]
		beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
	  if ([self synchronize] == YES)
	    done = YES;
        }
      if (done == NO)
	{
          RELEASE(self);
          return self = nil;
        }
    }
	
  // Check and if not existent add the Application and the Global domains
  if (![_persDomains objectForKey: processName])
    {
      [_persDomains setObject: 
		     [NSMutableDictionary 
		       dictionaryWithCapacity: 10] forKey: processName];
      [self __changePersistentDomain: processName];
    }
  if (![_persDomains objectForKey: NSGlobalDomain])
    {
      [_persDomains setObject: 
		   [NSMutableDictionary 
		     dictionaryWithCapacity: 10] forKey: NSGlobalDomain];
      [self __changePersistentDomain: NSGlobalDomain];
    }
	
  // Create volatile defaults and add the Argument and the Registration domains
  _tempDomains = [[NSMutableDictionary alloc] initWithCapacity: 10];
  [_tempDomains setObject: [self __createArgumentDictionary] 
	       forKey: NSArgumentDomain];
  [_tempDomains setObject: 
		 [NSMutableDictionary
		   dictionaryWithCapacity: 10] forKey: NSRegistrationDomain];
	
  return self;
}

- (void)dealloc
{
  if (_tickingTimer)
    [_tickingTimer invalidate];
  RELEASE(_lastSync);
  RELEASE(_searchList);
  RELEASE(_persDomains);
  RELEASE(_tempDomains);
  RELEASE(_changedDomains);
  RELEASE(_dictionaryRep);
  [super dealloc];
}

- (NSString *)description
{
  NSMutableString *desc =
    [NSMutableString stringWithFormat: @"%@",[super description]];

  // $$$ Not Implemented
  // It's good idea to put all useful info here -- so I can test it later
  [self notImplemented: _cmd];
  return desc;
}

/*************************************************************************
 *** Getting and Setting a Default
 *************************************************************************/
- (NSArray *)arrayForKey: (NSString *)defaultName
{
  id obj = [self objectForKey: defaultName];
	
  if (obj && [obj isKindOfClass: [NSArray class]])
    return obj;
  return nil;
}

- (BOOL)boolForKey: (NSString *)defaultName
{
  id obj = [self stringForKey: defaultName];
	
  if (obj)
    return [obj boolValue];
  return NO;
}

- (NSData *)dataForKey: (NSString *)defaultName
{
  id obj = [self objectForKey: defaultName];
	
  if (obj && [obj isKindOfClass: [NSData class]])
    return obj;
  return nil;
}

- (NSDictionary *)dictionaryForKey: (NSString *)defaultName
{
  id obj = [self objectForKey: defaultName];
	
  if (obj && [obj isKindOfClass: [NSDictionary class]])
    return obj;
  return nil;
}

- (float)floatForKey: (NSString *)defaultName
{
  id obj = [self stringForKey: defaultName];
	
  if (obj)
    return [obj floatValue];
  return 0.0;
}

- (int)integerForKey: (NSString *)defaultName
{
  id obj = [self stringForKey: defaultName];
	
  if (obj)
    return [obj intValue];
  return 0;
}

- (id)objectForKey: (NSString *)defaultName
{
  NSEnumerator *enumerator = [_searchList objectEnumerator];
  id object = nil;
  id dN;
	
  while ((dN = [enumerator nextObject]))
    {
      id dict;
      
      dict = [_persDomains objectForKey: dN];
      if (dict && (object = [dict objectForKey: defaultName]))
	break;
      dict = [_tempDomains objectForKey: dN];
      if (dict && (object = [dict objectForKey: defaultName]))
	break;
    }
	
  return object;
}

- (void)removeObjectForKey: (NSString *)defaultName
{
  id obj = [[_persDomains objectForKey: processName] objectForKey: defaultName];
	
  if (obj)
    {
      id	obj = [_persDomains objectForKey: processName];
      NSMutableDictionary *dict;

      if ([obj isKindOfClass: [NSMutableDictionary class]] == YES)
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
  return;
}

- (void)setBool: (BOOL)value forKey: (NSString *)defaultName
{
  id obj = (value)?@"YES": @"NO";
	
  [self setObject: obj forKey: defaultName];
  return;
}

- (void)setFloat: (float)value forKey: (NSString *)defaultName
{	
  char buf[32];
  sprintf(buf,"%g",value);
  [self setObject: [NSString stringWithCString: buf] forKey: defaultName];
  return;
}

- (void)setInteger: (int)value forKey: (NSString *)defaultName
{
  char buf[32];
  sprintf(buf,"%d",value);
  [self setObject: [NSString stringWithCString: buf] forKey: defaultName];
  return;
}

- (void)setObject: (id)value forKey: (NSString *)defaultName
{
  if (value && defaultName && ([defaultName length] > 0))
    {
      id	obj = [_persDomains objectForKey: processName];
      NSMutableDictionary *dict;

      if ([obj isKindOfClass: [NSMutableDictionary class]] == YES)
	{
	  dict = obj;
	}
      else
	{
	  dict = [obj mutableCopy];
	  [_persDomains setObject: dict forKey: processName];
	}
      [dict setObject: value forKey: defaultName];
      [self __changePersistentDomain: processName];
    }
  return;
}

- (NSArray *)stringArrayForKey: (NSString *)defaultName
{
  id arr = [self arrayForKey: defaultName];
	
  if (arr)
    {
      NSEnumerator *enumerator = [arr objectEnumerator];
      id obj;
		
      while ((obj = [enumerator nextObject]))
	if ( ! [obj isKindOfClass: [NSString class]])
	  return nil;
      return arr;
    }
  return nil;
}

- (NSString *)stringForKey: (NSString *)defaultName
{
  id obj = [self objectForKey: defaultName];
	
  if (obj && [obj isKindOfClass: [NSString class]])
    return obj;
  return nil;
}

/*************************************************************************
 *** Returning the Search List
 *************************************************************************/
- (NSMutableArray *)searchList
{
  return _searchList;
}

- (void)setSearchList: (NSArray*)newList
{
  DESTROY(_dictionaryRep);
  RELEASE(_searchList);
  _searchList = [newList mutableCopy];
}

/*************************************************************************
 *** Maintaining Persistent Domains
 *************************************************************************/
- (NSDictionary *)persistentDomainForName: (NSString *)domainName
{
  return [[_persDomains objectForKey: domainName] copy];
}

- (NSArray *)persistentDomainNames
{
  return [_persDomains allKeys];
}

- (void)removePersistentDomainForName: (NSString *)domainName
{
  if ([_persDomains objectForKey: domainName])
    {
      [_persDomains removeObjectForKey: domainName];
      [self __changePersistentDomain: domainName];
    }
  return;
}

- (void)setPersistentDomain: (NSDictionary *)domain 
		    forName: (NSString *)domainName
{
  id dict = [_tempDomains objectForKey: domainName];
	
  if (dict)
    {
      [NSException raise: NSInvalidArgumentException 
		   format: @"Volatile domain with %@ already exists",
		   domainName];
      return;
    }
  [_persDomains setObject: domain forKey: domainName];
  [self __changePersistentDomain: domainName];
  return;
}

- (BOOL) synchronize
{
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSMutableDictionary	*newDict = nil;
  NSDictionary		*attr;
  NSDate		*mod;

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
  if (_changedDomains == NO)
    {
      BOOL		wantRead = NO;

      if (_lastSync == nil)
	wantRead = YES;
      else
	{
	  attr = [mgr fileAttributesAtPath: _defaultsDatabase
			      traverseLink: YES];
	  if (attr == nil)
	    wantRead = YES;
	  else
	    {
	      mod = [attr objectForKey: NSFileModificationDate];
	      if ([_lastSync earlierDate: mod] != _lastSync)
		wantRead = YES;
	    }
	}
      if (wantRead == NO)
	return YES;
    }

  /*
   * Get file lock - break any lock that is more than five minute old.
   */
  if ([_defaultsDatabaseLock tryLock] == NO)
    {
      if ([[_defaultsDatabaseLock lockDate] timeIntervalSinceNow] < -300.0)
	{
	  [_defaultsDatabaseLock breakLock];
	  if ([_defaultsDatabaseLock tryLock] == NO)
	    {
	      return NO;
	    }
	}
      else
	{
	  return NO;
	}
    }
	
  DESTROY(_dictionaryRep);

  // Read the persistent data from the stored database
  if ([mgr fileExistsAtPath: _defaultsDatabase])
    {
      newDict = [[NSMutableDictionary allocWithZone: [self zone]]
        initWithContentsOfFile: _defaultsDatabase];
    }
  else
    {
      attr = [NSDictionary dictionaryWithObjectsAndKeys: 
		NSUserName(), NSFileOwnerAccountName, nil];
      NSLog(@"Creating defaults database file %@", _defaultsDatabase);
      [mgr createFileAtPath: _defaultsDatabase
		   contents: nil
		 attributes: attr];
      [[NSDictionary dictionary] writeToFile: _defaultsDatabase atomically: YES];
    }

  if (!newDict)
    {
      newDict = [[NSMutableDictionary allocWithZone: [self zone]]
		  initWithCapacity: 1];
    }

  if (_changedDomains)
    {           // Synchronize both dictionaries
      NSEnumerator *enumerator = [_changedDomains objectEnumerator];
      id obj, dict;
		
      while ((obj = [enumerator nextObject]))
	{
	  dict = [_persDomains objectForKey: obj];
	  if (dict)       // Domain was added or changet
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
	  [_defaultsDatabaseLock unlock];
	  return NO;
	}
      attr = [mgr fileAttributesAtPath: _defaultsDatabase
			  traverseLink: YES];
      mod = [attr objectForKey: NSFileModificationDate];
      ASSIGN(_lastSync, mod);
      [_defaultsDatabaseLock unlock];	// release file lock
    }
  else
    {
      attr = [mgr fileAttributesAtPath: _defaultsDatabase
			  traverseLink: YES];
      mod = [attr objectForKey: NSFileModificationDate];
      ASSIGN(_lastSync, mod);
      [_defaultsDatabaseLock unlock];	// release file lock
      if ([_persDomains isEqual: newDict] == NO)
	{
	  RELEASE(_persDomains);
	  _persDomains = newDict;
	  [[NSNotificationCenter defaultCenter] 
	    postNotificationName: NSUserDefaultsDidChangeNotification
			  object: nil];
	}
      else
	{
	  RELEASE(newDict);
	}
    }

  return YES;
}


/*************************************************************************
 *** Maintaining Volatile Domains
 *************************************************************************/
- (void)removeVolatileDomainForName: (NSString *)domainName
{
  DESTROY(_dictionaryRep);
  [_tempDomains removeObjectForKey: domainName];
}

- (void)setVolatileDomain: (NSDictionary *)domain 
		  forName: (NSString *)domainName
{
  id dict = [_persDomains objectForKey: domainName];
	
  if (dict)
    {
      [NSException raise: NSInvalidArgumentException 
		   format: @"Persistent domain with %@ already exists",
		   domainName];
      return;
    }
  DESTROY(_dictionaryRep);
  [_tempDomains setObject: domain forKey: domainName];
  return;
}

- (NSDictionary *)volatileDomainForName: (NSString *)domainName
{
  return [_tempDomains objectForKey: domainName];
}

- (NSArray *)volatileDomainNames
{
  return [_tempDomains allKeys];
}

/*************************************************************************
 *** Making Advanced Use of Defaults
 *************************************************************************/
- (NSDictionary *) dictionaryRepresentation
{
  if (_dictionaryRep == nil)
    {
      NSEnumerator		*enumerator;
      NSMutableDictionary	*dictRep;
      id obj;
      id dict;
	
      enumerator = [_searchList reverseObjectEnumerator];
      dictRep = [NSMutableDictionary allocWithZone: NSDefaultMallocZone()];
      dictRep = [dictRep initWithCapacity: 512];
      while ((obj = [enumerator nextObject]))
	{
	  if ( (dict = [_persDomains objectForKey: obj])
	       || (dict = [_tempDomains objectForKey: obj]) )
	    [dictRep addEntriesFromDictionary: dict];
	}
      _dictionaryRep = [dictRep copy];
      RELEASE(dictRep);
    }
  return _dictionaryRep;
}

- (void) registerDefaults: (NSDictionary*)newVals
{
  NSMutableDictionary	*regDefs;

  regDefs = [_tempDomains objectForKey: NSRegistrationDomain];
  if (regDefs == nil)
    {
      regDefs = [NSMutableDictionary dictionaryWithCapacity: [newVals count]];
    }
  DESTROY(_dictionaryRep);
  [regDefs addEntriesFromDictionary: newVals];
}

/*************************************************************************
 *** Accessing the User Defaults database
 *************************************************************************/
- (void)__createStandardSearchList
{
  NSArray *uL = [[self class] userLanguages];
  NSEnumerator *enumerator = [uL objectEnumerator];
  id object;
	
  // Note: The search list should exist!
	
  // 1. NSArgumentDomain
  [_searchList addObject: NSArgumentDomain];
	
  // 2. Application
  [_searchList addObject: processName];

  // 3. User's preferred languages
  while ((object = [enumerator nextObject]))
    {
      [_searchList addObject: object];
    }
	
  // 4. NSGlobalDomain
  [_searchList addObject: NSGlobalDomain];
	
  // 5. NSRegistrationDomain
  [_searchList addObject: NSRegistrationDomain];
	
  return;
}

- (NSDictionary *)__createArgumentDictionary
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];
  //$$$	NSArray *args = _searchList;  // $$$
  NSEnumerator *enumerator = [args objectEnumerator];
  NSMutableDictionary *argDict =
    [NSMutableDictionary dictionaryWithCapacity: 2];
  BOOL done;
  id key, val;
	
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
	  if (!val)
	    {            // No more args
	      [argDict setObject: @"" forKey: key];		// arg is empty.
	      if (old)
		[argDict setObject: @"" forKey: old];
	      done = YES;
	      continue;
	    }
	  else if ([val hasPrefix: @"-"])
	    {  // Yet another argument
	      [argDict setObject: @"" forKey: key];		// arg is empty.
	      if (old)
		[argDict setObject: @"" forKey: old];
	      key = val;
	      continue;
	    }
	  else
	    {                            // Real parameter
	      [argDict setObject: val forKey: key];
	      if (old)
		[argDict setObject: val forKey: old];
	    }
	}
      done = ((key = [enumerator nextObject]) == nil);
    }
  
  return argDict;
}

- (void)__changePersistentDomain: (NSString *)domainName
{
  NSEnumerator *enumerator = nil;
  id obj;

  DESTROY(_dictionaryRep);
  if (!_changedDomains)
    {
      _changedDomains = [[NSMutableArray alloc] initWithCapacity: 5];
      [[NSNotificationCenter defaultCenter] 
	postNotificationName: NSUserDefaultsDidChangeNotification object: nil];
    }
	
  enumerator = [_changedDomains objectEnumerator];
  while ((obj = [enumerator nextObject]))
    {
      if ([obj isEqualToString: domainName])
	return;
    }
  [_changedDomains addObject: domainName];
  return;
}

- (void) __timerTicked: (NSTimer*)tim
{
  if (tim == _tickingTimer)
    _tickingTimer = nil;

  [self synchronize];
}
@end
