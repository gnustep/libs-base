/* Implementation of host class
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.
   
   Written by: Luke Howard <lukeh@xedoc.com.au> 
   Date: 1996
   
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
#include <Foundation/NSLock.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSDictionary.h>
#include <netdb.h>
/* #include <libc.h> */

#ifdef WIN32
#include <Windows32/Sockets.h>
#endif /* WIN32 */

static NSLock *_hostCacheLock = nil;
static BOOL _hostCacheEnabled = NO;
static NSMutableDictionary *_hostCache = nil;

@interface NSHost (Private)
+ (NSHost *)_hostWithHostEntry:(struct hostent *)entry;
+ (NSHost *)_hostWithHostEntry:(struct hostent *)entry name:name;
- _initWithHostEntry:(struct hostent *)entry name:name;
@end

@implementation NSHost (Private)

+ (NSHost *)_hostWithHostEntry:(struct hostent *)entry
{
  if (!entry)
    return nil;
		
  return [[self class] _hostWithHostEntry:entry  
		       name:[NSString stringWithCString:entry->h_name]];
}

+ (NSHost *)_hostWithHostEntry:(struct hostent *)entry name:name
{
  NSHost *res = nil;
		
  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      res = [_hostCache objectForKey:name];
    }
  [_hostCacheLock unlock];
	
  return (res != nil) ? res : [[[[self class] alloc]  
				 _initWithHostEntry:entry name:name] autorelease];
}

- _initWithHostEntry:(struct hostent *)entry name:name
{
  int i;
  char *ptr;
  struct in_addr in;
  NSString *h_name;
	
  [super init];
	
  if (entry == (struct hostent *)NULL)
    {
      return nil;
    }
		
  names = [[NSMutableArray array] retain];
  addresses = [[NSMutableArray array] retain];
	
  [names addObject:name];
  h_name = [NSString stringWithCString:entry->h_name];
	
  if (![h_name isEqual:name])
    {
      [names addObject:h_name];
    }
	
  for (i = 0, ptr = entry->h_aliases[0]; ptr != NULL; i++,  
	 ptr = entry->h_aliases[i])
    {
      [names addObject:[NSString stringWithCString:ptr]];
    }

  for (i = 0, ptr = entry->h_addr_list[0]; ptr != NULL; i++,  
	 ptr = entry->h_addr_list[i])
    {
      memmove((void *)&in.s_addr, (const void *)ptr,  
	      entry->h_length);
      [addresses addObject:[NSString  
			     stringWithCString:inet_ntoa(in)]];
    }

  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      [_hostCache setObject:self forKey:name];
    }
  [_hostCacheLock unlock];
	
  return self;
}

@end

@implementation NSHost

- init
{
  return nil;
}

+ initialize
{
  _hostCacheLock = [[NSConditionLock alloc] init];
  _hostCache = [[NSMutableDictionary dictionary] retain];
  return self;
}

+ (NSHost *)currentHost
{
  char name[MAXHOSTNAMELEN];
  int res;
  struct hostent *h;
	
  res = gethostname(name, sizeof(name));
  if (res < 0)
    {
      return nil;
    }
		
  h = gethostbyname(name);
	
  return [self _hostWithHostEntry:h name:[NSString  
					   stringWithCString:name]];
}

+ (NSHost *)hostWithName:(NSString *)name
{
  struct hostent *h;
	
  h = gethostbyname((char *)[name cString]);
	
  return [self _hostWithHostEntry:h name:name];
	
}

+ (NSHost *)hostWithAddress:(NSString *)address
{
  struct hostent *h;
  struct in_addr hostaddr;
	
  hostaddr.s_addr = inet_addr((char *)[address cString]);
  if (hostaddr.s_addr == -1)
    {
      return nil;
    }
		
  h = gethostbyaddr((char *)&hostaddr, sizeof(hostaddr), AF_INET);
  return [self _hostWithHostEntry:h];
}

+ (void)setHostCacheEnabled:(BOOL)flag
{
  [_hostCacheLock lock];
  _hostCacheEnabled = flag;
  [_hostCacheLock unlock];
}

+ (BOOL)isHostCacheEnabled;
{
  BOOL res;
	
  [_hostCacheLock lock];
  res = _hostCacheEnabled;
  [_hostCacheLock unlock];
	
  return res;
}

+ (void)flushHostCache
{
  [_hostCacheLock lock];
  [_hostCache removeAllObjects];
  [_hostCacheLock unlock];
}

- (BOOL)isEqualToHost:(NSHost *)aHost
{
  // how should we check for equality?
  return ([[aHost addresses] isEqual:addresses]) && ([[aHost  
							names] isEqual:names]);
}

- (NSString *)name
{
  return [names objectAtIndex:0];
}

- (NSArray *)names
{
  return names;
}

- (NSString *)address
{
  return [addresses objectAtIndex:0];
}

- (NSArray *)addresses
{
  return addresses;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"Host %@ (%@ %@)", [self  
							  name],
		   [[self names] description], [[self addresses]  
						 description]];
}

- (void)dealloc
{
  [names autorelease];
  [addresses autorelease];
  [super dealloc];
}

@end
