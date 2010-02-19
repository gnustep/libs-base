/** Implementation for GSFileHandle for GNUStep
   Copyright (C) 1997-2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997, 2002

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

#define	_FILE_OFFSET_BITS 64

#import "common.h"
#define	EXPOSE_GSFileHandle_IVARS	1
#import "Foundation/NSData.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSFileHandle.h"
#import "GNUstepBase/GSFileHandle.h"
#import "Foundation/NSException.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSUserDefaults.h"
#import "GSPrivate.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

#import "../Tools/gdomap.h"

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
- (NSInteger) read: (void*)buf length: (NSUInteger)len
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
      len = recv(descriptor, buf, len, 0);
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
- (NSInteger) write: (const void*)buf length: (NSUInteger)len
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
      len = send(descriptor, buf, len, 0);
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
	  uint16_t	v = val;

	  sin->sin_port = GSSwapHostI16ToBig(v);
	  return YES;
        }
      else if (strcmp(ptr, "gdomap") == 0)
	{
	  uint16_t	v;
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

  [self finalize];

  RELEASE(readInfo);
  RELEASE(writeInfo);
  [super dealloc];
}

- (void) finalize
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
  int			net;
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
	  esocks = [esocks copy];
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

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) == -1)
    {
      NSLog(@"unable to create socket - %@", [NSError _last]);
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
      if (bind(net, (struct sockaddr *)&lsin, sizeof(lsin)) == -1)
	{
	  NSLog(@"unable to bind to port %s:%d - %@", inet_ntoa(lsin.sin_addr),
	    GSSwapBigI16ToHost(sin.sin_port), [NSError _last]);
	  (void) close(net);
	  RELEASE(self);
	  return nil;
	}
    }

  self = [self initWithFileDescriptor: net closeOnDealloc: YES];
  if (self)
    {
      NSMutableDictionary*	info;

      isSocket = YES;
      [self setNonBlocking: YES];
      if (connect(net, (struct sockaddr*)&sin, sizeof(sin)) == -1)
	{
	  if (errno != EINPROGRESS)
	    {
	      NSLog(@"unable to make connection to %s:%d - %@",
		inet_ntoa(sin.sin_addr),
		GSSwapBigI16ToHost(sin.sin_port), [NSError _last]);
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
  int			status = 1;
#endif
  int			net;
  struct sockaddr_in	sin;
  unsigned int		size = sizeof(sin);

  if (getAddr(a, s, p, &sin) == NO)
    {
      RELEASE(self);
      NSLog(@"bad address-service-protocol combination");
      return  nil;
    }

  if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) == -1)
    {
      NSLog(@"unable to create socket - %@", [NSError _last]);
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

  if (bind(net, (struct sockaddr *)&sin, sizeof(sin)) == -1)
    {
      NSLog(@"unable to bind to port %s:%d - %@", inet_ntoa(sin.sin_addr),
	GSSwapBigI16ToHost(sin.sin_port), [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (listen(net, 256) == -1)
    {
      NSLog(@"unable to listen on port - %@", [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  if (getsockname(net, (struct sockaddr*)&sin, &size) == -1)
    {
      NSLog(@"unable to get socket name - %@", [NSError _last]);
      (void) close(net);
      RELEASE(self);
      return nil;
    }

  self = [self initWithFileDescriptor: net closeOnDealloc: YES];
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
  int	d = open([path fileSystemRepresentation], O_RDONLY|O_BINARY);

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
  int	d = open([path fileSystemRepresentation], O_WRONLY|O_BINARY);

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
  int	d = open([path fileSystemRepresentation], O_RDWR|O_BINARY);

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
      IF_NO_GC([fh_stderr retain];)
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
      IF_NO_GC([fh_stdin retain];)
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
      IF_NO_GC([fh_stdout retain];)
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
  self = [self initWithFileDescriptor: open("/dev/null", O_RDWR|O_BINARY)
		       closeOnDealloc: YES];
  if (self)
    {
      isNullDevice = YES;
    }
  return self;
}

- (id) initWithFileDescriptor: (int)desc closeOnDealloc: (BOOL)flag
{
  self = [super init];
  if (self != nil)
    {
      struct stat	sbuf;
      int		e;

      if (fstat(desc, &sbuf) < 0)
	{
#if	defined(__MINGW32__)
	  /* On windows, an fstat will fail if the descriptor is a pipe
	   * or socket, so we simply mark the descriptor as not being a
	   * standard file.
	   */
	  isStandardFile = NO;
#else
	  /* This should never happen on unix.  If it does, we have somehow
	   * ended up with a bad descriptor.
	   */
          NSLog(@"unable to get status of descriptor %d - %@",
	    desc, [NSError _last]);
	  isStandardFile = NO;
#endif
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
    }
  return self;
}

- (id) initWithNativeHandle: (void*)hdl
{
  return [self initWithFileDescriptor: (uintptr_t)hdl closeOnDealloc: NO];
}

- (id) initWithNativeHandle: (void*)hdl closeOnDealloc: (BOOL)flag
{
  return [self initWithFileDescriptor: (uintptr_t)hdl closeOnDealloc: flag];
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
  return (void*)(intptr_t)descriptor;
}

// Synchronous I/O operations

- (NSData*) availableData
{
  char			buf[READ_SIZE];
  NSMutableData*	d;
  int			len;

  [self checkRead];
  d = [NSMutableData dataWithCapacity: 0];
  if (isStandardFile)
    {
      if (isNonBlocking == YES)
	{
	  [self setNonBlocking: NO];
	}
      while ((len = [self read: buf length: sizeof(buf)]) > 0)
        {
	  [d appendBytes: buf length: len];
        }
    }
  else
    {
      if (isNonBlocking == NO)
	{
	  [self setNonBlocking: YES];
	}
      len = [self read: buf length: sizeof(buf)];

      if (len <= 0)
	{
	  if (errno == EAGAIN || errno == EINTR)
	    {
	      /*
	       * Read would have blocked ... so try to get a single character
	       * in non-blocking mode (to ensure we wait until data arrives)
	       * and then try again.
	       * This ensures that we block for *some* data as we should.
	       */
	      [self setNonBlocking: NO];
	      len = [self read: buf length: 1];
	      [self setNonBlocking: YES];
	      if (len == 1)
		{
		  len = [self read: &buf[1] length: sizeof(buf) - 1];
		  if (len <= 0)
		    {
		      len = 1;
		    }
		  else
		    {
		      len = len + 1;
		    }
		}
	    }
	}

      if (len > 0)
	{
	  [d appendBytes: buf length: len];
	}
    }
  if (len < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to read from descriptor - %@",
                  [NSError _last]];
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
                  format: @"unable to read from descriptor - %@",
                  [NSError _last]];
    }
  return d;
}

- (NSData*) readDataOfLength: (unsigned)len
{
  NSMutableData	*d;
  int		got;
  char		buf[READ_SIZE];

  [self checkRead];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }

  d = [NSMutableData dataWithCapacity: len < READ_SIZE ? len : READ_SIZE];
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
		      format: @"unable to read from descriptor - %@",
		      [NSError _last]];
	}
    }
  while (len > 0 && got > 0);

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
	  if (errno == EAGAIN || errno == EINTR)
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
                  format: @"unable to write to descriptor - %@",
                  [NSError _last]];
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
      result = lseek(descriptor, 0, SEEK_CUR);
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %@",
                  [NSError _last]];
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
      result = lseek(descriptor, 0, SEEK_END);
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %@",
                  [NSError _last]];
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
      result = lseek(descriptor, (off_t)pos, SEEK_SET);
    }
  if (result < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"failed to move to offset in file - %@",
                  [NSError _last]];
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
      (void)sync();
    }
}

- (void) truncateFileAtOffset: (unsigned long long)pos
{
  if (isStandardFile && descriptor >= 0)
    {
      (void)ftruncate(descriptor, pos);
    }
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
	  [l removeEvent: (void*)(uintptr_t)descriptor
		    type: ET_RDESC
		 forMode: [modes objectAtIndex: i]
		     all: YES];
        }
    }
  else
    {
      [l removeEvent: (void*)(uintptr_t)descriptor
		type: ET_RDESC
	     forMode: NSDefaultRunLoopMode
		 all: YES];
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
	  [l removeEvent: (void*)(uintptr_t)descriptor
		    type: ET_WDESC
		 forMode: [modes objectAtIndex: i]
		     all: YES];
        }
    }
  else
    {
      [l removeEvent: (void*)(uintptr_t)descriptor
		type: ET_WDESC
	     forMode: NSDefaultRunLoopMode
		 all: YES];
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
	  [l addEvent: (void*)(uintptr_t)descriptor
		 type: ET_RDESC
	      watcher: self
	      forMode: [modes objectAtIndex: i]];
        }
      [readInfo setObject: modes forKey: NSFileHandleNotificationMonitorModes];
    }
  else
    {
      [l addEvent: (void*)(uintptr_t)descriptor
	     type: ET_RDESC
	  watcher: self
	  forMode: NSDefaultRunLoopMode];
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
	      [l addEvent: (void*)(uintptr_t)descriptor
		     type: ET_WDESC
		  watcher: self
		  forMode: [modes objectAtIndex: i]];
	    }
	}
      else
	{
	  [l addEvent: (void*)(uintptr_t)descriptor
		 type: ET_WDESC
	      watcher: self
	      forMode: NSDefaultRunLoopMode];
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
      int			desc;
      unsigned int		blen = sizeof(buf);

      desc = accept(descriptor, (struct sockaddr*)&buf, &blen);
      if (desc == -1)
	{
	  NSString	*s;

	  s = [NSString stringWithFormat: @"Accept attempt failed - %@",
	    [NSError _last]];
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

	  h = [[[self class] alloc] initWithFileDescriptor: desc
						closeOnDealloc: YES];
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
          if (errno != EAGAIN && errno != EINTR)
            {
	      NSString	*s;

	      s = [NSString stringWithFormat: @"Read attempt failed - %@",
		[NSError _last]];
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
      extern int errno;
      int	result;
      int	rval;
      unsigned	len = sizeof(result);

      rval = getsockopt(descriptor, SOL_SOCKET, SO_ERROR, (char*)&result, &len);
      if (rval != 0)
        {
          NSString	*s;

          s = [NSString stringWithFormat: @"Connect attempt failed - %@",
	    [NSError _last]];
          [info setObject: s forKey: GSFileHandleNotificationError];
	}
      else if (result != 0)
        {
          NSString	*s;

          s = [NSString stringWithFormat: @"Connect attempt failed - %@",
	    [NSError _systemError: result]];
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
	      if (written < 0 && errno != EAGAIN && errno != EINTR)
	        {
	          NSString	*s;

	          s = [NSString stringWithFormat:
		    @"Write attempt failed - %@", [NSError _last]];
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
  NSDebugMLLog(@"NSFileHandle", @"%@ event: %d", self, type);

  if (isNonBlocking == NO)
    {
      [self setNonBlocking: YES];
    }
  if (type == ET_RDESC)
    {
      [self receivedEventRead];
    }
  else
    {
      [self receivedEventWrite];
    }
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
	      NSLog(@"unable to set non-blocking mode for %d - %@",
		descriptor, [NSError _last]);
	    }
	  else
	    {
	      isNonBlocking = flag;
	    }
	}
      else
	{
	  NSLog(@"unable to get non-blocking mode for %d - %@",
	    descriptor, [NSError _last]);
	}
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

  if (getsockname(descriptor, (struct sockaddr*)&sin, &size) == -1)
    {
      NSLog(@"unable to get socket name - %@", [NSError _last]);
    }
  else
    {
      str = [NSString stringWithUTF8String: (char*)inet_ntoa(sin.sin_addr)];
    }
  return str;
}

- (NSString*) socketLocalService
{
  NSString	*str = nil;
  struct sockaddr_in sin;
  unsigned	size = sizeof(sin);

  if (getsockname(descriptor, (struct sockaddr*)&sin, &size) == -1)
    {
      NSLog(@"unable to get socket name - %@", [NSError _last]);
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

