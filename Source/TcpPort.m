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

/* A strange attempt to make SOCK_STREAM sockets look like ports.  The
   two concepts don't fit together easily.  Be prepared for a little
   weirdness. */

/* TODO:
   Make the sockets non-blocking. 
   Change so we don't wait on incoming packet prefix.
   All the abort()'s should be Exceptions.
   */

#include <objects/stdobjects.h>
#include <objects/TcpPort.h>
#include <objects/Array.h>
#include <objects/Notification.h>
#include <objects/RunLoop.h>
#include <objects/Invocation.h>
#include <Foundation/NSDate.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>		/* for gethostname() */
#include <sys/param.h>		/* for MAXHOSTNAMELEN */

#ifndef WIN32
#include <sys/time.h>
#include <sys/resource.h>
#endif

static int debug_tcp_port = 0;


/* Private interfaces */

@interface TcpInPort (Private)
- (int) _socket;
- (struct sockaddr_in*) _listeningSockaddr;
- (void) _addClientOutPort: p;
- (void) _connectedOutPortInvalidated: p;
- _tryToGetPacketFromReadableFD: (int)fd_index;
@end

@interface TcpOutPort (Private)
- (int) _socket;
- _initWithSocket: (int)s inPort: ip;
+ _newWithAcceptedSocket: (int)s peeraddr: (struct sockaddr_in*)addr inPort: p;
- (struct sockaddr_in*) _remoteInPortSockaddr;
@end

@interface TcpPacket (Private)
- (int) _fillFromSocket: (int)s;
- (void) _writeToSocket: (int)s 
      withReplySockaddr: (struct sockaddr_in*)addr;
+ (void) _getPacketSize: (int*)size
	   andReplyPort: (id*)rp
             fromSocket: (int)s
	         inPort: ip;
- _initForReceivingWithSize: (int)s replyPort: p;
@end

#if 0
/* Not currently being used; but see the comment in -sendPacket:withTimeout: */

/* TcpInStream - an object that represents an accept()'ed socket
   that's being polled by a TcpInPort's select().  This object cannot
   be the same as a TcpOutPort because we cannot be sure that someone
   is polling the socket on the other end---unfortunately this means
   that the socket's used by Tcp*Port objects are only used for sending
   data in one direction. */

@interface TcpInStream : NSObject
{
  int _socket;
  id _listening_in_port;
}
- initWithAcceptedSocket: (int)s inPort: p;
@end
#endif /* 0 */



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

static NSMapTable *socket_2_port = NULL;

static void 
init_socket_2_port ()
{
  if (!socket_2_port)
    socket_2_port =
      NSCreateMapTable (NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
}



/* TcpInPort class - An object that represents a listen()'ing socket,
   and a collection of socket's which we poll using select().  Each of
   the socket's that we poll is actually held by a TcpOutPort object.
   See the comments by TcpOutPort below. */

@implementation TcpInPort

/* This map table is used to make sure we don't create more than one
   TcpInPort listening to the same port number. */
static NSMapTable* port_number_2_port;

+ (void) initialize
{
  if (self == [TcpInPort class])
    port_number_2_port = 
      NSCreateMapTable (NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
  init_socket_2_port ();
}

/* This is the designated initializer. 
   If N is zero, it will choose a port number for you. */

+ newForReceivingFromPortNumber: (unsigned short)n
{
  TcpInPort *p;

  /* If there already is a TcpInPort listening to this port number,
     don't create a new one, just return the old one. */
  if ((p = (id) NSMapGet (port_number_2_port, (void*)((int)n))))
    {
      assert (p->is_valid);
      return p;
    }

  /* There isn't already a TcpInPort for this port number, so create
     a new one. */

  /* Create the port object. */
  p = [[TcpInPort alloc] init];

  /* Create the socket. */
  p->_socket = socket (AF_INET, SOCK_STREAM, 0);
  if (p->_socket < 0)
    {
      perror ("[TcpInPort +newForReceivingFromPortNumber:] socket()");
      abort ();
    }

  /* Register the port object according to its socket. */
  assert (!NSMapGet (socket_2_port, (void*)p->_socket));
  NSMapInsert (socket_2_port, (void*)p->_socket, p);
  
  /* Give the socket a name using bind(). */
  {
    struct hostent *hp;
    char hostname[MAXHOSTNAMELEN];
    int len = MAXHOSTNAMELEN;
    if (gethostname (hostname, len) < 0)
      {
	perror ("[TcpInPort +newForReceivingFromPortNumber:] gethostname()");
	abort ();
      }
    hp = gethostbyname (hostname);
    if (!hp)
      /* xxx This won't work with port connections on a network, though.
         Fix this.  Perhaps there is a better way of getting the address
	 of the local host. */
      hp = gethostbyname ("localhost");
    assert (hp);
    /* Use host's address, and not INADDR_ANY, so that went we
       encode our _listening_address for a D.O. operation, they get
       our unique host address that can identify us across the network. */
    memcpy (&(p->_listening_address.sin_addr), hp->h_addr, hp->h_length);
    p->_listening_address.sin_family = AF_INET;
    p->_listening_address.sin_port = htons (n);
    /* N may be zero, in which case bind() will choose a port number
       for us. */
    if (bind (p->_socket,
	      (struct sockaddr*) &(p->_listening_address),
	      sizeof (p->_listening_address)) 
	< 0)
      {
	perror ("[TcpInPort +newForReceivingFromPortNumber] bind()");
	abort ();
      }
  }

  if (!n)
    /* xxx Perhaps I should do this unconditionally? */
    {
      int size = sizeof (p->_listening_address);
      if (getsockname (p->_socket,
		       (struct sockaddr*)&(p->_listening_address),
		       &size)
	  < 0)
	{
	  perror ("[TcpInPort +newForReceivingFromPortNumber] getsockname()");
	  abort ();
	}
      assert (p->_listening_address.sin_port);
    }

  /* Set it up to accept connections, let 10 pending connections queue */
  /* xxx Make this "10" a class variable? */
  if (listen (p->_socket, 10) < 0)
    {
      perror ("[TcpInPort +newForReceivingFromPortNumber] listen()");
      abort ();
    }

  /* Initialize the set of active sockets. */
  FD_ZERO (&(p->active_fd_set));
  FD_SET (p->_socket, &(p->active_fd_set));

  /* Initialize the tables for matching socket's to out ports and packets. */
  p->client_sock_2_out_port = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);
  p->client_sock_2_packet = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /* Record the new port in TcpInPort's class table. */
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

- (unsigned) numberOfConnectedOutPorts
{
  return NSCountMapTable (client_sock_2_out_port);
}

- (struct sockaddr_in*) _listeningSockaddr
{
  assert (is_valid);
  return &_listening_address;
}

- receivePacketWithTimeout: (int)milliseconds
{
  id saved_packet_invocation = _packet_invocation;
  id packet = nil;
  id handle_packet (id p)
    {
      packet = p;
      return nil;
    }
  id _packet_invocation = [[ObjectFunctionInvocation alloc]
			    initWithObjectFunction: handle_packet];
  id date = [NSDate dateWithTimeIntervalSinceNow: milliseconds / 1000.0];

  if (!_run_loop)
    [self addToRunLoop: [RunLoop defaultInstance]
	  forMode: nil];
  while ([[RunLoop defaultInstance] runMode: nil
				    beforeDate: date]
	 && !packet)
    return packet;
}


/* The use of this method is deprecated. */
- old_receivePacketWithTimeout: (int)milliseconds
{
  static int fd_index = 0;
  fd_set read_fd_set;
  struct timeval timeout;
  void *select_timeout;
  int sel_ret;

  assert (is_valid);

  for (;;)
    {
      /* Set the file descriptors select() will wait on. */
      read_fd_set = active_fd_set;

      /* Set the amount of time to wait. */
      /* Linux select() modifies *select_timeout to reflect the
	 amount of time not slept, so we have to re-initialize it 
	 each time. */
      /* If MILLISECONDS is less than 0, wait forever. */
      if (milliseconds >= 0)
	{
	  timeout.tv_sec = milliseconds / 1000;
	  timeout.tv_usec = (milliseconds % 1000) * 1000;
	  select_timeout = &timeout;
	}
      else
	select_timeout = NULL;

      /* Wait for incoming data. */
      sel_ret = select (FD_SETSIZE, &read_fd_set, NULL, NULL, select_timeout);

      if (sel_ret < 0)
	{
	  perror ("[TcpInPort receivePacketWithTimeout:] select()");
	  abort ();
	}
      else if (sel_ret == 0)
	return nil;

      for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
	if (FD_ISSET (fd_index, &read_fd_set))
	  {
	    id packet = [self _tryToGetPacketFromReadableFD: fd_index];
	    if (packet)
	      return packet;
	  }
    }
}

/* Sneaky, sneaky!  We use ourselves as the invocation object
   and then implement the -invokeWithObject: method to handle the
   FileDescriptor argument that the RunLoop will pass. 
   This strategy is not necessarily condoned; in fact, in the future,
   I may change this code to no longer do this. */
- (void) invokeWithObject: file_desc
{
  int fd = [file_desc intValue];
  id packet = [self _tryToGetPacketFromReadableFD: fd];
  if (packet)
    [_packet_invocation invokeWithObject: packet];
}

- _tryToGetPacketFromReadableFD: (int)fd_index
{
  if (fd_index == _socket)
    {
      /* This is a connection request on the original socket. */
      int new;
      int size;
      volatile id op;
      struct sockaddr_in clientname;

      size = sizeof (clientname);
      new = accept (_socket, (struct sockaddr*)&clientname, &size);
      if (new < 0)
	{
	  perror ("[TcpInPort receivePacketWithTimeout:] accept()");
	  abort ();
	}
      op = [TcpOutPort _newWithAcceptedSocket: new 
		       peeraddr: &clientname
		       inPort: self];
      [self _addClientOutPort: op];
      if (debug_tcp_port)
	fprintf (stderr, 
		 "%s: Accepted connection from\n %s.\n",
		 object_get_class_name (self),
		 [[op description] cStringNoCopy]);
      [NotificationDispatcher
	postNotificationName: InPortAcceptedClientNotification
	object: self
	userInfo: op];
    }
  else
    {
      /* Data has arrived on an already-connected socket. */
      TcpPacket *packet;
      int remaining;

      /* See if there is already a Packet object waiting for
	 more data from this socket. */
      if (!(packet = NSMapGet (client_sock_2_packet,
			       (void*)fd_index)))
	{
	  /* This is the beginning of a new packet on this socket.
	     Create a new Packet object for gathering the data. */

	  /* First, get the packet size and reply port, (which is
	     encoded in the first few bytes of the stream). */
	  int packet_size;
	  id reply_port;
	  [TcpPacket _getPacketSize: &packet_size
		     andReplyPort: &reply_port
		     fromSocket: fd_index
		     inPort: self];
	  /* If we got an EOF when trying to read the packet prefix,
	     invalidate the port, and keep on waiting for incoming
	     data on other sockets. */
	  if (packet_size == EOF)
	    {
	      [(id) NSMapGet (client_sock_2_out_port,
			      (void*)fd_index)
		    invalidate];
	      return nil;
	    }
	  else
	    {
	      packet = [[TcpPacket alloc] 
			 _initForReceivingWithSize: packet_size
			 replyPort: reply_port];
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
	     port, and keep on waiting for incoming data on
	     other sockets. */
	  [packet release];
	  [(id) NSMapGet (client_sock_2_out_port, (void*)fd_index)
		invalidate];
	  return nil;
	}
      else if (remaining == 0)
	{
	  /* No bytes are remaining to be read for this packet; 
	     the packet is complete; return it. */
	  assert (packet && [packet class]);
	  return packet;
	}
    }
  return nil;
}


/* Dealing with the relationship to our monitoring _run_loop. */

/* Sneaky, sneaky!  We use ourselves as the invocation object
   and then implement the -invokeWithObject: method to handle the
   FileDescriptor argument that the RunLoop will pass. 
   This strategy is not necessarily condoned; in fact, in the future,
   I may change this code to no longer do this. */

- (void) _addClientOutPort: p toRunLoop: rl forMode: (id <String>)mode
{
  [rl addFileDescriptor: [p _socket]
      invocation: self
      forMode: mode];
}

- (void) addToRunLoop: rl forMode: (id <String>)mode
{
  NSMapEnumerator me;
  int sock;
  id out_port;
  
  /* Yipes.  How do we handle being added to multiple RunLoops/modes? */
  assert (!_run_loop);
  _run_loop = rl;
  _run_loop_mode = mode;
  [rl addFileDescriptor: _socket invocation: self forMode: mode];
  me = NSEnumerateMapTable (client_sock_2_out_port);
  while (NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port))
    [self _addClientOutPort: out_port toRunLoop: rl forMode: mode];
}

- (void) _removeClientOutPort: p
		  fromRunLoop: rl
		      forMode: (id <String>)mode
{
  [rl removeFileDescriptor: [p _socket] 
      forMode: mode];
}

- (void) removeFromRunLoop: rl forMode: (id <String>)mode
{
  NSMapEnumerator me;
  int sock;
  id out_port;

  [rl removeFileDescriptor: _socket forMode: mode];
  me = NSEnumerateMapTable (client_sock_2_out_port);
  while (NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)out_port))
    [self _removeClientOutPort: out_port fromRunLoop: rl forMode: mode];
  _run_loop = nil;
}


/* Add and removing out port's from the collection of connections we handle. */

- (void) _addClientOutPort: p
{
  int s = [p _socket];

  assert (is_valid);
  /* Make sure it hasn't already been added. */
  assert (!NSMapGet (client_sock_2_out_port, (void*)s));

 /* Add it, and put its socket in the set of file descriptors we poll. */
  NSMapInsert (client_sock_2_out_port, (void*)s, p);
  FD_SET (s, &active_fd_set);

  [self _addClientOutPort: p toRunLoop: _run_loop forMode: _run_loop_mode];
}

/* Called by an OutPort in its -invalidate method. */
- (void) _connectedOutPortInvalidated: p
{
  id packet;
  int s = [p _socket];

  assert (is_valid);
  if (debug_tcp_port)
    fprintf (stderr, 
	     "%s: Closed connection from\n %s\n",
	     object_get_class_name (self),
	     [[p description] cStringNoCopy]);

  packet = NSMapGet (client_sock_2_packet, (void*)s);
  if (packet)
    {
      NSMapRemove (client_sock_2_packet, (void*)s);
      [packet release];
    }
  NSMapRemove (client_sock_2_out_port, (void*)s);
  FD_CLR(s, &active_fd_set);

  [self _removeClientOutPort: p 
	fromRunLoop: _run_loop 
	forMode: _run_loop_mode];

  /* xxx Should this be earlier, so that the notification recievers
     can still use client_sock_2_out_port before the out port P is removed? */
  [NotificationDispatcher
    postNotificationName: InPortClientBecameInvalidNotification
    object: self
    userInfo: p];
}

- (int) _socket
{
  return _socket;
}

- (int) portNumber
{
  return (int) ntohs (_listening_address.sin_port);
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

      /* xxx Perhaps should delay this close() to keep another port from
	 getting it.  This may help Connection invalidation confusion. */
      close (_socket);

      /* These are here, and not in -dealloc, to prevent 
	 +newForReceivingFromPortNumber from returning invalid sockets. */
      NSMapRemove (socket_2_port, (void*)_socket);
      NSMapRemove (port_number_2_port,
		   (void*)(int) ntohs(_listening_address.sin_port));

      /* This also posts a PortBecameInvalidNotification. */
      [super invalidate];
    }
}

- (void) dealloc
{
  [self invalidate];
  /* assert that these are empty? */
  NSFreeMapTable (client_sock_2_out_port);
  NSFreeMapTable (client_sock_2_packet);
  [super dealloc];
}

- (void) checkConnection
{
  [self notImplemented: _cmd];
}

- (Class) packetClass
{
  return [TcpPacket class];
}

+ (Class) packetClass
{
  return [TcpPacket class];
}

- description
{
  return [NSString
	   stringWithFormat: @"%s%c0x%x port %hd socket %d",
	   object_get_class_name (self),
	   is_valid ? ' ' : '-',
	   (unsigned)self,
	   ntohs (_listening_address.sin_port),
	   _socket];
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy, not a Proxy class.
     Also, encode a "send right" (ala Mach), not the "receive right". */
  return [TcpOutPort class];
}

- (void) encodeWithCoder: aCoder
{
  assert (is_valid);
  /* We are actually encoding a "send right" (ala Mach), 
     not a receive right.  
     These values must match those expected by [TcpOutPort +newWithCoder] */
  [super encodeWithCoder: aCoder];
  [aCoder encodeValueOfCType: @encode(typeof(_listening_address.sin_port))
	  at: &_listening_address.sin_port 
	  withName: @"socket number"];
  [aCoder encodeValueOfCType:
	    @encode(typeof(_listening_address.sin_addr.s_addr))
	  at: &_listening_address.sin_addr.s_addr
	  withName: @"inet address"];
}

+ newWithCoder: aCoder
{
  /* An InPort cannot be created by decoding, only OutPort's. */
  [self shouldNotImplement: _cmd];
  return nil;
}

@end



/* TcpOutPort - An object that represents a connection to a remote
   host.  Although it is officially an "Out" Port, we actually receive
   data on the socket that is this object's `_socket' ivar; TcpInPort
   takes care of this. */

@implementation TcpOutPort

/* A collection of all the all the TcpOutPort's, keyed by their id. */
/* xxx This would be more efficient as a void* array instead of a map table. */
static NSMapTable *out_port_bag = NULL;

+ (void) initialize
{
  if (self == [TcpOutPort class])
    {
      init_socket_2_port ();
      out_port_bag = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
				       NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

#if 0
/* Not needed unless we use TcpInStream objects. */
+ (void) checkForInvalidatedPorts {}
#endif


/* This is the designated creator. 

   If SOCK is 0, then SOCKADDR must be non-NULL.  It is the address of
   the socket on which the remote TcpInPort is listen()'ing.  Note
   that it is *not* the address of the TcpOutPort's
   getsockname(_socket,...), and it is not the address of the
   TcpOutPort's getpeername(_socket,...).

   SOCK can be either an already-created socket, or 0, in which case a 
   socket will be created.

   If SOCK is non-zero, and SOCKADDR is non-zero, then this is a request
   to set the _remote_in_port_address ivar of a pre-existing TcpOutPort
   instance.  In this case the IP argument must match the _polling_in_port
   of the instance.

   IP can be either an already-created InPort object, or nil.  */

+ newForSendingToSockaddr: (struct sockaddr_in*)sockaddr 
       withAcceptedSocket: (int)sock
            pollingInPort: ip
{
  TcpOutPort *p;

  /* See if there already exists a port for this sockaddr;
     if so, just return it.  However, there is no need to do this
     if SOCK already holds an accept()'ed socket---in that case we
     should always create a new OutPort object. */
  if (!sock)
    {
      NSMapEnumerator me = NSEnumerateMapTable (out_port_bag);
      void *k;

      assert (sockaddr);
      while (NSNextMapEnumeratorPair (&me, &k, (void**)&p))
	{
	  /* xxx Do I need to make sure connectedInPort is the same too? */
	  /* xxx Come up with a way to do this with a hash key, not a list. */
	  if ((sockaddr->sin_port
	       == p->_remote_in_port_address.sin_port)
	      && (sockaddr->sin_addr.s_addr
		  == p->_remote_in_port_address.sin_addr.s_addr))
	    /* Assume that sin_family is equal.  Using memcmp() doesn't
	       work because sin_zero's may differ. */
	    {
	      assert (p->is_valid);
	      return p;
	    }
	}
    }
  /* xxx When the AcceptedSocket-style OutPort get's it's 
     _remote_in_port_address set, we should make sure that there isn't
     already an OutPort with that address. */

  /* See if there already exists a TcpOutPort object with ivar _socket
     equal to SOCK.  If there is, and if sockaddr is non-null, this
     call may be a request to set the TcpOutPort's _remote_in_port_address
     ivar. */
  if (sock && (p = NSMapGet (socket_2_port, (void*)sock)))
    {
      assert ([p isKindOfClass: [TcpOutPort class]]);
      if (sockaddr)
	{
	  /* Make sure the address we're setting it to is non-zero. */
	  assert (sockaddr->sin_port);

	  /* See if the _remote_in_port_address is already set */
	  if (p->_remote_in_port_address.sin_family)
	    {
	      /* It is set; make sure no one is trying to change it---that 
		 isn't allowed. */
	      if ((p->_remote_in_port_address.sin_port
		   != sockaddr->sin_port)
		  || (p->_remote_in_port_address.sin_addr.s_addr
		      != sockaddr->sin_addr.s_addr))
		[self error:"Can't change reply port of an out port once set"];
	    }
	  else
	    {
	      /* It wasn't set before; set it by copying it in. */
	      memcpy (&(p->_remote_in_port_address), 
		      sockaddr,
		      sizeof (p->_remote_in_port_address));
	    }
	}
      assert (p->is_valid);
      return p;
    }

  /* There isn't already an in port for this sockaddr or sock,
     so create a new port. */
  p = [[self alloc] init];

  /* Set its socket. */
  if (sock)
    p->_socket = sock;
  else
    {
      p->_socket = socket (AF_INET, SOCK_STREAM, 0);
      if (p->_socket < 0)
	{
	  perror ("[TcpOutPort newForSendingToSockaddr:...] socket()");
	  abort ();
	}
    }

  /* Register which InPort object will listen to replies from our messages. 
     This may be nil, in which case it can get set later in -sendPacket... */
  p->_polling_in_port = [ip retain];

  /* Set the port's address. */
  if (sockaddr)
    {
      assert (sockaddr->sin_port);
      memcpy (&(p->_remote_in_port_address), sockaddr, sizeof(*sockaddr));
    }
  else
    {
      /* Else, _remote_in_port_address will remain as zero's for the
	 time being, and may get set later by calling
	 +newForSendingToSockaddr..  with a non-zero socket, and a
	 non-NULL sockaddr. */
      p->_remote_in_port_address.sin_family = 0;
    }

  /* xxx Do I need to bind(_socket) to this address?  I don't think so. */

  /* Connect the socket to its destination, (if it hasn't been done 
     already by a previous accept() call. */
  if (!sock)
    {
      if (connect (p->_socket,
		   (struct sockaddr*)&(p->_remote_in_port_address), 
		   sizeof(p->_remote_in_port_address)) 
	  < 0)
	{
	  perror ("[TcpOutPort newForSendingToSockaddr:...] connect()");
	  abort ();
	}
    }

  /* Put it in the shared socket->port map table. */
  assert (!NSMapGet (socket_2_port, (void*)p->_socket));
  NSMapInsert (socket_2_port, (void*)p->_socket, p);

  /* Put it in TcpOutPort's registry. */
  NSMapInsert (out_port_bag, (void*)p, (void*)p);

  return p;
}

+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (id <String>)hostname
{
  struct hostent *hp;
  const char *host_cstring;
  struct sockaddr_in addr;

  /* Look up the hostname. */
  if (!hostname || ![hostname length])
    host_cstring = "localhost";
  else
    host_cstring = [hostname cStringNoCopy];
  hp = gethostbyname ((char*)host_cstring);
  if (hp == 0)
    [self error: "unknown host: \"%s\"", host_cstring];

  /* Get the sockaddr_in address. */
  memcpy (&addr.sin_addr, hp->h_addr, hp->h_length);
  addr.sin_family = AF_INET;
  addr.sin_port = htons (n);

  return [self newForSendingToSockaddr: &addr
	       withAcceptedSocket: 0
	       pollingInPort: nil];
}

+ newForSendingToRegisteredName: (id <String>)name 
			 onHost: (id <String>)hostname
{
  return [self newForSendingToPortNumber: 
		 name_2_port_number ([name cStringNoCopy])
	       onHost: hostname];;
}

+ _newWithAcceptedSocket: (int)s 
		peeraddr: (struct sockaddr_in*)peeraddr
                  inPort: p
{
#if 0
  struct sockaddr_in addr;
  int size = sizeof (struct sockaddr_in);

  /* Get the sockaddr. */
  if (getpeername (s, (struct sockaddr*)&addr, &size) < 0)
    {
      perror ("[TcpPort +newWithAcceptedSocket:] getsockname()");
      abort ();
    }
  assert (size == sizeof (struct sockaddr_in));
  /* xxx Perhaps I have to get peer name here!! */
  assert (ntohs (addr.sin_port) != [p portNumber]);
#elif 0
  struct sockaddr_in in_port_address;
  c = read (s, &in_port_address, sizeof(struct sockaddr_in));
#endif

  return [self newForSendingToSockaddr: NULL
	       withAcceptedSocket: s
	       pollingInPort: p];
}

- (struct sockaddr_in*) _remoteInPortSockaddr
{
  return &_remote_in_port_address;
}

- (BOOL) sendPacket: packet withTimeout: (int)milliseconds
{
  int c, l;
  id reply_port = [packet replyPort];

  assert (is_valid);

  /* If the socket of this TcpOutPort isn't already being polled
     for incoming data by a TcpInPort, and if the packet's REPLY_PORT
     is non-nil, then set up this TcpOutPort's socket to be polled by
     the REPLY_PORT.  Once a TcpOutPort is associated with a particular
     TcpInPort, it is permanantly associated with that InPort; it cannot 
     be re-associated with another TcpInPort later. 
     The creation and use of TcpInStream objects could avoid this 
     restriction; see the note about them at the top of this file. */
  if (_polling_in_port == nil && reply_port != nil)
    {
      _polling_in_port = [reply_port retain];
      [_polling_in_port _addClientOutPort: self];
    }
  else if (_polling_in_port != reply_port)
    [self error: "Instances of %s can't change their reply port once set.",
	  object_get_class_name (self)];
    /* Creating TcpInStream objects, and separating them from
       TcpOutPort's would fix this restriction.  However, it would
       also have the disadvantage of using all socket's only for
       sending data one-way, and creating twice as many socket's for
       two-way exchanges. */

  /* Ask the packet to write it's bytes to the socket.
     The TcpPacket will also write a prefix, indicating the packet size
     and the reply port address.  If REPLY_PORT is nil, the second argument
     to this call with be NULL, and __writeToSocket:withReplySockaddr: will
     know that there is no reply port. */
  [packet _writeToSocket: _socket 
	  withReplySockaddr: [reply_port _listeningSockaddr]];
  return YES;
}

- (int) _socket
{
  return _socket;
}

- (int) portNumber
{
  return (int) ntohs (_remote_in_port_address.sin_port);
}

- (void) close
{
  [self invalidate];
}

- (void) invalidate
{
  assert (is_valid);

  /* xxx Perhaps should delay this close() to keep another port from
     getting it.  This may help Connection invalidation confusion. */
  if (close (_socket) < 0)
    {
      perror ("[TcpOutPort -invalidate] close()");
      abort ();
    }
  [_polling_in_port _connectedOutPortInvalidated: self];
  [_polling_in_port release];
  _polling_in_port = nil;
      
  /* This is here, and not in -dealloc, because invalidated
     but not dealloc'ed ports should not be returned from
     the out_port_bag in +newForSendingToSockaddr:... */
  NSMapRemove (out_port_bag, (void*)self);
  /* This is here, and not in -dealloc, because invalidated
     but not dealloc'ed ports should not be returned from
     the socket_2_port in +newForSendingToSockaddr:... */
  NSMapRemove (socket_2_port, (void*)_socket);

  /* This also posts a PortBecameInvalidNotification. */
  [super invalidate];
}

- (void) dealloc
{
  if (is_valid)
    [self invalidate];
  [super dealloc];
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

+ (Class) packetClass
{
  return [TcpPacket class];
}

- description
{
  return [NSString 
	   stringWithFormat: @"%s%c0x%x host %s port %hd socket %d",
	   object_get_class_name (self),
	   is_valid ? ' ' : '-',
	   (unsigned)self,
	   inet_ntoa (_remote_in_port_address.sin_addr),
	   ntohs (_remote_in_port_address.sin_port),
	   _socket];
}

- (void) encodeWithCoder: aCoder
{
  assert (is_valid);
  [super encodeWithCoder: aCoder];
  assert (!_polling_in_port 
	  || (ntohs (_remote_in_port_address.sin_port)
	      != [_polling_in_port portNumber]));
  [aCoder encodeValueOfCType: @encode(typeof(_remote_in_port_address.sin_port))
	  at: &(_remote_in_port_address.sin_port)
	  withName: @"socket number"];
  [aCoder encodeValueOfCType: 
	    @encode(typeof(_remote_in_port_address.sin_addr.s_addr))
	  at: &(_remote_in_port_address.sin_addr.s_addr)
	  withName: @"inet address"];
}

+ newWithCoder: aCoder
{
  struct sockaddr_in addr;

  addr.sin_family = AF_INET;
  [aCoder decodeValueOfCType: @encode(typeof(addr.sin_port))
	  at: &(addr.sin_port)
	  withName: NULL];
  [aCoder decodeValueOfCType: @encode(typeof(addr.sin_addr.s_addr))
	  at: &(addr.sin_addr.s_addr)
	  withName: NULL];
  return [TcpOutPort newForSendingToSockaddr: &addr
		     withAcceptedSocket: 0
		     pollingInPort: nil];
}

@end



@implementation TcpPacket

/* If you change this "unsigned short", you must change the use
   of ntohs() and htons() below. */
#define PREFIX_LENGTH_TYPE unsigned short
#define PREFIX_LENGTH_SIZE sizeof (PREFIX_LENGTH_TYPE)
#define PREFIX_ADDRESS_TYPE struct sockaddr_in
#define PREFIX_ADDRESS_SIZE sizeof (PREFIX_ADDRESS_TYPE)
#define PREFIX_SIZE (PREFIX_LENGTH_SIZE + PREFIX_ADDRESS_SIZE)

/* This is the designated initialzer. */
/* xxx This will change; it doesn't set it's buffer size with a nice 
   interface */
- _initForReceivingWithSize: (int)s replyPort: p
{
  [super _initOnMallocBuffer: (*objc_malloc) (s)
	 size: s
	 eofPosition: 0
	 prefix: 0
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
	 prefix: PREFIX_SIZE
	 position: 0];
  assert ([p isValid]);
  reply_port = p;
  return self;
}

- (void) _writeToSocket: (int)s 
      withReplySockaddr: (struct sockaddr_in*)addr
{
  int c;

  /* Put the packet size in the first two bytes of the packet. */
  assert (prefix == PREFIX_SIZE);
  *(PREFIX_LENGTH_TYPE*)buffer = htons (eofPosition);

  /* Put the sockaddr_in for replies in the next bytes of the prefix
     region.  If there is no reply address specified, fill it with zeros. */
  if (addr)
    *(PREFIX_ADDRESS_TYPE*)(buffer + PREFIX_LENGTH_SIZE) = *addr;
  else
    memset (buffer + PREFIX_LENGTH_SIZE, 0, PREFIX_ADDRESS_SIZE);

  /* Write the packet on the socket. */
  c = write (s, buffer, prefix + eofPosition);
  if (c < 0)
    {
      perror ("[TcpOutPort -_writeToSocket:] write()");
      abort ();
    }

  /* Did we sucessfully write it all? */
  if (c != prefix + eofPosition)
    [self error: "socket write failed"];
}

+ (void) _getPacketSize: (int*)packet_size 
	   andReplyPort: (id*)rp
             fromSocket: (int)s
	         inPort: ip
{
  char prefix_buffer[PREFIX_SIZE];
  int c;
  struct sockaddr_in *addr;
  
  c = read (s, prefix_buffer, PREFIX_SIZE);
  if (c == 0)
    {
      *packet_size = EOF;  *rp = nil;
      return;
    }
  if (c != PREFIX_SIZE)
    {
      /* Was: [self error: "Failed to get packet prefix from socket."]; */
      /* xxx Currently treating this the same as EOF, but perhaps
	 we should treat it differently. */
      fprintf (stderr, "[%s %s]: Got %d chars instead of full prefix\n",
	       class_get_class_name (self), sel_get_name (_cmd));
      *packet_size = EOF;  *rp = nil;
      return;
    }      

  /* *size is the number of bytes in the packet, not including 
     the PREFIX_SIZE-byte header. */
  *packet_size = ntohs (*(PREFIX_LENGTH_TYPE*) prefix_buffer);
  assert (packet_size);

  /* If the reply address is non-zero, and the TcpOutPort for this socket
     doesn't already have its _address ivar set, then set it now. */
  {
    addr = (struct sockaddr_in*) (prefix_buffer + PREFIX_LENGTH_SIZE);
    if (addr->sin_family)
      {
#if 0    
	TcpOutPort *op = NSMapGet (socket_2_port, s);

	assert ([op isKindOf: [TcpOutPort class]]);
	if (![op portNumber])
	  [op _setRemoteInPortAddress: addr];
	else
	  {
	    struct sockaddr_in *op_addr = [op _sockaddr];
	    if (op_addr->sin_port != addr->sin_port
		|| op_addr->sin_addr.s_addr != addr->sin_addr.s_addr)
	      [self error: "TcpPort can't change reply port of an out port "
		    "once set."];
	    /* See comment above for identical error message. */
	  }
#else
      *rp = [TcpOutPort newForSendingToSockaddr: addr
			withAcceptedSocket: s
			pollingInPort: ip];
#endif
      }
    else
      *rp = nil;
  }
}

- (int) _fillFromSocket: (int)s
{
  int c;
  int remaining;

  remaining = size - eofPosition;
  /* xxx We need to make sure this read() is non-blocking. */
  c = read (s, buffer + prefix + eofPosition, remaining);
  if (c == 0)
    return EOF;
  eofPosition += c;
  return remaining - c;
}

@end

#if 0
/* Not used.  See comments about TcpInStream at top of file. */
@implementation TcpInStream 
- initWithAcceptedSocket: (int)s inPort: p
{
  [super init];
  _socket = s;
  _listening_in_port = p;
  return self;
}
@end
#endif



/* Notification Strings. */

NSString *
InPortClientBecameInvalidNotification = 
@"InPortClientBecameInvalidNotification";

NSString *
InPortAcceptedClientNotification = 
@"InPortAcceptedClientNotification";


/* Scraps */

#if 0
+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (id <String>)hostname
{
  TcpOutPort *p;
  int s;

  /* If the TcpOutPort object already exists, just return it.  This be
     judged according to the port number and host; this is what will
     get sent when a TcpPort encodes itself. */
  /* xxx check the out_port_bag here. */

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
    if (!hostname || ![hostname length])
      hostinfo = gethostbyname ("localhost");
    else
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
#endif

#if 0
+ newWithAcceptedSocket: (int)s 
	       sockaddr: (struct sockaddr_in*)addr
		 inPort: p
{
  TcpOutPort *op;
  struct sockaddr_in addr;
  int size = sizeof (struct sockaddr_in);

  /* Create the port object. */
  op = [[self alloc] _initWithSocket: s inPort: p];

  /* Fill in its _address ivar. */
  getsockname (op->_socket, (struct sockaddr*)&addr, &size);
  assert (size == sizeof (struct sockaddr_in));
  memcpy (&(op->_address), &addr, sizeof (struct sockaddr_in));

  return op;
}
#endif


