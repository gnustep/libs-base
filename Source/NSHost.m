/** Implementation of host class
   Copyright (C) 1996, 1997,1999 Free Software Foundation, Inc.

   Written by: Luke Howard <lukeh@xedoc.com.au>
   Date: 1996
   Rewrite by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1999

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   <title>NSHost class reference</title>
   $Date$ $Revision$
  */

#import "common.h"
#define	EXPOSE_NSHost_IVARS	1
#import "Foundation/Foundation.h"

#import	"GSFastEnumeration.h"
#import	"GNUstepBase/GNUstep.h"

#if defined(_WIN32)
#ifdef HAVE_WS2TCPIP_H
#include <ws2tcpip.h>
#endif // HAVE_WS2TCPIP_H
#if !defined(HAVE_INET_NTOP)
extern const char* WSAAPI inet_ntop(int, const void *, char *, size_t);
#endif
#if !defined(HAVE_INET_NTOP)
extern int WSAAPI inet_pton(int , const char *, void *);
#endif
#else /* !_WIN32 */
#include <netdb.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif /* !_WIN32 */
#if	defined(HAVE_RESOLV_H)
#include <resolv.h>
#endif

#ifndef	INADDR_NONE
#define	INADDR_NONE	-1
#endif

/* Use posix definition if not already defined
 */
#ifndef	INET6_ADDRSTRLEN
#define	INET6_ADDRSTRLEN	46
#endif

static NSString			*localHostName = @"GNUstep local host";
static Class			hostClass;
static NSRecursiveLock		*_hostCacheLock = nil;
static BOOL			_hostCacheEnabled = YES;
static NSMutableDictionary	*_hostCache = nil;
static id			null = nil;


/*
 *	Max hostname length in line with RFC  1123
 */
#define	GSMAXHOSTNAMELEN	255

/**
 * Return the current host name ... may change if we are using dhcp etc
 */
static NSString*
myHostName()
{
  static NSString	*name = nil;
  static char		old[GSMAXHOSTNAMELEN+1];
  char			buf[GSMAXHOSTNAMELEN+1];
  int			res;

  [_hostCacheLock lock];
  res = gethostname(buf, GSMAXHOSTNAMELEN);
  if (res < 0 || *buf == '\0')
    {
      NSLog(@"Unable to get name of current host - using 'localhost'");
      ASSIGN(name, @"localhost");
    }
  else if (name == nil || strcmp(old, buf) != 0)
    {
      strncpy(old, buf, sizeof(old) - 1);
      old[sizeof(old) - 1] = '\0';
      RELEASE(name);
      name = [[NSString alloc] initWithCString: buf];
    }
  [_hostCacheLock unlock];
  return name;
}

@interface NSHost (Private)
+ (void) _cacheHost: (NSHost*)host forKey: (NSString*)key;
- (void) _addName: (NSString*)name;
#if     defined(HAVE_GETADDRINFO) && defined(HAVE_RESOLV_H)
- (id) _initWithKey: (NSString*)key;
#else
- (id) _initWithHostEntry: (struct hostent*)entry key: (NSString*)name;
#endif
+ (NSMutableSet*) _localAddresses;
@end

@implementation NSHost (Private)

+ (void) _cacheHost: (NSHost*)host forKey: (NSString*)key
{
  NSAssert(nil == host || [host isKindOfClass: [NSHost class]],
    NSInvalidArgumentException);
  NSAssert([key isKindOfClass: [NSString class]], NSInvalidArgumentException);

  [_hostCacheLock lock];
  if (host)
    {
      NSSet *names = host->_names;
      NSSet *addresses = host->_addresses;

      FOR_IN (id, name, names)
      [_hostCache setObject: host forKey: name];
      END_FOR_IN (names)

      FOR_IN (id, address, addresses)
      [_hostCache setObject: host forKey: address];
      END_FOR_IN (addresses)
      [_hostCache setObject: host forKey: key];
    }
  else
    {
      [_hostCache setObject: [NSNull null] forKey: key];
      NSLog(@"Host '%@' not found - "
	@"perhaps the hostname is wrong or networking is not "
	@"set up on your machine", key);
    }
  [_hostCacheLock unlock];
}

- (void) _addName: (NSString*)name
{
  NSMutableSet	*s = [_names mutableCopy];

  name = [name copy];
  [s addObject: name];
  ASSIGNCOPY(_names, s);
  RELEASE(s);
  if (YES == _hostCacheEnabled)
    {
      [_hostCache setObject: self forKey: name];
    }
  RELEASE(name);
}

- (id) _initWithAddress: (NSString*)name
{
  if ((self = [super init]) == nil)
    {
      return nil;
    }
  name = [name copy];
  _names = [[NSSet alloc] initWithObjects: &name count: 1];
  _addresses = RETAIN(_names);
  if (YES == _hostCacheEnabled)
    {
      [_hostCache setObject: self forKey: name];
    }
  RELEASE(name);
  return self;
}

#if     defined(HAVE_GETADDRINFO) && defined(HAVE_RESOLV_H)

- (id) _initWithKey: (NSString*)key
{
  ENTER_POOL
  const char		*ptr = [key UTF8String];
  NSMutableSet		*names = [NSMutableSet setWithCapacity: 8];
  NSMutableSet		*addresses = [NSMutableSet setWithCapacity: 8];
  struct addrinfo	*entry;
  struct addrinfo       hints;
  struct addrinfo	*tmp;
  int			err;

  memset(&hints, '\0', sizeof(hints));
  hints.ai_flags = AI_CANONNAME;
  hints.ai_family = AF_UNSPEC; 

  if ([key isEqualToString: myHostName()])
    {
      [addresses addObject: @"127.0.0.1"];
#if     defined(AF_INET6)
      [addresses addObject: @"::1"];
#endif
      [names addObject: @"localhost"];
    }
  else if ([key isEqualToString: localHostName]
    || [key isEqualToString: @"localhost"])
    {
#if     defined(AF_INET6)
      [addresses addObject: @"::1"];
#endif
      ptr = "127.0.0.1";
    }

  err = getaddrinfo(ptr, 0, &hints, &entry);
  if (err)
    {
      fprintf(stderr, "getaddrinfo failed: %s\n", gai_strerror(err));
      entry = NULL;
    }
  for (tmp = entry; tmp != NULL; tmp = tmp->ai_next)
    {
      char	ipstr[INET6_ADDRSTRLEN];
      void	*addr;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-align"
      if (AF_INET == tmp->ai_family)
	{
	  struct sockaddr_in *ipv4 = (struct sockaddr_in *)(tmp->ai_addr);
	  addr = &(ipv4->sin_addr);
        }
      else if (AF_INET6 == tmp->ai_family)
	{
	  struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)tmp->ai_addr;
	  addr = &(ipv6->sin6_addr);
        }
      else
	{
          continue;	// Unsupported family
        }
#pragma clang diagnostic pop
      inet_ntop(tmp->ai_family, addr, ipstr, sizeof(ipstr));
      [addresses addObject: [NSString stringWithUTF8String: ipstr]];

      if (tmp->ai_canonname && *tmp->ai_canonname)
	{
	  unsigned char response[NS_PACKETSZ];
	  ns_msg 	msg;
	  int		count;
	  int 		len;
	  int		i;
	  NSString	*n;

	  n = [NSString stringWithUTF8String: tmp->ai_canonname];
	  [names addObject: n];

	  /* Perform DNS query for CNAME record (type CNAME = 5)
	   */
	  len = res_query(tmp->ai_canonname, ns_c_in, ns_t_cname,
	    response, sizeof(response));
	  if (len < 0)
	    {
	      perror("res_query");
	      continue;
	    }

	  ns_initparse(response, len, &msg);
	  count = ns_msg_count(msg, ns_s_an);
	  for (i = 0; i < count; i++)
	    {
	      ns_rr	rr;

	      ns_parserr(&msg, ns_s_an, i, &rr);

	      // Check if the record is a CNAME
	      if (ns_rr_type(rr) == ns_t_cname)
		{
		  char cname[NS_MAXDNAME];

		  if (ns_name_uncompress(ns_msg_base(msg), ns_msg_end(msg),
		    ns_rr_rdata(rr), cname, sizeof(cname)) < 0)
		    {
		      fprintf(stderr, "Failed to uncompress CNAME\n");
		      continue;
		    }
		  [names addObject: [NSString stringWithUTF8String: cname]];
		}
	    }
	}
    }
  if (entry)
    {
      freeaddrinfo(entry);
    }
  if ([names count] || [addresses count])
    {
      _names = [names copy];
      _addresses = [addresses copy];
    }
  else
    {
      DESTROY(self);
    }
  LEAVE_POOL
  return self;
}

#else

- (id) _initWithHostEntry: (struct hostent*)entry key: (NSString*)name
{
  int			i;
  char			*ptr;
  struct in_addr	in;
  NSString		*h_name;
  NSMutableSet		*names;
  NSMutableSet		*addresses;
  NSMutableSet		*extra;

  if ((self = [super init]) == nil)
    {
      return nil;
    }
  if ([name isEqualToString: localHostName] == NO
    && entry == (struct hostent*)NULL)
    {
      NSLog(@"Host '%@' init failed - perhaps the name/address is wrong or "
	@"networking is not set up on your machine", name);
      DESTROY(self);
      return nil;
    }
  else if (name == nil && entry != (struct hostent*)NULL)
    {
      NSLog(@"Nil hostname supplied but network database entry is not empty");
      DESTROY(self);
      return nil;
    }

  names = [NSMutableSet new];
  addresses = [NSMutableSet new];

  if ([name isEqualToString: localHostName] == YES)
    {
      extra = [hostClass _localAddresses];
    }
  else
    {
      extra = nil;
    }

  for (;;)
    {
      /*
       * We remove all the IP addresses that we have added to the host so
       * far from the set of extra addresses available on the current host.
       * Then we try to find a new network database entry for one of the
       * remaining extra addresses, and loop round to add all the names
       * and addresses for that entry.
       */
      [extra minusSet: addresses];
      while (entry == 0 && [extra count] > 0)
	{
	  NSString	*a = [extra anyObject];

	  entry = gethostbyname([a UTF8String]);
	  if (entry == 0)
	    {
	      /*
	       * Can't find a database entry for this IP address, but since
	       * we know the address is valid, we add it to the list of
	       * addresses for this host anyway.
	       */
	      [addresses addObject: a];
	      [extra removeObject: a];
	    }
	}
      if (entry == 0)
	{
	  break;
	}

      h_name = [NSString stringWithUTF8String: entry->h_name];
      [names addObject: h_name];

      if (entry->h_aliases != 0)
	{
	  i = 0;
	  while ((ptr = entry->h_aliases[i++]) != 0)
	    {
	      [names addObject: [NSString stringWithUTF8String: ptr]];
	    }
	}
      if (entry->h_addr_list != 0)
	{
	  i = 0;
	  while ((ptr = entry->h_addr_list[i++]) != 0)
	    {
	      NSString	*addr;

	      memset((void*)&in, '\0', sizeof(in));
	      memcpy((void*)&in.s_addr, (const void*)ptr, entry->h_length);
	      addr = [NSString stringWithUTF8String: (char*)inet_ntoa(in)];
	      [addresses addObject: addr];
	    }
	}
      entry = 0;
    }

  _names = [names copy];
  RELEASE(names);
  _addresses = [addresses copy];
  RELEASE(addresses);

  if (YES == _hostCacheEnabled)
    {
      [_hostCache setObject: self forKey: name];
    }

  return self;
}

#endif

+ (NSMutableSet*) _localAddresses
{
  NSMutableSet	*set;

  set = [[self currentHost]->_addresses mutableCopy];
  [set addObject: @"127.0.0.1"];
  return AUTORELEASE(set);
}
@end

@implementation NSHost

+ (void) initialize
{
  if (self == [NSHost class])
    {
      hostClass = self;
      null = [[NSNull null] retain];
      [[NSObject leakAt: &null] release];
      _hostCacheLock = [[NSRecursiveLock alloc] init];
      [[NSObject leakAt: &_hostCacheLock] release];
      _hostCache = [NSMutableDictionary new];
      [[NSObject leakAt: &_hostCache] release];
    }
}

+ (NSHost*) currentHost
{
  return [self hostWithName: myHostName()];
}

+ (NSHost*) hostWithName: (NSString*)name
{
  NSHost	*host = nil;
  const char	*n;

  if (name == nil)
    {
      NSLog(@"Nil host name sent to [NSHost +hostWithName:]");
      return nil;
    }
  if ([name isEqual: @""] == YES)
    {
      NSLog(@"Empty host name sent to [NSHost +hostWithName:]");
      return nil;
    }

  /* If this looks like an address rather than a host name ...
   * call the correct method instead of this one.
   */
  n = [name UTF8String];
  if ((isdigit(n[0]) && sscanf(n, "%*d.%*d.%*d.%*d") == 4)
    || 0 != strchr(n, ':'))
    {
      return [self hostWithAddress: name];
    }

  if (YES == _hostCacheEnabled)
    {
      [_hostCacheLock lock];
      host = RETAIN([_hostCache objectForKey: name]);
      [_hostCacheLock unlock];
    }
  if (nil == host)
    {
#if     defined(HAVE_GETADDRINFO) && defined(HAVE_RESOLV_H)
      host = [[self alloc] _initWithKey: name];
#else

      if ([name isEqualToString: localHostName] == YES)
	{
	  /* Special GNUstep extension host - we try to have a host entry
	   * with ALL the IP addresses of any interfaces on the local machine
	   */
	  host = [[self alloc] _initWithHostEntry: 0 key: localHostName];
	}
      else
	{
	  struct hostent	*h;

	  h = gethostbyname((char*)n);
	  if (0 == h)
	    {
	      if ([name isEqualToString: myHostName()] == YES)
		{
		  host = RETAIN([self hostWithAddress: @"127.0.0.1"]);
		  [host _addName: name];
		}
	    }
	  else
	    {
	      host = [[self alloc] _initWithHostEntry: h key: name];
	    }
	}
#endif
    }
  if (_hostCacheEnabled)
    {
      [self _cacheHost: host forKey: name];
    }
  return AUTORELEASE(host);
}

+ (NSHost*) hostWithAddress: (NSString*)address
{
  NSHost		*host = nil;
  char			buf[40];
  const char		*a;

  if (address == nil)
    {
      NSLog(@"Nil host address sent to [NSHost +hostWithAddress:]");
      return nil;
    }
  a = [address UTF8String];
  if (0 == a || '\0' == *a)
    {
      NSLog(@"Empty host address sent to [NSHost +hostWithAddress:]");
      return nil;
    }

  /* Now check that the address is of valid format, and standardise it
   * by converting from characters to binary and back.
   */
  if (0 == strchr(a, ':'))
    {
      struct in_addr	hostaddr;

      if (inet_pton(AF_INET, a, (void*)&hostaddr) <= 0)
	{
	  NSLog(@"Invalid host address sent to [NSHost +hostWithAddress:]");
	  return nil;
	}
      inet_ntop(AF_INET, (void*)&hostaddr, buf, sizeof(buf));
      a = buf;
      address = [NSString stringWithUTF8String: a];
    }
  else
#if     defined(AF_INET6)
    {
      struct in6_addr	hostaddr6;

      if (inet_pton(AF_INET6, a, (void*)&hostaddr6) <= 0)
	{
	  NSLog(@"Invalid host address sent to [NSHost +hostWithAddress:]");
	  return nil;
	}
      inet_ntop(AF_INET6, (void*)&hostaddr6, buf, sizeof(buf));
      a = buf;
      address = [NSString stringWithUTF8String: a];
    }
#else
  NSLog(@"Unsupported host address sent to [NSHost +hostWithAddress:]");
  return nil;
#endif

  if (YES == _hostCacheEnabled)
    {
      [_hostCacheLock lock];
      host = RETAIN([_hostCache objectForKey: address]);
      [_hostCacheLock unlock];
    }
  if (nil == host)
    {
#if     defined(HAVE_GETADDRINFO) && defined(HAVE_RESOLV_H)
      host = [[self alloc] _initWithKey: address];
#else
      struct hostent	*h;

      /* The gethostbyname() function should handle names, ipv4 addresses,
       * and ipv6 addresses ... so we can use it whatever we have.
       */
      h = gethostbyname(a);
      if (0 == h)
	{
	  host = [[self alloc] _initWithAddress: address];
	}
      else
	{
	  host = [[self alloc] _initWithHostEntry: h key: address];
	}
#endif
    }
  if (_hostCacheEnabled)
    {
      [self _cacheHost: host forKey: address];
    }
  return AUTORELEASE(host);
}

+ (void) setHostCacheEnabled: (BOOL)flag
{
  [_hostCacheLock lock];
  _hostCacheEnabled = flag;
  [_hostCacheLock unlock];
}

+ (BOOL) isHostCacheEnabled
{
  return _hostCacheEnabled;
}

+ (void) flushHostCache
{
  [_hostCacheLock lock];
  [_hostCache removeAllObjects];
  [_hostCacheLock unlock];
}

/* Methods for encoding/decoding */

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  NSString	*address = [self address];

  if ([address isEqual: @"127.0.0.1"] == YES)
    {
      NSEnumerator	*e = [_addresses objectEnumerator];

      while ((address = [e nextObject]) != nil)
	{
	  if ([address isEqual: @"127.0.0.1"] == NO)
	    {
	      break;
	    }
	}
    }
  [aCoder encodeObject: address];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSString	*address;
  NSHost	*host;

  address = [aCoder decodeObject];
  if (address != nil)
    {
      host = [NSHost hostWithAddress: address];
    }
  else
    {
      host = [NSHost currentHost];
    }
  IF_NO_ARC([host retain];)
  DESTROY(self);
  return host;
}

- (void) dealloc
{
  RELEASE(_names);
  RELEASE(_addresses);
  [super dealloc];
}

- (id) init
{
  [self dealloc];
  return nil;
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
- (NSUInteger) hash
{
  return 1;
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    {
      return YES;
    }
  if ([other isKindOfClass: [NSHost class]])
    {
      return [self isEqualToHost: (NSHost*)other];
    }
  return NO;
}

- (BOOL) isEqualToHost: (NSHost*)aHost
{
  NSEnumerator	*e;
  NSString	*a;

  if (aHost == self)
    {
      return YES;
    }
  e = [aHost->_addresses objectEnumerator];
  while ((a = [e nextObject]) != nil)
    {
      if ([_addresses member: a] != nil)
	{
	  return YES;
	}
    }
  return NO;
}

- (NSString*) localizedName
{
  NSString      *n = myHostName();

  if (self != [NSHost hostWithName: n])
    {
      n = nil;
    }
  return n;
}

- (NSString*) name
{
  return [_names anyObject];
}

- (NSArray*) names
{
  return [_names allObjects];
}

- (NSString*) address
{
  return [_addresses anyObject];
}

- (NSArray*) addresses
{
  return [_addresses allObjects];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Host %@ (%@ %@)",
    [self name], _names, _addresses];
}

@end

@implementation	NSHost (GNUstep)
+ (NSHost*) localHost
{
  return [self hostWithName: localHostName];
}
@end

@implementation	NSHost (NSProcessInfo)
+ (NSString*) _myHostName
{
  return myHostName();
}
@end
