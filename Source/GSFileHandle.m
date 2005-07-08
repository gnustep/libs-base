/** Implementation for GSFileHandle for GNUStep
   Copyright (C) 1997-2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997, 2002

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */

#define	_FILE_OFFSET_BITS 64

#include "config.h"

#include "GNUstepBase/preface.h"
#include "Foundation/NSObject.h"
#include "Foundation/NSData.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSString.h"
#include "Foundation/NSFileHandle.h"
#include "GNUstepBase/GSFileHandle.h"
#include "Foundation/NSException.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSNotificationQueue.h"
#include "Foundation/NSHost.h"
#include "Foundation/NSByteOrder.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSUserDefaults.h"
#include "Foundation/NSDebug.h"

#include "../Tools/gdomap.h"

#if defined(__MINGW__)
#include <winsock2.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <io.h>
#include <stdio.h>
#else
#include <time.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/ioctl.h>
#ifdef	__svr4__
#include <sys/filio.h>
#endif
#include <netdb.h>

#define	SOCKET	int
#define	SOCKET_ERROR	-1
#define	INVALID_SOCKET	-1
#endif /* __MINGW__ */

#include <string.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <errno.h>

/*
 *	Stuff for setting the sockets into non-blocking mode.
 */
#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#ifndef	O_BINARY
#ifdef	_O_BINARY
#define	O_BINARY	_O_BINARY
#else
#define	O_BINARY	0
#endif
#endif

#ifndef	INADDR_NONE
#define	INADDR_NONE	-1
#endif

// Maximum data in single I/O operation
#define	NETBUF_SIZE	4096
#define	READ_SIZE	NETBUF_SIZE*10

static GSFileHandle*	fh_stdin = nil;
static GSFileHandle*	fh_stdout = nil;
static GSFileHandle*	fh_stderr = nil;

// Key to info dictionary for operation mode.
static NSString*	NotificationKey = @"NSFileHandleNotificationKey";

@interface GSFileHandle(private)
- (void) receivedEventRead;
- (void) receivedEventWrite;
@end

@implementation GSFileHandle

/**
 * Encapsulates low level read operation to get data from the operating
 * system.
 */
- (int) read: (void*)buf length: (int)len
{
#if	USE_ZLIB
  if (gzDescriptor != 0)
    {
      len = gzread(gzDescriptor, buf, len);
    }
  else
#endif
  if (isSocket)
    {
#if defined(__MINGW__)
      len = recv((SOCKET)_get_osfhandle(descriptor), buf, len, 0);
#else
      len = recv(descriptor, buf, len, 0);
#endif
    }
  else
    {
      len = read(descriptor, buf, len);
    }
  return len;
}

/**
 * Encapsulates low level write operation to send data to the operating
 * system.
 */
- (int) write: (const void*)buf length: (int)len
{
#if	USE_ZLIB
  if (gzDescriptor != 0)
    {
      len = gzwrite(gzDescriptor, (char*)buf, len);
    }
  else
#endif
  if (isSocket)
    {
#if defined(__MINGW__)
      len = send((SOCKET)_get_osfhandle(descriptor), buf, len, 0);
#else
      len = send(descriptor, buf, len, 0);
#endif
    }
  else
    {
      len = write(descriptor, buf, len);
    }
  return len;
}

static BOOL
getAddr(NSString* name, NSString* svc, NSString* pcl, struct sockaddr_in *sin)
{
  const char		*proto = "tcp";
  struct servent	*sp;

  if (pcl)
    {
      proto = [pcl lossyCString];
    }
  memset(sin, '\0', sizeof(*sin));
  sin->sin_family = AF_INET;

  /*
   *	If we were given a hostname, we use any address for that host.
   *	Otherwise we expect the given name to be an address unless it is
   *	a null (any address).
   */
  if (name)
    {
      NSHost*		host = [NSHost hostWithName: name];

      if (host != nil)
	{
	  name = [host address];
	}
#ifndef	HAVE_INET_ATON
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
      sin->sin_addr.s_addr = GSSwapHostI32ToBig(INADDR_ANY);
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
	  gsu16       v = val;

	  sin->sin_port = GSSwapHostI16ToBig(v);
	  return YES;
        }
      else if (strcmp(ptr, "gdomap") == 0)
	{
	  gsu16       v;
#ifdef	GDOMAP_PORT_OVERRIDE
	  v = GDOMAP_PORT_OVERRIDE;
#else
	  v = 538;	// IANA allocated port
#endif
	  sin->sin_port = GSSwapHostI16ToBig(v);
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

+ (id) allocWithZone: (NSZone*)z
{
  return NSAllocateObject ([self class], 0, z);
}

- (void) dealloc
{
  RELEASE(address);
  RELEASE(service);
  RELEASE(protocol);

  [self gcFinalize];

  RELEASE(readInfo);
  RELEASE(writeInfo);
  [super dealloc];
}

- (void) gcFinalize
{
  if (self == fh_stdin)
    fh_stdin = nil;
  if (self == fh_stdout)
    fh_stdout = nil;
  if (self == fh_stderr)
    fh_stderr = nil;

  [self ignoreReadDescriptor];
  [self ignoreWriteDescriptor];

#if	USE_ZLIB
  /*
   * The gzDescriptor should always be closed when we have done with it.
   */
  if (gzDescriptor != 0)
    {
      gzclose(gzDescriptor);
    }
#endif
  if (descriptor != -1)
    {
      [self setNonBlocking: wasNonBlocking];
      if (closeOnDealloc == YES)
	{
#if defined(__MINGW__)
	  if (isSocket)
            {
              closesocket((SOCKET)_get_osfhandle(descriptor));
	      WSACloseEvent(event);
	      event = WSA_INVALID_EVENT;
            }
#endif
	  close(descriptor);
	  descriptor = -1;
	}
    }
}

// Initializing a GSFileHandle Object

- (id) init
{
  return [self initWithNullDevice];
}

/**
 * Initialise as a client socket connection ... do this by using
 * [-initAsClientInBackgroundAtAddress:service:protocol:forModes:]
 * and running the current run loop in NSDefaultRunLoopMode until
 * the connection attempt succeeds, fails, or times out.
 */
- (id) initAsClientAtAddress: (NSString*)a
		     service: (NSString*)s
		    protocol: (NSString*)p
{
  self = [self initAsClientInBackgroundAtAddress: a
					 service: s
					protocol: p
					forModes: nil];
  if (self != nil)
    {
      NSRunLoop	*loop;
      NSDate	*limit;

      loop = [NSRunLoop currentRunLoop];
      limit = [NSDate dateWithTimeIntervalSinceNow: 300];
      while ([limit timeIntervalSinceNow] > 0
	&& (readInfo != nil || [writeInfo count] > 0))
	{
	  [loop runMode: NSDefaultRunLoopMode
	     beforeDate: limit];
	}
      if (readInfo != nil || [writeInfo count] > 0 || readOK == NO)
	{
	  /* Must have timed out or failed */
	  DESTROY(self);
	}
      else
	{
	  [self setNonBlocking: NO];
	}
    }
  return self;
}

/*
 * States for socks connection negotiation
 */
NSString * const GSSOCKSConnect = @"GSSOCKSConnect";
NSString * const GSSOCKSSendAuth = @"GSSOCKSSendAuth";
NSString * const GSSOCKSRecvAuth = @"GSSOCKSRecvAuth";
NSString * const GSSOCKSSendConn = @"GSSOCKSSendConn";
NSString * const GSSOCKSRecvConn = @"GSSOCKSRecvConn";
NSString * const GSSOCKSRecvAddr = @"GSSOCKSRecvAddr";

- (void) _socksHandler: (NSNotification*)aNotification
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSString		*name = [aNotification name];
  NSDictionary		*info = (NSMutableDictionary*)[aNotification userInfo];
  NSArray		*modes;
  NSString		*error;
  NSMutableDictionary	*i = nil;
  NSNotification	*n = nil;

  NSDebugMLLog(@"NSFileHandle", @"%@ SOCKS connection: %@",
    self, aNotification);

  [nc removeObserver: self name: name object: self];

  modes = (NSArray*)[info objectForKey: NSFileHandleNotificationMonitorModes];
  error = [info objectForKey: GSFileHandleNotificationError];

  if (error == nil)
    {
      if (name == GSSOCKSConnect)
	{
	  NSData	*item;

	  /*
	   * Send an authorisation record to the SOCKS server.
	   */
	  i = [info mutableCopy];
	  /*
	   * Authorisation record is at least three bytes -
	   *   socks version (5)
	   *   authorisation method bytes to follow (1)
	   *   say we do no authorisation (0)
	   */
	  item = [[NSData alloc] initWithBytes: "\5\1\0"
					length: 3];
	  [i setObject: item forKey: NSFileHandleNotificationDataItem];
	  RELEASE(item);
	  [i setObject: GSSOCKSSendAuth forKey: NotificationKey];
	  [writeInfo addObject: i];
	  RELEASE(i);
	  [nc addObserver: self
		 selector: @selector(_socksHandler:)
		     name: GSSOCKSSendAuth
		   object: self];
	  [self watchWriteDescriptor];
	}
      else if (name == GSSOCKSSendAuth)
	{
	  NSMutableData	*item;

	  /*
	   * We have written the authorisation record, so we
	   * request a response from the SOCKS server.
	   */
	  readMax = 2;
	  readInfo = [info mutableCopy];
	  [readInfo setObject: GSSOCKSRecvAuth forKey: NotificationKey];
	  item = [[NSMutableData alloc] initWithCapacity: 0];
	  [readInfo setObject: item forKey: NSFileHandleNotificationDataItem];
	  RELEASE(item);
	  [nc addObserver: self
		 selector: @selector(_socksHandler:)
		     name: GSSOCKSRecvAuth
		   object: self];
	  [self watchReadDescriptorForModes: modes];
	}
      else if (name == GSSOCKSRecvAuth)
	{
	  NSData		*response;
	  const unsigned char	*bytes;

	  response = [info objectForKey: NSFileHandleNotificationDataItem];
	  bytes = (const unsigned char*)[response bytes];
	  if ([response length] != 2)
	    {
	      error = @"authorisation response from SOCKS was not two bytes";
	    }
	  else if (bytes[0] != 5)
	    {
	      error = @"authorisation response from SOCKS had wrong version";
	    }
	  else if (bytes[1] != 0)
	    {
	      error = @"authorisation response from SOCKS had wrong method";
	    }
	  else
	    {
	      NSData		*item;
	      char		buf[10];
	      const char	*ptr;
	      int		p;

	      /*
	       * Send the address information to the SOCKS server.
	       */
	      i = [info mutableCopy];
	      /*
	       * Connect command is ten bytes -
	       *   socks version
	       *   connect command
	       *   reserved byte
	       *   address type
	       *   address 4 bytes (big endian)
	       *   port 2 bytes (big endian)
	       */
	      buf[0] = 5;	// Socks version number
	      buf[1] = 1;	// Connect command
	      buf[2] = 0;	// Reserved
	      buf[3] = 1;	// Address type (IPV4)
	      ptr = [address lossyCString];
	      buf[4] = atoi(ptr);
	      while (isdigit(*ptr))
		ptr++;
	      ptr++;
	      buf[5] = atoi(ptr);
	      while (isdigit(*ptr))
		ptr++;
	      ptr++;
	      buf[6] = atoi(ptr);
	      while (isdigit(*ptr))
		ptr++;
	      ptr++;
	      buf[7] = atoi(ptr);
	      p = [service intValue];
	      buf[8] = ((p & 0xff00) >> 8);
	      buf[9] = (p & 0xff);

	      item = [[NSData alloc] initWithBytes: buf length: 10];
	      [i setObject: item forKey: NSFileHandleNotificationDataItem];
	      RELEASE(item);
	      [i setObject: GSSOCKSSendConn
		    forKey: NotificationKey];
	      [writeInfo addObject: i];
	      RELEASE(i);
	      [nc addObserver: self
		     selector: @selector(_socksHandler:)
			 name: GSSOCKSSendConn
		       object: self];
	      [self watchWriteDescriptor];
	    }
	}
      else if (name == GSSOCKSSendConn)
	{
	  NSMutableData	*item;

	  /*
	   * We have written the connect command, so we
	   * request a response from the SOCKS server.
	   */
	  readMax = 4;
	  readInfo = [info mutableCopy];
	  [readInfo setObject: GSSOCKSRecvConn forKey: NotificationKey];
	  item = [[NSMutableData alloc] initWithCapacity: 0];
	  [readInfo setObject: item forKey: NSFileHandleNotificationDataItem];
	  RELEASE(item);
	  [nc addObserver: self
		 selector: @selector(_socksHandler:)
		     name: GSSOCKSRecvConn
		   object: self];
	  [self watchReadDescriptorForModes: modes];
	}
      else if (name == GSSOCKSRecvConn)
	{
	  NSData		*response;
	  const unsigned char	*bytes;
	  unsigned		len = 0;

	  response = [info objectForKey: NSFileHandleNotificationDataItem];
	  bytes = (const unsigned char*)[response bytes];
	  if ([response length] != 4)
	    {
	      error = @"connect response from SOCKS had bad length";
	    }
	  else if (bytes[0] != 5)
	    {
	      error = @"connect response from SOCKS had wrong version";
	    }
	  else if (bytes[1] != 0)
	    {
	      switch (bytes[1])
		{
		  case 1:
		    error = @"SOCKS server general failure";
		    break;
		  case 2:
		    error = @"SOCKS server says permission denied";
		    break;
		  case 3:
		    error = @"SOCKS server says network unreachable";
		    break;
		  case 4:
		    error = @"SOCKS server says host unreachable";
		    break;
		  case 5:
		    error = @"SOCKS server says connection refused";
		    break;
		  case 6:
		    error = @"SOCKS server says connection timed out";
		    break;
		  case 7:
		    error = @"SOCKS server says command not supported";
		    break;
		  case 8:
		    error = @"SOCKS server says address type not supported";
		    break;
		  default:
		    error = @"connect response from SOCKS was failure";
		    break;
		}
	    }
	  else if (bytes[3] == 1)
	    {
	      len = 4;			// Fixed size (IPV4) address
	    }
	  else if (bytes[3] == 3)
	    {
	      len = 1 + bytes[4];	// Domain name with leading length
	    }
	  else if (bytes[3] == 4)
	    {
	      len = 16;			// Fixed size (IPV6) address
	    }
	  else
	    {
	      error = @"SOCKS server returned unknown address type";
	    }

	  if (error == nil)
	    {
	      NSMutableData	*item;

	      /*
	       * We have received a success, so we must now consume the
	       * address and port information the SOCKS server sends.
	       */
	      readMax = len + 2;
	      readInfo = [info mutableCopy];
	      [readInfo setObject: GSSOCKSRecvAddr forKey: NotificationKey];
	      item = [[NSMutableData alloc] initWithCapacity: 0];
	      [readInfo setObject: item
			   forKey: NSFileHandleNotificationDataItem];
	      RELEASE(item);
	      [nc addObserver: self
		     selector: @selector(_socksHandler:)
			 name: GSSOCKSRecvAddr
		       object: self];
	      [self watchReadDescriptorForModes: modes];
	    }
	}
      else if (name == GSSOCKSRecvAddr)
	{
	  /*
	   * Success ... We read the address from the socks server so
	   * the connection is now ready to go.
	   */
	  name = GSFileHandleConnectCompletionNotification;
	  i = [info mutableCopy];
	  [i setObject: name forKey: NotificationKey];
	  n = [NSNotification notificationWithName: name
					    object: self
					  userInfo: i];
	  RELEASE(i);
	}
      else
	{
	  /*
	   * Argh ... unexpected notification.
	   */
	  error = @"unexpected notification during SOCKS connection";
	}
    }

  /*
   * If 'error' is non-null, we set up a notification to tell people
   * the connection failed.
   */
  if (error != nil)
    {
      NSDebugMLLog(@"NSFileHandle", @"%@ SOCKS error: %@", self, error);

      /*
       * An error in the initial connection ... notify observers
       * by re-posting the notification with a new name.
       */
      name = GSFileHandleConnectCompletionNotification;
      i = [info mutableCopy];
      [i setObject: name forKey: NotificationKey];
      [i setObject: error forKey: GSFileHandleNotificationError];
      n = [NSNotification notificationWithName: name
					object: self
				      userInfo: i];
      RELEASE(i);
    }

  /*
   * If a notification has been set up, we post it as the last thing we do.
   */
  if (n != nil)
    {
      NSNotificationQueue	*q;

      q = [NSNotificationQueue defaultQueue];
      [q enqueueNotification: n
		postingStyle: NSPostASAP
		coalesceMask: NSNotificationNoCoalescing
		    forModes: modes];
    }
}

- (id) initAsClientInBackgroundAtAddress: (NSString*)a
				 service: (NSString*)s
			        protocol: (NSString*)p
			        forModes: (NSArray*)modes
{
  static NSString	*esocks = nil;
  static NSString	*dsocks = nil;
  static BOOL		beenHere = NO;
  SOCKET		net;
  struct sockaddr_in	sin;
  struct sockaddr_in	lsin;
  NSString		*lhost = nil;
  NSString		*shost = nil;
  NSString		*sport = nil;
  int			status;

  if (beenHere == NO)
    {
      NSUserDefaults	*defs;

      beenHere = YES;
      defs = [NSUserDefaults standardUserDefaults];
      dsocks = [[defs stringForKey: @"GSSOCKS"] copy];
      if (dsocks == nil)
	{
	  NSDictionary	*env;

	  env = [[NSProcessInfo processInfo] environment];
	  esocks = [env objectForKey: @"SOCKS5_SERVER"];
	  if (esocks == nil)
	    {
	      esocks = [env objectForKey: @"SOCKS_SERVER"];
	    }
	  [esocks = esocks copy];
	}
    }

  if (a == nil || [a isEqualToString: @""])
    {
      a = @"localhost";
    }
  if (s == nil)
    {
      NSLog(@"bad argument - service is nil");
      RELEASE(self);
      return nil;
    }

  if ([p hasPrefix: @"bind-"] == YES)
    {
      NSRange	r;

      lhost = [p substringFromIndex: 5];
      r = [lhost rangeOfString: @":"];
      if (r.length > 0)
	{
	  p = [lhost substringFromIndex: NSMaxRange(r)];
	  lhost = [lhost substringToIndex: r.location];
	}
      else
	{
	  p = nil;
	}
      if (getAddr(lhost, p, @"tcp", &lsin) == NO)
	{
	  NSLog(@"bad bind address specification");
	  RELEASE(self);
	  return nil;
	}
      p = @"tcp";
    }

  /**
   * A protocol fo the form 'socks-...' controls socks operation,
   * overriding defaults and environment variables.<br />
   * If it is just 'socks-' it turns off socks for this fiel handle.<br />
   * Otherwise, the following text must be the name of the socks server
   * (optionally followed by :port).
   */
  if ([p hasPrefix: @"socks-"] == YES)
    {
      shost = [p substringFromIndex: 6];
      p = @"tcp";
    }
  else if (dsocks != nil)
    {
      shost = dsocks;	// GSSOCKS user default
    }
  else
    {
      shost = esocks;	// SOCKS_SERVER environment variable.
    }

  if (shost != nil && [shost length] > 0)
    {
      NSRange	r;

      r = [shost rangeOfString: @":"];
      if (r.length > 0)
	{
	  sport = [shost substringFromIndex: NSMaxRange(r)];
	  shost = [shost substringToIndex: r.location];
	}
      else
	{
	  sport = @"1080";
	}
      p = @"tcp";
    }

  if (getAddr(a, s, p, &sin) == NO)
    {
      RELEASE(self);
      NSLog(@"bad address-service-protocol combination");
      return nil;
    }
  [self setAddr: &sin];		// Store the address of the remote end.

  /*
   * Don't use SOCKS if we are contacting the local host.
   */
  if (shost != nil)
    {
      NSHost	*remote = [NSHost hostWithAddress: [self socketAddress]];
      NSHost	*local = [NSHost currentHost];

      if ([remote isEqual: local] || [remote isEqual: [NSHost localHost]])
        {
	  shost = nil;
	}
    }
  if (shost != nil)
    {
      if (getAddr(shost, sport, p, &sin) == NO)
	{
	  NSLog(@"bad SOCKS host-port combination");
	  RELEASE(self);
	  return nil;
	}
    }

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) == INVALID_SOCKET)
    {
      NSLog(@"unable to create socket - %s", GSLastErrorStr(errno));
      RELEASE(self);
      return nil;
    }
  /*
   * Enable tcp-level tracking of whether connection is alive.
   */
  status = 1;
  setsockopt(net, SOL_SOCKET, SO_KEEPALIVE, (char *)&status, sizeof(status));

  if (lhost != nil)
    {
      if (bind(net, (struct sockaddr *)&lsin, sizeof(lsin)) == SOCKET_ERROR)
	{
	  NSLog(@"unable to bind to port %s:%d - %s", inet_ntoa(lsin.sin_addr),
	    GSSwapBigI16ToHost(sin.sin_port), GSLastErrorStr(errno));
#if defined(__MINGW__)
	  (void) closesocket(net);
#else
	  (void) close(net);
#endif
	  RELEASE(self);
	  return nil;
	}
    }

#if defined(__MINGW__)
  self = [self initWithNativeHandle: (void*)net closeOnDealloc: YES];
#else
  self = [self initWithFileDescriptor: net closeOnDealloc: YES];
#endif
  if (self)
    {
      NSMutableDictionary*	info;

      isSocket = YES;
      [self setNonBlocking: YES];
      if (connect(net, (struct sockaddr*)&sin, sizeof(sin)) == SOCKET_ERROR)
	{
#if defined(__MINGW__)
	  if (WSAGetLastError() != WSAEWOULDBLOCK)
#else
	  if (errno != EINPROGRESS)
#endif
	    {
	      NSLog(@"unable to make connection to %s:%d - %s",
		inet_ntoa(sin.sin_addr),
		GSSwapBigI16ToHost(sin.sin_port), GSLastErrorStr(errno));
	      RELEASE(self);
	      return nil;
	    }
	}
	
      info = [[NSMutableDictionary alloc] initWithCapacity: 4];
      [info setObject: address forKey: NSFileHandleNotificationDataItem];
      if (shost == nil)
	{
	  [info setObject: GSFileHandleConnectCompletionNotification
		   forKey: NotificationKey];
	}
      else
	{
	  NSNotificationCenter	*nc;

	  /*
	   * If we are making a socks connection, register self as an
	   * observer of notifications and ensure we will manage this.
	   */
	  nc = [NSNotificationCenter defaultCenter];
	  [nc addObserver: self
		 selector: @selector(_socksHandler:)
		     name: GSSOCKSConnect
		   object: self];
	  [info setObject: GSSOCKSConnect
		   forKey: NotificationKey];
	}
      if (modes)
	{
	  [info setObject: modes forKey: NSFileHandleNotificationMonitorModes];
	}
      [writeInfo addObject: info];
      RELEASE(info);
      [self watchWriteDescriptor];
      connectOK = YES;
      acceptOK = NO;
      readOK = NO;
      writeOK = NO;
    }
  return self;
}

- (id) initAsServerAtAddress: (NSString*)a
		     service: (NSString*)s
		    protocol: (NSString*)p
{
#ifndef	BROKEN_SO_REUSEADDR
  int		status = 1;
#endif
  SOCKET	net;
  struct sockaddr_in	sin;
  unsigned int		size = sizeof(sin);

  if (getAddr(a, s, p, &sin) == NO)
    {
      RELEASE(self);
      NSLog(@"bad address-service-protocol combination");
      return  nil;
    }

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) == INVALID_SOCKET)
    {
      NSLog(@"unable to create socket - %s", GSLastErrorStr(errno));
      RELEASE(self);
      return nil;
    }

#ifndef	BROKEN_SO_REUSEADDR
  /*
   * Under decent systems, SO_REUSEADDR means that the port can be reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  setsockopt(net, SOL_SOCKET, SO_REUSEADDR, (char *)&status, sizeof(status));
#endif

  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) == SOCKET_ERROR)
    {
      NSLog(@"unable to bind to port %s:%d - %s", inet_ntoa(sin.sin_addr),
	GSSwapBigI16ToHost(sin.sin_port), GSLastErrorStr(errno));
#if defined(__MINGW__)
      (void) closesocket(net);
#else
      (void) close(net);
#endif
      RELEASE(self);
      return nil;
    }

  if (listen(net, 5) == SOCKET_ERROR)
    {
      NSLog(@"unable to listen on port - %s", GSLastErrorStr(errno));
#if defined(__MINGW__)
      (void) closesocket(net);
#else
      (void) close(net);
#endif
      RELEASE(self);
      return nil;
    }

  if (getsockname(net, (struct sockaddr*)&sin, &size) == SOCKET_ERROR)
    {
      NSLog(@"unable to get socket name - %s", GSLastErrorStr(errno));
#if defined(__MINGW__)
      (void) closesocket(net);
#else
      (void) close(net);
#endif
      RELEASE(self);
      return nil;
    }

#if defined(__MINGW__)
  self = [self initWithNativeHandle: (void*)net closeOnDealloc: YES];
#else
  self = [self initWithFileDescriptor: net closeOnDealloc: YES];
#endif
  if (self)
    {
      isSocket = YES;
      connectOK = NO;
      acceptOK = YES;
      readOK = NO;
      writeOK = NO;
      [self setAddr: &sin];
    }
  return self;
}

- (id) initForReadingAtPath: (NSString*)path
{
#if defined(__MINGW__)
  int	d = _wopen(
    (unichar*)[path cStringUsingEncoding: NSUnicodeStringEncoding],
    O_RDONLY|O_BINARY);
#else
  int	d = open([path fileSystemRepresentation], O_RDONLY|O_BINARY);
#endif

  if (d < 0)
    {
      RELEASE(self);
      return nil;
    }
  else
    {
      self = [self initWithFileDescriptor: d closeOnDealloc: YES];
      if (self)
	{
	  connectOK = NO;
	  acceptOK = NO;
	  writeOK = NO;
	}
      return self;
    }
}

- (id) initForWritingAtPath: (NSString*)path
{
#if defined(__MINGW__)
  int	d = _wopen(
    (unichar*)[path cStringUsingEncoding: NSUnicodeStringEncoding],
    O_WRONLY|O_BINARY);
#else
  int	d = open([path fileSystemRepresentation], O_WRONLY|O_BINARY);
#endif

  if (d < 0)
    {
      RELEASE(self);
      return nil;
    }
  else
    {
      self = [self initWithFileDescriptor: d closeOnDealloc: YES];
      if (self)
	{
	  connectOK = NO;
	  acceptOK = NO;
	  readOK = NO;
	}
      return self;
    }
}

- (id) initForUpdatingAtPath: (NSString*)path
{
#if defined(__MINGW__)
  int	d = _wopen(
    (unichar*)[path cStringUsingEncoding: NSUnicodeStringEncoding],
    O_RDWR|O_BINARY);
#else
  int	d = open([path fileSystemRepresentation], O_RDWR|O_BINARY);
#endif

  if (d < 0)
    {
      RELEASE(self);
      return nil;
    }
  else
    {
      self = [self initWithFileDescriptor: d closeOnDealloc: YES];
      if (self != nil)
	{
	  connectOK = NO;
	  acceptOK = NO;
	}
      return self;
    }
}

- (id) initWithStandardError
{
  if (fh_stderr != nil)
    {
      RETAIN(fh_stderr);
      RELEASE(self);
    }
  else
    {
      self = [self initWithFileDescriptor: 2 closeOnDealloc: NO];
      fh_stderr = self;
    }
  self = fh_stderr;
  if (self)
    {
      readOK = NO;
    }
  return self;
}

- (id) initWithStandardInput
{
  if (fh_stdin != nil)
    {
      RETAIN(fh_stdin);
      RELEASE(self);
    }
  else
    {
      self = [self initWithFileDescriptor: 0 closeOnDealloc: NO];
      fh_stdin = self;
    }
  self = fh_stdin;
  if (self)
    {
      writeOK = NO;
    }
  return self;
}

- (id) initWithStandardOutput
{
  if (fh_stdout != nil)
    {
      RETAIN(fh_stdout);
      RELEASE(self);
    }
  else
    {
      self = [self initWithFileDescriptor: 1 closeOnDealloc: NO];
      fh_stdout = self;
    }
  self = fh_stdout;
  if (self)
    {
      readOK = NO;
    }
  return self;
}

- (id) initWithNullDevice
{
#if defined(__MINGW__)
  isNullDevice = YES;
  isStandardFile = YES;
  descriptor = -1;
#else
  self = [self initWithFileDescriptor: open("/dev/null", O_RDWR|O_BINARY)
		       closeOnDealloc: YES];
  if (self)
    {
      isNullDevice = YES;
    }
#endif
  return self;
}

- (id) initWithFileDescriptor: (int)desc closeOnDealloc: (BOOL)flag
{
  self = [super init];
  if (self != nil)
    {
#if defined(__MINGW__)
      struct _stat sbuf;
#else
      struct stat sbuf;
      int	  e;
#endif

#if defined(__MINGW__)
      if (_fstat(desc, &sbuf) != 0)
#else
      if (fstat(desc, &sbuf) < 0)
#endif
	{
          NSLog(@"unable to get status of descriptor %d - %s",
	    desc, GSLastErrorStr(errno));
	}
      else
	{
	  if (S_ISREG(sbuf.st_mode))
	    {
	      isStandardFile = YES;
	    }
	  else
	    {
	      isStandardFile = NO;
	    }
	}

#if defined(__MINGW__)
      if (isStandardFile == NO)
	{
	  unsigned long nbio = 0;

	  isSocket = YES;
	  /*
	   * This is probably a socket ... try
	   * using a socket specific call and see if that fails.
	   */
	  if (ioctlsocket((SOCKET)_get_osfhandle(desc), FIONBIO, &nbio) == 0)
	    {
	      wasNonBlocking = (nbio == 0) ? NO : YES;
	    }
	  else
	    {
	      isSocket = NO; // maybe special file desc. like std in/out/err?
	    }
	}
#else
      if ((e = fcntl(desc, F_GETFL, 0)) >= 0)
	{
	  if (e & NBLK_OPT)
	    {
	      wasNonBlocking = YES;
	    }
	  else
	    {
	      wasNonBlocking = NO;
	    }
	}
#endif

      isNonBlocking = wasNonBlocking;
      descriptor = desc;
      closeOnDealloc = flag;
      readInfo = nil;
      writeInfo = [NSMutableArray new];
      readMax = 0;
      writePos = 0;
      readOK = YES;
      writeOK = YES;
      acceptOK = YES;
      connectOK = YES;
#ifdef __MINGW32__
      if (isSocket)
        {
          event = CreateEvent(NULL, NO, NO, NULL);
          if (event == WSA_INVALID_EVENT)
            {
              NSLog(@"Invalid Event - '%d'", WSAGetLastError());
              return nil;
            }
          WSAEventSelect(_get_osfhandle(descriptor), event, FD_ALL_EVENTS);
        }
      else
	{
	  event = WSA_INVALID_EVENT;
	}
#endif
    }
  return self;
}

- (id) initWithNativeHandle: (void*)hdl
{
#if defined(__MINGW__)
  return [self initWithFileDescriptor: _open_osfhandle((SOCKET)hdl, 0)
		       closeOnDealloc: NO];
#else
  return [self initWithFileDescriptor: (gsaddr)hdl closeOnDealloc: NO];
#endif
}

- (id) initWithNativeHandle: (void*)hdl closeOnDealloc: (BOOL)flag
{
#if defined(__MINGW__)
  return [self initWithFileDescriptor: _open_osfhandle((SOCKET)hdl, 0)
		       closeOnDealloc: flag];
#else
  return [self initWithFileDescriptor: (gsaddr)hdl closeOnDealloc: flag];
#endif
}

- (void) checkAccept
{
  if (acceptOK == NO)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"accept not permitted in this file handle"];
    }
  if (readInfo)
    {
      id	operation = [readInfo objectForKey: NotificationKey];

      if (operation == NSFileHandleConnectionAcceptedNotification)
        {
          [NSException raise: NSFileHandleOperationException
                      format: @"accept already in progress"];
	}
      else
	{
          [NSException raise: NSFileHandleOperationException
                      format: @"read already in progress"];
	}
    }
}

- (void) checkConnect
{
  if (connectOK == NO)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"connect not permitted in this file handle"];
    }
  if ([writeInfo count] > 0)
    {
      NSDictionary	*info = [writeInfo objectAtIndex: 0];
      id		operation = [info objectForKey: NotificationKey];

      if (operation == GSFileHandleConnectCompletionNotification)
	{
          [NSException raise: NSFileHandleOperationException
                      format: @"connect already in progress"];
	}
      else
	{
          [NSException raise: NSFileHandleOperationException
                      format: @"write already in progress"];
	}
    }
}

- (void) checkRead
{
  if (readOK == NO)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"read not permitted on this file handle"];
    }
  if (readInfo)
    {
      id	operation = [readInfo objectForKey: NotificationKey];

      if (operation == NSFileHandleConnectionAcceptedNotification)
        {
          [NSException raise: NSFileHandleOperationException
                      format: @"accept already in progress"];
	}
      else
	{
          [NSException raise: NSFileHandleOperationException
                      format: @"read already in progress"];
	}
    }
}

- (void) checkWrite
{
  if (writeOK == NO)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"write not permitted in this file handle"];
    }
  if ([writeInfo count] > 0)
    {
      NSDictionary	*info = [writeInfo objectAtIndex: 0];
      id		operation = [info objectForKey: NotificationKey];

      if (operation != GSFileHandleWriteCompletionNotification)
	{
          [NSException raise: NSFileHandleOperationException
                      format: @"connect in progress"];
	}
    }
}

// Returning file handles

- (int) fileDescriptor
{
  return descriptor;
}

- (void*) nativeHandle
{
#if defined(__MINGW__)
  return (void*)(SOCKET)_get_osfhandle(descriptor);
#else
  return (void*)descriptor;
#endif
}

// Synchronous I/O operations

- (NSData*) availableData
{
  char			buf[READ_SIZE];
  NSMutableData*	d;
  int			len;

  [self checkRead];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }
  d = [NSMutableData dataWithCapacity: 0];
  if (isStandardFile)
    {
      while ((len = [self read: buf length: sizeof(buf)]) > 0)
        {
	  [d appendBytes: buf length: len];
        }
    }
  else
    {
      len = [self read: buf length: sizeof(buf)];
      if (len > 0)
	{
	  [d appendBytes: buf length: len];
	}
    }
  if (len < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to read from descriptor - %s",
                  GSLastErrorStr(errno)];
    }
  return d;
}

- (NSData*) readDataToEndOfFile
{
  char			buf[READ_SIZE];
  NSMutableData*	d;
  int			len;

  [self checkRead];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }
  d = [NSMutableData dataWithCapacity: 0];
  while ((len = [self read: buf length: sizeof(buf)]) > 0)
    {
      [d appendBytes: buf length: len];
    }
  if (len < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to read from descriptor - %s",
                  GSLastErrorStr(errno)];
    }
  return d;
}

- (NSData*) readDataOfLength: (unsigned)len
{
  NSMutableData	*d;
  int		got;

  [self checkRead];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }
  if (len <= 65536)
    {
      char	*buf;

      buf = NSZoneMalloc(NSDefaultMallocZone(), len);
      d = [NSMutableData dataWithBytesNoCopy: buf length: len];
      got = [self read: [d mutableBytes] length: len];
      if (got < 0)
	{
	  [NSException raise: NSFileHandleOperationException
		      format: @"unable to read from descriptor - %s",
		      GSLastErrorStr(errno)];
	}
      [d setLength: got];
    }
  else
    {
      char	buf[READ_SIZE];

      d = [NSMutableData dataWithCapacity: 0];
      do
	{
	  int	chunk = len > sizeof(buf) ? sizeof(buf) : len;

	  got = [self read: buf length: chunk];
	  if (got > 0)
	    {
	      [d appendBytes: buf length: got];
	      len -= got;
	    }
	  else if (got < 0)
	    {
	      [NSException raise: NSFileHandleOperationException
			  format: @"unable to read from descriptor - %s",
			  GSLastErrorStr(errno)];
	    }
	}
      while (len > 0 && got > 0);
    }
  return d;
}

- (void) writeData: (NSData*)item
{
  int		rval = 0;
  const void*	ptr = [item bytes];
  unsigned int	len = [item length];
  unsigned int	pos = 0;

  [self checkWrite];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }
  while (pos < len)
    {
      int	toWrite = len - pos;

      if (toWrite > NETBUF_SIZE)
	{
	  toWrite = NETBUF_SIZE;
	}
      rval = [self write: (char*)ptr+pos length: toWrite];
      if (rval < 0)
	{
#ifdef __MINGW32__
          if (WSAGetLastError()== WSAEINTR ||
                WSAGetLastError()== WSAEWOULDBLOCK)
#else
	  if (errno == EAGAIN || errno == EINTR)
#endif
	    {
	      rval = 0;
	    }
	  else
	    {
	      break;
	    }
	}
      pos += rval;
    }
  if (rval < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to write to descriptor - %s",
                  GSLastErrorStr(errno)];
    }
}


// Asynchronous I/O operations

- (void) acceptConnectionInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self checkAccept];
  readMax = 0;
  RELEASE(readInfo);
  readInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [readInfo setObject: NSFileHandleConnectionAcceptedNotification
	       forKey: NotificationKey];
  [self watchReadDescriptorForModes: modes];
}

- (void) readDataInBackgroundAndNotifyLength: (unsigned)len
				    forModes: (NSArray*)modes
{
  NSMutableData	*d;

  [self checkRead];
  if (len > 0x7fffffff)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"length (%u) too large", len];
    }
  readMax = len;
  RELEASE(readInfo);
  readInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [readInfo setObject: NSFileHandleReadCompletionNotification
	       forKey: NotificationKey];
  d = [[NSMutableData alloc] initWithCapacity: readMax];
  [readInfo setObject: d forKey: NSFileHandleNotificationDataItem];
  RELEASE(d);
  [self watchReadDescriptorForModes: modes];
}

- (void) readInBackgroundAndNotifyForModes: (NSArray*)modes
{
  NSMutableData	*d;

  [self checkRead];
  readMax = -1;		// Accept any quantity of data.
  RELEASE(readInfo);
  readInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [readInfo setObject: NSFileHandleReadCompletionNotification
	       forKey: NotificationKey];
  d = [[NSMutableData alloc] initWithCapacity: 0];
  [readInfo setObject: d forKey: NSFileHandleNotificationDataItem];
  RELEASE(d);
  [self watchReadDescriptorForModes: modes];
}

- (void) readToEndOfFileInBackgroundAndNotifyForModes: (NSArray*)modes
{
  NSMutableData	*d;

  [self checkRead];
  readMax = 0;
  RELEASE(readInfo);
  readInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [readInfo setObject: NSFileHandleReadToEndOfFileCompletionNotification
	       forKey: NotificationKey];
  d = [[NSMutableData alloc] initWithCapacity: 0];
  [readInfo setObject: d forKey: NSFileHandleNotificationDataItem];
  RELEASE(d);
  [self watchReadDescriptorForModes: modes];
}

- (void) waitForDataInBackgroundAndNotifyForModes: (NSArray*)modes
{
  [self checkRead];
  readMax = 0;
  RELEASE(readInfo);
  readInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [readInfo setObject: NSFileHandleDataAvailableNotification
	       forKey: NotificationKey];
  [readInfo setObject: [NSMutableData dataWithCapacity: 0]
	       forKey: NSFileHandleNotificationDataItem];
  [self watchReadDescriptorForModes: modes];
}

// Seeking within a file

- (unsigned long long) offsetInFile
{
  off_t	result = -1;

  if (isStandardFile && descriptor >= 0)
    {
#if	USE_ZLIB
      if (gzDescriptor != 0)
	{
	  result = gzseek(gzDescriptor, 0, SEEK_CUR);
	}
      else
#endif
#if defined(__MINGW__)
      result = _lseek(descriptor, 0, SEEK_CUR);
#else
      result = lseek(descriptor, 0, SEEK_CUR);
#endif
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %s",
                  GSLastErrorStr(errno)];
    }
  return (unsigned long long)result;
}

- (unsigned long long) seekToEndOfFile
{
  off_t	result = -1;

  if (isStandardFile && descriptor >= 0)
    {
#if	USE_ZLIB
      if (gzDescriptor != 0)
	{
	  result = gzseek(gzDescriptor, 0, SEEK_END);
	}
      else
#endif
#if defined(__MINGW__)
      result = _lseek(descriptor, 0, SEEK_END);
#else
      result = lseek(descriptor, 0, SEEK_END);
#endif
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %s",
                  GSLastErrorStr(errno)];
    }
  return (unsigned long long)result;
}

- (void) seekToFileOffset: (unsigned long long)pos
{
  off_t	result = -1;

  if (isStandardFile && descriptor >= 0)
    {
#if	USE_ZLIB
      if (gzDescriptor != 0)
	{
	  result = gzseek(gzDescriptor, (off_t)pos, SEEK_SET);
	}
      else
#endif
#if defined(__MINGW__)
      result = _lseek(descriptor, (off_t)pos, SEEK_SET);
#else
      result = lseek(descriptor, (off_t)pos, SEEK_SET);
#endif
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %s",
                  GSLastErrorStr(errno)];
    }
}


// Operations on file

- (void) closeFile
{
  if (descriptor < 0)
    {
      [NSException raise: NSFileHandleOperationException
		  format: @"attempt to close closed file"];
    }
  [self ignoreReadDescriptor];
  [self ignoreWriteDescriptor];

  [self setNonBlocking: wasNonBlocking];
#if	USE_ZLIB
  if (gzDescriptor != 0)
    {
      gzclose(gzDescriptor);
      gzDescriptor = 0;
    }
#endif
#if defined(__MINGW__)
  if (isSocket)
    {
      (void)closesocket((SOCKET)_get_osfhandle(descriptor));
      WSACloseEvent(event);
      event = WSA_INVALID_EVENT;
    }
#endif
  (void)close(descriptor);
  descriptor = -1;
  acceptOK = NO;
  connectOK = NO;
  readOK = NO;
  writeOK = NO;

  /*
   *    Clear any pending operations on the file handle, sending
   *    notifications if necessary.
   */
  if (readInfo)
    {
      [readInfo setObject: @"File handle closed locally"
                   forKey: GSFileHandleNotificationError];
      [self postReadNotification];
    }

  if ([writeInfo count])
    {
      NSMutableDictionary       *info = [writeInfo objectAtIndex: 0];

      [info setObject: @"File handle closed locally"
               forKey: GSFileHandleNotificationError];
      [self postWriteNotification];
      [writeInfo removeAllObjects];
    }
}

- (void) synchronizeFile
{
  if (isStandardFile)
    {
#if defined(__MINGW__)
      (void)_commit(descriptor);
#else
      (void)sync();
#endif
    }
}

- (void) truncateFileAtOffset: (unsigned long long)pos
{
#if defined(__MINGW__)
  _chsize(descriptor, pos);
#else
  if (isStandardFile && descriptor >= 0)
    {
      (void)ftruncate(descriptor, pos);
    }
#endif
  [self seekToFileOffset: pos];
}

- (void) writeInBackgroundAndNotify: (NSData*)item forModes: (NSArray*)modes
{
  NSMutableDictionary*	info;

  [self checkWrite];

  info = [[NSMutableDictionary alloc] initWithCapacity: 4];
  [info setObject: item forKey: NSFileHandleNotificationDataItem];
  [info setObject: GSFileHandleWriteCompletionNotification
		forKey: NotificationKey];
  if (modes != nil)
    {
      [info setObject: modes forKey: NSFileHandleNotificationMonitorModes];
    }
  [writeInfo addObject: info];
  RELEASE(info);
  [self watchWriteDescriptor];
}

- (void) writeInBackgroundAndNotify: (NSData*)item;
{
  [self writeInBackgroundAndNotify: item forModes: nil];
}

- (void) postReadNotification
{
  NSMutableDictionary	*info = readInfo;
  NSNotification	*n;
  NSNotificationQueue	*q;
  NSArray		*modes;
  NSString		*name;

  [self ignoreReadDescriptor];
  readInfo = nil;
  readMax = 0;
  modes = (NSArray*)[info objectForKey: NSFileHandleNotificationMonitorModes];
  name = (NSString*)[info objectForKey: NotificationKey];

  if (name == nil)
    {
      return;
    }
  n = [NSNotification notificationWithName: name object: self userInfo: info];

  RELEASE(info);	/* Retained by the notification.	*/

  q = [NSNotificationQueue defaultQueue];
  [q enqueueNotification: n
	    postingStyle: NSPostASAP
	    coalesceMask: NSNotificationNoCoalescing
		forModes: modes];
}

- (void) postWriteNotification
{
  NSMutableDictionary	*info = [writeInfo objectAtIndex: 0];
  NSNotificationQueue	*q;
  NSNotification	*n;
  NSArray		*modes;
  NSString		*name;

  [self ignoreWriteDescriptor];
  modes = (NSArray*)[info objectForKey: NSFileHandleNotificationMonitorModes];
  name = (NSString*)[info objectForKey: NotificationKey];

  n = [NSNotification notificationWithName: name object: self userInfo: info];

  writePos = 0;
  [writeInfo removeObjectAtIndex: 0];	/* Retained by notification.	*/

  q = [NSNotificationQueue defaultQueue];
  [q enqueueNotification: n
	    postingStyle: NSPostASAP
	    coalesceMask: NSNotificationNoCoalescing
		forModes: modes];
  if ((writeOK || connectOK) && [writeInfo count] > 0)
    {
      [self watchWriteDescriptor];	/* In case of queued writes.	*/
    }
}

- (BOOL) readInProgress
{
  if (readInfo)
    {
      return YES;
    }
  return NO;
}

- (BOOL) writeInProgress
{
  if ([writeInfo count] > 0)
    {
      return YES;
    }
  return NO;
}

- (void) ignoreReadDescriptor
{
  NSRunLoop	*l;
  NSArray	*modes;

  if (descriptor < 0)
    {
      return;
    }
  l = [NSRunLoop currentRunLoop];
  modes = nil;

  if (readInfo)
    {
      modes = (NSArray*)[readInfo objectForKey:
	NSFileHandleNotificationMonitorModes];
    }

  if (modes && [modes count])
    {
      unsigned int	i;

      for (i = 0; i < [modes count]; i++)
	{
#ifdef __MINGW32__
	  [l removeEvent: (void*)(gsaddr)event
		    type: ET_HANDLE
		 forMode: [modes objectAtIndex: i]
		     all: YES];
#else
	  [l removeEvent: (void*)(gsaddr)descriptor
		    type: ET_RDESC
		 forMode: [modes objectAtIndex: i]
		     all: YES];
#endif
        }
    }
  else
    {
#ifdef __MINGW32__
      [l removeEvent: (void*)(gsaddr)event
	        type: ET_HANDLE
	     forMode: NSDefaultRunLoopMode
                 all: YES];
#else
      [l removeEvent: (void*)(gsaddr)descriptor
		type: ET_RDESC
	     forMode: NSDefaultRunLoopMode
		 all: YES];
#endif
    }
}

- (void) ignoreWriteDescriptor
{
  NSRunLoop	*l;
  NSArray	*modes;

  if (descriptor < 0)
    {
      return;
    }
  l = [NSRunLoop currentRunLoop];
  modes = nil;

  if ([writeInfo count] > 0)
    {
      NSMutableDictionary*	info = [writeInfo objectAtIndex: 0];

      modes=(NSArray*)[info objectForKey: NSFileHandleNotificationMonitorModes];
    }

  if (modes && [modes count])
    {
      unsigned int	i;

      for (i = 0; i < [modes count]; i++)
	{
#ifdef __MINGW32__
          [l removeEvent: (void*)(gsaddr)event
	            type: ET_HANDLE
	         forMode: [modes objectAtIndex: i]
                     all: YES];
#else
	  [l removeEvent: (void*)(gsaddr)descriptor
		    type: ET_WDESC
		 forMode: [modes objectAtIndex: i]
		     all: YES];
#endif
        }
    }
  else
    {
#ifdef __MINGW32__
      [l removeEvent: (void*)(gsaddr)event
                type: ET_HANDLE
	     forMode: NSDefaultRunLoopMode
                 all: YES];
#else
      [l removeEvent: (void*)(gsaddr)descriptor
		type: ET_WDESC
	     forMode: NSDefaultRunLoopMode
		 all: YES];
#endif
    }
}

- (void) watchReadDescriptorForModes: (NSArray*)modes;
{
  NSRunLoop	*l;

  if (descriptor < 0)
    {
      return;
    }

  l = [NSRunLoop currentRunLoop];
  [self setNonBlocking: YES];
  if (modes && [modes count])
    {
      unsigned int	i;

      for (i = 0; i < [modes count]; i++)
	{
#ifdef __MINGW32__
	  [l addEvent: (void*)(gsaddr)event
		 type: ET_HANDLE
	      watcher: self
	      forMode: [modes objectAtIndex: i]];
#else
	  [l addEvent: (void*)(gsaddr)descriptor
		 type: ET_RDESC
	      watcher: self
	      forMode: [modes objectAtIndex: i]];
#endif
        }
      [readInfo setObject: modes forKey: NSFileHandleNotificationMonitorModes];
    }
  else
    {
#ifdef __MINGW32__
      [l addEvent: (void*)(gsaddr)event
	     type: ET_HANDLE
	  watcher: self
	  forMode: NSDefaultRunLoopMode];
#else
      [l addEvent: (void*)(gsaddr)descriptor
	     type: ET_RDESC
	  watcher: self
	  forMode: NSDefaultRunLoopMode];
#endif
    }
}

- (void) watchWriteDescriptor
{
  if (descriptor < 0)
    {
      return;
    }
  if ([writeInfo count] > 0)
    {
      NSMutableDictionary	*info = [writeInfo objectAtIndex: 0];
      NSRunLoop			*l = [NSRunLoop currentRunLoop];
      NSArray			*modes = nil;

      modes = [info objectForKey: NSFileHandleNotificationMonitorModes];

      [self setNonBlocking: YES];
      if (modes && [modes count])
	{
	  unsigned int	i;

	  for (i = 0; i < [modes count]; i++)
	    {
#ifdef __MINGW32__
	      [l addEvent: (void*)(gsaddr)event
		     type: ET_HANDLE
		  watcher: self
		  forMode: [modes objectAtIndex: i]];
#else
	      [l addEvent: (void*)(gsaddr)descriptor
		     type: ET_WDESC
		  watcher: self
		  forMode: [modes objectAtIndex: i]];
#endif
	    }
	}
      else
	{
#ifdef __MINGW32__
	  [l addEvent: (void*)(gsaddr)event
		 type: ET_HANDLE
	      watcher: self
	      forMode: NSDefaultRunLoopMode];
#else
	  [l addEvent: (void*)(gsaddr)descriptor
		 type: ET_WDESC
	      watcher: self
	      forMode: NSDefaultRunLoopMode];
#endif
	}
    }
}

- (void) receivedEventRead
{
  NSString	*operation;

  operation = [readInfo objectForKey: NotificationKey];
  if (operation == NSFileHandleConnectionAcceptedNotification)
    {
      struct sockaddr_in	buf;
#if defined(__MINGW__)
      SOCKET		        desc;
#else
      int			desc;
#endif
      unsigned int		blen = sizeof(buf);

#if defined(__MINGW__)
      desc = accept((SOCKET)_get_osfhandle(descriptor), (struct sockaddr*)&buf, &blen);
#else
      desc = accept(descriptor, (struct sockaddr*)&buf, &blen);
#endif
      if (desc == INVALID_SOCKET)
	{
	  NSString	*s;

	  s = [NSString stringWithFormat: @"Accept attempt failed - %s",
		GSLastErrorStr(errno)];
	  [readInfo setObject: s forKey: GSFileHandleNotificationError];
	}
      else
	{ // Accept attempt completed.
	  GSFileHandle		*h;
	  struct sockaddr_in	sin;
	  unsigned int		size = sizeof(sin);
	  int			status;

	  /*
	   * Enable tcp-level tracking of whether connection is alive.
	   */
	  status = 1;
	  setsockopt(desc, SOL_SOCKET, SO_KEEPALIVE, (char *)&status,
	    sizeof(status));

#if defined(__MINGW__)
	  h = [[[self class] alloc] initWithNativeHandle: (void*)desc
						closeOnDealloc: YES];
#else
	  h = [[[self class] alloc] initWithFileDescriptor: desc
						closeOnDealloc: YES];
#endif
	  h->isSocket = YES;
	  getpeername(desc, (struct sockaddr*)&sin, &size);
	  [h setAddr: &sin];
	  [readInfo setObject: h
		   forKey: NSFileHandleNotificationFileHandleItem];
	  RELEASE(h);
	}
      [self postReadNotification];
    }
  else if (operation == NSFileHandleDataAvailableNotification)
    {
      [self postReadNotification];
    }
  else
    {
      NSMutableData	*item;
      int		length;
      int		received = 0;
      char		buf[READ_SIZE];

      item = [readInfo objectForKey: NSFileHandleNotificationDataItem];
      /*
       * We may have a maximum data size set...
       */
      if (readMax > 0)
        {
          length = (unsigned int)readMax - [item length];
          if (length > (int)sizeof(buf))
            {
	      length = sizeof(buf);
	    }
	}
      else
	{
	  length = sizeof(buf);
	}

      received = [self read: buf length: length];
      if (received == 0)
        { // Read up to end of file.
          [self postReadNotification];
        }
      else if (received < 0)
        {
#ifdef __MINGW32__
          if (WSAGetLastError() != WSAEINTR
	    && WSAGetLastError() != WSAEWOULDBLOCK)
#else
          if (errno != EAGAIN && errno != EINTR)
#endif
            {
	      NSString	*s;

	      s = [NSString stringWithFormat: @"Read attempt failed - %s",
		    GSLastErrorStr(errno)];
	      [readInfo setObject: s forKey: GSFileHandleNotificationError];
	      [self postReadNotification];
	    }
	}
      else
	{
	  [item appendBytes: buf length: received];
	  if (readMax < 0 || (readMax > 0 && (int)[item length] == readMax))
	    {
	      // Read a single chunk of data
	      [self postReadNotification];
	    }
	}
    }
}

- (void) receivedEventWrite
{
  NSString	*operation;
  NSMutableDictionary	*info;

  info = [writeInfo objectAtIndex: 0];
  operation = [info objectForKey: NotificationKey];
  if (operation == GSFileHandleConnectCompletionNotification
    || operation == GSSOCKSConnect)
    { // Connection attempt completed.
      int	result;
      unsigned	len = sizeof(result);

#if defined(__MINGW__)
      if (getsockopt((SOCKET)_get_osfhandle(descriptor), SOL_SOCKET, SO_ERROR,
        (char*)&result, &len) == 0 && result != 0)
#else
      if (getsockopt(descriptor, SOL_SOCKET, SO_ERROR,
        (char*)&result, &len) == 0 && result != 0)
#endif
        {
          NSString	*s;

          s = [NSString stringWithFormat: @"Connect attempt failed - %s",
		GSLastErrorStr(result)];
          [info setObject: s forKey: GSFileHandleNotificationError];
        }
      else
        {
          readOK = YES;
          writeOK = YES;
        }
      connectOK = NO;
      [self postWriteNotification];
    }
  else
    {
      NSData	*item;
      int		length;
      const void	*ptr;

      item = [info objectForKey: NSFileHandleNotificationDataItem];
      length = [item length];
      ptr = [item bytes];
      if (writePos < length)
        {
          int	written;

          written = [self write: (char*)ptr+writePos
    		     length: length-writePos];
          if (written <= 0)
            {
#ifdef __MINGW32__
              if (written < 0 && WSAGetLastError()!= WSAEINTR
		&& WSAGetLastError()!= WSAEWOULDBLOCK)
#else
	      if (written < 0 && errno != EAGAIN && errno != EINTR)
#endif
	        {
	          NSString	*s;

	          s = [NSString stringWithFormat:
	        	@"Write attempt failed - %s", GSLastErrorStr(errno)];
	          [info setObject: s forKey: GSFileHandleNotificationError];
	          [self postWriteNotification];
	        }
	    }
	  else
            {
	      writePos += written;
	    }
	}
      if (writePos >= length)
        { // Write operation completed.
          [self postWriteNotification];
        }
    }
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
#ifdef __MINGW32__
  WSANETWORKEVENTS ocurredEvents;
#endif

  NSDebugMLLog(@"NSFileHandle", @"%@ event: %d", self, type);

  if (isNonBlocking == NO)
    {
      [self setNonBlocking: YES];
    }
#ifdef __MINGW32__
  if (WSAEnumNetworkEvents((SOCKET)_get_osfhandle(descriptor), 
    event, &ocurredEvents) == SOCKET_ERROR)
    {
      NSLog(@"Error getting event type %d", WSAGetLastError());
      abort();
    }
  if (ocurredEvents.lNetworkEvents & FD_CONNECT)
    {
      NSDebugMLLog(@"NSFileHandle", @"Connect on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_CONNECT;
      [self receivedEventWrite];
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents & FD_ACCEPT)
    {
      NSDebugMLLog(@"NSFileHandle", @"Accept on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_ACCEPT;
      [self receivedEventRead];
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents & FD_WRITE)
    {
      NSDebugMLLog(@"NSFileHandle", @"Write on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_WRITE;
      [self receivedEventWrite];
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents & FD_READ)
    {
      NSDebugMLLog(@"NSFileHandle", @"Read on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_READ;
      [self receivedEventRead];
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents & FD_OOB)
    {
      NSDebugMLLog(@"NSFileHandle", @"OOB on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_OOB;
      [self receivedEventRead];
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents & FD_CLOSE)
    {
      NSDebugMLLog(@"NSFileHandle", @"Close on %x", extra);
      ocurredEvents.lNetworkEvents ^= FD_CLOSE;
      if ([writeInfo count] > 0)
	{
	  [self receivedEventWrite];
	}
      else
	{
	  [self receivedEventRead];
	}
      GSNotifyASAP();
    }
  if (ocurredEvents.lNetworkEvents)
    {
      NSLog(@"Event not get %d", ocurredEvents.lNetworkEvents);
      abort();      
    }
#else
  if (type == ET_RDESC)
    {
      [self receivedEventRead];
    }
  else
    {
      [self receivedEventWrite];
    }
#endif
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;		/* Don't restart timed out events	*/
}

- (void) setAddr: (struct sockaddr_in *)sin
{
  address = [[NSString alloc] initWithCString: (char*)inet_ntoa(sin->sin_addr)];
  service = [[NSString alloc] initWithFormat: @"%d",
    (int)GSSwapBigI16ToHost(sin->sin_port)];
  protocol = @"tcp";
}

- (void) setNonBlocking: (BOOL)flag
{
  if (descriptor < 0)
    {
      return;
    }
  else if (isStandardFile == YES)
    {
      return;
    }
  else if (isNonBlocking == flag)
    {
      return;
    }
  else
    {
#if defined(__MINGW__)
      unsigned long	dummy;

      if (isSocket != YES)
        return;

      if (flag)
	{
	  dummy = 1;
	  if (ioctlsocket((SOCKET)_get_osfhandle(descriptor), FIONBIO, &dummy)
	    == SOCKET_ERROR)
	    {
	      NSLog(@"unable to set non-blocking mode - %s",
		GSLastErrorStr(errno));
	    }
	  else
	    isNonBlocking = flag;
	}
      else
	{
	  dummy = 0;
	  if (ioctlsocket((SOCKET)_get_osfhandle(descriptor), FIONBIO, &dummy)
	    == SOCKET_ERROR)
	    {
	      NSLog(@"unable to set blocking mode - %s",
		GSLastErrorStr(errno));
	    }
	  else
	    isNonBlocking = flag;
	}
#else
      int	e;

      if ((e = fcntl(descriptor, F_GETFL, 0)) >= 0)
	{
	  if (flag == YES)
	    {
	      e |= NBLK_OPT;
	    }
	  else
	    {
	      e &= ~NBLK_OPT;
	    }
	  if (fcntl(descriptor, F_SETFL, e) < 0)
	    {
	      NSLog(@"unable to set non-blocking mode for %d - %s",
		descriptor, GSLastErrorStr(errno));
	    }
	  else
	    {
	      isNonBlocking = flag;
	    }
	}
      else
	{
	  NSLog(@"unable to get non-blocking mode for %d - %s",
	    descriptor, GSLastErrorStr(errno));
	}
#endif
    }
}

- (NSString*) socketAddress
{
  return address;
}

- (NSString*) socketLocalAddress
{
  NSString	*str = nil;
  struct sockaddr_in sin;
  unsigned	size = sizeof(sin);

  if (getsockname(descriptor, (struct sockaddr*)&sin, &size) == SOCKET_ERROR)
    {
      NSLog(@"unable to get socket name - %s", GSLastErrorStr(errno));
    }
  else
    {
      str = [NSString stringWithCString: (char*)inet_ntoa(sin.sin_addr)];
    }
  return str;
}

- (NSString*) socketLocalService
{
  NSString	*str = nil;
  struct sockaddr_in sin;
  unsigned	size = sizeof(sin);

  if (getsockname(descriptor, (struct sockaddr*)&sin, &size) == SOCKET_ERROR)
    {
      NSLog(@"unable to get socket name - %s", GSLastErrorStr(errno));
    }
  else
    {
      str = [NSString stringWithFormat: @"%d",
	(int)GSSwapBigI16ToHost(sin.sin_port)];
    }
  return str;
}

- (NSString*) socketProtocol
{
  return protocol;
}

- (NSString*) socketService
{
  return service;
}

- (BOOL) useCompression
{
#if	USE_ZLIB
  int	d;

  if (gzDescriptor != 0)
    {
      return YES;	// Already open
    }
  if (descriptor < 0)
    {
      return NO;	// No descriptor available.
    }
  if (readOK == YES && writeOK == YES)
    {
      return NO;	// Can't both read and write.
    }
  d = dup(descriptor);
  if (d < 0)
    {
      return NO;	// No descriptor available.
    }
  if (readOK == YES)
    {
      gzDescriptor = gzdopen(d, "rb");
    }
  else
    {
      gzDescriptor = gzdopen(d, "wb");
    }
  if (gzDescriptor == 0)
    {
      close(d);
      return NO;	// Open attempt failed.
    }
  return YES;
#endif
  return NO;
}
@end

