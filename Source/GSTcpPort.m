/* Implementation of network port object based on TCP sockets
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   
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
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSDebug.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#ifndef __MINGW__
#include <unistd.h>		/* for gethostname() */
#include <netinet/in.h>		/* for inet_ntoa() */
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/file.h>

extern	int	errno;

#if 0
#define	DO_LOCK(X) {NSDebugMLLog(@"GSTcpHandle",@"lock %@",X); [X lock];}
#define	DO_UNLOCK(X) {NSDebugMLLog(@"GSTcpHandle",@"unlock %@",X); [X unlock];}
#else
#define	DO_LOCK(X) {[X lock];}
#define	DO_UNLOCK(X) {[X unlock];}
#endif

#define	GS_CONNECTION_MSG	0
#define	NETBLOCK	8192

/*
 *	Stuff for setting the sockets into non-blocking mode.
 */
#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#endif /* !__MINGW__ */
#include <string.h>		/* for memset() and strchr() */
#ifndef __MINGW__
#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <errno.h>
#endif /* !__MINGW__ */

#ifndef INADDR_NONE
#define	INADDR_NONE	-1
#endif

@class	GSTcpPort;

/*
 * Theory of operation
 *
 * 
 */


/* Private interfaces */

/*
 * The GSPortItemType constant is used to identify the type of data in
 * each packet read.  All data transmitted is in a packet, each packet
 * has an initial packet type and packet length.
 */
typedef	enum {
  GSP_NONE,
  GSP_PORT,		/* Simple port item.			*/
  GSP_DATA,		/* Simple data item.			*/
  GSP_HEAD		/* Port message header + initial data.	*/
} GSPortItemType;

/*
 * The GSPortItemHeader structure defines the header for each item transmitted.
 * Its contents are transmitted in network byte order.
 */
typedef struct {
  gsu32	type;		/* A GSPortItemType as a 4-byte number.		*/
  gsu32	length;		/* The length of the item (excluding header).	*/
} GSPortItemHeader;

/*
 * The GSPortMsgHeader structure is at the start of any item of type GSP_HEAD.
 * Its contents are transmitted in network byte order.
 * Any additional data in the item is an NSData object.
 * NB. additional data counts as part of the same item.
 */
typedef struct {
  gsu32	mId;		/* The ID for the message starting with this.	*/
  gsu32	nItems;		/* Number of items (including this one).	*/
} GSPortMsgHeader;

typedef	struct {
  gsu16 num;		/* TCP port num	*/
  char	addr[0];	/* host address	*/
} GSPortInfo;

/*
 * Here is how data is transmitted over a socket -
 * Initially the process making the connection sends an item of type
 * GSP_PORT to tell the remote end what port is connecting to it.
 * Therafter, all communication is via port messages.  Each port message
 * consists of an item of type GSP_HEAD followed by zero or more items
 * of type GSP_PORT or GSP_DATA.  The number of items in a port message
 * is encoded in the 'nItems' field of the header.
 */

typedef enum {
  GS_H_UNCON = 0,	// Currently idle and unconnected.
  GS_H_TRYCON,		// Trying connection (outgoing).
  GS_H_ACCEPT,		// Making initial connection (incoming).
  GS_H_CONNECTED	// Currently connected.
} GSHandleState;

@interface GSTcpHandle : NSObject <GCFinalization, RunLoopEvents>
{
  NSLock		*myLock;	/* Lock for this handle.	*/
  int			desc;		/* File descriptor for I/O.	*/
  unsigned		wItem;		/* Index of item being written.	*/
  NSMutableData		*wData;		/* Data object being written.	*/
  unsigned		wLength;	/* Ammount written so far.	*/
  NSMutableArray	*wMsgs;		/* Message in progress.		*/
  NSMutableData		*rData;		/* Buffer for incoming data	*/
  gsu32			rLength;	/* Amount read so far.		*/
  gsu32			rWant;		/* Amount desired.		*/
  NSMutableArray	*rItems;	/* Message in progress.		*/
  GSPortItemType	rType;		/* Type of data being read.	*/
  gsu32			rId;		/* Id of incoming message.	*/
  unsigned		nItems;		/* Number of items to be read.	*/
  GSHandleState		state;		/* State of the handle.		*/
  int			addrNum;	/* Address number within host.	*/
@public
  BOOL			caller;		/* Did we connect to other end?	*/
  BOOL			valid;
  GSTcpPort		*recvPort;
  GSTcpPort		*sendPort;
}

+ (GSTcpHandle*) handleWithDescriptor: (int)d;
- (BOOL) connectToPort: (GSTcpPort*)aPort beforeDate: (NSDate*)when;
- (int) descriptor;
- (void) dispatch;
- (void) invalidate;
- (BOOL) isValid;
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
- (GSTcpPort*) recvPort;
- (BOOL) sendMessage: (NSArray*)components beforeDate: (NSDate*)when;
- (GSTcpPort*) sendPort;
- (void) setState: (GSHandleState)s;
- (GSHandleState) state;
- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode;
@end

@interface GSTcpPort : NSPort <GCFinalization, RunLoopEvents>
{
  NSRecursiveLock	*myLock;
  NSHost		*host;		/* OpenStep host for this port.	*/
  NSString		*address;	/* Forced internet address.	*/
  gsu16			portNum;	/* TCP port in host byte order.	*/
  int			listener;	/* Descriptor to listen on.	*/
  NSMapTable		*handles;	/* Handles indexed by socket.	*/
}

+ (GSTcpPort*) existingPortWithNumber: (gsu16)number
			       onHost: (NSHost*)host;
+ (GSTcpPort*) portWithNumber: (gsu16)number
		       onHost: (NSHost*)host
		 forceAddress: (NSString*)addr
		     listener: (BOOL)shouldListen;

- (void) addHandle: (GSTcpHandle*)handle forSend: (BOOL)send;
- (NSString*) address;
- (void) getFds: (int*)fds count: (int*)count;
- (GSTcpHandle*) handleForPort: (GSTcpPort*)recvPort beforeDate: (NSDate*)when;
- (void) handlePortMessage: (NSPortMessage*)m;
- (NSHost*) host;
- (gsu16) portNumber;
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
- (void) removeHandle: (GSTcpHandle*)h;
- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode;
@end


/*
 * Utility functions for encoding and decoding ports.
 */
static GSTcpPort*
decodePort(NSData *data)
{
  GSPortItemHeader	*pih;
  GSPortInfo		*pi;
  NSString		*addr;
  gsu16			pnum;
  gsu32			length;
  NSHost		*host;
  
  pih = (GSPortItemHeader*)[data bytes];
  NSCAssert(GSSwapBigI32ToHost(pih->type) == GSP_PORT,
    NSInternalInconsistencyException);
  length = GSSwapBigI32ToHost(pih->length);
  pi = (GSPortInfo*)&pih[1];
  pnum = GSSwapBigI16ToHost(pi->num);
  addr = [NSString stringWithCString: pi->addr];

  NSDebugFLLog(@"NSPort", @"Decoded port as '%@:%d'", addr, pnum);

  host = [NSHost hostWithAddress: addr];
  return [GSTcpPort portWithNumber: pnum
			    onHost: host
		      forceAddress: nil
			  listener: NO];
}

static NSData*
newDataWithEncodedPort(GSTcpPort *port)
{
  GSPortItemHeader	*pih;
  GSPortInfo		*pi;
  NSMutableData		*data;
  unsigned		plen;
  NSString		*addr;
  gsu16			pnum;
  
  pnum = [port portNumber];
  addr = [port address];
  if (addr == nil)
    {
      /*
       * If the port is not forced to use a specific address, just try one
       * at random, but try not to make it the loopback address!
       */
      addr = [[port host] address];
      if ([addr isEqualToString: @"127.0.0.1"] == YES)
	{
	  NSArray	*a = [[port host] addresses];
          unsigned	c = [a count];
	  unsigned	i;

	  for (i = 0; i < c; i++)
	    {
	      addr = [a objectAtIndex: i];
	      if ([addr isEqualToString: @"127.0.0.1"] == NO)
		{
		  break;
		}
	    }
	}
    }
  plen = [addr cStringLength] + 3;
  data = [[NSMutableData alloc] initWithLength: sizeof(GSPortItemHeader)+plen];
  pih = (GSPortItemHeader*)[data mutableBytes];
  pih->type = GSSwapHostI32ToBig(GSP_PORT);
  pih->length = GSSwapHostI32ToBig(plen);
  pi = (GSPortInfo*)&pih[1];
  pi->num = GSSwapHostI16ToBig(pnum);
  [addr getCString: pi->addr];

  NSDebugFLLog(@"NSPort", @"Encoded port as '%@:%d'", addr, pnum);

  return data;
}



@implementation	GSTcpHandle

static Class	mutableArrayClass;
static Class	mutableDataClass;
static Class	portMessageClass;
static Class	runLoopClass;

+ (id) allocWithZone: (NSZone*)zone
{
  [NSException raise: NSGenericException
	      format: @"attempt to alloc a GSTcpHandle!"];
  return nil;
}

+ (GSTcpHandle*) handleWithDescriptor: (int)d
{
  GSTcpHandle	*handle;
  int		e;

  if (d < 0)
    {
      NSLog(@"illegal descriptor (%d) for Tcp Handle", d);
      return nil;
    }
  if ((e = fcntl(d, F_GETFL, 0)) >= 0)
    {
      e |= NBLK_OPT;
      if (fcntl(d, F_SETFL, e) < 0)
	{
	  NSLog(@"unable to set non-blocking mode - %s", strerror(errno));
	  return nil;
	}
    }
  else
    {
      NSLog(@"unable to get non-blocking mode - %s", strerror(errno));
      return nil;
    }
  handle = (GSTcpHandle*)NSAllocateObject(self,0,NSDefaultMallocZone());
  handle->desc = d;
  handle->wMsgs = [NSMutableArray new];
  handle->myLock = [NSRecursiveLock new];
  handle->valid = YES;
  return AUTORELEASE(handle);
}

+ (void) initialize
{
  if (self == [GSTcpHandle class])
    {
      mutableArrayClass = [NSMutableArray class];
      mutableDataClass = [NSMutableData class];
      portMessageClass = [NSPortMessage class];
      runLoopClass = [NSRunLoop class];
    }
}

- (BOOL) connectToPort: (GSTcpPort*)aPort beforeDate: (NSDate*)when
{
  NSArray		*addrs;
  struct sockaddr_in	sin;
  BOOL			gotAddr = NO;
  NSRunLoop		*l;

  NSDebugMLLog(@"GSTcpHandle", @"Connecting before %@", when);
  if (state != GS_H_UNCON)
    {
      NSLog(@"attempting connect on connected handle");
      return YES;	/* Already connected.	*/
    }
  if (recvPort == nil || aPort == nil)
    {
      NSLog(@"attempting connect with port(s) unset");
      return NO;	/* impossible.		*/
    }

  /*
   * Get an IP address to try to connect to.
   * If the port has a 'forced' address, just use that. Otherwise we try
   * each of the addresses for the host in turn.
   */
  if ([aPort address] != nil)
    {
      addrs = [NSArray arrayWithObject: [aPort address]];
    }
  else
    {
      addrs = [[aPort host] addresses];
    }
  while (gotAddr == NO)
    {
      const char	*addr;

      if (addrNum >= [addrs count])
	{
	  NSLog(@"run out of addresses to try (tried %d)", addrNum);
	  return NO;
	}
      addr = [[addrs objectAtIndex: addrNum++] cString];
      memset(&sin, '\0', sizeof(sin));
      sin.sin_family = AF_INET;
#ifndef HAVE_INET_ATON
      sin.sin_addr.s_addr = inet_addr(addr);
      if (sin.sin_addr.s_addr == INADDR_NONE)
#else
      if (inet_aton(addr, &sin.sin_addr) == 0)
#endif
	{
	  NSLog(@"bad ip address - '%s'", addr);
	}
      else
	{
	  gotAddr = YES;
	}
    }
  sin.sin_port = GSSwapHostI16ToBig([aPort portNumber]);

  if (connect(desc, (struct sockaddr*)&sin, sizeof(sin)) < 0)
    {
      if (errno != EINPROGRESS)
	{
	  NSLog(@"unable to make connection to %s:%d - %s",
	      inet_ntoa(sin.sin_addr),
	      GSSwapBigI16ToHost(sin.sin_port), strerror(errno));
	  if (addrNum < [addrs count])
	    {
	      return [self connectToPort: aPort beforeDate: when];
	    }
	  else
	    {
	      return NO;	/* Tried all addresses	*/
	    }
	}
    }

  state = GS_H_TRYCON;
  l = [NSRunLoop currentRunLoop];
  [l addEvent: (void*)(gsaddr)desc
	 type: ET_WDESC
      watcher: self
      forMode: NSDefaultRunLoopMode];
  while (state == GS_H_TRYCON && [when timeIntervalSinceNow] > 0)
    {
      [l runMode: NSDefaultRunLoopMode beforeDate: when];
    }
  [l removeEvent: (void*)(gsaddr)desc
	    type: ET_WDESC
	 forMode: NSDefaultRunLoopMode
	     all: NO];

  if (state == GS_H_TRYCON)
    {
      state = GS_H_UNCON;
      addrNum = 0;
      return NO;	/* Timed out 	*/
    }
  else if (state == GS_H_UNCON)
    {
      if (addrNum < [addrs count] && [when timeIntervalSinceNow] > 0)
	{
	  /*
	   * The connection attempt failed, but there are still IP addresses
	   * that we haven't tried.
	   */
	  return [self connectToPort: aPort beforeDate: when];
	}
      addrNum = 0;
      state = GS_H_UNCON;
      return NO;	/* connection failed	*/
    }
  else
    {
      addrNum = 0;
      caller = YES;
      [aPort addHandle: self forSend: YES];
      return YES;
    }
}

- (void) dealloc
{
  [self gcFinalize];
  DESTROY(rData);
  DESTROY(rItems);
  DESTROY(wMsgs);
  DESTROY(myLock);
  [super dealloc];
}

- (int) descriptor
{
  return desc;
}

/*
 * Method to pass an incoming message to the recieving port.
 */ 
- (void) dispatch
{
  NSPortMessage	*pm;
  GSTcpPort	*rp = [self recvPort];

  pm = [portMessageClass allocWithZone: NSDefaultMallocZone()];
  pm = [pm initWithSendPort: [self sendPort]
		receivePort: rp
		 components: rItems];
  [pm setMsgid: rId];
  rId = 0;
  DESTROY(rItems);
  NSDebugMLLog(@"GSTcpHandle", @"got message %@", pm);
  [rp handlePortMessage: pm];
  RELEASE(pm);
}

- (void) gcFinalize
{
  (void)close(desc);
  desc = -1;
}

- (void) invalidate
{
  DO_LOCK(myLock);
  if (valid == YES)
    { 
      valid = NO;
      NSDebugMLLog(@"GSTcpHandle", @"invalidated", 0);
      [[self recvPort] removeHandle: self];
      [[self sendPort] removeHandle: self];
    }
  DO_UNLOCK(myLock);
}

- (BOOL) isValid
{
  return valid;
}

- (GSTcpPort*) recvPort
{
  if (recvPort == nil)
    return nil;
  else
    return GS_GC_UNHIDE(recvPort);
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  NSDebugMLLog(@"GSTcpHandle", @"received %s event on 0x%x",
    type == ET_RPORT ? "read" : "write", self);
  /*
   * If we have been invalidated (desc < 0) then we should ignore this
   * event and remove ourself from the runloop.
   */
  if (desc < 0)
    {
      NSRunLoop	*l = [runLoopClass currentRunLoop];

      [l removeEvent: data
		type: ET_WDESC
	     forMode: mode
		 all: YES];
      return;
    }

  if (type == ET_RPORT)
    {
      unsigned	want;
      void	*bytes;
      int	res;

      /*
       * Make sure we have a buffer big enough to hold all the data we are
       * expecting, or NETBLOCK bytes, whichever is greater.
       */
      if (rData == nil)
	{
	  rData = [[mutableDataClass alloc] initWithLength: NETBLOCK];
	  rWant = sizeof(GSPortItemHeader);
	  rLength = 0;
	  want = NETBLOCK;
	}
      else
	{
	  want = [rData length];
	  if (want < rWant)
	    {
	      want = rWant;
	      [rData setLength: want];
	    }
	  if (want < NETBLOCK)
	    {
	      want = NETBLOCK;
	      [rData setLength: want];
	    }
	}

      /*
       * Now try to fill the buffer with data.
       */
      bytes = [rData mutableBytes];
      res = read(desc, bytes + rLength, want - rLength);
      if (res <= 0)
	{
	  if (res == 0)
	    {
	      NSDebugMLLog(@"GSTcpHandle", @"read attempt failed - eof", 0);
	      [self invalidate];
	      return;
	    }
	  else if (errno != EINTR && errno != EAGAIN)
	    {
	      NSDebugMLLog(@"GSTcpHandle", @"read attempt failed - %s",
		strerror(errno));
	      [self invalidate];
	      return;
	    }
	  res = 0;	/* Interrupted - continue	*/
	}
      NSDebugMLLog(@"GSTcpHandle", @"read %d bytes", res);
      rLength += res;


      while (valid == YES && rLength >= rWant)
	{
	  switch (rType)
	    {
	      case GSP_NONE:
		{
		  GSPortItemHeader	*h;
		  unsigned		l;

		  /*
		   * We have read an item header - set up to read the
		   * remainder of the item.
		   */
		  h = (GSPortItemHeader*)bytes;
		  rType = GSSwapBigI32ToHost(h->type);
		  l = GSSwapBigI32ToHost(h->length);
		  if (rType == GSP_PORT)
		    {
		      /*
		       * For a port, we leave the item header in the data
		       * so that our decode function can check length info.
		       */
		      rWant += l;
		    }
		  else if (rType == GSP_DATA && l == 0)
		    {
		      NSData	*d;

		      /*
		       * For a zero-length data chunk, we create an empty
		       * data object and add it to the current message.
		       */
		      rType = GSP_NONE;	/* ready for a new item	*/
		      rLength -= rWant;
		      if (rLength > 0)
			{
			  memcpy(bytes, bytes + rWant, rLength);
			}
		      rWant = sizeof(GSPortItemHeader);
		      d = [mutableDataClass new];
		      [rItems addObject: d];
		      RELEASE(d);
		      if (nItems == [rItems count])
			{
			  [self dispatch];
			}
		    }
		  else
		    {
		      /*
		       * If not a port or zero length data,
		       * we discard the data read so far and fill the
		       * data object with the data item from the msg.
		       */
		      rLength -= rWant;
		      if (rLength > 0)
			{
			  memcpy(bytes, bytes + rWant, rLength);
			}
		      rWant = l;
		    }
		}
		break;

	      case GSP_HEAD:
		{
		  GSPortMsgHeader	*h;

		  rType = GSP_NONE;	/* ready for a new item	*/
		  /*
		   * We have read a message header - set up to read the
		   * remainder of the message.
		   */
		  h = (GSPortMsgHeader*)bytes;
		  rId = GSSwapBigI32ToHost(h->mId);
		  nItems = GSSwapBigI32ToHost(h->nItems);
		  NSAssert(nItems >0, NSInternalInconsistencyException);
		  rItems
		    = [mutableArrayClass allocWithZone: NSDefaultMallocZone()];
		  rItems = [rItems initWithCapacity: nItems];
		  if (rWant > sizeof(GSPortMsgHeader))
		    {
		      NSData	*d;

		      /*
		       * The first data item of the message was included in
		       * the header - so add it to the rItems array.
		       */
		      rWant -= sizeof(GSPortMsgHeader);
		      d = [mutableDataClass alloc];
		      d = [d initWithBytes: bytes + sizeof(GSPortMsgHeader)
				    length: rWant];
		      [rItems addObject: d];
		      RELEASE(d);
		      rWant += sizeof(GSPortMsgHeader);
		      rLength -= rWant;
		      if (rLength > 0)
			{
			  memcpy(bytes, bytes + rWant, rLength);
			}
		      rWant = sizeof(GSPortItemHeader);
		      if (nItems == 1)
			{
			  [self dispatch];
			}
		    }
		  else
		    {
		      /*
		       * want to read another item
		       */
		      rLength -= rWant;
		      if (rLength > 0)
			{
			  memcpy(bytes, bytes + rWant, rLength);
			}
		      rWant = sizeof(GSPortItemHeader);
		    }
		}
		break;

	      case GSP_DATA:
		{
		  NSData	*d;

		  rType = GSP_NONE;	/* ready for a new item	*/
		  d = [mutableDataClass allocWithZone: NSDefaultMallocZone()];
		  d = [d initWithBytes: bytes length: rWant];
		  [rItems addObject: d];
		  RELEASE(d);
		  rLength -= rWant;
		  if (rLength > 0)
		    {
		      memcpy(bytes, bytes + rWant, rLength);
		    }
		  rWant = sizeof(GSPortItemHeader);
		  if (nItems == [rItems count])
		    {
		      [self dispatch];
		    }
		}
		break;

	      case GSP_PORT:
		{
		  GSTcpPort	*p;

		  rType = GSP_NONE;	/* ready for a new item	*/
		  p = decodePort(rData);
		  /*
		   * Set up to read another item header.
		   */
		  rLength -= rWant;
		  if (rLength > 0)
		    {
		      memcpy(bytes, bytes + rWant, rLength);
		    }
		  rWant = sizeof(GSPortItemHeader);

		  if (state == GS_H_ACCEPT)
		    {
		      /*
		       * This is the initial port information on a new
		       * connection - set up port relationships.
		       */
		      state = GS_H_CONNECTED;
		      [p addHandle: self forSend: YES];
		    }
		  else
		    {
		      /*
		       * This is a port within a port message - add
		       * it to the message components.
		       */
		      [rItems addObject: p];
		      if (nItems == [rItems count])
			{
			  [self dispatch];
			}
		    }
		}
		break;
	    }
	}
    }
  else if (type == ET_WDESC)
    {
      if (state == GS_H_TRYCON)	/* Connection attempt.	*/
	{
	  int	res;
	  int	len = sizeof(res);

	  if (getsockopt(desc, SOL_SOCKET, SO_ERROR, (char*)&res, &len) == 0
	    && res != 0)
	    {
	      state = GS_H_UNCON;
	      NSLog(@"connect attempt failed - %s", strerror(res));
	    }
	  else
	    {
	      NSData	*d = newDataWithEncodedPort([self recvPort]);

	      len = write(desc, [d bytes], [d length]);
	      if (len == [d length])
		{
		  NSDebugMLLog(@"GSTcpHandle", @"wrote %d bytes", len);
		  state = GS_H_CONNECTED;
		}
	      else
		{
		  state = GS_H_UNCON;
		  NSLog(@"connect write attempt failed - %s", strerror(errno));
		}
	      RELEASE(d);
	    }
	}
      else
	{
	  int		res;
	  unsigned	l;
	  const void	*b;

	  if (wData == nil)
	    {
	      if ([wMsgs count] > 0)
		{
		  NSArray	*components = [wMsgs objectAtIndex: 0];

		  wData = [components objectAtIndex: wItem++];
		  wLength = 0;
		}
	      else
		{
		  NSLog(@"No messages to write on 0x%x.", self);
		  return;
		}
	    }
	  b = [wData bytes];
	  l = [wData length];
	  res = write(desc, b + wLength,  l - wLength);
	  if (res < 0)
	    {
	      if (errno != EINTR && errno != EAGAIN)
		{
		  NSLog(@"write attempt failed - %s", strerror(errno));
		  [self invalidate];
		  return;
		}
	    }
	  else
	    {
	      NSDebugMLLog(@"GSTcpHandle", @"wrote %d bytes on 0x%x",
		res, self);
	      wLength += res;
	      if (wLength == l)
		{
		  NSArray	*components;

		  /*
		   * We have completed a data item so see what is
		   * left of the message components.
		   */
		  components = [wMsgs objectAtIndex: 0];
		  wLength = 0;
		  if ([components count] > wItem)
		    {
		      /*
		       * More to write - get next item.
		       */
		      wData = [components objectAtIndex: wItem++];
		    }
		  else
		    {
		      NSRunLoop	*l = [runLoopClass currentRunLoop];

		      /*
		       * message completed - remove from list.
		       */
		      NSDebugMLLog(@"GSTcpHandle", @"completed 0x%x on 0x%x",
			components, self);
		      wData = nil;
		      wItem = 0;
		      [wMsgs removeObjectAtIndex: 0];

		      [l removeEvent: data
				type: ET_WDESC
			     forMode: mode
				 all: NO];
		    }
		}
	    }
	}
    }
}

- (BOOL) sendMessage: (NSArray*)components beforeDate: (NSDate*)when
{
  NSRunLoop	*l;
  BOOL		sent = NO;

  NSAssert([components count] > 0, NSInternalInconsistencyException);
  NSDebugMLLog(@"GSTcpHandle", @"Sending message 0x%x %@ on 0x%x(%d) before %@",
    components, components, self, desc, when);
  [wMsgs addObject: components];

  l = [runLoopClass currentRunLoop];

  RETAIN(self);

  [l addEvent: (void*)(gsaddr)desc
	 type: ET_WDESC
      watcher: self
      forMode: NSDefaultRunLoopMode];
  while ([wMsgs indexOfObjectIdenticalTo: components] != NSNotFound
    && [when timeIntervalSinceNow] > 0)
    {
      [l runMode: NSDefaultRunLoopMode beforeDate: when];
    }
  /*
   * NB. We will remove ourself from the run loop when the message send
   * is completed, so we don't need to do it here.
   */
  if ([wMsgs indexOfObjectIdenticalTo: components] == NSNotFound)
    {
      sent = YES;
    }
  RELEASE(self);
  NSDebugMLLog(@"GSTcpHandle", @"Message send 0x%x on 0x%x status %d",
    components, self, sent);
  return sent;
}

- (GSTcpPort*) sendPort
{
  if (sendPort == nil)
    return nil;
  else if (caller == YES)
    return GS_GC_UNHIDE(sendPort);	// We called, so port is not retained.
  else
    return sendPort;			// Retained port.
}

- (void) setState: (GSHandleState)s
{
  state = s;
}

- (GSHandleState) state
{
  return state;
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

@end



@implementation	GSTcpPort

static NSRecursiveLock	*tcpPortLock = nil;
static NSMapTable	*tcpPortMap = 0;
static Class		tcpPortClass;

+ (void) initialize
{
  if (self == [GSTcpPort class])
    {
      tcpPortClass = self;
      tcpPortLock = [NSRecursiveLock new];
      tcpPortMap = NSCreateMapTable(NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

+ (id) new
{
  return RETAIN([self portWithNumber: 0
			      onHost: nil
			forceAddress: nil
			    listener: YES]);
}

/*
 * Look up an existing GSTcpPort given a host and number
 */
+ (GSTcpPort*) existingPortWithNumber: (gsu16)number
			       onHost: (NSHost*)aHost
{
  GSTcpPort	*port = nil;
  NSMapTable	*thePorts;

  [tcpPortLock lock];

  /*
   *	Get the map table of ports with the specified number.
   */
  thePorts = (NSMapTable*)NSMapGet(tcpPortMap, (void*)(gsaddr)number);
  if (thePorts != 0)
    {
      port = (GSTcpPort*)NSMapGet(thePorts, (void*)aHost);
    }
  [tcpPortLock unlock];
  return port;
}

/*
 * This is the preferred initialisation method for GSTcpPort
 *
 * 'number' should be a TCP/IP port number or may be zero for a port on
 * the local host.
 * 'aHost' should be the host for the port or may be nil for the local
 * host.
 * 'addr' is the IP address that MUST be used for this port - if it is nil
 * then, for the local host, the port uses ALL IP addresses, and for a
 * remote host, the port will use the first address that works.
 */
+ (GSTcpPort*) portWithNumber: (gsu16)number
		       onHost: (NSHost*)aHost
		 forceAddress: (NSString*)addr
		     listener: (BOOL)shouldListen
{
  unsigned		i;
  GSTcpPort		*port = nil;
  NSHost		*thisHost = [NSHost currentHost];
  NSMapTable		*thePorts;

  if (thisHost == nil)
    {
      NSLog(@"attempt to create port on host without networking set up!");
      return nil;
    }
  if (aHost == nil)
    {
      aHost = thisHost;
    }
  if (addr != nil && [[aHost addresses] containsObject: addr] == NO)
    {
      NSLog(@"attempt to use address '%@' on host without that address", addr);
      return nil;
    }
  if (number == 0 && [thisHost isEqual: aHost] == NO)
    {
      NSLog(@"attempt to get port zero on remote host");
      return nil;
    }

  [tcpPortLock lock];

  /*
   * First try to find a pre-existing port.
   */
  thePorts = (NSMapTable*)NSMapGet(tcpPortMap, (void*)(gsaddr)number);
  if (thePorts != 0)
    {
      port = (GSTcpPort*)NSMapGet(thePorts, (void*)aHost);
    }

  if (port == nil)
    {
      port = (GSTcpPort*)NSAllocateObject(self,0,NSDefaultMallocZone());
      port->listener = -1;
      port->host = RETAIN(aHost);
      port->address = [addr copy];
      port->handles = NSCreateMapTable(NSIntMapKeyCallBacks,
	NSObjectMapValueCallBacks, 0);
      port->myLock = [NSRecursiveLock new];
      port->_is_valid = YES;

      if (shouldListen == YES && [thisHost isEqual: aHost] == YES)
	{
	  int	reuse = 1;	/* Should we re-use ports?	*/
	  int	desc;
	  BOOL	addrOk = YES;
	  struct sockaddr_in	sockaddr;

	  /*
	   * Creating a new port on the local host - so we must create a
	   * listener socket to accept incoming connections.
	   */
	  memset(&sockaddr, '\0', sizeof(sockaddr));
	  sockaddr.sin_family = AF_INET;
	  if (addr == nil)
	    {
	      sockaddr.sin_addr.s_addr = GSSwapHostI32ToBig(INADDR_ANY);
	    }
	  else
	    {
#ifndef HAVE_INET_ATON
	      sockaddr.sin_addr.s_addr = inet_addr([addr cString]);
	      if (sockaddr.sin_addr.s_addr == INADDR_NONE)
#else
	      if (inet_aton([addr cString], &sockaddr.sin_addr) == 0)
#endif
		{
		  addrOk = NO;
		}
	    }

	  /*
           * Need size of buffer for getsockbyname() later.
	   */
	  i = sizeof(sockaddr);

	  if (addrOk == NO)
	    {
	      NSLog(@"Bad address (%@) specified for listening port", addr);
	      DESTROY(port);
	    }
	  else if ((desc = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
	    {
	      NSLog(@"unable to create socket - %s", strerror(errno));
	      DESTROY(port);
	    }
	  else if (setsockopt(desc, SOL_SOCKET, SO_REUSEADDR, (char*)&reuse,
		sizeof(reuse)) < 0)
	    {
	      (void) close(desc);
              NSLog(@"unable to set reuse on socket - %s", strerror(errno));
              DESTROY(port);
	    }
	  else if (bind(desc, (struct sockaddr *)&sockaddr,
	    sizeof(sockaddr)) < 0)
	    {
	      NSLog(@"unable to bind to port %s:%d - %s",
		inet_ntoa(sockaddr.sin_addr), number, strerror(errno));
	      (void) close(desc);
              DESTROY(port);
	    }
	  else if (listen(desc, 5) < 0)
	    {
	      NSLog(@"unable to listen on port - %s", strerror(errno));
	      (void) close(desc);
	      DESTROY(port);
	    }
	  else if (getsockname(desc, (struct sockaddr*)&sockaddr, &i) < 0)
	    {
	      NSLog(@"unable to get socket name - %s", strerror(errno));
	      (void) close(desc);
	      DESTROY(port);
	    }
	  else
	    {
	      /*
	       * Set up the listening descriptor and the actual TCP port
	       * number (which will have been set to a real port number when
	       * we did the 'bind' call.
	       */
	      port->listener = desc;
	      port->portNum = GSSwapBigI16ToHost(sockaddr.sin_port); 

	      /*
	       * Make sure we have the map table for this port.
	       */
	      thePorts = (NSMapTable*)NSMapGet(tcpPortMap,
		    (void*)(gsaddr)port->portNum);
	      if (thePorts == 0)
		{
		  /*
		   * No known ports with this port number -
		   * create the map table to add the new port to.
		   */ 
		  thePorts = NSCreateMapTable(NSObjectMapKeyCallBacks,
				  NSNonOwnedPointerMapValueCallBacks, 0);
		  NSMapInsert(tcpPortMap, (void*)(gsaddr)port->portNum,
		    (void*)thePorts);
		}
	      /*
	       * Ok - now add the port for the host
	       */
	      NSMapInsert(thePorts, (void*)aHost, (void*)port);
	      NSDebugMLLog(@"NSPort", @"Created listening port: %@", port);
	    }
	}
      else
	{
	  /*
	   * Make sure we have the map table for this port.
	   */
	  port->portNum = number;
	  thePorts = (NSMapTable*)NSMapGet(tcpPortMap, (void*)(gsaddr)number);
	  if (thePorts == 0)
	    {
	      /*
	       * No known ports within this port number -
	       * create the map table to add the new port to.
	       */ 
	      thePorts = NSCreateMapTable(NSIntMapKeyCallBacks,
			      NSNonOwnedPointerMapValueCallBacks, 0);
	      NSMapInsert(tcpPortMap, (void*)(gsaddr)number, (void*)thePorts);
	    }
	  /*
	   * Record the port by host.
	   */
	  NSMapInsert(thePorts, (void*)aHost, (void*)port);
	  NSDebugMLLog(@"NSPort", @"Created speaking port: %@", port);
	}
      IF_NO_GC(AUTORELEASE(port));
    }
  else
    {
      NSDebugMLLog(@"NSPort", @"Using pre-existing port: %@", port);
    }

  [tcpPortLock unlock];
  return port;
}

- (void) addHandle: (GSTcpHandle*)handle forSend: (BOOL)send
{
  DO_LOCK(myLock);
  if (send == YES)
    {
      if (handle->caller == YES)
	handle->sendPort = GS_GC_HIDE(self);
      else
	ASSIGN(handle->sendPort, self);
    }
  else
    {
      handle->recvPort = GS_GC_HIDE(self);
    }
  NSMapInsert(handles, (void*)(gsaddr)[handle descriptor], (void*)handle);
  DO_UNLOCK(myLock);
}

- (NSString*) address
{
  return address;
}

- (id) copyWithZone: (NSZone*)zone
{
  return RETAIN(self);
}

- (void) dealloc
{
  [self gcFinalize];
  DESTROY(host);
  [super dealloc];
}

- (NSString*) description
{
  NSMutableString	*desc;

  desc = [NSMutableString stringWithFormat: @"Host - %@\n", host];
  [desc appendFormat: @"Addr - %@\n", address];
  [desc appendFormat: @"Port - %d\n", portNum];
  return desc;
}

- (void) gcFinalize
{
  [self invalidate];
}

/*
 * This is a callback method used by the NSRunLoop class to determine which
 * descriptors to watch for the port.
 */
- (void) getFds: (int*)fds count: (int*)count
{
  NSMapEnumerator	me;
  int			sock;
  GSTcpHandle		*handle;

  DO_LOCK(myLock);

  /*
   * Make sure there is enough room in the provided array.
   */
  NSAssert(*count > NSCountMapTable(handles), NSInternalInconsistencyException);

  /*
   * Put in our listening socket.
   */
  *count = 0;
  fds[(*count)++] = listener;

  /*
   * Enumerate all our socket handles, and put them in.
   */
  me = NSEnumerateMapTable(handles);
  while (NSNextMapEnumeratorPair(&me, (void*)&sock, (void*)&handle))
    {
      fds[(*count)++] = sock;
    }
  DO_UNLOCK(myLock);
}

- (GSTcpHandle*) handleForPort: (GSTcpPort*)recvPort beforeDate: (NSDate*)when
{
  NSMapEnumerator	me;
  int			sock;
  GSTcpHandle		*handle = nil;

  DO_LOCK(myLock);
  /*
   * Enumerate all our socket handles, and look for one with port.
   */
  me = NSEnumerateMapTable(handles);
  while (NSNextMapEnumeratorPair(&me, (void*)&sock, (void*)&handle))
    {
      if ([handle recvPort] == recvPort)
	{
	  DO_UNLOCK(myLock);
	  return handle;
	}
    }
  if (handle == nil)
    {
      int	opt = 1;

      if ((sock = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
	{
	  NSLog(@"unable to create socket - %s", strerror(errno));
	}
      else if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char*)&opt,
	sizeof(opt)) < 0)
	{
	  (void)close(sock);
	  NSLog(@"unable to set reuse on socket - %s", strerror(errno));
	}
      else if ((handle = [GSTcpHandle handleWithDescriptor: sock]) == nil)
	{
	  (void)close(sock);
	  NSLog(@"unable to create GSTcpHandle - %s", strerror(errno));
	}
      else
	{
	  [recvPort addHandle: handle forSend: NO];
	}
    }
  DO_UNLOCK(myLock);
  /*
   * If we succeeded in creating a new handle - connect to remote host.
   */
  if (handle != nil)
    {
      if ([handle connectToPort: self beforeDate: when] == NO)
	{
	  [handle invalidate];
	  handle = nil;
	}
    }
  return handle;
}

- (void) handlePortMessage: (NSPortMessage*)m
{
  id	d = [self delegate];

  if (d == nil)
    {
      NSDebugMLLog(@"NSPort", @"No delegate to handle incoming message", 0);
      return;
    }
  if ([d respondsToSelector: @selector(handlePortMessage:)] == NO)
    {
      NSDebugMLLog(@"NSPort", @"delegate doesn't handle messages", 0);
      return;
    }
  [d handlePortMessage: m];
}

- (unsigned) hash
{
  return (unsigned)portNum;
}

- (NSHost*) host
{
  return host;
}

- (id) init
{
  RELEASE(self);
  self = [tcpPortClass new];
  return self;
}

- (void) invalidate
{
  DO_LOCK(myLock);

  if ([self isValid])
    {
      NSMapTable	*thePorts;
      NSArray		*handleArray;
      unsigned		i;

      [tcpPortLock lock];
      thePorts = NSMapGet(tcpPortMap, (void*)(gsaddr)portNum);
      if (thePorts != 0)
	{
	  if (listener >= 0)
	    {
	      (void)close(listener);
	      listener = -1;
	    }
	  NSMapRemove(thePorts, (void*)host);
	}
      [tcpPortLock unlock];

      handleArray = NSAllMapTableValues(handles);
      i = [handleArray count];
      while (i-- > 0)
	{
	  GSTcpHandle	*handle = [handleArray objectAtIndex: i];

	  [handle invalidate];
	}
      NSFreeMapTable(handles);
      handles = 0;
      [super invalidate];
    }
  DO_UNLOCK(myLock);
}

- (BOOL) isEqual: (id)anObject
{
  if (anObject == self)
    {
      return YES;
    }
  if ([anObject class] == [self class])
    {
      GSTcpPort	*o = (GSTcpPort*)anObject;

      if (o->portNum == portNum && [o->host isEqual: host])
	{
	  return YES;
	}
    }
  return NO;
}

- (gsu16) portNumber
{
  return portNum;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  int		desc = (int)(gsaddr)extra;
  GSTcpHandle	*handle;


  if (desc == listener)
    {
      struct sockaddr_in	clientname;
      int			size = sizeof(clientname);

      desc = accept(listener, (struct sockaddr*)&clientname, &size);
      if (desc < 0)
        {
          [NSException raise: NSInternalInconsistencyException
		      format: @"GSTcpPort accept(): %s", strerror(errno)];
        }
      /*
       * Create a handle for the socket and set it up so we are its
       * receiving port, and it's waiting to get the port name from
       * the other end.
       */
      handle = [GSTcpHandle handleWithDescriptor: desc];
      [handle setState: GS_H_ACCEPT];
      [self addHandle: handle forSend: NO];
    }
  else
    {
      DO_LOCK(myLock);
      handle = (GSTcpHandle*)NSMapGet(handles, (void*)(gsaddr)desc);
      AUTORELEASE(RETAIN(handle));
      DO_UNLOCK(myLock);
      if (handle == nil)
	{
	  NSLog(@"No handle for event on descriptor %d", desc);
	}
      else
	{
	  [handle receivedEvent: data type: type extra: extra forMode: mode];
	}
    }
}

/*
 * This is called when a tcp/ip socket connection is broken.  We remove the
 * connection handle from this port and, if this was the last handle to a
 * remote port, we invalidate the port.
 */
- (void) removeHandle: (GSTcpHandle*)handle
{
  DO_LOCK(myLock);
  if ([handle sendPort] == self)
    {
      if (handle->caller == YES)
	{
	  AUTORELEASE(self);
	}
      handle->sendPort = nil;
    }
  if ([handle recvPort] == self)
    {
      handle->recvPort = nil;
    }
  NSMapRemove(handles, (void*)(gsaddr)[handle descriptor]);
  if (listener < 0 && NSCountMapTable(handles) == 0)
    {
      [self invalidate];
    }
  DO_UNLOCK(myLock);
}

/*
 * This returns the amount of space that a port coder should reserve at the
 * start of its encoded data so that the GSTcpPort can insert header info
 * into the data.
 * The idea is that a message consisting of a single data item with space at
 * the start can be written directly without having to copy data to another
 * buffer etc.
 */
- (unsigned int) reservedSpaceLength
{
  return sizeof(GSPortItemHeader) + sizeof(GSPortMsgHeader);
}

- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgId
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned)length
{
  BOOL		sent = NO;
  GSTcpHandle	*h;
  unsigned	rl;

  if ([self isValid] == NO)
    {
      return NO;
    }
  if ([components count] == 0)
    {
      NSLog(@"empty components sent");
      return NO;
    }
  /*
   * If the reserved length in the first data object is wrong - we have to
   * fail, unless it's zero, in which case we can insert a data object for
   * the header.
   */
  rl = [self reservedSpaceLength];
  if (length != 0 && length != rl)
    {
      NSLog(@"bad reserved length - %u", length);
      return NO;
    }
  if ([receivingPort isKindOfClass: tcpPortClass] == NO)
    {
      NSLog(@"woah there - receiving port is not the correct type");
      return NO;
    }

  h = [self handleForPort: (GSTcpPort*)receivingPort beforeDate: when];
  if (h != nil)
    {
      NSMutableData	*header;
      unsigned		hLength;
      unsigned		l;
      GSPortItemHeader	*pih;
      GSPortMsgHeader	*pmh;
      unsigned		c = [components count];
      unsigned		i;
      BOOL		pack = YES;

      /*
       * Ok - ensure we have space to insert header info.
       */
      if (length == 0 && rl != 0)
	{
	  header = [[mutableDataClass alloc] initWithCapacity: NETBLOCK];

	  [header setLength: rl];
	  [components insertObject: header atIndex: 0];
	  RELEASE(header);
	} 

      header = [components objectAtIndex: 0];
      /*
       * The Item header contains the item type and the length of the
       * data in the item (excluding the item header itsself).
       */
      hLength = [header length];
      l = hLength - sizeof(GSPortItemHeader);
      pih = (GSPortItemHeader*)[header mutableBytes];
      pih->type = GSSwapHostI32ToBig(GSP_HEAD);
      pih->length = GSSwapHostI32ToBig(l);

      /*
       * The message header contains the message Id and the original count
       * of components in the message (excluding any extra component added
       * simply to hold the header).
       */
      pmh = (GSPortMsgHeader*)&pih[1];
      pmh->mId = GSSwapHostI32ToBig(msgId);
      pmh->nItems = GSSwapHostI32ToBig(c);

      /*
       * Now insert item header information as required.
       * Pack as many items into the initial data object as possible, up to
       * a maximum of NETBLOCK bytes.  This is to try to get a single,
       * efficient write operation if possible.
       */
      for (i = 1; i < c; i++)
	{
	  id	o = [components objectAtIndex: i];

	  if ([o isKindOfClass: [NSData class]])
	    {
	      GSPortItemHeader	*pih;
	      unsigned		h = sizeof(GSPortItemHeader);
	      unsigned		l = [o length];
	      void		*b;

	      if (pack == YES && hLength + l + h <= NETBLOCK)
		{
		  [header setLength: hLength + l + h];
		  b = [header mutableBytes];
		  b += hLength;
#if NEED_WORD_ALIGNMENT
		  /*
		   * When packing data, an item may not be aligned on a
		   * word boundary, so we work with an aligned buffer
		   * and use memcmpy()
		   */
		  if ((*hLength % __alignof__(gsu32)) != 0)
		    {
		      GSPortItemHeader	itemHeader;

		      pih = (GSPortItemHeader*)&itemHeader;
		      pih->type = GSSwapHostI32ToBig(GSP_DATA);
		      pih->length = GSSwapHostI32ToBig(l);
		      memcpy(b, (void*)pih, h);
		    }
		  else
		    {
		      pih = (GSPortItemHeader*)b;
		      pih->type = GSSwapHostI32ToBig(GSP_DATA);
		      pih->length = GSSwapHostI32ToBig(l);
		    }
#else
		  pih = (GSPortItemHeader*)b;
		  pih->type = GSSwapHostI32ToBig(GSP_DATA);
		  pih->length = GSSwapHostI32ToBig(l);
#endif
		  memcpy(b+h, [o bytes], l);
		  [components removeObjectAtIndex: i--];
		  c--;
		  hLength += l + h;
		}
	      else
		{
		  NSMutableData	*d;

		  pack = NO;
		  d = [[NSMutableData alloc] initWithLength: l + h];
		  b = [d mutableBytes];
		  pih = (GSPortItemHeader*)b;
		  memcpy(b+h, [o bytes], l);
		  pih->type = GSSwapHostI32ToBig(GSP_DATA);
		  pih->length = GSSwapHostI32ToBig(l);
		  [components replaceObjectAtIndex: i
					withObject: d];
		  RELEASE(d);
		}
	    }
	  else if ([o isKindOfClass: tcpPortClass])
	    {
	      NSData	*d = newDataWithEncodedPort(o);
	      unsigned	dLength = [d length];

	      if (pack == YES && hLength + dLength <= NETBLOCK)
		{
		  void	*b;

		  [header setLength: hLength + dLength];
		  b = [header mutableBytes];
		  b += hLength;
		  hLength += dLength;
		  memcpy(b, [d bytes], dLength);
		  [components removeObjectAtIndex: i--];
		  c--;
		}
	      else
		{
		  pack = NO;
		  [components replaceObjectAtIndex: i withObject: d];
		}
	      RELEASE(d);
	    }
	}

      /*
       * Now send the message.
       */
      sent = [h sendMessage: components beforeDate: when];
    }
  return sent;
}

- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode
{
  return nil;
}

@end

