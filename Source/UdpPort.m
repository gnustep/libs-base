/* Implementation of UDP port object for use with Connection
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

/* xxx I should also look into SOCK_RDM and SOCK_SEQPACKET. */

#include <config.h>
#include <base/UdpPort.h>
#include <base/Coder.h>
#include <base/ConnectedCoder.h>
#include <base/Array.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHost.h>

#if _AIX
#include <sys/select.h>
#endif /* _AIX */

#ifdef __WIN32__
#include <winsock.h>
#else 
#include <unistd.h>
#include <netdb.h>
#include <time.h>
#include <sys/time.h>
#endif /* !__WIN32__ */

/* For IRIX machines, which don't define this */
#ifndef        IPPORT_USERRESERVED
#define        IPPORT_USERRESERVED     5000
#endif /* IPPORT_USERRESERVED */

@interface UdpInPort (Private)
@end
@interface UdpOutPort (Private)
+ newForSendingToSockaddr: (struct sockaddr_in*)addr;
@end
@interface UdpInPacket (Private)
- (void) _setReplyPort: p;
@end

/* The maximum size of packet UdpPort's will send or recieve. */
/* xxx What is the UDP maximum? */
#define MAX_PACKET_SIZE 2048

/* Make this a hashtable? */
static NSLock* udp_port_gate = nil;

static BOOL udp_port_debug = NO;


/* Our current, sad excuse for a name server. */

static unsigned short
name_2_port_number (const char *name)
{
  unsigned int ret = 0;
  unsigned int ctr = 0;
        
  while (*name) 
    {
      ret ^= *name++ << ctr;
      ctr = (ctr + 1) % sizeof (void *);
    }
  return (ret % (65535 - IPPORT_USERRESERVED - 1)) + IPPORT_USERRESERVED;
  /* return strlen (name) + IPPORT_USERRESERVED; */
}

@implementation UdpInPort 

static NSMapTable *port_number_2_in_port = NULL;

+ (void) initialize
{
  if (self == [UdpInPort class])
    {
      port_number_2_in_port = 
	NSCreateMapTable (NSIntMapKeyCallBacks,
			  NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

/* This is the designated initializer.
   If N is zero, it will choose a port number for you. */

+ newForReceivingFromPortNumber: (unsigned short)n 
{
  UdpInPort* p;

  NSAssert(n > IPPORT_USERRESERVED, NSInvalidArgumentException);

  [udp_port_gate lock];

  /* See if there is already one created */
  if ((p = NSMapGet (port_number_2_in_port, (void*)(int)n)))
    return p;

  /* No, create a new port object */
  p = [[self alloc] init];

  /* Make a new socket for the port object */
  if ((p->_port_socket = socket (AF_INET, SOCK_DGRAM, 0)) < 0)
    {
      perror("[UdpInPort +newForReceivingFromPortNumber:] socket()");
      abort ();
    }

  /* Give the socket a name using bind */
  {
    struct hostent *hp;

    hp = gethostbyname ([[[NSHost currentHost] name] cString]);
    if (!hp)
      /* xxx This won't work with port connections on a network, though.
         Fix this.  Perhaps there is a better way of getting the address
	 of the local host. */
      hp = gethostbyname ("localhost");
    NSAssert(hp, NSInternalInconsistencyException);
    /* Use host's address, and not INADDR_ANY, so that went we
       encode our _address for a D.O. operation, they get
       our unique host address that can identify us across the network. */
    memcpy (&(p->_address.sin_addr), hp->h_addr, hp->h_length);
    p->_address.sin_family = AF_INET;
    p->_address.sin_port = htons (n);
    /* N may be zero, in which case bind() will choose a port number
       for us. */
    if (bind (p->_port_socket,
	      (struct sockaddr*) &(p->_address),
	      sizeof (p->_address)) 
	< 0)
      {
	perror ("[UdpInPort +newForReceivingFromPortNumber] bind()");
	abort ();
      }
  }

  /* If the caller didn't specify a port number, it was chosen for us.
     Here, find out what number was chosen. */
  if (!n)
    /* xxx Perhaps I should do this unconditionally? */
    {
      int size = sizeof (p->_address);
      if (getsockname (p->_port_socket,
		       (struct sockaddr*)&(p->_address),
		       &size)
	  < 0)
	{
	  perror ("[UdpInPort +newForReceivingFromPortNumber] getsockname()");
	  abort ();
	}
      NSAssert(p->_address.sin_port, NSInternalInconsistencyException);
    }

  /* Record it in UdpInPort's map table. */
  NSMapInsert (port_number_2_in_port, (void*)(int)n, p);
  [udp_port_gate unlock];

  if (udp_port_debug)
    fprintf(stderr, "created new UdpInPort 0x%x, fd=%d port_number=%d\n",
	   (unsigned)p, p->_port_socket, htons(p->_address.sin_port));

  return p;
}

+ newForReceivingFromRegisteredName: (NSString*)name
{
  int n;

  n = name_2_port_number ([name cString]);
  return [self newForReceivingFromPortNumber: n];
}

/* Usually, you would run the run loop to get packets, but if you
   want to wait for one directly from a port, you can use this method. */
- newPacketReceivedBeforeDate: date
{
  return nil;
}


/* Returns nil on timeout.
   Pass -1 for milliseconds to ignore timeout parameter and block indefinitely.
*/

- receivePacketWithTimeout: (int)milliseconds
{
  int r;
  struct sockaddr_in remote_addr;
  int remote_len;
  UdpInPacket *packet;

  if (udp_port_debug)
    fprintf(stderr, "receiving from %d\n", [self portNumber]);

  if (milliseconds >= 0)
    {
      /* A timeout was requested; use select to ask if something is ready. */
      struct timeval timeout;
      fd_set ready;

      timeout.tv_sec = milliseconds / 1000;
      timeout.tv_usec = (milliseconds % 1000) * 1000;
      memset(&ready, '\0', sizeof(ready));
      FD_SET(_port_socket, &ready);
      if ((r = select(_port_socket + 1, &ready, 0, 0, &timeout)) < 0)
	{
	  perror("select");
	  abort ();
	}

      if (r == 0)		/* timeout */
	return nil;
      if (!FD_ISSET(_port_socket, &ready))
	[self error:"select lied"];
    }

  /* There is a packet on the socket ready for us to receive. */

  /* Create a packet. */
  packet = [[UdpInPacket alloc] initWithCapacity: MAX_PACKET_SIZE];

  /* Fill it with the UDP packet data. */
  remote_len = sizeof(remote_addr);
  if (recvfrom (_port_socket, [packet streamBuffer], MAX_PACKET_SIZE, 0,
		(struct sockaddr*)&remote_addr, &remote_len)
      < 0)
    {
      perror("recvfrom");
      abort ();
    }

  /* Set the packet's reply_port. */
  if (remote_len != sizeof(struct sockaddr_in))
    [self error:"remote address size mismatch"];
  [packet _setReplyPort: [[self class] newForSendingToSockaddr: &remote_addr]];
  
  return packet;
}

- (void) invalidate
{
  if (_is_valid)
    {
      close (_port_socket);
      [super invalidate];
    }
}

- (void) dealloc
{
  [self invalidate];
  [super dealloc];
}

- (int) socket
{
  return _port_socket;
}

- (int) portNumber
{
  return (int) ntohs (_address.sin_port);
}

- (Class) packetClass
{
  return [UdpInPacket class];
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy, not a Proxy class.
     Also, don't encode a "receive right" (ala Mach), encode a "send right". */
  return [UdpOutPort class];
}

- (Class) classForPortCoder
{
  return [UdpOutPort class];
}
- replacementObjectForPortCoder: aRmc
{
  return self;
}

- (void) encodeWithCoder: aCoder
{
  /* We are actually encoding a "send right" (ala Mach), 
     not a receive right.
     These values must match those expected by [TcpOutPort +newWithCoder] */
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfCType: @encode(typeof(_address.sin_port))
	  at: &_address.sin_port 
	  withName: @"socket number"];
  [aCoder encodeValueOfCType: @encode(typeof(_address.sin_addr.s_addr))
	  at: &_address.sin_addr.s_addr
	  withName: @"inet address"];
}

+ newWithCoder: aCoder
{
  /* An InPort cannot be created by decoding, only OutPort's. */
  [self shouldNotImplement: _cmd];
  return nil;
}

+ (void) setDebug: (BOOL)f
{
  udp_port_debug = f;
}

@end



@implementation UdpOutPort

static Array *udp_out_port_array;

+ (void) initialize
{
  if (self == [UdpOutPort class])
    {
      udp_out_port_array = [Array new];
    }
}

#define SOCKADDR_EQUAL(s1,s2) ((s1)->sin_port == (s2)->sin_port && (s1)->sin_addr.s_addr == (s2)->sin_addr.s_addr) 
/* xxx Change to make INADDR_ANY and the localhost address be equal. */
/* Assume that sin_family is equal */
/* (!memcmp(s1, s2, sizeof(struct sockaddr_in))) 
   didn't work because sin_zero's differ.  Does this matter? */


/* This is the designated initializer. */

+ newForSendingToSockaddr: (struct sockaddr_in*)sockaddr
{
  UdpOutPort *p;

  /* See if there already exists a port for this sockaddr;
     if so, just return it. */
  FOR_ARRAY (udp_out_port_array, p)
    {
      /* xxx Come up with a way to do this with a hashtable, not a list. */
      if (SOCKADDR_EQUAL (sockaddr, &(p->_address)))
	return p;
    }
  END_FOR_ARRAY (udp_out_port_array);

  /* Create a new port. */
  p = [[self alloc] init];

  /* Set the address. */
  memcpy (&(p->_address), sockaddr, sizeof(p->_address));

  /* Remember it in the array. */
  /* xxx This will retain it; how will it ever get dealloc'ed? */
  [udp_out_port_array addObject: p];

  return p;
}


+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (NSString*)hostname
{
  struct hostent *hp;
  const char *host_cstring;
  struct sockaddr_in addr;

  /* Look up the hostname. */
  if (!hostname || ![hostname length])
    host_cstring = "localhost";
  else
    host_cstring = [hostname cString];
  hp = gethostbyname ((char*)host_cstring);
  if (hp == 0)
    [self error: "unknown host: \"%s\"", host_cstring];

  /* Get the sockaddr_in address. */
  memcpy (&addr.sin_addr, hp->h_addr, hp->h_length);
  addr.sin_family = AF_INET;
  addr.sin_port = htons (n);

  return [self newForSendingToSockaddr: &addr];
}


/* This currently ignores the timeout parameter */

- (BOOL) sendPacket: packet timeout: (NSTimeInterval)seconds
{
  id reply_port = [packet replyPort];
  int len = [packet streamEofPosition];

  NSAssert(len < MAX_PACKET_SIZE, NSInternalInconsistencyException);

  if ( ! [reply_port isKindOfClass: [UdpInPort class]])
    [self error:"Trying to send to a port that is not a UdpInPort"];
  if (udp_port_debug)
    fprintf (stderr, "sending to %d\n", (int) ntohs (_address.sin_port));
  if (sendto ([reply_port socket],
	      [packet streamBuffer], len, 0,
	      (struct sockaddr*)&_address, sizeof (_address)) 
      < 0)
    {
      perror ("sendto");
      abort ();
    }
  return YES;
}

- (int) portNumber
{
  return (int) ntohs (_address.sin_port);
}

- (NSString*) hostname
{
  [self notImplemented: _cmd];
  return nil;
}

- (Class) packetClass
{
  return [UdpInPacket class];
}

- (void) encodeWithCoder: aCoder
{
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfCType: @encode(typeof(_address.sin_port))
	  at: &_address.sin_port 
	  withName: @"socket number"];
  [aCoder encodeValueOfCType: @encode(typeof(_address.sin_addr.s_addr))
	  at: &_address.sin_addr.s_addr
	  withName: @"inet address"];
}

+ newWithCoder: aCoder
{
  struct sockaddr_in addr;

  addr.sin_family = AF_INET;
  [aCoder decodeValueOfCType: @encode(typeof(addr.sin_port))
	  at: &addr.sin_port 
	  withName: NULL];
  [aCoder decodeValueOfCType: @encode(typeof(addr.sin_addr.s_addr))
	  at: &addr.sin_addr.s_addr
	  withName: NULL];
  return [UdpOutPort newForSendingToSockaddr: &addr];
}

@end



@implementation UdpInPacket

- (void) _setReplyPort: p
{
  [self notImplemented: _cmd];
}

@end
