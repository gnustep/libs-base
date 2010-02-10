/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#import "config.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSHost.h"
#import "GSNetwork.h"
#import "GSPrivate.h"
#import "GNUstepBase/NSFileHandle+GNUstepBase.h"


@implementation NSFileHandle(GNUstepBase)
// From GSFileHandle.m

static BOOL
getAddr(NSString* name, NSString* svc, NSString* pcl, struct  sockaddr_in *sin)
{
  const char        *proto = "tcp";
  struct servent    *sp;

  if (pcl)
    {
      proto = [pcl lossyCString];
    }
  memset(sin, '\0', sizeof(*sin));
  sin->sin_family = AF_INET;

  /*
   *    If we were given a hostname, we use any address for that host.
   *    Otherwise we expect the given name to be an address unless it  is
   *    a null (any address).
   */
  if (name)
    {
      NSHost*        host = [NSHost hostWithName: name];

      if (host != nil)
        {
	  name = [host address];
        }
#ifndef    HAVE_INET_ATON
      sin->sin_addr.s_addr = inet_addr([name lossyCString]);
      if (sin->sin_addr.s_addr == INADDR_NONE)
#else
	if (inet_aton([name lossyCString], &sin->sin_addr) == 0)
#endif
	  {
	    return NO;
	  }
    }
  else
    {
      sin->sin_addr.s_addr = NSSwapHostIntToBig(INADDR_ANY);
    }
  if (svc == nil)
    {
      sin->sin_port = 0;
      return YES;
    }
  else if ((sp = getservbyname([svc lossyCString], proto)) == 0)
    {
      const char*     ptr = [svc lossyCString];
      int             val = atoi(ptr);

      while (isdigit(*ptr))
	{
	  ptr++;
	}
      if (*ptr == '\0' && val <= 0xffff)
	{
	  unsigned short       v = val;

	  sin->sin_port = NSSwapHostShortToBig(v);
	  return YES;
	}
      else if (strcmp(ptr, "gdomap") == 0)
	{
	  unsigned short       v;
#ifdef    GDOMAP_PORT_OVERRIDE
	  v = GDOMAP_PORT_OVERRIDE;
#else
	  v = 538;    // IANA allocated port
#endif
	  sin->sin_port = NSSwapHostShortToBig(v);
	  return YES;
	}
      else
	{
	  return NO;
	}
    }
  else
    {
      sin->sin_port = sp->s_port;
      return YES;
    }
}

- (id) initAsServerAtAddress: (NSString*)a
                           service: (NSString*)s
                          protocol: (NSString*)p
{
#ifndef    BROKEN_SO_REUSEADDR
  int    status = 1;
#endif
  int    net;
  struct sockaddr_in    sin;
  unsigned int		size = sizeof(sin);

  if (getAddr(a, s, p, &sin) == NO)
    {
      RELEASE(self);
      NSLog(@"bad address-service-protocol combination");
      return  nil;
    }

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
    {
      NSLog(@"unable to create socket - %@", [NSError _last]);
      RELEASE(self);
      return nil;
    }

#ifndef    BROKEN_SO_REUSEADDR
  /*
   * Under decent systems, SO_REUSEADDR means that the port can be  reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  setsockopt(net, SOL_SOCKET, SO_REUSEADDR, (char *)&status,  sizeof(status));
#endif

  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) < 0)
    {
      NSLog(@"unable to bind to port %s:%d - %@",  inet_ntoa(sin.sin_addr),
	    NSSwapBigShortToHost(sin.sin_port),  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (listen(net, 5) < 0)
    {
      NSLog(@"unable to listen on port - %@",  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (getsockname(net, (struct sockaddr*)&sin, &size) < 0)
    {
      NSLog(@"unable to get socket name - %@",  [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  self = [self initWithFileDescriptor: net closeOnDealloc: YES];

  return self;
}

+ (id) fileHandleAsServerAtAddress: (NSString*)address
                           service: (NSString*)service
                          protocol: (NSString*)protocol
{
  id    o = [self allocWithZone: NSDefaultMallocZone()];

  return AUTORELEASE([o initAsServerAtAddress: address
                                      service: service
                                     protocol: protocol]);
}

- (NSString*) socketAddress
{
  struct sockaddr_in    sin;
  unsigned int    size = sizeof(sin);

  if (getsockname([self fileDescriptor], (struct sockaddr*)&sin,  &size) < 0)
    {
      NSLog(@"unable to get socket name - %@",  [NSError _last]);
      return nil;
    }

  return [[[NSString alloc] initWithCString:  (char*)inet_ntoa(sin.sin_addr)]
	   autorelease];
}

@end


