/* Implementation of network port object based on TCP sockets
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: February 1996
   
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

/* Name server support and exceptions added october 1996
   by Richard Frith-Macdonald (richard@brainstorm.co.uk)
   Socket I/O made non blocking. */

/* A strange attempt to make SOCK_STREAM sockets look like ports.  The
   two concepts don't fit together easily.  Be prepared for a little
   weirdness. */

/* TODO:
   Change so we don't wait on incoming packet prefix.
   */

#include <config.h>
#include <base/preface.h>
#include <base/TcpPort.h>
#include <base/Array.h>
#include <base/NotificationDispatcher.h>
#include <base/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSByteOrder.h>
#include <base/Invocation.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSPortNameServer.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#ifndef __WIN32__
#include <unistd.h>		/* for gethostname() */
#include <sys/param.h>		/* for MAXHOSTNAMELEN */
#include <netinet/in.h>		/* for inet_ntoa() */
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/file.h>

/* For IRIX machines, which don't define this */
#ifndef        IPPORT_USERRESERVED
#define        IPPORT_USERRESERVED     5000
#endif /* IPPORT_USERRESERVED */

/*
 *	Stuff for setting the sockets into non-blocking mode.
 */
#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#define	stringify_it(X)	#X
#define	make_gdomap_cmd(X)	stringify_it(X) "/Tools/"GNUSTEP_TARGET_DIR"/gdomap &"
#define	make_gdomap_err(X)	"check that " stringify_it(X) "/Tools/"GNUSTEP_TARGET_DIR"/gdomap is running and owned by root."

#endif /* !__WIN32__ */
#include <string.h>		/* for memset() and strchr() */
#ifndef __WIN32__
#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/errno.h>
#endif /* !__WIN32__ */

static int debug_tcp_port = 0;




@interface TcpPrefPacket : TcpInPacket
@end
@implementation TcpPrefPacket
@end


@interface NSPort (Debug)
+ (void) setDebug: (int)val;
@end

@implementation NSPort (Debug)
+ (void) setDebug: (int)val
{
    debug_tcp_port = val;
}
@end


/* Private interfaces */

@interface TcpInPort (Private)
- (int) _port_socket;
- (struct sockaddr_in*) _listeningSockaddr;
- (void) _addClientOutPort: p;
- (void) _connectedOutPortInvalidated: p;
- _tryToGetPacketFromReadableFD: (int)fd_index;
@end

@interface TcpOutPort (Private)
- (int) _port_socket;
- _initWithSocket: (int)s inPort: ip;
+ _newWithAcceptedSocket: (int)s peeraddr: (struct sockaddr_in*)addr inPort: p;
- (struct sockaddr_in*) _remoteInPortSockaddr;
@end

@interface TcpInPacket (Private)
- (int) _fillFromSocket: (int)s;
+ (void) _getPacketSize: (int*)size
	    andSendPort: (id*)sp
	 andReceivePort: (id*)rp
             fromSocket: (int)s;
@end

@interface TcpOutPacket (Private)
- (void) _writeToSocket: (int)s 
	   withSendPort: (id)sp
	withReceivePort: (id)rp
                timeout: (NSTimeInterval)t;
@end

#if 0
/* Not currently being used; but see the comment in -sendPacket:timeout: */

/* TcpInStream - an object that represents an accept()'ed socket
   that's being polled by a TcpInPort's select().  This object cannot
   be the same as a TcpOutPort because we cannot be sure that someone
   is polling the socket on the other end---unfortunately this means
   that the socket's used by Tcp*Port objects are only used for sending
   data in one direction. */

@interface TcpInStream : NSObject
{
  int _port_socket;
  id _listening_in_port;
}
- initWithAcceptedSocket: (int)s inPort: p;
@end
#endif /* 0 */



extern	int	errno;	/* For systems where it is not in the include	*/

/*
 *	Name -		tryRead()
 *	Purpose -	Attempt to read from a non blocking channel.
 *			Time out in specified time.
 *			If length of data is zero then just wait for
 *			descriptor to be readable.
 *			If the length is negative then attempt to
 *			read the absolute value of length but return
 *			as soon as anything is read.
 *
 *			Return -1 on failure
 *			Return -2 on timeout
 *			Return number of bytes read
 */
static int
tryRead(int desc, int tim, unsigned char* dat, int len)
{
  struct timeval timeout;
  fd_set	fds;
  void		*to;
  int		rval;
  int		pos = 0;
  time_t	when = 0;
  int		neg = 0;

  if (len < 0) {
    neg = 1;
    len = -len;
  }

  /*
   *	First time round we do a select with an instant timeout to see
   *	if the descriptor is already readable.
   */
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;

  for (;;) {
    to = &timeout;
    memset(&fds, '\0', sizeof(fds));
    FD_SET(desc, &fds);

    rval = select(FD_SETSIZE, &fds, 0, 0, to);
    if (rval == 0) {
      time_t	now = time(0);

      if (when == 0) {
	when = now;
      }
      else if (now - when >= tim) {
        return(-2);		/* Timed out.		*/
      }
      else {
	/* Set the timeout for a new call to select next time round
         * the loop. */
	timeout.tv_sec = tim - (now - when);
	timeout.tv_usec = 0;
      }
    }
    else if (rval < 0) {
      return(-1);		/* Error in select.	*/
    }
    else if (len > 0) {
      rval = read(desc, &dat[pos], len - pos);
      if (rval < 0) {
	if (errno != EWOULDBLOCK) {
          return(-1);		/* Error in read.	*/
        }
      }
      else if (rval == 0) {
        return(-1);		/* End of file.		*/
      }
      else {
        pos += rval;
	if (pos == len || neg == 1) {
	    return(pos);	/* Read as needed.	*/
	}
      }
    }
    else {
      return(0);	/* Not actually asked to read.	*/
    }
  }
}

/*
 *	Name -		tryWrite()
 *	Purpose -	Attempt to write to a non blocking channel.
 *			Time out in specified time.
 *			If length of data is zero then just wait for
 *			descriptor to be writable.
 *			If the length is negative then attempt to
 *			write the absolute value of length but return
 *			as soon as anything is written.
 *
 *			Return -1 on failure
 *			Return -2 on timeout
 *			Return number of bytes written
 */
static int
tryWrite(int desc, int tim, unsigned char* dat, int len)
{
  struct timeval timeout;
  fd_set	fds;
  void		*to;
  int		rval;
  int		pos = 0;
  time_t	when = 0;
  int		neg = 0;

  if (len < 0) {
    neg = 1;
    len = -len;
  }

  /*
   *	First time round we do a select with an instant timeout to see
   *	if the descriptor is already writable.
   */
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;

  for (;;) {
    to = &timeout;
    memset(&fds, '\0', sizeof(fds));
    FD_SET(desc, &fds);

    rval = select(FD_SETSIZE, 0, &fds, 0, to);
    if (rval == 0) {
      time_t	now = time(0);

      if (when == 0) {
	when = now;
      }
      else if (now - when >= tim) {
        return(-2);		/* Timed out.		*/
      }
      else {
	/* Set the timeout for a new call to select next time round
         * the loop. */
	timeout.tv_sec = tim - (now - when);
	timeout.tv_usec = 0;
      }
    }
    else if (rval < 0) {
      return(-1);		/* Error in select.	*/
    }
    else if (len > 0) {
      rval = write(desc, &dat[pos], len - pos);

      if (rval <= 0) {
	if (errno != EWOULDBLOCK) {
          return(-1);		/* Error in write.	*/
        }
      }
      else {
        pos += rval;
	if (pos == len || neg == 1) {
	    return(pos);	/* Written as needed.	*/
	}
      }
    }
    else {
      return(0);	/* Not actually asked to write.	*/
    }
  }
}


/* Both TcpInPort's and TcpOutPort's are entered in this maptable. */

static NSMapTable *socket_2_port = NULL;

static void 
init_port_socket_2_port ()
{
  if (!socket_2_port)
    socket_2_port =
      NSCreateMapTable (NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
}



/* TcpInPort class - An object that represents a listen()'ing socket,
   and a collection of socket's which the NSRunLoop will poll using
   select().  Each of the socket's that is polled is actually held by
   a TcpOutPort object.  See the comments by TcpOutPort below. */

@implementation TcpInPort

/* This map table is used to make sure we don't create more than one
   TcpInPort listening to the same port number. */
static NSMapTable* port_number_2_port;

+ (void) initialize
{
  if (self == [TcpInPort class])
    {
      port_number_2_port = 
        NSCreateMapTable (NSIntMapKeyCallBacks,
			  NSNonOwnedPointerMapValueCallBacks, 0);
      init_port_socket_2_port ();
      /*
       *	If SIGPIPE is not ignored, we will abort on any attempt to
       *	write to a pipe/socket that has been closed by the other end!
       */
      signal(SIGPIPE, SIG_IGN);
    }
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
      NSAssert(p->is_valid, NSInternalInconsistencyException);
      return [p retain];
    }

  /* There isn't already a TcpInPort for this port number, so create
     a new one. */

  /* Create the port object. */
  p = [[TcpInPort alloc] init];

  /* Create the socket. */
  p->_port_socket = socket (AF_INET, SOCK_STREAM, 0);
  if (p->_port_socket < 0)
    {
      [p release];
      [NSException raise: NSInternalInconsistencyException
	  format: @"[TcpInPort +newForReceivingFromPortNumber:] socket(): %s",
	  strerror(errno)];
    }

  /* Register the port object according to its socket. */
  NSAssert(!NSMapGet (socket_2_port, (void*)p->_port_socket), NSInternalInconsistencyException);
  NSMapInsert (socket_2_port, (void*)p->_port_socket, p);
  
  /* Give the socket a name using bind() and INADDR_ANY for the
     machine address in _LISTENING_ADDRESS; then put the network
     address of this machine in _LISTENING_ADDRESS.SIN_ADDR, so
     that when we encode the address, another machine can find us. */
  {
    struct hostent *hp;
    char hostname[MAXHOSTNAMELEN];
    int len = MAXHOSTNAMELEN;
    int	r;

    /* Set the re-use socket option so that we don't get this socket
       hanging around after we close it (or die) */
    r = 1;
    setsockopt(p->_port_socket,SOL_SOCKET,SO_REUSEADDR,(char*)&r,sizeof(r));
    /* Fill in the _LISTENING_ADDRESS with the address this in port on
       which will listen for connections.  Use INADDR_ANY so that we
       will accept connection on any of the machine network addresses;
       most machine will have both an Internet address, and the
       "localhost" address (i.e. 127.0.0.1) */
    p->_listening_address.sin_addr.s_addr = GSSwapHostI32ToBig (INADDR_ANY);
    p->_listening_address.sin_family = AF_INET;
    p->_listening_address.sin_port = GSSwapHostI16ToBig (n);
    /* N may be zero, in which case bind() will choose a port number
       for us. */
    if (bind (p->_port_socket,
	      (struct sockaddr*) &(p->_listening_address),
	      sizeof (p->_listening_address)) 
	< 0)
      {
	BOOL	ok = NO;
	/* bind() sometimes seems to fail when given a port of zero - this
	 * should really never happen, so we retry a few times in case the
	 * kernel has had a temporary brainstorm.
	 */
	if (n == 0) {
	  int	count;

	  for (count = 0; count < 10; count++) {
	    memset(&p->_listening_address, 0, sizeof(p->_listening_address));
	    p->_listening_address.sin_addr.s_addr = GSSwapHostI32ToBig (INADDR_ANY);
	    p->_listening_address.sin_family = AF_INET;
	    if (bind (p->_port_socket,
	      (struct sockaddr*) &(p->_listening_address),
	      sizeof (p->_listening_address)) == 0) {
	      ok = YES;
	      break;
	    }
	  }
	}
	if (ok == NO) {
	  [p release];
	  [NSException raise: NSInternalInconsistencyException
	    format: @"[TcpInPort +newForReceivingFromPortNumber:] bind(): %s",
	    strerror(errno)];
	}
      }

    /* If the caller didn't specify a port number, it was chosen for us.
       Here, find out what number was chosen. */
    if (!n)
      /* xxx Perhaps I should do this unconditionally? */
      {
	int size = sizeof (p->_listening_address);
	if (getsockname (p->_port_socket,
			 (struct sockaddr*)&(p->_listening_address),
			 &size)
	    < 0)
	  {
	    [p release];
	    [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort +newForReceivingFromPortNumber:] getsockname(): %s",
	      strerror(errno)];

	  }
	NSAssert(p->_listening_address.sin_port, NSInternalInconsistencyException);
	n = GSSwapBigI16ToHost(p->_listening_address.sin_port);
      }

    /* Now change _LISTENING_ADDRESS to the specific network address of this
       machine so that, when we encoded our _LISTENING_ADDRESS for a
       Distributed Objects connection to another machine, they get our
       unique host address that can identify us across the network. */
    if (gethostname (hostname, len) < 0)
      {
	[p release];
	[NSException raise: NSInternalInconsistencyException
	  format: @"[TcpInPort +newForReceivingFromPortNumber:] gethostname(): %s",
	  strerror(errno)];
      }
    /* Terminate the name at the first dot. */
    {
      char *first_dot = strchr (hostname, '.');
      if (first_dot)
	*first_dot = '\0';
    }
    hp = gethostbyname (hostname);
    if (!hp)
      [self error: "Could not get address of local host \"%s\"", hostname];
    NSAssert(hp, NSInternalInconsistencyException);
    memcpy (&(p->_listening_address.sin_addr), hp->h_addr, hp->h_length);
  }

  /* Set it up to accept connections, let 10 pending connections queue */
  /* xxx Make this "10" a class variable? */
  if (listen (p->_port_socket, 10) < 0)
    {
      [p release];
      [NSException raise: NSInternalInconsistencyException
	format: @"[TcpInPort +newForReceivingFromPortNumber:] listen(): %s",
	strerror(errno)];
    }

  /* Initialize the tables for matching socket's to out ports and packets. */
  p->_client_sock_2_out_port = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);
  p->_client_sock_2_packet = 
    NSCreateMapTable (NSIntMapKeyCallBacks,
		      NSNonOwnedPointerMapValueCallBacks, 0);

  /* Record the new port in TcpInPort's class table. */
  NSMapInsert (port_number_2_port, (void*)(int)n, p);

  return p;
}

+ newForReceivingFromRegisteredName: (NSString*)name
{
  return [self newForReceivingFromRegisteredName: name fromPort: 0];
}

+ newForReceivingFromRegisteredName: (NSString*)name
			   fromPort: (int)portn
{
  TcpInPort*		p = [self newForReceivingFromPortNumber: portn];
  struct sockaddr_in	sin;

  if (p) {
    [[NSPortNameServer defaultPortNameServer] registerPort: p
						   forName: name];
  }
  return p;
}

+ newForReceiving
{
  return [self newForReceivingFromPortNumber: 0];
}

- (id <Collecting>) connectedOutPorts
{
  NSMapEnumerator me = NSEnumerateMapTable (_client_sock_2_out_port);
  int count = NSCountMapTable (_client_sock_2_out_port);
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
  return NSCountMapTable (_client_sock_2_out_port);
}

- (struct sockaddr_in*) _listeningSockaddr
{
  NSAssert(is_valid, NSInternalInconsistencyException);
  return &_listening_address;
}

/* Usually, you would run the run loop to get packets, but if you
   want to wait for one directly from a port, you can use this method. */
- newPacketReceivedBeforeDate: date
{
  NSString*	saved_mode = [NSRunLoop currentMode];
  id saved_packet_invocation;
  id packet = nil;
  id handle_packet (id p)
    {
      packet = p;
      return nil;
    }

  /* Swap in our own temporary handler. */
  saved_packet_invocation = _packet_invocation;
  _packet_invocation = [[ObjectFunctionInvocation alloc]
			 initWithObjectFunction: handle_packet];

  /* Make sure we're in the run loop, and run it, waiting for the
     incoming packet. */
  [[NSRunLoop currentRunLoop] addPort: self
			      forMode: saved_mode];
  while ([NSRunLoop runOnceBeforeDate: date]
	 && !packet)
    ;

  /* Clean up, getting ready to return. Swap back in the old packet
     handler, and decrement the number of times we've been added to
     this run loop. */ 
  _packet_invocation = saved_packet_invocation;
  [[NSRunLoop currentRunLoop] removePort: self
			         forMode: saved_mode];
  return packet;
}


/* Read some data from FD; if we read enough to complete a packet,
   return the packet.  Otherwise, keep the partially read packet in
   _CLIENT_SOCK_2_PACKET. */

- _tryToGetPacketFromReadableFD: (int)fd_index
{
  if (fd_index == _port_socket)
    {
      /* This is a connection request on the original listen()'ing socket. */
      int new;
      int size;
      int rval;
      volatile id op;
      struct sockaddr_in clientname;

      size = sizeof (clientname);
      new = accept (_port_socket, (struct sockaddr*)&clientname, &size);
      if (new < 0)
	{
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort receivePacketWithTimeout:] accept(): %s",
	      strerror(errno)];
	}
      /*
       *	Code to ensure that new socket is non-blocking.
       */
      if ((rval = fcntl(new, F_GETFL, 0)) >= 0) {
	rval |= NBLK_OPT;
	if (fcntl(new, F_SETFL, rval) < 0) {
	  close(new);
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort receivePacketWithTimeout:] fcntl(SET): %s",
	      strerror(errno)];
	}
      }
      else {
	close(new);
	[NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort receivePacketWithTimeout:] fcntl(GET): %s",
	      strerror(errno)];
      }
      op = [TcpOutPort _newWithAcceptedSocket: new 
		       peeraddr: &clientname
		       inPort: self];
      [self _addClientOutPort: op];
      [op release];
      if (debug_tcp_port)
	NSLog(@"%s: Accepted connection from\n %@.\n",
		 object_get_class_name (self), [op description]);
      [NotificationDispatcher
	postNotificationName: InPortAcceptedClientNotification
	object: self
	userInfo: op];
    }
  else
    {
      /* Data has arrived on an already-connected socket. */
      TcpInPacket *packet;
      int remaining;

      /* See if there is already a InPacket object waiting for
	 more data from this socket. */
      if (!(packet = NSMapGet (_client_sock_2_packet,
			       (void*)fd_index)))
	{
	  /* This is the beginning of a new packet on this socket.
	     Create a new InPacket object for gathering the data. */

	  /* First, get the packet size and reply port, (which is
	     encoded in the first few bytes of the stream). */
	  int packet_size;
	  id send_port;
	  id receive_port;
	  [TcpInPacket _getPacketSize: &packet_size
			  andSendPort: &send_port
		       andReceivePort: &receive_port
			   fromSocket: fd_index];
	  /* If we got an EOF when trying to read the packet prefix,
	     invalidate the port, and keep on waiting for incoming
	     data on other sockets. */
	  if (packet_size == EOF)
	    {
	      [(id) NSMapGet (_client_sock_2_out_port, (void*)fd_index)
		    invalidate];
	      return nil;
	    }
	  else
	    {
	      packet = [[TcpInPacket alloc] 
			 initForReceivingWithCapacity: packet_size
			 receivingInPort: send_port
			 replyOutPort: receive_port];
	      if (packet == nil)
	        [NSException raise: NSInternalInconsistencyException
	          format: @"[TcpInPort _tryToGetPacketFromReadableFD:"
			@" - failed to create incoming packet"];
	      NSMapInsert(_client_sock_2_packet,(void*)fd_index,(void*)packet);
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
          NSMapRemove(_client_sock_2_packet, (void*)fd_index);
	  [packet release];
	  [(id) NSMapGet (_client_sock_2_out_port, (void*)fd_index)
		invalidate];
	  return nil;
	}
      else if (remaining == 0)
	{
	  /* No bytes are remaining to be read for this packet; 
	     the packet is complete; return it. */
	  NSAssert(packet && [packet class], NSInternalInconsistencyException);
          NSMapRemove(_client_sock_2_packet, (void*)fd_index);
	  if (debug_tcp_port > 1)
	    NSLog(@"%s: Read from socket %d\n",
		object_get_class_name (self), fd_index);
	  return packet;
	}
    }
  return nil;
}


/* Dealing with the relationship to a NSRunLoop. */

/* The NSRunLoop will send us this message just before it's about to call
   select().  It is asking us to fill fds[] in with the sockets on which
   it should listen.  *count should be set to the number of sockets we
   put in the array. */

- (void) getFds: (int*)fds count: (int*)count
{
  NSMapEnumerator me;
  int sock;
  id out_port;

  /* Make sure there is enough room in the provided array. */
  NSAssert(*count > NSCountMapTable (_client_sock_2_out_port), NSInternalInconsistencyException);

  /* Put in our listening socket. */
  *count = 0;
  fds[(*count)++] = _port_socket;

  /* Enumerate all our client sockets, and put them in. */
  me = NSEnumerateMapTable (_client_sock_2_out_port);
  while (NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port))
    fds[(*count)++] = sock;
}

/* This is called by the NSRunLoop when select() says the FD is ready
   for reading. */

#include <Foundation/NSAutoreleasePool.h>
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  id arp = [NSAutoreleasePool new];
  id packet;

  NSAssert(type == ET_RPORT, NSInvalidArgumentException);

  packet = [self _tryToGetPacketFromReadableFD: (int)extra];
  if (packet) {
    [_packet_invocation invokeWithObject: packet];
  }
  [arp release];
  return;
}

- (NSDate*)timedOutEvent: (void*)data
		    type: (RunLoopEventType)type
		 forMode: (NSString*)mode
{
    return nil;
}


/* Adding an removing client sockets (ports). */
 
/* Add and removing out port's from the collection of connections we handle. */

- (void) _addClientOutPort: p
{
  int s = [p _port_socket];

  NSAssert(is_valid, NSInternalInconsistencyException);
  /* Make sure it hasn't already been added. */
  NSAssert(!NSMapGet (_client_sock_2_out_port, (void*)s), NSInternalInconsistencyException);

 /* Add it, and put its socket in the set of file descriptors we poll. */
  NSMapInsert (_client_sock_2_out_port, (void*)s, p);
}

/* Called by an OutPort in its -invalidate method. */
- (void) _connectedOutPortInvalidated: p
{
  id packet;
  int s = [p _port_socket];

  NSAssert(is_valid, NSInternalInconsistencyException);
  if (debug_tcp_port)
    NSLog(@"%s: Closed connection from\n %@\n",
	     object_get_class_name (self), [p description]);

  packet = NSMapGet (_client_sock_2_packet, (void*)s);
  if (packet)
    {
      NSMapRemove (_client_sock_2_packet, (void*)s);
      [packet release];
    }
  NSMapRemove (_client_sock_2_out_port, (void*)s);
/*
 *	This method is all wrong - messes up badly when called from
 *	an OutPort which is deallocating itsself.
 */
#if 0
  /* xxx Should this be earlier, so that the notification recievers
     can still use _client_sock_2_out_port before the out port P is removed? */
  [NotificationDispatcher
    postNotificationName: InPortClientBecameInvalidNotification
    object: self
    userInfo: p];
#endif
}

- (int) _port_socket
{
  return _port_socket;
}

- (int) portNumber
{
  return (int) GSSwapBigI16ToHost (_listening_address.sin_port);
}

- (void) invalidate
{
  if (is_valid)
    {
      NSMapEnumerator me = NSEnumerateMapTable (_client_sock_2_out_port);
      int count = NSCountMapTable (_client_sock_2_out_port);
      id out_port;
      int sock;
      id out_ports[count];
      int i;

      /* These are here, and not in -dealloc, to prevent 
	 +newForReceivingFromPortNumber: from returning invalid sockets. */
      NSMapRemove (socket_2_port, (void*)_port_socket);
      NSMapRemove (port_number_2_port,
		   (void*)(int)GSSwapBigI16ToHost(_listening_address.sin_port));

      for (i = 0; 
	   NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port);
	   i++)
	out_ports[i] = out_port;
      for (i = 0; i < count; i++)
	{
	  /* This will call [self _invalidateConnectedOutPort: for each. */
	  [out_ports[i] invalidate];
	}
      NSAssert(!NSCountMapTable (_client_sock_2_out_port), NSInternalInconsistencyException);

      /* xxx Perhaps should delay this close() to keep another port from
	 getting it.  This may help Connection invalidation confusion. 
	 However, then the process might run out of FD's if the close()
	 was delayed too long. */
      if (_port_socket > 0)
	{
#ifdef	__WIN32__
          closesocket (_port_socket);
#else
          close (_port_socket);
#endif	/* __WIN32__ */
	}

      /* This also posts a NSPortDidBecomeInvalidNotification. */
      [super invalidate];
    }
}

- (void) dealloc
{
  [self invalidate];
  NSFreeMapTable (_client_sock_2_out_port);
  NSFreeMapTable (_client_sock_2_packet);
  [super dealloc];
}

- (void) checkConnection
{
  [self notImplemented: _cmd];
}

+ (Class) outPacketClass
{
  return [TcpOutPacket class];
}

- (Class) outPacketClass
{
  return [TcpOutPacket class];
}

- description
{
  return [NSString
	   stringWithFormat: @"%s%c0x%x port %hd socket %d",
	   object_get_class_name (self),
	   is_valid ? ' ' : '-',
	   (unsigned)self,
	   GSSwapBigI16ToHost(_listening_address.sin_port),
	   _port_socket];
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy, not a Proxy class.
     Also, encode a "send right" (ala Mach), not the "receive right". */
  return [TcpOutPort class];
}

- (Class) classForPortCoder
{
  return [TcpOutPort class];
}
- replacementObjectForPortCoder: aRmc
{
    return self;
}

- (void) encodeWithCoder: aCoder
{
  NSAssert(is_valid, NSInternalInconsistencyException);
  /* We are actually encoding a "send right" (ala Mach), 
     not a receive right.  
     These values must match those expected by [TcpOutPort +newWithCoder] */
  /* Encode these at bytes, not as C-variables, because they are
     already in "network byte-order". */
  [aCoder encodeBytes: &_listening_address.sin_port
	  count: sizeof (_listening_address.sin_port)
	  withName: @"socket number"];
  [aCoder encodeBytes: &_listening_address.sin_addr.s_addr
	  count: sizeof (_listening_address.sin_addr.s_addr)
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
   data on the socket that is this object's `_port_socket' ivar; TcpInPort
   takes care of this. */

@implementation TcpOutPort

/* A collection of all the all the TcpOutPort's, keyed by their id. */
/* xxx This would be more efficient as a void* array instead of a map table. */
static NSMapTable *out_port_bag = NULL;

+ (void) initialize
{
  if (self == [TcpOutPort class])
    {
      init_port_socket_2_port ();
      out_port_bag = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
				       NSNonOwnedPointerMapValueCallBacks, 0);
      /*
       *	If SIGPIPE is not ignored, we will abort on any attempt to
       *	write to a pipe/socket that has been closed by the other end!
       */
      signal(SIGPIPE, SIG_IGN);
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
   getsockname(_port_socket,...), and it is not the address of the
   TcpOutPort's getpeername(_port_socket,...).

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

      NSAssert(sockaddr, NSInternalInconsistencyException);
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
	      NSAssert(p->is_valid, NSInternalInconsistencyException);
	      return [p retain];
	    }
	}
    }
  /* xxx When the AcceptedSocket-style OutPort gets its 
     _remote_in_port_address set, we should make sure that there isn't
     already an OutPort with that address. */

  /* See if there already exists a TcpOutPort object with ivar _port_socket
     equal to SOCK.  If there is, and if sockaddr is non-null, this
     call may be a request to set the TcpOutPort's _remote_in_port_address
     ivar. */
  if (sock && (p = NSMapGet (socket_2_port, (void*)sock)))
    {
      NSAssert([p isKindOfClass: [TcpOutPort class]], NSInternalInconsistencyException);
      if (sockaddr)
	{
	  /* Make sure the address we're setting it to is non-zero. */
	  NSAssert(sockaddr->sin_port, NSInternalInconsistencyException);

	  /* See if the _remote_in_port_address is already set */
	  if (p->_remote_in_port_address.sin_family)
	    {
#if 0
	      /* It is set; make sure no one is trying to change it---that 
		 isn't allowed. */
	      if ((p->_remote_in_port_address.sin_port
		   != sockaddr->sin_port)
		  || (p->_remote_in_port_address.sin_addr.s_addr
		      != sockaddr->sin_addr.s_addr))
		[self error:"Can't change reply port of an out port once set"];
#else
	      if ((p->_remote_in_port_address.sin_port
		   != sockaddr->sin_port)
		  || (p->_remote_in_port_address.sin_addr.s_addr
		      != sockaddr->sin_addr.s_addr))
		{
	          NSString *od = [p description];

	          NSMapRemove (out_port_bag, (void*)p);
	          memcpy (&(p->_remote_in_port_address), 
		          sockaddr,
		          sizeof (p->_remote_in_port_address));
	          NSMapInsert (out_port_bag, (void*)p, (void*)p);
/*
	          NSLog(@"Out port changed from %@ to %@\n", od,
			    [p description]);
*/
		}
#endif
	    }
	  else
	    {
	      /* It wasn't set before; set it by copying it in. */
	      memcpy (&(p->_remote_in_port_address), 
		      sockaddr,
		      sizeof (p->_remote_in_port_address));
	      if (debug_tcp_port)
		NSLog(@"TcpOutPort setting remote address\n%@\n",
			[self description]);
	    }
	}
      if (p)
	{
	  NSAssert(p->is_valid, NSInternalInconsistencyException);
	  return [p retain];
	}
    }

  /* There isn't already an in port for this sockaddr or sock,
     so create a new port. */
  p = [[self alloc] init];

  /* Set its socket. */
  if (sock)
    p->_port_socket = sock;
  else
    {
      p->_port_socket = socket (AF_INET, SOCK_STREAM, 0);
      if (p->_port_socket < 0)
	{
	  [p release];
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] socket(): %s",
	      strerror(errno)];
	}
    }

  /* Register which InPort object will listen to replies from our messages. 
     This may be nil, in which case it can get set later in -sendPacket... */
  p->_polling_in_port = [ip retain];

  /* Set the port's address. */
  if (sockaddr)
    {
      NSAssert(sockaddr->sin_port, NSInternalInconsistencyException);
      memcpy (&(p->_remote_in_port_address), sockaddr, sizeof(*sockaddr));
    }
  else
    {
      /* Else, _remote_in_port_address will remain as zero's for the
	 time being, and may get set later by calling
	 +newForSendingToSockaddr..  with a non-zero socket, and a
	 non-NULL sockaddr. */
      memset (&(p->_remote_in_port_address), '\0', sizeof(*sockaddr));
    }

  /* xxx Do I need to bind(_port_socket) to this address?  I don't think so. */

  /* Connect the socket to its destination, (if it hasn't been done 
     already by a previous accept() call. */
  if (!sock) {
      int	rval;

      NSAssert(p->_remote_in_port_address.sin_family, NSInternalInconsistencyException);

      if (connect (p->_port_socket,
		   (struct sockaddr*)&(p->_remote_in_port_address), 
		   sizeof(p->_remote_in_port_address)) < 0)
	{
	  [p release];
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] connect(): %s",
	      strerror(errno)];
	}

      /*
       *	Ensure the socket is non-blocking.
       */
      if ((rval = fcntl(p->_port_socket, F_GETFL, 0)) >= 0) {
	rval |= NBLK_OPT;
	if (fcntl(p->_port_socket, F_SETFL, rval) < 0) {
	  [p release];
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] fcntl(SET): %s",
	      strerror(errno)];
	}
      }
      else {
	[p release];
	[NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] fcntl(GET): %s",
	      strerror(errno)];
      }

    }

  /* Put it in the shared socket->port map table. */
  NSAssert(!NSMapGet (socket_2_port, (void*)p->_port_socket), NSInternalInconsistencyException);
  NSMapInsert (socket_2_port, (void*)p->_port_socket, p);

  /* Put it in TcpOutPort's registry. */
  NSMapInsert (out_port_bag, (void*)p, (void*)p);

  return p;
}

+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (NSString*)hostname
{
  struct hostent *hp;
  const char *host_cstring;
  struct sockaddr_in addr;
  /* Only used if no hostname is passed in. */
  char local_hostname[MAXHOSTNAMELEN];

  /* Look up the hostname. */
  if (!hostname || ![hostname length])
    {
      int len = sizeof (local_hostname);
      char *first_dot;
      if (gethostname (local_hostname, len) < 0)
	{
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToPortNumber:onHost:] gethostname(): %s",
	      strerror(errno)];
	}
      host_cstring = local_hostname;
      first_dot = strchr (host_cstring, '.');
      if (first_dot)
	*first_dot = '\0';
    }
  else
    host_cstring = [hostname cString];
  hp = gethostbyname ((char*)host_cstring);
  if (!hp)
    [self error: "unknown host: \"%s\"", host_cstring];

  /* Get the sockaddr_in address. */
  memcpy (&addr.sin_addr, hp->h_addr, hp->h_length);
  addr.sin_family = AF_INET;
  addr.sin_port = GSSwapHostI16ToBig (n);

  return [self newForSendingToSockaddr: &addr
	       withAcceptedSocket: 0
	       pollingInPort: nil];
}

+ newForSendingToRegisteredName: (NSString*)name 
			 onHost: (NSString*)hostname
{
  id	c;

  c = [[NSPortNameServer defaultPortNameServer] portForName: name
						     onHost: hostname];
  return [c retain];
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
      [NSException raise: NSInternalInconsistencyException
	  format: @"[TcpInPort newWithAcceptedSocket:] getsockname(): %s",
	  strerror(errno)];
    }
  NSAssert(size == sizeof (struct sockaddr_in), NSInternalInconsistencyException);
  /* xxx Perhaps I have to get peer name here!! */
  NSAssert(GSSwapBigI16ToHost(addr.sin_port) != [p portNumber], NSInternalInconsistencyException);
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

- (BOOL) sendPacket: packet timeout: (NSTimeInterval)timeout
{
  id reply_port = [packet replyInPort];

  NSAssert(is_valid, NSInternalInconsistencyException);

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
     and the port addresses.  If REPLY_PORT is nil, the third argument
     to this call with be NULL, and
	__writeToSocket:withSendPort:withReceivePort:timeout:
     will know that there is no reply port. */
  [packet _writeToSocket: _port_socket 
	    withSendPort: self
	 withReceivePort: reply_port
		 timeout: timeout];
  return YES;
}

- (int) _port_socket
{
  return _port_socket;
}

- (int) portNumber
{
  return (int) GSSwapBigI16ToHost (_remote_in_port_address.sin_port);
}

- (void) close
{
  [self invalidate];
}

- (void) invalidate
{
  if (is_valid)
    {
      id	port = _polling_in_port;

      _polling_in_port = nil;

      /* This is here, and not in -dealloc, because invalidated
	 but not dealloc'ed ports should not be returned from
	 the out_port_bag in +newForSendingToSockaddr:... */
      NSMapRemove (out_port_bag, (void*)self);
      /* This is here, and not in -dealloc, because invalidated
	 but not dealloc'ed ports should not be returned from
	 the socket_2_port in +newForSendingToSockaddr:... */
      NSMapRemove (socket_2_port, (void*)_port_socket);

      /* This also posts a NSPortDidBecomeInvalidNotification. */
      [super invalidate];

      /* xxx Perhaps should delay this close() to keep another port from
	 getting it.  This may help Connection invalidation confusion. */
      if (_port_socket > 0)
	{
    #ifdef	__WIN32__
          if (closesocket (_port_socket) < 0)
    #else
          if (close (_port_socket) < 0)
    #endif /* __WIN32 */
	    {
	      [NSException raise: NSInternalInconsistencyException
	          format: @"[TcpOutPort -invalidate:] close(): %s",
	          strerror(errno)];
	    }
	}

      [port _connectedOutPortInvalidated: self];
      [port release];
    }
}

- (void) dealloc
{
  [self invalidate];
  [super dealloc];
}

- classForPortCoder
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- replacementObjectForPortCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return self;
}

- (Class) outPacketClass
{
  return [TcpOutPacket class];
}

+ (Class) outPacketClass
{
  return [TcpOutPacket class];
}

- description
{
  return [NSString 
	   stringWithFormat: @"%s%c0x%x host %s port %hd socket %d",
	   object_get_class_name (self),
	   is_valid ? ' ' : '-',
	   (unsigned)self,
	   inet_ntoa (_remote_in_port_address.sin_addr),
	   GSSwapBigI16ToHost(_remote_in_port_address.sin_port),
	   _port_socket];
}

- (void) encodeWithCoder: aCoder
{
  NSAssert(is_valid, NSInternalInconsistencyException);
  NSAssert(!_polling_in_port 
	  || (GSSwapBigI16ToHost(_remote_in_port_address.sin_port)
      != [_polling_in_port portNumber]), NSInternalInconsistencyException);
  /* Encode these at bytes, not as C-variables, because they are
     already in "network byte-order". */
  [aCoder encodeBytes: &_remote_in_port_address.sin_port
	  count: sizeof (_remote_in_port_address.sin_port)
	  withName: @"socket number"];
  [aCoder encodeBytes: &_remote_in_port_address.sin_addr.s_addr
	  count: sizeof (_remote_in_port_address.sin_addr.s_addr)
	  withName: @"inet address"];
  if (debug_tcp_port)
    NSLog(@"TcpOutPort encoded port %hd host %s\n",
	    GSSwapBigI16ToHost(_remote_in_port_address.sin_port),
	    inet_ntoa (_remote_in_port_address.sin_addr));
}

+ newWithCoder: aCoder
{
  struct sockaddr_in addr;

  addr.sin_family = AF_INET;
  [aCoder decodeBytes: &addr.sin_port
	  count: sizeof (addr.sin_port)
	  withName: NULL];
  [aCoder decodeBytes: &addr.sin_addr.s_addr
	  count: sizeof (addr.sin_addr.s_addr)
	  withName: NULL];
  if (debug_tcp_port)
    NSLog(@"TcpOutPort decoded port %hd host %s\n",
	    GSSwapBigI16ToHost(addr.sin_port),
	    inet_ntoa (addr.sin_addr));
  return [TcpOutPort newForSendingToSockaddr: &addr
		     withAcceptedSocket: 0
		     pollingInPort: nil];
}

@end


/* In and Out Packet classes. */

#define PREFIX_LENGTH_TYPE gsu32
#define PREFIX_LENGTH_SIZE sizeof (PREFIX_LENGTH_TYPE)
#define PREFIX_ADDRESS_TYPE struct sockaddr_in
#define PREFIX_ADDRESS_SIZE sizeof (PREFIX_ADDRESS_TYPE)
#define	PREFIX_SP_OFF	PREFIX_LENGTH_SIZE
#define	PREFIX_RP_OFF	(PREFIX_LENGTH_SIZE + PREFIX_ADDRESS_SIZE)
#define PREFIX_SIZE (PREFIX_LENGTH_SIZE + 2*PREFIX_ADDRESS_SIZE)

@implementation TcpInPacket

+ (void) _getPacketSize: (int*)packet_size 
	    andSendPort: (id*)sp
	 andReceivePort: (id*)rp
             fromSocket: (int)s
{
  char	prefix_buffer[PREFIX_SIZE];
  int	c;
  
  c = tryRead (s, 3, prefix_buffer, PREFIX_SIZE);
  if (c <= 0)
    {
      *packet_size = EOF;
      *sp = nil;
      *rp = nil;
      return;
    }
  if (c != PREFIX_SIZE)
    {
      /* Was: [self error: "Failed to get packet prefix from socket."]; */
      /* xxx Currently treating this the same as EOF, but perhaps
	 we should treat it differently. */
      fprintf (stderr, "[%s %s]: Got %d chars instead of full prefix\n",
	       class_get_class_name (self), sel_get_name (_cmd), c);
      *packet_size = EOF;
      *sp = nil;
      *rp = nil;
      return;
    }      

  /* *size is the number of bytes in the packet, not including 
     the PREFIX_SIZE-byte header. */
  *packet_size = GSSwapBigI32ToHost (*(PREFIX_LENGTH_TYPE*) prefix_buffer);
  NSAssert(packet_size, NSInternalInconsistencyException);

  /* If the reply address is non-zero, and the TcpOutPort for this socket
     doesn't already have its _address ivar set, then set it now. */
  {
    struct sockaddr_in addr;

    /* Use memcpy instead of simply casting the pointer because
       some systems fail to do the cast correctly (due to alignment issues?) */

    /*
     *	Get the senders send port (our receive port)
     */
    memcpy (&addr, prefix_buffer + PREFIX_SP_OFF, sizeof (typeof (addr)));
    if (addr.sin_family)
      {
	gsu16	pnum = GSSwapBigI16ToHost(addr.sin_port);

        *sp = [TcpInPort newForReceivingFromPortNumber: pnum];
	[(*sp) autorelease];
      }
    else
      *sp = nil;

    /*
     *	Now get the senders receive port (our send port)
     */
    memcpy (&addr, prefix_buffer + PREFIX_RP_OFF, sizeof (typeof (addr)));
    if (addr.sin_family)
      {
        *rp = [TcpOutPort newForSendingToSockaddr: &addr
			       withAcceptedSocket: s
				    pollingInPort: *sp];
	[(*rp) autorelease];
      }
    else
      *rp = nil;
  }
}

- (int) _fillFromSocket: (int)s
{
  int c;
  int remaining;

  remaining = [data length] - prefix - eof_position;
  c = tryRead(s, 1, [data mutableBytes] + prefix + eof_position, -remaining);
  if (c <= 0) {
    return EOF;
  }
  eof_position += c;
  return remaining - c;
}

@end

@implementation TcpOutPacket

+ (unsigned) prefixSize
{
  return PREFIX_SIZE;
}

- (void) _writeToSocket: (int)s 
	   withSendPort: (id)sp
	withReceivePort: (id)rp
                timeout: (NSTimeInterval)timeout
{
  struct sockaddr_in	*addr;
  int			c;

  if (debug_tcp_port > 1)
    NSLog(@"%s: Write to socket %d\n", object_get_class_name (self), s);

  /* Put the packet size in the first four bytes of the packet. */
  NSAssert(prefix == PREFIX_SIZE, NSInternalInconsistencyException);
  *(PREFIX_LENGTH_TYPE*)[data mutableBytes] = GSSwapHostI32ToBig(eof_position);

  addr = [sp _remoteInPortSockaddr];
  /* Put the sockaddr_in for replies in the next bytes of the prefix
     region.  If there is no reply address specified, fill it with zeros. */
  if (addr)
    /* Do this memcpy instead of simply casting the pointer because
       some systems fail to do the cast correctly (due to alignment issues?) */
    memcpy ([data mutableBytes]+PREFIX_SP_OFF, addr, PREFIX_ADDRESS_SIZE);
  else
    memset ([data mutableBytes]+PREFIX_SP_OFF, 0, PREFIX_ADDRESS_SIZE);

  addr = [rp _listeningSockaddr];
  /* Put the sockaddr_in for the destination in the next bytes of the prefix
     region.  If there is no destination address specified, fill with zeros. */
  if (addr)
    /* Do this memcpy instead of simply casting the pointer because
       some systems fail to do the cast correctly (due to alignment issues?) */
    memcpy ([data mutableBytes]+PREFIX_RP_OFF, addr, PREFIX_ADDRESS_SIZE);
  else
    memset ([data mutableBytes]+PREFIX_RP_OFF, 0, PREFIX_ADDRESS_SIZE);

  /* Write the packet on the socket. */
  c = tryWrite (s, (int)timeout, (unsigned char*)[data bytes], prefix + eof_position);
  if (c == -2) {
    [NSException raise: NSPortTimeoutException
	format: @"[TcpOutPort -_writeToSocket:] write() timed out"];
  }
  else if (c < 0) {
    [NSException raise: NSInternalInconsistencyException
	format: @"[TcpOutPort -_writeToSocket:] write(): %s",
	strerror(errno)];
  }
  if (c != prefix + eof_position) {
    [NSException raise: NSInternalInconsistencyException
	format: @"[TcpOutPort -_writeToSocket:] partial write(): %s",
	strerror(errno)];
  }
}

@end
