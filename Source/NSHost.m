/* Implementation of host class
   Copyright (C) 1996, 1997,1999 Free Software Foundation, Inc.

   Written by: Luke Howard <lukeh@xedoc.com.au>
   Date: 1996
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1999

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

#ifndef	INADDR_NONE
#define	INADDR_NONE	-1
#endif

static NSLock			*_hostCacheLock = nil;
static BOOL			_hostCacheEnabled = YES;
static NSMutableDictionary	*_hostCache = nil;

@interface NSHost (Private)
- (id) _initWithHostEntry: (struct hostent*)entry;
@end

@implementation NSHost (Private)

- (id) _initWithHostEntry: (struct hostent*)entry
{
  int			i;
  char			*ptr;
  struct in_addr	in;
  NSString		*h_name;

  if ((self = [super init]) == nil)
    {
      return nil;
    }
  if (entry == (struct hostent*)NULL)
    {
      RELEASE(self);
      return nil;
    }

  _names = [NSMutableArray new];
  _addresses = [NSMutableArray new];

  h_name = [NSString stringWithCString: entry->h_name];
  [_names addObject: h_name];

  i = 0;
  while ((ptr = entry->h_aliases[i++]) != 0)
    {
      [_names addObject: [NSString stringWithCString: ptr]];
    }

  i = 0;
  while ((ptr = entry->h_addr_list[i++]) != 0)
    {
      NSString	*addr;

      memcpy((void*)&in.s_addr, (const void*)ptr, entry->h_length);
      addr = [NSString stringWithCString: (char*)inet_ntoa(in)];
      [_addresses addObject: addr];
    }

  if (_hostCacheEnabled == YES)
    {
      NSEnumerator	*enumerator;
      NSString		*key;

      enumerator = [_names objectEnumerator];
      while ((key = [enumerator nextObject]) != nil)
	{
	  [_hostCache setObject: self forKey: key];
	}
      enumerator = [_addresses objectEnumerator];
      while ((key = [enumerator nextObject]) != nil)
	{
	  [_hostCache setObject: self forKey: key];
	}
    }

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
      _hostCacheLock = [[NSLock alloc] init];
      _hostCache = [NSMutableDictionary new];
    }
}

/*
 *	Max hostname length in line with RFC  1123
 */
#define	GSMAXHOSTNAMELEN	255

+ (NSHost*) currentHost
{
  char		name[GSMAXHOSTNAMELEN+1];
  int		res;

  res = gethostname(name, GSMAXHOSTNAMELEN);
  if (res < 0)
    {
      return nil;
    }
  name[GSMAXHOSTNAMELEN] = '\0';
  return [self hostWithName: [NSString stringWithCString: name]];
}

+ (NSHost*) hostWithName: (NSString*)name
{
  NSHost	*host = nil;

  if (name == nil)
    {
      NSLog(@"Nil host name sent to +[NSHost hostWithName]");
      return nil;
    }

  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      host = [_hostCache objectForKey: name];
    }
  if (host == nil)
    {
      struct hostent	*h;

      h = gethostbyname((char*)[name cString]);

      host = [[self alloc] _initWithHostEntry: h];
      AUTORELEASE(host);
    }
  [_hostCacheLock unlock];
  return host;
}

+ (NSHost*) hostWithAddress: (NSString*)address
{
  NSHost	*host = nil;

  if (address == nil)
    {
      NSLog(@"Nil host address sent to +[NSHost hostWithName]");
      return nil;
    }

  [_hostCacheLock lock];
  if (_hostCacheEnabled == YES)
    {
      host = [_hostCache objectForKey: address];
    }

  if (host == nil)
    {
      struct hostent	*h;
      struct in_addr	hostaddr;
      BOOL		addrOk = YES;

#ifndef	HAVE_INET_ATON
      hostaddr.s_addr = inet_addr([address cString]);
      if (hostaddr.s_addr == INADDR_NONE)
	{
	  addrOk = NO;
	}
#else
      if (inet_aton([address cString], (struct in_addr*)&hostaddr.s_addr) == 0)
	{
	  addrOk = NO;
	}
#endif
      if (addrOk == YES)
	{
	  h = gethostbyaddr((char*)&hostaddr, sizeof(hostaddr), AF_INET);
	  host = [[self alloc] _initWithHostEntry: h];
	  AUTORELEASE(host);
	}
    }
  [_hostCacheLock unlock];
  return host;
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

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSString	*address;
  NSHost	*host;

  self = [super initWithCoder: aCoder];
  address = [aCoder decodeObject];
  host = RETAIN([NSHost hostWithAddress: address]);
  RELEASE(self);
  return host;
}

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
    [self name], [self names], [self addresses]];
}

- (void) dealloc
{
  RELEASE(_names);
  RELEASE(_addresses);
  [super dealloc];
}

@end
