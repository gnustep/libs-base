/* Implementation of NSPortNameServer class for Distributed Objects
   Copyright (C) 1998 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
 *	Private methods for internal use only.
 */
@interface	NSPortNameServer (Private)
- (void) _close;
- (void) _didConnect: (NSNotification*)notification;
- (void) _didRead: (NSNotification*)notification;
- (void) _didWrite: (NSNotification*)notification;
- (void) _open: (NSString*)host;
- (void) _retry;
@end

@implementation NSPortNameServer

static NSTimeInterval	writeTimeout = 5.0;
static NSTimeInterval	readTimeout = 15.0;
static NSTimeInterval	connectTimeout = 20.0;
static NSString		*serverPort = @"gdomap";
static NSString		*mode = @"NSPortServerLookupMode";
static NSArray		*modes = nil;
static NSRecursiveLock	*serverLock = nil;
static NSPortNameServer	*defaultServer = nil;

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
      [gnustep_global_lock lock];
      if (serverLock == nil)
	{
          serverLock = [NSRecursiveLock new];
	  modes = [[NSArray alloc] initWithObjects: &mode count: 1];
#ifdef	GDOMAP_PORT_OVERRIDE
	  serverPort = RETAIN([NSString stringWithCString:
		make_gdomap_port(GDOMAP_PORT_OVERRIDE)]);
#endif
	} 
      [gnustep_global_lock unlock];
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
      s->data = [NSMutableData new];
      s->portMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
		NSObjectMapValueCallBacks, 0);
      s->nameMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
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
  gdo_req		msg;		/* Message structure.	*/
  NSMutableData		*dat;		/* Hold message here.	*/
  unsigned		len;
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  struct in_addr	singleServer;
  struct in_addr	*svrs = &singleServer;
  unsigned		numSvrs;
  unsigned		count;
  unsigned		portNum = 0;

  if (name == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"attempt to register port with nil name"]; 
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

  if (host != nil && [host isEqual: @"*"])
    {
      NSMutableData	*tmp;
      unsigned	bufsiz;
      unsigned	length;

      msg.rtype = GDO_SERVERS;	/* Get a list of name servers.	*/
      msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
      msg.nsize = 0;
      msg.port = 0;
      dat = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];

      [serverLock lock];
      NS_DURING
	{
	  [self _open: nil];
	  expecting = sizeof(msg);
	  [handle writeInBackgroundAndNotify: dat
				    forModes: modes];
	  [loop runMode: mode
	     beforeDate: [NSDate dateWithTimeIntervalSinceNow: writeTimeout]];
	  if (expecting)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out writing to gdomap"]; 
	    }

	  expecting = sizeof(unsigned);
	  [data setLength: 0];
	  [handle readInBackgroundAndNotifyForModes: modes];
	  [loop runMode: mode
	     beforeDate: [NSDate dateWithTimeIntervalSinceNow: readTimeout]];
	  if (expecting)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out reading from gdomap"]; 
	    }
	  numSvrs = NSSwapBigIntToHost(*(unsigned*)[data bytes]);
	  if (numSvrs == 0)
	    {
	      [NSException raise: NSInternalInconsistencyException
			  format: @"failed to get list of name servers on net"];
	    }

	  /*
	   *	Calculate size of buffer for server internet addresses and
	   *	allocate a buffer to store them in.
	   */
	  bufsiz = numSvrs * sizeof(struct in_addr);
	  tmp = [NSMutableData dataWithLength: bufsiz];
	  svrs = (struct in_addr*)[tmp mutableBytes];

	  /*
	   *	Read the addresses from the name server if necessary
	   *	and copy them to our newly allocated buffer.
	   *	We may already have some/all of the data, in which case
	   *	we don't need to do a read.
	   */
	  length = [data length] - sizeof(unsigned);
	  if (length > 0)
	    {
	      void	*bytes = [data mutableBytes];

	      memcpy(bytes, bytes+sizeof(unsigned), length);
	      [data setLength: length];
	    }
	  else
	    {
	      [data setLength: 0];
	    }

	  if (length < bufsiz)
	    {
	      expecting = bufsiz;
	      [handle readInBackgroundAndNotifyForModes: modes];
	      [loop runMode: mode
		 beforeDate: [NSDate dateWithTimeIntervalSinceNow:
				readTimeout]];
	      if (expecting)
		{
		  [NSException raise: NSPortTimeoutException
			      format: @"timed out reading from gdomap"]; 
		}
	    }

	  [data getBytes: (void*)svrs length: bufsiz];
	  [self _close];
	}
      NS_HANDLER
	{
	  /*
	   *	If we had a problem - unlock before continueing.
	   */
	  [self _close];
	  [serverLock unlock];
          [localException raise];
	}
      NS_ENDHANDLER
      [serverLock unlock];
    }
  else
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

  [serverLock lock];
  NS_DURING
    {
      for (count = 0; count < numSvrs; count++)
	{
	  NSString	*addr;

	  msg.rtype = GDO_LOOKUP;	/* Find the named port.		*/
	  msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
	  msg.port = 0;
	  msg.nsize = len;
	  [name getCString: msg.name];
	  dat = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];

	  addr = [NSString stringWithCString: (char*)inet_ntoa(svrs[count])];
	  [self _open: addr];
	  expecting = sizeof(msg);
	  [handle writeInBackgroundAndNotify: dat
				    forModes: modes];
	  [loop runMode: mode
	     beforeDate: [NSDate dateWithTimeIntervalSinceNow: writeTimeout]];
	  if (expecting)
	    {
	      [self _close];
	    }
	  else
	    {
	      expecting = sizeof(unsigned);
	      [data setLength: 0];
	      [handle readInBackgroundAndNotifyForModes: modes];
	      [loop runMode: mode
		 beforeDate: [NSDate dateWithTimeIntervalSinceNow:
				readTimeout]];
	      [self _close];
	      if (expecting == 0)
		{
		  portNum = NSSwapBigIntToHost(*(unsigned*)[data bytes]);
		  if (portNum != 0)
		    {
		      break;
		    }
		}
	    }
	}
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - unlock before continueing.
       */
      [self _close];
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
      sin.sin_addr.s_addr = svrs[count].s_addr;

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
  gdo_req	msg;		/* Message structure.	*/
  NSMutableData	*dat;		/* Hold message here.	*/
  unsigned	len;
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];

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
      NSMutableSet	*known = NSMapGet(portMap, port);

      /*
       *	If there is no set of names for this port - create one.
       */
      if (known == nil)
	{
	  known = [NSMutableSet new];
	  NSMapInsert(portMap, port, known);
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
	  msg.rtype = GDO_UNREG;
	  msg.ptype = GDO_TCP_GDO;
	  msg.nsize = 0;
	  msg.port = NSSwapHostIntToBig([(TcpInPort*)port portNumber]);
	  dat = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];

	  [self _open: nil];

	  expecting = sizeof(msg);
	  [handle writeInBackgroundAndNotify: dat
				    forModes: modes];
	  [loop runMode: mode
	     beforeDate: [NSDate dateWithTimeIntervalSinceNow: writeTimeout]];
	  if (expecting)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out writing to gdomap"]; 
	    }

	  /*
	   *	Queue a read request in our own run mode then run until the
	   *	timeout period or until the read completes.
	   */
	  expecting = sizeof(unsigned);
	  [data setLength: 0];
	  [handle readInBackgroundAndNotifyForModes: modes];
	  [loop runMode: mode
	     beforeDate: [NSDate dateWithTimeIntervalSinceNow: readTimeout]];
	  if (expecting)
	    {
	      [NSException raise: NSPortTimeoutException
			  format: @"timed out reading from gdomap"]; 
	    }

	  if ([data length] != sizeof(unsigned))
	    {
	      [NSException raise: NSInternalInconsistencyException
			  format: @"too much data read from gdomap"]; 
	    }
	  [self _close];
	}

      msg.rtype = GDO_REGISTER;	/* Register a port.		*/
      msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
      msg.nsize = len;
      [name getCString: msg.name];
      msg.port = NSSwapHostIntToBig((unsigned)[(TcpInPort*)port portNumber]);
      dat = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];

      [self _open: nil];

      /*
       *	Queue a write request in our own run mode then run until the
       *	timeout period or until the write completes.
       */
      expecting = sizeof(msg);
      [handle writeInBackgroundAndNotify: dat
				forModes: modes];
      [loop runMode: mode
	 beforeDate: [NSDate dateWithTimeIntervalSinceNow: writeTimeout]];
      if (expecting)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out writing to gdomap"]; 
	}

      /*
       *	Queue a read request in our own run mode then run until the
       *	timeout period or until the read completes.
       */
      expecting = sizeof(unsigned);
      [data setLength: 0];
      [handle readInBackgroundAndNotifyForModes: modes];
      [loop runMode: mode
	 beforeDate: [NSDate dateWithTimeIntervalSinceNow: readTimeout]];
      if (expecting)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out reading from gdomap"]; 
	}

      if ([data length] != sizeof(unsigned))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"too much data read from gdomap"]; 
	}
      else
	{
	  unsigned	result = NSSwapBigIntToHost(*(unsigned*)[data bytes]);

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
	      NSMapInsert(nameMap, name, port);
	    }
	}
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - close and unlock before continueing.
       */
      [self _close];
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [self _close];
  [serverLock unlock];
  return YES;
}

- (void) removePortForName: (NSString*)name
{
  gdo_req	msg;		/* Message structure.	*/
  NSMutableData	*dat;		/* Hold message here.	*/
  unsigned	len;
  NSRunLoop	*loop = [NSRunLoop currentRunLoop];

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

  msg.rtype = GDO_UNREG;	/* Unregister a port.		*/
  msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
  msg.nsize = len;
  [name getCString: msg.name];
  msg.port = 0;
  dat = [NSMutableData dataWithBytes: (void*)&msg length: sizeof(msg)];

  /*
   *	Lock out other threads while doing I/O to gdomap
   */
  [serverLock lock];

  NS_DURING
    {
      [self _open: nil];

      /*
       *	Queue a write request in our own run mode then run until the
       *	timeout period or until the write completes.
       */
      expecting = sizeof(msg);
      [handle writeInBackgroundAndNotify: dat
				forModes: modes];
      [loop runMode: mode
	 beforeDate: [NSDate dateWithTimeIntervalSinceNow: writeTimeout]];
      if (expecting)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out writing to gdomap"]; 
	}

      /*
       *	Queue a read request in our own run mode then run until the
       *	timeout period or until the read completes.
       */
      expecting = sizeof(unsigned);
      [data setLength: 0];
      [handle readInBackgroundAndNotifyForModes: modes];
      [loop runMode: mode
	 beforeDate: [NSDate dateWithTimeIntervalSinceNow: readTimeout]];
      if (expecting)
	{
	  [NSException raise: NSPortTimeoutException
		      format: @"timed out reading from gdomap"]; 
	}

      /*
       *	Finished with server - so close connection.
       */
      [self _close];

      if ([data length] != sizeof(unsigned))
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"too much data read from gdomap"]; 
	}
      else
	{
	  unsigned	result = NSSwapBigIntToHost(*(unsigned*)[data bytes]);

	  if (result == 0)
	    {
	      NSLog(@"NSPortNameServer unable to unregister '%@'\n", name);
	    }
	  else
	    {
	      NSPort		*port;

	      /*
	       *	Find the port that was registered for this name and
	       *	remove the mapping table entries.
	       */
	      port = NSMapGet(nameMap, name);
	      if (port)
		{
		  NSMutableSet	*known;

		  NSMapRemove(nameMap, name);
		  known = NSMapGet(portMap, port);
		  if (known)
		    {
		      [known removeObject: name];
		      if ([known count] == 0)
			{
			  NSMapRemove(portMap, port);
			}
		    }
		}
	    }
	}
    }
  NS_HANDLER
    {
      /*
       *	If we had a problem - unlock before continueing.
       */
      [self _close];
      [serverLock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [serverLock unlock];
}
@end

@implementation	NSPortNameServer (Private)
- (void) _close
{
  if (handle)
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
      RELEASE(handle);
      handle = nil;
    }
}

- (void) _didConnect: (NSNotification*)notification
{
  NSDictionary    *userInfo = [notification userInfo];
  NSString        *e;

  e = [userInfo objectForKey:GSFileHandleNotificationError];
  if (e)
    {
      NSLog(@"NSPortNameServer failed connect to gdomap - %@", e); 
    }
  else
    {
      /*
       *	There should now be nothing for the runloop to do so
       *	control should return to the method that started the connection.
       *	Set 'expecting' to zero to show that the connection worked and
       *	stop watching for connection completion.
       */ 
      expecting = 0;
      [[NSNotificationCenter defaultCenter]
	removeObserver: self
		  name: GSFileHandleConnectCompletionNotification
		object: handle];
    }
}

- (void) _didRead: (NSNotification*)notification
{
  NSDictionary	*userInfo = [notification userInfo];
  NSData	*d;

  d = [userInfo objectForKey:NSFileHandleNotificationDataItem];

  if (d == nil || [d length] == 0)
    {
      [self _close];
      [NSException raise: NSGenericException
		  format: @"NSPortNameServer lost connection to gdomap"]; 
    }
  else
    {
      [data appendData: d];
      if ([data length] < expecting)
	{
	  /*
	   *	Not enough data read yet - go read some more.
	   */
	  [handle readInBackgroundAndNotifyForModes: modes];
	}
      else
	{
	  /*
	   *	There should now be nothing for the runloop to do so
	   *	control should return to the method that started the read.
	   *	Set 'expecting' to zero to show that the data was read.
	   */ 
	  expecting = 0;
	}
    }
}

- (void) _didWrite: (NSNotification*)notification
{
  NSDictionary    *userInfo = [notification userInfo];
  NSString        *e;

  e = [userInfo objectForKey:GSFileHandleNotificationError];
  if (e)
    {
      [self _close];
      [NSException raise: NSGenericException
		  format: @"NSPortNameServer failed write to gdomap - %@", e]; 
    }
  else
    {
      /*
       *	There should now be nothing for the runloop to do so
       *	control should return to the method that started the write.
       *	Set 'expecting' to zero to show that the data was written.
       */ 
      expecting = 0;
    }
}

- (void) _open: (NSString*)host
{
  NSNotificationCenter *nc;
  NSRunLoop	*loop;
  NSString	*hostname = host;
  BOOL		isLocal = NO;

  if (handle)
    {
      return;		/* Connection already open.	*/
    }
  if (hostname == nil)
    {
      hostname = @"localhost";
      isLocal = YES;
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
	  isLocal = YES;
	}
    }

  NS_DURING
    {
      handle = [NSFileHandle  fileHandleAsClientInBackgroundAtAddress: host
							  service: serverPort
							 protocol: @"tcp"
							 forModes: modes];
    }
  NS_HANDLER
    {
      if ([[localException name] isEqual: NSInvalidArgumentException])
	{
	  NSLog(@"Exception looking up port for gdomap - %@\n", localException);
	  handle = nil;
	}
      else
	{
	  [localException raise];
	}
    }
  NS_ENDHANDLER

  if (handle == nil)
    {
      NSLog(@"Failed to find gdomap port with name '%@',\nperhaps your "
		@"/etc/services file is not correctly set up?\n"
		@"Retrying with default (IANA allocated) port number 538",
		serverPort);
      NS_DURING
	{
	  handle = [NSFileHandle  fileHandleAsClientInBackgroundAtAddress: host
							  service: @"538"
							 protocol: @"tcp"
							 forModes: modes];
	}
      NS_HANDLER
	{
	  [localException raise];
	}
      NS_ENDHANDLER
      if (handle)
	{
	  RELEASE(serverPort);
	  serverPort = @"538";
	}
    }

  if (handle == nil)
    {
      [NSException raise: NSGenericException
		  format: @"failed to create file handle to gdomap on %@",
			hostname];
    }

  expecting = 1;
  RETAIN(handle);
  nc = [NSNotificationCenter defaultCenter];
  [nc addObserver: self
	 selector: @selector(_didConnect:)
	     name: GSFileHandleConnectCompletionNotification
	   object: handle];
  [nc addObserver: self
	 selector: @selector(_didRead:)
	     name: NSFileHandleReadCompletionNotification
	   object: handle];
  [nc addObserver: self
	 selector: @selector(_didWrite:)
	     name: GSFileHandleWriteCompletionNotification
	   object: handle];
  loop = [NSRunLoop currentRunLoop];
  [loop runMode: mode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: connectTimeout]];
  if (expecting)
    {
      static BOOL	retrying = NO;

      [self _close];
      if (isLocal == YES && retrying == NO)
	{
	  retrying = YES;
	  NS_DURING
	    {
	      [self _retry];
	    }
	  NS_HANDLER
	    {
	      retrying = NO;
	      [localException raise];
	    }
	  NS_ENDHANDLER
	  retrying = NO;
	}
      else
	{
	  if (isLocal)
	    {
	      NSLog(@"NSPortNameServer failed to connect to gdomap - %s",
		    make_gdomap_err(GNUSTEP_INSTALL_PREFIX)); 
	    }
	  else
	    {
	      NSLog(@"NSPortNameServer failed to connect to gdomap on %@",
		    hostname);
	    }
	}
    }
}

- (void) _retry
{
  static NSString	*cmd = nil;

  if (cmd == nil)
    cmd = [NSString stringWithCString: make_gdomap_cmd(GNUSTEP_INSTALL_PREFIX)]; 
  NSLog(@"NSPortNameServer attempting to start gdomap on local host"); 
  [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
  [NSTimer scheduledTimerWithTimeInterval: 5.0
			       invocation: nil
				  repeats: NO];
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 5.0]];
  NSLog(@"NSPortNameServer retrying connection attempt to gdomap"); 
  [self _open: nil];
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
      NSMutableSet	*known = (NSMutableSet*)NSMapGet(portMap, port);
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
