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
static NSMutableString   *defaultsDatabase = nil;     
static NSMutableString   *defaultsDatabaseLock = nil;
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
  if (sharedDefaults)
    return sharedDefaults;
	
  // Create new sharedDefaults (NOTE: Not added to the autorelease pool!)
  sharedDefaults = [[self alloc] init];
	
  [sharedDefaults __createStandardSearchList];
	
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
      [self release];		/* xxx really? -mccallum. */
      return nil;
    }
  filename = [userHome stringByAppendingString: GNU_UserDefaultsDatabase];
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
      defaultsDatabase =
	[[NSMutableString stringWithFormat:@"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabase] retain];
      defaultsDatabaseLock =
	[[NSMutableString stringWithFormat:@"%@/%@",
			  NSHomeDirectoryForUser(NSUserName()),
			  GNU_UserDefaultsDatabaseLock] retain];
      processName = [[[NSProcessInfo processInfo] processName] retain];
#if 0
      processName = [[NSMutableString stringWithFormat:@"TestApp"] retain];
#endif
  }
	
  // Create an empty search list
  searchList = [[NSMutableArray arrayWithCapacity:10] retain];
	
  // Initialize persDomains from the archived user defaults (persistent)
  persDomains = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
  if ([self synchronize] == NO)
    {
      NSLog(@"unable to load defaults - %s", strerror(errno));
      [self dealloc];
      return self = nil;
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
      [[persDomains objectForKey:processName] removeObjectForKey:defaultName];
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
      [[persDomains objectForKey:processName]
	setObject:value forKey:defaultName];
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
  [searchList release];
  searchList = [newList mutableCopy];
}

/*************************************************************************
 *** Maintaining Persistent Domains
 *************************************************************************/
- (NSDictionary *)persistentDomainForName:(NSString *)domainName
{
  return [persDomains objectForKey:domainName];
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

  // Get file lock
  if (mkdir([defaultsDatabaseLock cString],0755) == -1)
    return NO;
	
  // Read the persistent data from the stored database
  newDict = [[NSMutableDictionary allocWithZone:[self zone]]
	      initWithContentsOfFile:defaultsDatabase];
  if (!newDict)
    newDict = [[NSMutableDictionary allocWithZone:[self zone]]
		initWithCapacity:1];

  if (changedDomains)
    {           // Synchronize bpth dictionaries
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
	  rmdir([defaultsDatabaseLock cString]);  // release file lock
	  return NO;
	}
    }
  else
    {                          // Just update from disk
      [persDomains release];
      persDomains = newDict;
    }
	
  rmdir([defaultsDatabaseLock cString]);  // release file lock

  return YES;
}


/*************************************************************************
 *** Maintaining Volatile Domains
 *************************************************************************/
- (void)removeVolatileDomainForName:(NSString *)domainName
{
  [tempDomains removeObjectForKey:domainName];
  return;
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
- (NSDictionary *)dictionaryRepresentation
{
  NSEnumerator *enumerator = [searchList reverseObjectEnumerator];
  NSMutableDictionary *dictRep =
    [NSMutableDictionary dictionaryWithCapacity:10];
  id obj;
  id dict;
	
  while ((obj = [enumerator nextObject]))
    {
      if ( (dict = [persDomains objectForKey:obj])
	   || (dict = [tempDomains objectForKey:obj]) )
	[dictRep addEntriesFromDictionary:dict];
    }
  // $$$ Should we return NSDictionary here ?
  return dictRep;
}

- (void)registerDefaults:(NSDictionary *)dictionary
{
  [tempDomains setObject:dictionary forKey:NSRegistrationDomain];
  return;
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
      if ([key hasPrefix:@"-GS"] || [key hasPrefix:@"--GS"]) {
	val = [enumerator nextObject];
	if (!val)
	  {            // No more args
	    [argDict setObject:nil forKey:key];
	    done = YES;
	    continue;
	  }
	else if ([val hasPrefix:@"-"])
	  {  // Yet another argument
	    [argDict setObject:nil forKey:key];
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
	
  if (!changedDomains)
    {
      changedDomains = [[NSMutableArray arrayWithCapacity:5] retain];
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:NSUserDefaultsChanged object:nil];
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
