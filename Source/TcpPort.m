/* Implementation of network port object based on TCP sockets
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: February 1996
   
   This file is part of the GNU Objective C Class Library.

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

/* TODO:
   Make the sockets non-blocking. 
   */

#include <objects/stdobjects.h>
#include <objects/TcpPort.h>
#include <objects/Array.h>
#include <stdio.h>
#include <stdlib.h>

#ifndef WIN32
#include <sys/time.h>
#include <sys/resource.h>
#endif

#define debug_tcp_port 1

@interface TcpInPort (Private)
- (int) _socket;
- (void) _addOutPort: p;
- (void) _connectedOutPortInvalidated: p;
@end

@interface TcpOutPort (Private)
- (int) _socket;
- _initWithSocket: (int)s inPort: ip;
+ newWithAcceptedSocket: (int)s inPort: p;
@end

@interface TcpPacket (Private)
- (int) _fillFromSocket: (int)s;
- (void) _writeToSocket: (int)s;
+ (int) readPacketSizeFromSocket: (int)s;
- _initForReceivingWithSize: (int)s replyPort: p;
@end


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



/* Both TcpInPort's and TcpOutPort's are entered in this maptable. */

static NSMapTable *socket_2_port;
static void 
init_socket_2_port ()
{
  socket_2_port =
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
}



@implementation TcpInPort

static NSMapTable* port_number_2_port;

+ (void) initialize
{
  if (self == [TcpInPort class])
    port_number_2_port = 
      NSCreateMapTable (NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
  if (!socket_2_port)
    init_socket_2_port ();
}

/* this is the designated initializer. */
+ newForReceivingFromPortNumber: (unsigned short)n
{
  TcpInPort *p;
  int sock;

  if ((p = (id) NSMapGet (port_number_2_port, (void*)((int)n))))
    return p;

  /* Create the socket. */
  sock = socket (AF_INET, SOCK_STREAM, 0);
  if (sock < 0)
    {
      perror ("socket");
      abort ();
    }

  /* Create the port object. */
  p = [[TcpInPort alloc] init];
  p->_socket = sock;
  NSMapInsert (socket_2_port, (void*)sock, self);
  
  /* Give the socket a name. */
  p->_address.sin_family = AF_INET;
  p->_address.sin_addr.s_addr = htonl (INADDR_ANY);
  p->_address.sin_port = htons (n);
  if (bind (sock, (struct sockaddr*) &(p->_address), sizeof (p->_address)) < 0)
    {
      perror ("bind");
      abort ();
    }

  /* Set it up to accept connections, let 10 pending connections queue */
  if (listen (sock, 10) < 0)
    {
      perror ("listen");
      abort ();
    }

  /* Initialize the set of active sockets. */
  FD_ZERO (&(p->active_fd_set));
  FD_SET (sock, &(p->active_fd_set));

  /* Initializer the tables. */
  p->client_sock_2_out_port = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  p->client_sock_2_packet = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /* Record the new port in the table. */
  NSMapInsert (port_number_2_port, (void*)(int)n, p);

  return p;
}

+ newForReceivingFromRegisteredName: (id <String>)name
{
  return [self newForReceivingFromPortNumber: 
		 name_2_port_number ([name cStringNoCopy])];
}

+ newForReceiving
{
  return [self newForReceivingFromPortNumber: 0];
}

- (id <Collecting>) connectedOutPorts
{
  NSMapEnumerator me = NSEnumerateMapTable (client_sock_2_out_port);
  int count = NSCountMapTable (client_sock_2_out_port);
  int sock;
  id out_port;
  id out_ports[count];
  int i;
  for (i = 0; 
       NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port);
       i++)
    out_ports[i] = out_port;
  return [[[Array alloc] initWithObjects: out_ports count: count]
	   autorelease];
}

- receivePacketWithTimeout: (int)milliseconds
{
  static int fd_index = 0;
  fd_set read_fd_set;
  struct sockaddr_in clientname;
  struct timeval timeout;
  void *select_timeout;
  int sel_ret;

  /* If MILLISECONDS is less than 0, wait forever. */
  if (milliseconds >= 0)
    {
      timeout.tv_sec = milliseconds / 1000;
      timeout.tv_usec = (milliseconds % 1000) * 1000;
      select_timeout = &timeout;
    }
  else
    select_timeout = NULL;

  for (;;)
    {
      read_fd_set = active_fd_set;
      sel_ret = select (FD_SETSIZE, &read_fd_set, NULL, NULL, select_timeout);
      if (sel_ret < 0)
	{
	  perror ("select");
	  abort ();
	}
      else if (sel_ret == 0)
	return nil;

      for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
	if (FD_ISSET (fd_index, &read_fd_set))
	  {
	    if (fd_index == _socket)
	      {
		/* This is a connection request on the original socket. */
		int new;
		int size;

		size = sizeof (clientname);
		new = accept (_socket, (struct sockaddr*)&clientname, &size);
		if (new < 0)
		  {
		    perror ("accept");
		    abort ();
		  }
		if (debug_tcp_port)
		  fprintf (stderr, 
			   "Accepted connection from host %s, port %hd.\n",
			   inet_ntoa (clientname.sin_addr),
			   ntohs (clientname.sin_port));
		[self _addOutPort: [TcpOutPort newWithAcceptedSocket: new
				     inPort: self]];
	      }
	    else
	      {
		/* Data arriving on an already-connected socket. */
		TcpPacket *packet;
		int remaining;
		if (!(packet = NSMapGet (client_sock_2_packet,
					 (void*)fd_index)))
		  {
		    /* This is the beginning of a new packet on this socket.
		       Create a new Packet object for gathering the data. */

		    /* First, get the packet size, (which is encoded in 
		       the first few bytes of the stream). */
		    int packet_size = 
		      [TcpPacket readPacketSizeFromSocket: fd_index];
		    /* We got an EOF when trying to read the packet size;
		       invalidate the port, and keep on waiting for
		       incoming data on other sockets. */
		    if (packet_size == EOF)
		      {
			[(id) NSMapGet (client_sock_2_out_port,
					(void*)fd_index)
			      invalidate];
			continue;
		      }
		    else
		      {
			packet = [[TcpPacket alloc] 
				   _initForReceivingWithSize: packet_size
				   replyPort: 
				     NSMapGet (client_sock_2_out_port, 
					       (void*)fd_index)];
		      }
		    /* The packet has now been created with correct capacity */
		  }

		/* Suck bytes from the socket into the packet; find out
		   how many more bytes are needed before packet will be
		   complete. */
		remaining = [packet _fillFromSocket: (int)fd_index];
		if (remaining == EOF)
		  {
		    /* We got an EOF when trying to read packet data;
		       release the packet and invalidate the corresponding
		       port. */
		    [packet release];
		    [(id) NSMapGet (client_sock_2_out_port, (void*)fd_index)
			  invalidate];
		  }
		else if (remaining == 0)
		  /* No bytes are remaining to be read for this packet; 
		     the packet is complete; return it. */
		  return packet;
	      }
	  }
    }
  return nil;
}

- (void) _addOutPort: p
{
  int s = [p _socket];

  FD_SET (s, &active_fd_set);

  NSMapInsert (client_sock_2_out_port, (void*)s, p);
}

- (void) _connectedOutPortInvalidated: p
{
  id packet;
  int s = [p _socket];

  packet = NSMapGet (client_sock_2_packet, (void*)s);
  if (packet)
    {
      NSMapRemove (client_sock_2_packet, (void*)s);
      [packet release];
    }
  NSMapRemove (client_sock_2_out_port, (void*)s);
  FD_CLR(s, &active_fd_set);
}

- (int) _socket
{
  return _socket;
}

- (void) invalidate
{
  if (is_valid)
    {
      NSMapEnumerator me = NSEnumerateMapTable (client_sock_2_out_port);
      int count = NSCountMapTable (client_sock_2_out_port);
      id out_port;
      int sock;
      id out_ports[count];
      int i;
      for (i = 0; 
	   NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port);
	   i++)
	out_ports[i] = out_port;
      for (i = 0; i < count; i++)
	{
	  /* This will call [self _invalidateConnectedOutPort: for each. */
	  [out_ports[i] invalidate];
	}
      assert (!NSCountMapTable (client_sock_2_out_port));
      close (_socket);
      [super invalidate];
    }
}

- (void) dealloc
{
  [self invalidate];
  NSMapRemove (port_number_2_port, (void*)(int)ntohs(_address.sin_port));
  /* assert that these are empty? */
  NSFreeMapTable (client_sock_2_out_port);
  NSFreeMapTable (client_sock_2_packet);
  NSMapRemove (socket_2_port, (void*)_socket);
  [super dealloc];
}

- (void) checkConnection
{
  [self notImplemented: _cmd];
}

- classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (Class) packetClass
{
  return [TcpPacket class];
}

@end


@implementation TcpOutPort

+ (void) initialize
{
  if (self == [TcpOutPort class])
    {
      if (!socket_2_port)
	init_socket_2_port ();
    }
}

/* This is the designated initializer. */
- _initWithSocket: (int)s inPort: ip
{
  [super init];
  _socket = s;
  NSMapInsert (socket_2_port, (void*)s, self);
  connected_in_port = ip;
  return self;
}

+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (id <String>)hostname
{
  TcpOutPort *p;
  int s;

  /* xxx If the TcpOutPort object already exists, just return it. */
  /* This needs to be judged according to the port number and host;
     this is what will get sent when a TcpPort encodes itself. */

  /* There isn't one already; create the TcpOutPort. */

  /* Create the socket. */
  s = socket (AF_INET, SOCK_STREAM, 0);
  if (s < 0)
    {
      perror ("socket (client)");
      abort ();
    }

  /* Create a port object. */
  p = [[self alloc] _initWithSocket: s inPort: nil];

  /* Initialize the address. */
  {
    struct hostent *hostinfo;
    p->_address.sin_family = AF_INET;
    p->_address.sin_port = htons (n);
    hostinfo = gethostbyname ([hostname cStringNoCopy]);
    if (hostinfo == NULL)
    {
      fprintf (stderr, "Unknown host %s.\n", hostname);
      abort ();
    }
    p->_address.sin_addr = *(struct in_addr *) hostinfo->h_addr;
  }

  /* Connect to destination. */
  if (connect (s, (struct sockaddr*)&(p->_address), sizeof(p->_address)) < 0)
    {
      perror ("connect (client)");
      abort ();
    }

  return p;
}

+ newForSendingToRegisteredName: (id <String>)name 
			 onHost: (id <String>)hostname
{
  return [self newForSendingToPortNumber: 
		 name_2_port_number ([name cStringNoCopy])
	       onHost: hostname];;
}

+ newWithAcceptedSocket: (int)s inPort: p
{
  return [[self alloc] _initWithSocket: s inPort: p];
}

- (int) writeBytes: (const char*)b length: (int)len
{
  return write (_socket, b, len);
}

- (BOOL) sendPacket: packet withTimeout: (int)milliseconds
{
  int c, l;
  id reply_port = [packet replyPort];

  if (connected_in_port == nil && reply_port != nil)
    {
      connected_in_port = reply_port;
      [connected_in_port retain];
      [connected_in_port _addOutPort: self];
      /* xxx Register socket with the replyPort. */
    }
  else if (connected_in_port != reply_port)
    [self error:"TcpPort can't change reply port of an out port once set."];

  [packet _writeToSocket: _socket];
  return YES;
}

- (int) _socket
{
  return _socket;
}

- (void) close
{
  [self invalidate];
}

- (void) invalidate
{
  if (is_valid)
    {
      if (close (_socket) < 0)
	perror ("close, -invalidate");
      [connected_in_port _connectedOutPortInvalidated: self];
      [connected_in_port release];
      connected_in_port = nil;
      [super invalidate];
    }
}

- (void) dealloc
{
  if (is_valid)
    [self invalidate];
  NSMapRemove (socket_2_port, (void*)_socket);
}

- classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (Class) packetClass
{
  return [TcpPacket class];
}

@end



@implementation TcpPacket

/* If you change this, you must change the use of ntohs() and htons() below. */
#define PREFIX_TYPE unsigned short
#define PREFIX_LENGTH sizeof (PREFIX_TYPE)

/* This is the designated initialzer. */
/* xxx This will change; it doesn't set it's buffer size with a nice 
   interface */
- _initForReceivingWithSize: (int)s replyPort: p
{
  [super _initOnMallocBuffer: (*objc_malloc) (s)
	 size: s
	 eofPosition: 0
	 prefix: PREFIX_LENGTH
	 position: 0];
  assert (p);
  reply_port = p;
  return self;
}

- initForSendingWithCapacity: (unsigned)c
   replyPort: p
{
  [super _initOnMallocBuffer: (*objc_malloc)(c)
	 size: c
	 eofPosition: 0
	 prefix: PREFIX_LENGTH
	 position: 0];
  reply_port = p;
  return self;
}

- (void) _writeToSocket: (int)s
{
  int write_len = eofPosition + 1;
  int c, len = write_len - sizeof (unsigned short);

  /* Put the packet size in the first two bytes of the packet. 
     We use `-sizeof()'  because the size does not include this
     length-indicating prefix. */
  assert (prefix == PREFIX_LENGTH);
  *(PREFIX_TYPE*)buffer = htons (len);

  /* Write the packet on the socket. */
  c = write (s, buffer, write_len);
  if (c < 0)
    {
      perror ("write");
      abort ();
    }

  /* Did we sucessfully write it all? */
  if (c != write_len)
    [self error: "socket write failed"];
}

+ (int) readPacketSizeFromSocket: (int)s
{
  char size_buffer[PREFIX_LENGTH];
  int c;
  int packet_size;
  
  c = read (s, size_buffer, PREFIX_LENGTH);
  if (c == 0)
    return EOF;
  if (c != PREFIX_LENGTH)
    [self error: "Failed to get packet size from socket."];

  /* packet_size is the number of bytes in the packet, not including 
     this two-byte length header. */
  packet_size = ntohs (*(PREFIX_TYPE*) size_buffer);
  assert (packet_size);
  return packet_size;
}

- (int) _fillFromSocket: (int)s
{
  int c;
  int remaining;

  remaining = size - position;
  c = read (s, buffer + position, remaining);
  if (c == 0)
    return EOF;
  position += c;
  eofPosition = position;
  return remaining - c;
}

@end

