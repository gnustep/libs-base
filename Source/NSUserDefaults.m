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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <config.h>
#include <gnustep/base/preface.h>
#if 0 
/* My Linux doesn't have <libc.h>.  Why is this necessary? 
   What is a work-around that will work for all?  -mccallum*/
#include <libc.h>
/* If POSIX then:  #include <unistd.h> */
#endif /* 0 */
#ifndef __WIN32__
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
- (void)__changePersistentDomain:(NSString *)domainName;
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
+ (NSUserDefaults *)standardUserDefaults
  /*
    Returns the shared defaults object. If it doesn't exist yet, it's
    created. The defaults are initialized for the current user.
    The search list is guaranteed to be standard only the first time 
    this method is invoked. The shared instance is provided as a 
    convenience; other instances may also be created.
    */
{
  static BOOL	beenHere = NO;	/* Flag to prevent infinite recursion */

  if (beenHere)
    return sharedDefaults;
  beenHere = YES;
  // Create new sharedDefaults (NOTE: Not added to the autorelease pool!)
  sharedDefaults = [[self alloc] init];
	
  [sharedDefaults __createStandardSearchList];

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
  return sharedDefaults;
}


+ (NSArray *)userLanguages
{
  NSMutableArray *uL = [NSMutableArray arrayWithCapacity:5];
  NSArray *currLang = [[self standardUserDefaults] 
			stringArrayForKey:@"Languages"];
  NSEnumerator *enumerator;
  id obj;
	
  if (!currLang)
    {                    // Try to build it from the env 
      const char *env_list;
      NSString *env;
      env_list = getenv("LANGUAGES");
      if (env_list)
	{
	  env = [NSString stringWithCString:env_list];
	  currLang = [[env componentsSeparatedByString:@";"] retain];
	}
    }
  [uL addObjectsFromArray:currLang];

  // Check if "English" is includet
  enumerator = [uL objectEnumerator];
  while ((obj = [enumerator nextObject]))
    {
      if ([obj isEqualToString:@"English"])
	return uL;
    }
  [uL addObject:@"English"];
	
  return uL;
}

+ (void)setUserLanguages:(NSArray *)languages
{
  NSMutableDictionary *globDict = [[self standardUserDefaults] 
				    persistentDomainForName:NSGlobalDomain];
	
  if (!languages)          // Remove the entry
    [globDict removeObjectForKey:@"Languages"];
  else
    [globDict setObject:languages forKey:@"Languages"];
  [[self standardUserDefaults] 
    setPersistentDomain:globDict forName:NSGlobalDomain];
  return;
}

/*************************************************************************
 *** Initializing the User Defaults
 *************************************************************************/
- (id)init
  /* Initializes defaults for current user calling initWithUser:. */
{
  return [self initWithUser:NSUserName()];
}

/* Initializes defaults for the specified user calling initWithFile:. */
- (id)initWithUser:(NSString *)userName
{
  NSString* userHome = NSHomeDirectoryForUser(userName);
  NSString *filename;
	
  // Either userName is empty or it's wrong
  if (!userHome)
    {  
      [self dealloc];
      return nil;
    }
  filename = [NSString stringWithFormat: @"%@/%@",
	userHome, GNU_UserDefaultsDatabase];
  return [self initWithContentsOfFile: filename];
}

- (id)initWithContentsOfFile:(NSString *)path
  /* Initializes defaults for the specified path. Returns an object with 
     an empty search list. */
{
  [super init];
	
  // Find the user's home folder and build the paths (executed only once)
  if (!defaultsDatabase)
    {
      if (path != nil && [path isEqual: @""] == NO)
        defaultsDatabase = [path copy];
      else
        defaultsDatabase =
	[[NSMutableString stringWithFormat:@"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabase] retain];

      if ([[defaultsDatabase lastPathComponent] isEqual:
		[GNU_UserDefaultsDatabase lastPathComponent]] == YES)
        defaultsDatabaseLockName =
	  [[NSMutableString stringWithFormat:@"%@/%@",
			  [defaultsDatabase stringByDeletingLastPathComponent],
			  [GNU_UserDefaultsDatabaseLock lastPathComponent]]
				retain];
      else
        defaultsDatabaseLockName =
	  [[NSMutableString stringWithFormat:@"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabaseLock] retain];
      defaultsDatabaseLock =
	[[NSDistributedLock lockWithPath: defaultsDatabaseLockName] retain];
  }
  if (processName == nil)
    processName = [[[[NSProcessInfo processInfo] processName]
	lastPathComponent] retain];
	
  // Create an empty search list
  searchList = [[NSMutableArray arrayWithCapacity:10] retain];
	
  // Initialize persDomains from the archived user defaults (persistent)
  persDomains = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
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
          [self dealloc];
          return self = nil;
        }
    }
	
  // Check and if not existent add the Application and the Global domains
  if (![persDomains objectForKey:processName])
    {
      [persDomains setObject:
		     [NSMutableDictionary 
		       dictionaryWithCapacity:10] forKey:processName];
      [self __changePersistentDomain:processName];
    }
  if (![persDomains objectForKey:NSGlobalDomain])
    {
      [persDomains setObject:
		   [NSMutableDictionary 
		     dictionaryWithCapacity:10] forKey:NSGlobalDomain];
      [self __changePersistentDomain:NSGlobalDomain];
    }
	
  // Create volatile defaults and add the Argument and the Registration domains
  tempDomains = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
  [tempDomains setObject:[self __createArgumentDictionary] 
	       forKey:NSArgumentDomain];
  [tempDomains setObject:
		 [NSMutableDictionary
		   dictionaryWithCapacity:10] forKey:NSRegistrationDomain];
	
  return self;
}

- (void)dealloc
{
  [searchList release];
  [persDomains release];
  [tempDomains release];
  [changedDomains release];
  [dictionaryRep release];
  [super dealloc];
}

- (NSString *)description
{
  NSMutableString *desc =
    [NSMutableString stringWithFormat:@"%@",[super description]];

  // $$$ Not Implemented
  // It's good idea to put all useful info here -- so I can test it later
  [self notImplemented: _cmd];
  return desc;
}

/*************************************************************************
 *** Getting and Setting a Default
 *************************************************************************/
- (NSArray *)arrayForKey:(NSString *)defaultName
{
  id obj = [self objectForKey:defaultName];
	
  if (obj && [obj isKindOfClass:[NSArray class]])
    return obj;
  return nil;
}

- (BOOL)boolForKey:(NSString *)defaultName
{
  id obj = [self stringForKey:defaultName];
	
  if (obj
      && ([obj isEqualToString:@"YES"] || [obj isEqualToString:@"yes"]
	  || [obj intValue]))
    return YES;
  return NO;
}

- (NSData *)dataForKey:(NSString *)defaultName
{
  id obj = [self objectForKey:defaultName];
	
  if (obj && [obj isKindOfClass:[NSData class]])
    return obj;
  return nil;
}

- (NSDictionary *)dictionaryForKey:(NSString *)defaultName
{
  id obj = [self objectForKey:defaultName];
	
  if (obj && [obj isKindOfClass:[NSDictionary class]])
    return obj;
  return nil;
}

- (float)floatForKey:(NSString *)defaultName
{
  id obj = [self stringForKey:defaultName];
	
  if (obj)
    return [obj floatValue];
  return 0.0;
}

- (int)integerForKey:(NSString *)defaultName
{
  id obj = [self stringForKey:defaultName];
	
  if (obj)
    return [obj intValue];
  return 0;
}

- (id)objectForKey:(NSString *)defaultName
{
  NSEnumerator *enumerator = [searchList objectEnumerator];
  id object = nil;
  id dN;
	
  while ((dN = [enumerator nextObject]))
    {
      id dict;
      
      dict = [persDomains objectForKey:dN];
      if (dict && (object = [dict objectForKey:defaultName]))
	break;
      dict = [tempDomains objectForKey:dN];
      if (dict && (object = [dict objectForKey:defaultName]))
	break;
    }
	
  return object;
}

- (void)removeObjectForKey:(NSString *)defaultName
{
  id obj = [[persDomains objectForKey:processName] objectForKey:defaultName];
	
  if (obj)
    {
      id	obj = [persDomains objectForKey: processName];
      NSMutableDictionary *dict;

      if ([obj isKindOfClass: [NSMutableDictionary class]] == YES)
	{
	  dict = obj;
	}
      else
	{
	  dict = [obj mutableCopy];
	  [persDomains setObject: dict forKey: processName];
	}
      [dict removeObjectForKey:defaultName];
      [self __changePersistentDomain:processName];
    }
  return;
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
  id obj = (value)?@"YES":@"NO";
	
  [self setObject:obj forKey:defaultName];
  return;
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName
{	
  char buf[32];
  sprintf(buf,"%g",value);
  [self setObject:[NSString stringWithCString:buf] forKey:defaultName];
  return;
}

- (void)setInteger:(int)value forKey:(NSString *)defaultName
{
  char buf[32];
  sprintf(buf,"%d",value);
  [self setObject:[NSString stringWithCString:buf] forKey:defaultName];
  return;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
  if (value && defaultName && ([defaultName length] > 0))
    {
      id	obj = [persDomains objectForKey: processName];
      NSMutableDictionary *dict;

      if ([obj isKindOfClass: [NSMutableDictionary class]] == YES)
	{
	  dict = obj;
	}
      else
	{
	  dict = [obj mutableCopy];
	  [persDomains setObject: dict forKey: processName];
	}
      [dict setObject:value forKey:defaultName];
      [self __changePersistentDomain:processName];
    }
  return;
}

- (NSArray *)stringArrayForKey:(NSString *)defaultName
{
  id arr = [self arrayForKey:defaultName];
	
  if (arr)
    {
      NSEnumerator *enumerator = [arr objectEnumerator];
      id obj;
		
      while ((obj = [enumerator nextObject]))
	if ( ! [obj isKindOfClass:[NSString class]])
	  return nil;
      return arr;
    }
  return nil;
}

- (NSString *)stringForKey:(NSString *)defaultName
{
  id obj = [self objectForKey:defaultName];
	
  if (obj && [obj isKindOfClass:[NSString class]])
    return obj;
  return nil;
}

/*************************************************************************
 *** Returning the Search List
 *************************************************************************/
- (NSMutableArray *)searchList
{
  return searchList;
}

- (void)setSearchList:(NSArray*)newList
{
  DESTROY(dictionaryRep);
  [searchList release];
  searchList = [newList mutableCopy];
}

/*************************************************************************
 *** Maintaining Persistent Domains
 *************************************************************************/
- (NSDictionary *)persistentDomainForName:(NSString *)domainName
{
  return [[persDomains objectForKey:domainName] copy];
}

- (NSArray *)persistentDomainNames
{
  return [persDomains allKeys];
}

- (void)removePersistentDomainForName:(NSString *)domainName
{
  if ([persDomains objectForKey:domainName])
    {
      [persDomains removeObjectForKey:domainName];
      [self __changePersistentDomain:domainName];
    }
  return;
}

- (void)setPersistentDomain:(NSDictionary *)domain 
		    forName:(NSString *)domainName
{
  id dict = [tempDomains objectForKey:domainName];
	
  if (dict)
    {
      [NSException raise:NSInvalidArgumentException 
		   format:@"Volatile domain with %@ already exists",
		   domainName];
      return;
    }
  [persDomains setObject:domain forKey:domainName];
  [self __changePersistentDomain:domainName];
  return;
}

- (BOOL)synchronize
{
  NSMutableDictionary *newDict = nil;
		
  tickingTimer = NO;

  // Get file lock - break any lock that is more than five minute old.
  if ([defaultsDatabaseLock tryLock] == NO)
    if ([[defaultsDatabaseLock lockDate] timeIntervalSinceNow] < -300.0)
    {
      [defaultsDatabaseLock breakLock];
      if ([defaultsDatabaseLock tryLock] == NO)
        return NO;
    }
    else
      return NO;
	
  DESTROY(dictionaryRep);

  // Read the persistent data from the stored database
  if ([[NSFileManager defaultManager] fileExistsAtPath: defaultsDatabase])
    newDict = [[NSMutableDictionary allocWithZone:[self zone]]
		initWithContentsOfFile:defaultsDatabase];
  else
    {
      NSLog(@"Creating defaults database file %@", defaultsDatabase);
      [[NSFileManager defaultManager] createFileAtPath: defaultsDatabase
				  contents: nil
				  attributes: nil];
    }

    if (!newDict)
      newDict = [[NSMutableDictionary allocWithZone:[self zone]]
		  initWithCapacity:1];

  if (changedDomains)
    {           // Synchronize both dictionaries
      NSEnumerator *enumerator = [changedDomains objectEnumerator];
      id obj, dict;
		
      while ((obj = [enumerator nextObject]))
	{
	  dict = [persDomains objectForKey:obj];
	  if (dict)       // Domane was added or changet
	    [newDict setObject:dict forKey:obj];
	  else            // Domain was removed
	    [newDict removeObjectForKey:obj];
	}
      [persDomains release];
      persDomains = newDict;
      // Save the changes
      if (![persDomains writeToFile:defaultsDatabase atomically:YES])
	{
	  [defaultsDatabaseLock unlock];
	  return NO;
	}
    }
  else
    {                          // Just update from disk
      [persDomains release];
      persDomains = newDict;
    }
	
  [defaultsDatabaseLock unlock];	// release file lock

  return YES;
}


/*************************************************************************
 *** Maintaining Volatile Domains
 *************************************************************************/
- (void)removeVolatileDomainForName:(NSString *)domainName
{
  DESTROY(dictionaryRep);
  [tempDomains removeObjectForKey:domainName];
}

- (void)setVolatileDomain:(NSDictionary *)domain 
		  forName:(NSString *)domainName
{
  id dict = [persDomains objectForKey:domainName];
	
  if (dict)
    {
      [NSException raise:NSInvalidArgumentException 
		   format:@"Persistent domain with %@ already exists",
		   domainName];
      return;
    }
  DESTROY(dictionaryRep);
  [tempDomains setObject:domain forKey:domainName];
  return;
}

- (NSDictionary *)volatileDomainForName:(NSString *)domainName
{
  return [tempDomains objectForKey:domainName];
}

- (NSArray *)volatileDomainNames
{
  return [tempDomains allKeys];
}

/*************************************************************************
 *** Making Advanced Use of Defaults
 *************************************************************************/
- (NSDictionary *) dictionaryRepresentation
{
  if (dictionaryRep == nil)
    {
      NSEnumerator		*enumerator;
      NSMutableDictionary	*dictRep;
      id obj;
      id dict;
	
      enumerator = [searchList reverseObjectEnumerator];
      dictRep = [NSMutableDictionary allocWithZone: NSDefaultMallocZone()];
      dictRep = [dictRep initWithCapacity: 512];
      while ((obj = [enumerator nextObject]))
	{
	  if ( (dict = [persDomains objectForKey: obj])
	       || (dict = [tempDomains objectForKey: obj]) )
	    [dictRep addEntriesFromDictionary: dict];
	}
      dictionaryRep = [dictRep copy];
      [dictRep release];
    }
  return dictionaryRep;
}

- (void) registerDefaults: (NSDictionary*)newVals
{
  NSMutableDictionary	*regDefs;

  regDefs = [tempDomains objectForKey: NSRegistrationDomain];
  if (regDefs == nil)
    {
      regDefs = [NSMutableDictionary dictionaryWithCapacity: [newVals count]];
    }
  DESTROY(dictionaryRep);
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
  [searchList addObject:NSArgumentDomain];
	
  // 2. Application
  [searchList addObject:processName];

  // 3. User's preferred languages
  while ((object = [enumerator nextObject]))
    {
      [searchList addObject:object];
    }
	
  // 4. NSGlobalDomain
  [searchList addObject:NSGlobalDomain];
	
  // 5. NSRegistrationDomain
  [searchList addObject:NSRegistrationDomain];
	
  return;
}

- (NSDictionary *)__createArgumentDictionary
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];
  //$$$	NSArray *args = searchList;  // $$$
  NSEnumerator *enumerator = [args objectEnumerator];
  NSMutableDictionary *argDict =
    [NSMutableDictionary dictionaryWithCapacity:2];
  BOOL done;
  id key, val;
	
  done = ((key = [enumerator nextObject]) == nil);
	
  while (!done)
    {
      if ([key hasPrefix:@"-"]) {
	/* anything beginning with a '-' is a defaults key and we must strip
	    the '-' from it.  As a special case, we leave the '- in place
	    for '-GS...' and '--GS...' for backward compatibility. */
        if ([key hasPrefix:@"-GS"] == NO && [key hasPrefix:@"--GS"] == NO) {
	  key = [key substringFromIndex: 1];
	}
	val = [enumerator nextObject];
	if (!val)
	  {            // No more args
	    [argDict setObject:@"" forKey:key];		// arg is empty.
	    done = YES;
	    continue;
	  }
	else if ([val hasPrefix:@"-"])
	  {  // Yet another argument
	    [argDict setObject:@"" forKey:key];		// arg is empty.
	    key = val;
	    continue;
	  }
	else
	  {                            // Real parameter
	    [argDict setObject:val forKey:key];
	  }
      }
      done = ((key = [enumerator nextObject]) == nil);
    }
  
  return argDict;
}

- (void)__changePersistentDomain:(NSString *)domainName
{
  NSEnumerator *enumerator = nil;
  id obj;

  DESTROY(dictionaryRep);
  if (!changedDomains)
    {
      changedDomains = [[NSMutableArray arrayWithCapacity:5] retain];
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:NSUserDefaultsDidChangeNotification object:nil];
    }
	
  if (!tickingTimer)
    {
      [NSTimer scheduledTimerWithTimeInterval:30
	       target:self
	       selector:@selector(synchronize)
	       userInfo:nil
	       repeats:NO];
      tickingTimer = YES;
    }

  enumerator = [changedDomains objectEnumerator];
  while ((obj = [enumerator nextObject]))
    {
      if ([obj isEqualToString:domainName])
	return;
    }
  [changedDomains addObject:domainName];
  return;
}

@end
