/* Implementation of NSPortNameServer class for Distributed Objects
   Copyright (C) 1998,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

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
#include <Foundation/NSString.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSDebug.h>
#include <base/TcpPort.h>
#include <arpa/inet.h>

/*
 *	Protocol definition stuff for talking to gdomap process.
 */
#include        "../Tools/gdomap.h"

/*
 *	Macros to build text to start name server and to give an error
 *	message about it - they include installation path information.
 */
#define stringify_it(X) #X
#define make_gdomap_cmd(X)      stringify_it(X) "/Tools/gdomap"
#define make_gdomap_err(X)      "check that " stringify_it(X) "/Tools/gdomap is running and owned by root."
#define	make_gdomap_port(X)	stringify_it(X)

/*
 * to suppress warnings about using this private method.
 */
@interface TcpOutPort (Hack)
+ newForSendingToSockaddr: (struct sockaddr_in*)sockaddr
       withAcceptedSocket: (int)sock
            pollingInPort: (id)ip;
@end

/*
 * class-wide variables.
 */
static unsigned		maxHandles = 4;
static NSTimeInterval	timeout = 20.0;
static NSString		*serverPort = @"gdomap";
static NSString		*mode = @"NSPortServerLookupMode";
static NSArray		*modes = nil;
static NSRecursiveLock	*serverLock = nil;
static NSPortNameServer	*defaultServer = nil;
static NSString		*launchCmd = nil;



typedef enum {
  GSPC_NONE,
  GSPC_LOPEN,
  GSPC_ROPEN,
  GSPC_RETRY,
  GSPC_WRITE,
  GSPC_READ1,
  GSPC_READ2,
  GSPC_FAIL,
  GSPC_DONE
} GSPortComState;

@interface	GSPortCom : NSObject
{
  gdo_req		msg;
  unsigned		expecting;
  NSMutableData		*data;
  NSFileHandle		*handle;
  GSPortComState	state; 
  struct in_addr	addr;
}
- (struct in_addr) addr;
- (void) close;
- (NSData*) data;
- (void) didConnect: (NSNotification*)notification;
- (void) didRead: (NSNotification*)notification;
- (void) didWrite: (NSNotification*)notification;
- (void) fail;
- (BOOL) isActive;
- (void) open: (NSString*)host;
- (void) setAddr: (struct in_addr)addr;
- (GSPortComState) state;
- (void) startListNameServers;
- (void) startPortLookup: (NSString*)name onHost: (NSString*)addr;
- (void) startPortRegistration: (gsu32)portNumber withName: (NSString*)name;
- (void) startPortUnregistration: (gsu32)portNumber withName: (NSString*)name;
@end

@implementation GSPortCom

- (struct in_addr) addr
{
  return addr;
}

- (void) close
{
  if (handle != nil)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

      [nc removeObserver: self
		    name: GSFileHandleConnectCompletionNotification
		  object: handle];
      [nc removeObserver: self
		    name: NSFileHandleReadCompletionNotification
		  object: handle];
      [nc removeObserver: self
		    name: GSFileHandleWriteCompletionNotification
		  object: handle];
      [handle closeFile];
      DESTROY(handle);
    }
}

- (NSData*) data
{
  return data;
}

- (void) dealloc
{
  [self close];
  TEST_RELEASE(data);
  [super dealloc];
}

- (void) didConnect: (NSNotification*)notification
{
  NSDictionary    *userInfo = [notification userInfo];
  NSString        *e;

  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      NSLog(@"NSPortNameServer failed connect to gdomap - %@", e); 
      /*
       * Remove our file handle, then either retry or fail.
       */
      [self close];
      if (state == GSPC_LOPEN)
	{
	  NSLog(@"NSPortNameServer attempting to start gdomap on local host"); 
	  [NSTask launchedTaskWithLaunchPath: launchCmd arguments: nil];
	  [NSTimer scheduledTimerWithTimeInterval: 5.0
				       invocation: nil
					  repeats: NO];
	  [[NSRunLoop currentRunLoop] runUntilDate:
	    [NSDate dateWithTimeIntervalSinceNow: 5.0]];
	  NSLog(@"NSPortNameServer retrying connection attempt to gdomap"); 
	  state = GSPC_RETRY;
	  [self open: nil];
	}
      else
	{
	  [self fail];
	}
    }
  else
    {
      [[NSNotificationCenter defaultCenter]
	removeObserver: self
		  name: GSFileHandleConnectCompletionNotification
		object: handle];
      /*
       * Now we have established a connection, we can write the request
       * to the name server.
       */
      state = GSPC_WRITE;
      [handle writeInBackgroundAndNotify: data
				forModes: modes];
      DESTROY(data);
    }
}

- (void) didRead: (NSNotification*)notification
{
  NSDictionary	*userInfo = [notification userInfo];
  NSData	*d;

  d = [userInfo objectForKey: NSFileHandleNotificationDataItem];

  if (d == nil || [d length] == 0)
    {
      [self fail];
      NSLog(@"NSPortNameServer lost connection to gdomap"); 
    }
  else
    {
      if (data == nil)
	{
	  data = [d mutableCopy];
	}
      else
	{
	  [data appendData: d];
	}
      if ([data length] < expecting)
	{
	  /*
	   *	Not enough data read yet - go read some more.
	   */
	  [handle readInBackgroundAndNotifyForModes: modes];
	}
      else if (state == GSPC_READ1 && msg.rtype == GDO_SERVERS)
	{
	  gsu32	numSvrs = GSSwapBigI32ToHost(*(gsu32*)[data bytes]);

	  if (numSvrs == 0)
	    {
	      [self fail];
	      NSLog(@"failed to get list of name servers on net");
	    }
	  else
	    {
	      /*
	       * Now read in the addresses of the servers.
	       */
	      expecting += numSvrs * sizeof(struct in_addr);
	      if ([data length] < expecting)
		{
		  state = GSPC_READ2;
		  [handle readInBackgroundAndNotifyForModes: modes];
		}
	      else
		{
		  [[NSNotificationCenter defaultCenter]
		    removeObserver: self
			      name: NSFileHandleReadCompletionNotification
			    object: handle];
		  state = GSPC_DONE;
		}
	    }
	}
      else
	{
	  [[NSNotificationCenter defaultCenter]
	    removeObserver: self
		      name: NSFileHandleReadCompletionNotification
		    object: handle];
	  state = GSPC_DONE;
	}
    }
}

- (void) didWrite: (NSNotification*)notification
{
  NSDictionary    *userInfo = [notification userInfo];
  NSString        *e;

  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      [self fail];
      NSLog(@"NSPortNameServer failed write to gdomap - %@", e); 
    }
  else
    {
      state = GSPC_READ1;
      data = [NSMutableData new];
      expecting = 4;
      [handle readInBackgroundAndNotifyForModes: modes];
    }
}

- (void) fail
{
  [self close];
  if (data != nil)
    {
      DESTROY(data);
    }
  msg.rtype = 0;
  state = GSPC_FAIL;
}

- (BOOL) isActive
{
  if (handle == nil)
    return NO;
  if (state == GSPC_FAIL)
    return NO;
  if (state == GSPC_NONE)
    return NO;
  if (state == GSPC_DONE)
    return NO;
  return YES;
}

- (void) open: (NSString*)hostname
{
  NSNotificationCenter	*nc;

  NSAssert(state == GSPC_NONE || state == GSPC_RETRY, @"open in bad state");

  if (state == GSPC_NONE)
    {
      state = GSPC_ROPEN;	/* Assume we are connection to remote system */
      if (hostname == nil || [hostname isEqual: @""])
	{
	  hostname = @"localhost";
	  state = GSPC_LOPEN;
	}
      else
	{
	  NSHost	*current = [NSHost currentHost];
	  NSHost	*host = [NSHost hostWithName: hostname];

	  if (host == nil)
	    {
	      host = [NSHost hostWithAddress: hostname];
	    }
	  if ([current isEqual: host])
	    {
	      state = GSPC_LOPEN;
	    }
	}
    }

  NS_DURING
    {
      handle = [NSFileHandle  fileHandleAsClientInBackgroundAtAddress:
	hostname service: serverPort protocol: @"tcp" forModes: modes];
    }
  NS_HANDLER
    {
      NSLog(@"Exception looking up port for gdomap - %@", localException);
      if ([[localException name] isEqual: NSInvalidArgumentException])
	{
	  handle = nil;
	}
      else
	{
	  [self fail];
	}
    }
  NS_ENDHANDLER

  if (state == GSPC_FAIL)
    return;

  if (handle == nil)
    {
      NSLog(@"Failed to find gdomap port with name '%@',\nperhaps your "
		@"/etc/services file is not correctly set up?\n"
		@"Retrying with default (IANA allocated) port number 538",
		serverPort);
      NS_DURING
	{
	  handle = [NSFileHandle fileHandleAsClientInBackgroundAtAddress:
	    hostname service: @"538" protocol: @"tcp" forModes: modes];
	}
      NS_HANDLER
	{
	  NSLog(@"Exception creating handle for gdomap - %@", localException);
	  [self fail];
	}
      NS_ENDHANDLER
      if (handle)
	{
	  RELEASE(serverPort);
	  serverPort = @"538";
	}
    }

  if (state == GSPC_FAIL)
    return;

  RETAIN(handle);
  nc = [NSNotificationCenter defaultCenter];
  [nc addObserver: self
	 selector: @selector(didConnect:)
	     name: GSFileHandleConnectCompletionNotification
	   object: handle];
  [nc addObserver: self
	 selector: @selector(didRead:)
	     name: NSFileHandleReadCompletionNotification
	   object: handle];
  [nc addObserver: self
	 selector: @selector(didWrite:)
	     name: GSFileHandleWriteCompletionNotification
	   object: handle];
}

- (void) setAddr: (struct in_addr)anAddr
{
  addr = anAddr;
}

- (GSPortComState) state
{
  return state;
}

- (void) startListNameServers
{
  msg.rtype = GDO_SERVERS;	/* Get a list of name servers.	*/
  msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
  msg.nsize = 0;
  msg.port = 0;
  TEST_RELEASE(data);
  data = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];
  RETAIN(data);
  [self open: nil];
}

- (void) startPortLookup: (NSString*)name onHost: (NSString*)host
{
  msg.rtype = GDO_LOOKUP;	/* Find the named port.		*/
  msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
  msg.port = 0;
  msg.nsize = [name cStringLength];
  [name getCString: msg.name];
  TEST_RELEASE(data);
  data = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];
  RETAIN(data);
  [self open: host];
}

- (void) startPortRegistration: (gsu32)portNumber withName: (NSString*)name
{
  msg.rtype = GDO_REGISTER;	/* Register a port.		*/
  msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
  msg.nsize = [name cStringLength];
  [name getCString: msg.name];
  msg.port = GSSwapHostI32ToBig(portNumber);
  TEST_RELEASE(data);
  data = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];
  RETAIN(data);
  [self open: nil];
}

- (void) startPortUnregistration: (gsu32)portNumber withName: (NSString*)name
{
  msg.rtype = GDO_UNREG;
  msg.ptype = GDO_TCP_GDO;
  if (name == nil)
    {
      msg.nsize = 0;
    }
  else
    {
      msg.nsize = [name cStringLength];
      [name getCString: msg.name];
    }
  msg.port = GSSwapHostI32ToBig(portNumber);
  TEST_RELEASE(data);
  data = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];
  RETAIN(data);
  [self open: nil];
}

@end



@implementation NSPortNameServer

+ (id) allocWithZone: (NSZone*)aZone
{
  [NSException raise: NSGenericException
	      format: @"attempt to create extra port name server"]; 
  return nil;
}

+ (void) initialize
{
  if (self == [NSPortNameServer class])
    {
      serverLock = [NSRecursiveLock new];
      modes = [[NSArray alloc] initWithObjects: &mode count: 1];
#ifdef	GDOMAP_PORT_OVERRIDE
      serverPort = RETAIN([NSString stringWithCString:
	make_gdomap_port(GDOMAP_PORT_OVERRIDE)]);
#endif
      launchCmd = [NSString stringWithCString:
	make_gdomap_cmd(GNUSTEP_INSTALL_PREFIX)]; 
    }
}

+ (id) defaultPortNameServer
{
  if (defaultServer == nil)
    {
      NSPortNameServer	*s;

      [serverLock lock];
      if (defaultServer)
	{
          [serverLock unlock];
	  return defaultServer;
	}
      s = (NSPortNameServer*)NSAllocateObject(self, 0, NSDefaultMallocZone());
      s->_portMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
		NSObjectMapValueCallBacks, 0);
      s->_nameMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
		NSNonOwnedPointerMapValueCallBacks, 0);
      defaultServer = s;
      [serverLock unlock];
    }
  return defaultServer;
}

- (void) dealloc
{
  [NSException raise: NSGenericException
	      format: @"attempt to deallocate default port name server"]; 
}

- (NSPort*) portForName: (NSString*)name
{
  return [self portForName: name onHost: nil];
}

- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host
{
  GSPortCom		*com = nil;
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  struct in_addr	singleServer;
  struct in_addr	*svrs = &singleServer;
  unsigned		numSvrs;
  unsigned		count;
  unsigned		portNum = 0;
  unsigned		len;
  NSMutableArray	*array;
  NSDate		*limit = [NSDate dateWithTimeIntervalSinceNow: timeout];

  if (name == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to lookup port with nil name"]; 
    }

  len = [name cStringLength];
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to lookup port with no name"]; 
    }
  if (len > GDO_NAME_MAX_LEN)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"name of port is too long (max %d) bytes",
			GDO_NAME_MAX_LEN]; 
    }

  /*
   * get one or more host addresses in network byte order.
   */
  if (host == nil || [host isEqual: @""])
    {
      /*
       *	Query a single nameserver - on the local host.
       */
      numSvrs = 1;
#ifndef HAVE_INET_ATON
      svrs->s_addr = inet_addr("127.0.0.1");
#else
      inet_aton("127.0.0.1", (struct in_addr *)&svrs->s_addr);
#endif
    }
  else if ([host isEqual: @"*"])
    {
      GSPortCom	*com = [GSPortCom new];

      [serverLock lock];
      NS_DURING
	{
	  GSPortCom	*tmp;
	  NSData	*dat;

	  [com startListNameServers];
	  while ([limit timeIntervalSinceNow] > 0 && [com isActive] == YES)
	    {
	      [loop runMode: mode
		 beforeDate: limit];
	    }
	  [com close];
	  if ([com state] != GSPC_DONE)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out listing name servers"]; 
	    }
          /*
           * Retain and autorelease the data item so the buffer won't disappear
	   * when the 'com' object is destroyed.
	   */
          dat = AUTORELEASE(RETAIN([com data]));
	  svrs = (struct in_addr*)([dat bytes] + 4);
	  numSvrs = GSSwapBigI32ToHost(*(gsu32*)[dat bytes]);
	  if (numSvrs == 0)
	    {
	      [NSException raise: NSInternalInconsistencyException
			  format: @"failed to get list of name servers on net"];
	    }
	  tmp = com;
	  com = nil;
	  RELEASE(tmp);
	}
      NS_HANDLER
	{
	  /*
	   *	If we had a problem - unlock before continueing.
	   */
	  RELEASE(com);
	  [serverLock unlock];
          [localException raise];
	}
      NS_ENDHANDLER
      [serverLock unlock];
    }
  else
    {
      NSHost	*h;

      /*
       *	Query a single nameserver - on the specified host.
       */
      numSvrs = 1;
      h = [NSHost hostWithName: host];
      if (h)
	host = [h address];
#ifndef HAVE_INET_ATON
      svrs->s_addr = inet_addr([host cString]);
#else
      inet_aton([host cString], (struct in_addr *)&svrs->s_addr);
#endif
    }

  /*
   * Ok, 'svrs'now points to one or more internet addresses in network
   * byte order, and numSvrs tells us how many there are.
   */
  array = [NSMutableArray arrayWithCapacity: maxHandles];
  [serverLock lock];
  NS_DURING
    {
      unsigned	i;

      portNum = 0;
      count = 0;
      do
	{
	  /*
	   *	Make sure that all the array slots are full if possible
	   */
	  while (count < numSvrs && [array count] < maxHandles)
	    {
	      NSString	*addr;

	      com = [GSPortCom new];
	      [array addObject: com];
	      RELEASE(com);
	      [com setAddr: svrs[count]];
	      addr = [NSString stringWithCString:
		(char*)inet_ntoa(svrs[count])];
	      [com startPortLookup: name onHost: addr];
	      count++;
	    }

	  /*
	   * Handle I/O on the file handles.
	   */
	  i = [array count];
	  if (i == 0)
	    {
	      break;	/* No servers left to try!	*/
	    }
	  [loop runMode: mode
	     beforeDate: limit];

	  /*
	   * Check for completed operations.
	   */
	  while (portNum == 0 && i-- > 0)
	    {
	      com = [array objectAtIndex: i];
	      if ([com isActive] == NO)
		{
		  [com close];
		  if ([com state] == GSPC_DONE)
		    {
		      portNum = GSSwapBigI32ToHost(*(gsu32*)[[com data] bytes]);
		      if (portNum != 0)
			{
			  singleServer = [com addr];
			}
		    }
		  [array removeObjectAtIndex: i];
		}
	    }
	}
      while (portNum == 0 && [limit timeIntervalSinceNow] > 0);

      /*
       * Make sure that any outstanding lookups are cancelled.
       */
      i = [array count];
      while (i-- > 0)
	{
	  [[array objectAtIndex: i] fail];
	  [array removeObjectAtIndex: i];
	}
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - unlock before continueing.
       */
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [serverLock unlock];

  if (portNum)
    {
      struct sockaddr_in	sin;
      NSPort			*p;
      unsigned short		n;

      memset(&sin, '\0', sizeof(sin));
      sin.sin_family = AF_INET;

      /*
       *	The returned port is an unsigned int - so we have to
       *	convert to a short in network byte order (big endian).
       */
      n = (unsigned short)portNum;
      sin.sin_port = NSSwapHostShortToBig(n);

      /*
       *	The host addresses are given to us in network byte order
       *	so we just copy the address into place.
       */
      sin.sin_addr = singleServer;

      p = [TcpOutPort newForSendingToSockaddr: &sin
			   withAcceptedSocket: 0
				pollingInPort: nil];
      return AUTORELEASE(p);
    }
  else
    {
      return nil;
    }
}

- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name
{
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];
  GSPortCom	*com;
  unsigned	len;
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: timeout];

  if (name == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to register port with nil name"]; 
    }
  if (port == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to register nil port"]; 
    }
  len = [name cStringLength];
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to register port with no name"]; 
    }
  if (len > GDO_NAME_MAX_LEN)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"name of port is too long (max %d) bytes",
			GDO_NAME_MAX_LEN]; 
    }
  /*
   *	Lock out other threads while doing I/O to gdomap
   */
  [serverLock lock];

  NS_DURING
    {
      NSMutableSet	*known = NSMapGet(_portMap, port);
      GSPortCom		*tmp;

      /*
       *	If there is no set of names for this port - create one.
       */
      if (known == nil)
	{
	  known = [NSMutableSet new];
	  NSMapInsert(_portMap, port, known);
	  RELEASE(known);
	}

      /*
       *	If this port has never been registered under any name, first
       *	send an unregister message to gdomap to ensure that any old 
       *	names for the port (perhaps from a server that crashed without
       *	unregistering its ports) are no longer around.
       */
      if ([known count] == 0)
	{
	  com = [GSPortCom new];
	  [com startPortUnregistration: [(TcpInPort*)port portNumber]
			      withName: nil];
	  while ([limit timeIntervalSinceNow] > 0 && [com isActive] == YES)
	    {
	      [loop runMode: mode
		 beforeDate: limit];
	    }
	  [com close];
	  if ([com state] != GSPC_DONE)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out unregistering port"]; 
	    }
	  tmp = com;
	  com = nil;
	  RELEASE(tmp);
	}

      com = [GSPortCom new];
      [com startPortRegistration: [(TcpInPort*)port portNumber]
			withName: name];
      while ([limit timeIntervalSinceNow] > 0 && [com isActive] == YES)
	{
	  [loop runMode: mode
	     beforeDate: limit];
	}
      [com close];
      if ([com state] != GSPC_DONE)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out registering port %@", name]; 
	}
      else
	{
	  unsigned	result;

	  result = GSSwapBigI32ToHost(*(gsu32*)[[com data] bytes]);
	  if (result == 0)
	    {
	      [NSException raise: NSGenericException
			  format: @"unable to register %@", name]; 
	    }
	  else
	    {
	      /*
	       *	Add this name to the set of names that the port
	       *	is known by and to the name map.
	       */
	      [known addObject: name];
	      NSMapInsert(_nameMap, name, port);
	    }
	}
      tmp = com;
      com = nil;
      RELEASE(tmp);
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - close and unlock before continueing.
       */
      RELEASE(com);
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [serverLock unlock];
  return YES;
}

- (void) removePortForName: (NSString*)name
{
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];
  GSPortCom	*com;
  unsigned	len;
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: timeout];

  if (name == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to remove port with nil name"]; 
    }

  len = [name cStringLength];
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to remove port with no name"]; 
    }
  if (len > GDO_NAME_MAX_LEN)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"name of port is too long (max %d) bytes",
			GDO_NAME_MAX_LEN]; 
    }

  /*
   *	Lock out other threads while doing I/O to gdomap
   */
  [serverLock lock];

  NS_DURING
    {
      GSPortCom	*tmp;

      com = [GSPortCom new];
      [com startPortUnregistration: 0 withName: name];
      while ([limit timeIntervalSinceNow] > 0 && [com isActive] == YES)
	{
	  [loop runMode: mode
	     beforeDate: limit];
	}
      [com close];
      if ([com state] != GSPC_DONE)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out unregistering port"]; 
	}
      else
	{
	  unsigned	result;

	  result = GSSwapBigI32ToHost(*(gsu32*)[[com data] bytes]);
	  if (result == 0)
	    {
	      NSLog(@"NSPortNameServer unable to unregister '%@'", name);
	    }
	  else
	    {
	      NSPort		*port;

	      /*
	       *	Find the port that was registered for this name and
	       *	remove the mapping table entries.
	       */
	      port = NSMapGet(_nameMap, name);
	      if (port)
		{
		  NSMutableSet	*known;

		  NSMapRemove(_nameMap, name);
		  known = NSMapGet(_portMap, port);
		  if (known)
		    {
		      [known removeObject: name];
		      if ([known count] == 0)
			{
			  NSMapRemove(_portMap, port);
			}
		    }
		}
	    }
	}
      tmp = com;
      com = nil;
      RELEASE(tmp);
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - unlock before continueing.
       */
      RELEASE(com);
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [serverLock unlock];
}
@end

@implementation	NSPortNameServer (GNUstep)

/*
 *	Remove all names for a particular port - used when a port is
 *	invalidated.
 */
- (void) removePort: (NSPort*)port
{
  [serverLock lock];
  NS_DURING
    {
      NSMutableSet	*known = (NSMutableSet*)NSMapGet(_portMap, port);
      NSString	*name;

      while ((name = [known anyObject]) != nil)
	{
	  [self removePortForName: name];
	}
    }
  NS_HANDLER
    {
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [serverLock lock];
}
@end


