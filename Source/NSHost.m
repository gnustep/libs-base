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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
  */ 

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <netdb.h>
/* #include <libc.h>*/

#if	defined(__WIN32__) && !defined(__CYGWIN__)
#include <Windows32/Sockets.h>
#else
#include <unistd.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif /* __WIN32__*/

static NSLock*_hostCacheLock = nil;
static BOOL _hostCacheEnabled = NO;
static NSMutableDictionary*_hostCache = nil;

@interface NSHost (Private)
+ (NSHost*) _hostWithHostEntry: (struct hostent*)entry;
+ (NSHost*) _hostWithHostEntry: (struct hostent*)entry name: name;
- (id) _initWithHostEntry: (struct hostent*)entry name: name;
@end

@implementation NSHost (Private)

+ (NSHost*) _hostWithHostEntry: (struct hostent*)entry
{
  if (!entry)
    return nil;
		
  return [[self class] _hostWithHostEntry: entry  
		       name: [NSString stringWithCString: entry->h_name]];
}

+ (NSHost*) _hostWithHostEntry: (struct hostent*)entry name: name
{
  NSHost*res = nil;
		
  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      res = [_hostCache objectForKey: name];
    }
  [_hostCacheLock unlock];
	
  return (res != nil) ? res
    : AUTORELEASE([[[self class] alloc]  
		       _initWithHostEntry: entry name: name]);
}

- (id) _initWithHostEntry: (struct hostent*)entry name: name
{
  int i;
  char*ptr;
  struct in_addr in;
  NSString*h_name;
	
  [super init];
	
  if (entry == (struct hostent*)NULL)
    {
      return nil;
    }
		
  _names = RETAIN([NSMutableArray array]);
  _addresses = RETAIN([NSMutableArray array]);
	
  [_names addObject: name];
  h_name = [NSString stringWithCString: entry->h_name];
	
  if (![h_name isEqual: name])
    {
      [_names addObject: h_name];
    }
	
  for (i = 0, ptr = entry->h_aliases[0]; ptr != NULL; i++,  
	 ptr = entry->h_aliases[i])
    {
      [_names addObject: [NSString stringWithCString: ptr]];
    }

  for (i = 0, ptr = entry->h_addr_list[0]; ptr != NULL; i++,  
	 ptr = entry->h_addr_list[i])
    {
      memcpy((void*)&in.s_addr, (const void*)ptr,  
	      entry->h_length);
      [_addresses addObject: [NSString  
			     stringWithCString: (char*)inet_ntoa(in)]];
    }

  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      [_hostCache setObject: self forKey: name];
    }
  [_hostCacheLock unlock];
	
  return self;
}

@end

@implementation NSHost

- (id) init
{
  [self dealloc];
  return nil;
}

+ (void) initialize
{
  if (self == [NSHost class])
    {
      _hostCacheLock = [[NSConditionLock alloc] init];
      _hostCache = [NSMutableDictionary new];
    }
}

/*
 *	Max hostname length in line with RFC  1123
 */
#define	GSMAXHOSTNAMELEN	255

+ (NSHost*) currentHost
{
  char	name[GSMAXHOSTNAMELEN+1];
  int	res;
  struct hostent	*h;
	
  res = gethostname(name, GSMAXHOSTNAMELEN);
  if (res < 0)
    {
      return nil;
    }
  name[GSMAXHOSTNAMELEN] = '\0';
		
  h = gethostbyname(name);
  if (h == NULL)
    {
      NSLog(@"Unable to determine current host");
      return nil;
    }
	
	
  return [self _hostWithHostEntry: h name: [NSString  
					   stringWithCString: name]];
}

+ (NSHost*) hostWithName: (NSString*)name
{
  struct hostent*h;

  if (name == nil)
    {
      NSLog(@"Nil host name sent to +[NSHost hostWithName]");
      return nil;
    }
	
  h = gethostbyname((char*)[name cString]);
	
  return [self _hostWithHostEntry: h name: name];
	
}

+ (NSHost*) hostWithAddress: (NSString*)address
{
  struct hostent*h;
  struct in_addr hostaddr;
	
  if (address == nil)
    {
      NSLog(@"Nil address sent to +[NSHost hostWithAddress]");
      return nil;
    }
#ifndef	HAVE_INET_ATON
  hostaddr.s_addr = inet_addr([address cString]);
  if (hostaddr.s_addr == -1)
    {
      return nil;
    }
#else
  if (inet_aton([address cString], &hostaddr.s_addr) == 0)
    {
      return nil;
    }
#endif
		
  h = gethostbyaddr((char*)&hostaddr, sizeof(hostaddr), AF_INET);
  return [self _hostWithHostEntry: h];
}

+ (void) setHostCacheEnabled: (BOOL)flag
{
  [_hostCacheLock lock];
  _hostCacheEnabled = flag;
  [_hostCacheLock unlock];
}

+ (BOOL) isHostCacheEnabled;
{
  BOOL res;
	
  [_hostCacheLock lock];
  res = _hostCacheEnabled;
  [_hostCacheLock unlock];
	
  return res;
}

+ (void) flushHostCache
{
  [_hostCacheLock lock];
  [_hostCache removeAllObjects];
  [_hostCacheLock unlock];
}

/* Methods for encoding/decoding*/
- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    return self;
}
- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [super encodeWithCoder: aCoder];
    [aCoder encodeObject: [self address]];
}

#if 1
/*	GNUstep specific method for more efficient decoding.*/
+ (id) newWithCoder: (NSCoder*)aCoder
{
    NSString	*address = [aCoder decodeObject];
    return [NSHost hostWithAddress: address];
}
#else
/*	OpenStep methods for decoding (not used)*/
- (id) awakeAfterUsingCoder: (NSCoder*)aCoder
{
    return [NSHost hostWithAddress: [_addresses objectAtIndex: 0]];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    NSString	*address;

    [super initWithCoder: aCoder];
    address = [aCoder decodeObject];
    _addresses = [NSArray arrayWithObject: address];
    return self;
}
#endif

/*
*	The OpenStep spec says that [-hash] must be the same for any two
*	objects that [-isEqual: ] returns YES for.  We have a problem in
*	that [-isEqualToHost: ] is specified to return YES if any name or
*	address part of two hosts is the same.  That means we can't
*	reasonably calculate a hash since two hosts with radically
*	different ivar contents may be 'equal'.  The best I can think of
*	is for all hosts to hash to the same value - which makes it very
*	inefficient to store them in a set, dictionary, map or hash table.
*/
- (unsigned) hash
{
  return 1;
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    return YES;
  if ([other isKindOfClass: [NSHost class]])
    return [self isEqualToHost: (NSHost*)other];
  return NO;
}

- (BOOL) isEqualToHost: (NSHost*)aHost
{
  NSArray*	a;
  int		i;

  if (aHost == self)
    return YES;

  a = [aHost addresses];
  for (i = 0; i < [a count]; i++)
    if ([_addresses containsObject: [a objectAtIndex: i]])
      return YES;

  a = [aHost names];
  for (i = 0; i < [a count]; i++)
    if ([_addresses containsObject: [a objectAtIndex: i]])
      return YES;

  return NO;
}

- (NSString*) name
{
  return [_names objectAtIndex: 0];
}

- (NSArray*) names
{
  return _names;
}

- (NSString*) address
{
  return [_addresses objectAtIndex: 0];
}

- (NSArray*) addresses
{
  return _addresses;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Host %@ (%@ %@)",
    [self name], [[self names] description], [[self addresses] description]];
}

- (void) dealloc
{
  RELEASE(_names);
  RELEASE(_addresses);
  [super dealloc];
}

@end
