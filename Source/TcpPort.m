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
#include <gnustep/base/preface.h>
#include <gnustep/base/TcpPort.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <gnustep/base/Invocation.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#ifndef __WIN32__
#include <unistd.h>		/* for gethostname() */
#include <sys/param.h>		/* for MAXHOSTNAMELEN */
#include <arpa/inet.h>		/* for inet_ntoa() */
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/file.h>
/*
 *	Stuff for setting the sockets into non-blocking mode.
 */
#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#define	GDOMAP	1	/* 1 = Use name server.	*/
#define	stringify_it(X)	#X
#define	make_gdomap_cmd(X)	stringify_it(X) "/Tools/"GNUSTEP_TARGET_DIR"/gdomap &"
#define	make_gdomap_err(X)	"check that " stringify_it(X) "/Tools/"GNUSTEP_TARGET_DIR"/gdomap is running and owned by root."

#endif /* !__WIN32__ */
#include <string.h>		/* for memset() and strchr() */
#ifndef __WIN32__
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/errno.h>
#endif /* !__WIN32__ */

/* On some systems FD_ZERO is a macro that uses bzero().
   Just define it to use GCC's builtin memset(). */
#define bzero(PTR, LEN) memset (PTR, 0, LEN)

static int debug_tcp_port = 0;



@interface TcpPrefPacket : TcpInPacket
@end
@implementation TcpPrefPacket
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
	   andReplyPort: (id*)rp
             fromSocket: (int)s
	         inPort: ip;
@end

@interface TcpOutPacket (Private)
- (void) _writeToSocket: (int)s 
       withReplySockaddr: (struct sockaddr_in*)addr
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



#ifdef	GDOMAP
/*
 *	Code to contact distributed objects name server.
 */
#include	"../Tools/gdomap.h"

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
    FD_ZERO(&fds);
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
    FD_ZERO(&fds);
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
      void	(*ifun)();

      /*
       *	Should be able to write this short a message immediately, but
       *	if the connection is lost we will get a signal we must trap.
       */
      ifun = signal(SIGPIPE, (void(*)(int))SIG_IGN);
      rval = write(desc, &dat[pos], len - pos);
      signal(SIGPIPE, ifun);

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

/*
 *	Name -		tryHost()
 *	Purpose -	Perform a name server operation with a given
 *			request packet to a server at specified address.
 *			On error - return non-zero with reason in 'errno'
 */
static int
tryHost(unsigned char op, unsigned char len, const unsigned char* name,
struct sockaddr_in* addr, unsigned short* p, unsigned char **v)
{
    int desc = socket(AF_INET, SOCK_STREAM, 0);
    int	e = 0;
    unsigned long	port = *p;
    gdo_req		msg;
    struct sockaddr_in sin;

    *p = 0;
    if (desc < 0) {
	return(1);	/* Couldn't create socket.	*/
    }

    if ((e = fcntl(desc, F_GETFL, 0)) >= 0) {
	e |= NBLK_OPT;
	if (fcntl(desc, F_SETFL, e) < 0) {
	    e = errno;
	    close(desc);
	    errno = e;
	    return(2);	/* Couldn't set non-blocking.	*/
	}
    }
    else {
	e = errno;
	close(desc);
	errno = e;
	return(2);	/* Couldn't set non-blocking.	*/
    }

    memcpy(&sin, addr, sizeof(sin));
    if (connect(desc, (struct sockaddr*)&sin, sizeof(sin)) != 0) {
	if (errno == EINPROGRESS) {
	    e = tryWrite(desc, 10, 0, 0);
	    if (e == -2) {
		e = errno;
		close(desc);
		errno = e;
		return(3);	/* Connect timed out.	*/
	    }
	    else if (e == -1) {
		e = errno;
		close(desc);
		errno = e;
		return(3);	/* Select failed.	*/
	    }
	}
	else {
	    e = errno;
	    close(desc);
	    errno = e;
	    return(3);		/* Failed connect.	*/
	}
    }

    memset((char*)&msg, '\0', GDO_REQ_SIZE);
    msg.rtype = op;
    msg.nsize = len;
    msg.ptype = GDO_TCP_GDO;
    if (op != GDO_REGISTER) {
	port = 0;
    }
    msg.port = htonl(port);
    memcpy(msg.name, name, len);

    e = tryWrite(desc, 10, (unsigned char*)&msg, GDO_REQ_SIZE);
    if (e != GDO_REQ_SIZE) {
	e = errno;
	close(desc);
	errno = e;
	return(4);
    }
    e = tryRead(desc, 3, (unsigned char*)&port, 4);
    if (e != 4) {
	e = errno;
	close(desc);
	errno = e;
	return(5);	/* Read timed out.	*/
    }
    port = ntohl(port);

/*
 *	Special case for GDO_SERVERS - allocate buffer and read list.
 */
    if (op == GDO_SERVERS) {
	int	len = port * sizeof(struct in_addr);
	unsigned char*	b;

	b = (unsigned char*)objc_malloc(len);
	if (tryRead(desc, 3, b, len) != len) {
	    objc_free(b);
	    e = errno;
	    close(desc);
	    errno = e;
	    return(5);
	}
	*v = b;
    }

    *p = (unsigned short)port;
    close(desc);
    errno = 0;
    return(0);
}

/*
 *	Name -		nameFail()
 *	Purpose -	If given a failure status from tryHost()
 *			raise an appropriate exception.
 */
static void
nameFail(int why)
{
    switch (why) {
	case 0:	break;
	case 1:
	    [NSException raise: NSInternalInconsistencyException
		format: @"failed to contact name server - socket - %s - %s",
		strerror(errno),
	        make_gdomap_err(GNUSTEP_INSTALL_PREFIX)];
	case 2:
	    [NSException raise: NSInternalInconsistencyException
		format: @"failed to contact name server - socket - %s - %s",
		strerror(errno),
	        make_gdomap_err(GNUSTEP_INSTALL_PREFIX)];
	case 3:
	    [NSException raise: NSInternalInconsistencyException
		format: @"failed to contact name server - socket - %s - %s",
		strerror(errno),
	        make_gdomap_err(GNUSTEP_INSTALL_PREFIX)];
	case 4:
	    [NSException raise: NSInternalInconsistencyException
		format: @"failed to contact name server - socket - %s - %s",
		strerror(errno),
	        make_gdomap_err(GNUSTEP_INSTALL_PREFIX)];
    }
}

/*
 *	Name -		nameServer()
 *	Purpose -	Perform name server lookup or registration.
 *			Return success/failure status and set up an
 *			address structure for use in bind or connect.
 *	Restrictions -	0xffff byte name limit
 *			Uses old style host lookup - only handles the
 *			primary network interface for each host!
 */
static int
nameServer(const char* name, const char* host, int op, struct sockaddr_in* addr, int pnum, int max)
{
    struct sockaddr_in	sin;
    struct servent*	sp;
    struct hostent*	hp;
    unsigned short	p = htons(GDOMAP_PORT);
    unsigned short	port = 0;
    int			len = strlen(name);
    int			multi = 0;
    int			found = 0;
    int			rval;
    char local_hostname[MAXHOSTNAMELEN];

    if (len == 0) {
        [NSException raise: NSInternalInconsistencyException
		format: @"no name specified"];
    }
    if (len > 255) {
        [NSException raise: NSInternalInconsistencyException
		format: @"name length to large (>255 characters)"];
    }

    /*
     *	Ensure we have port number to connect to name server.
     *	The TCP service name 'gdomap' overrides the default port.
     */
    if ((sp = getservbyname("gdomap", "tcp")) != 0) {
	p = sp->s_port;		/* Network byte order.	*/
    }

    /*
     *	The host name '*' matches any host on the local network.
     */
    if (host && host[0] == '*' && host[1] == '\0') {
	multi = 1;
    }
    /*
     *	If no host name is given, we use the name of the local host.
     *	NB. This should always be the case for operations other than lookup.
     */
    if (multi || host == 0 || *host == '\0') {
        char *first_dot;

        if (gethostname(local_hostname, sizeof(local_hostname)) < 0) {
	    [NSException raise: NSInternalInconsistencyException
		format: @"gethostname() failed: %s", strerror(errno)];
	}
        first_dot = strchr(local_hostname, '.');
        if (first_dot) {
	    *first_dot = '\0';
	}
	host = local_hostname;
    }
    if ((hp = gethostbyname(host)) == 0) {
	[NSException raise: NSInternalInconsistencyException
		format: @"get host address for %s", host];
    }
    if (hp->h_addrtype != AF_INET) {
	[NSException raise: NSInternalInconsistencyException
		format: @"non-internet network not supported for %s", host];
    }

    memset((char*)&sin, '\0', sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_port = p;
    memcpy((caddr_t)&sin.sin_addr, hp->h_addr, hp->h_length);

    if (multi) {
	unsigned short	num;
	struct in_addr*	b;

	/*
	 *	A host name of '*' is a special case which should do lookup on
	 *	all machines on the local network until one is found which has 
	 *	the specified server on it.
	 */
	rval = tryHost(GDO_SERVERS, 0, 0, &sin, &num, (unsigned char**)&b);
	/*
	 *	If the connection to the local name server fails,
	 *	attempt to start it us and retry the lookup.
	 */
	if (rval != 0 && host == local_hostname) {
	    system(make_gdomap_cmd(GNUSTEP_INSTALL_PREFIX));
	    sleep(5);
	    rval = tryHost(GDO_SERVERS, 0, 0, &sin, &num, (unsigned char**)&b);
	}
	if (rval == 0) {
	    int	i;

	    for (i = 0; found == 0 && i < num; i++) {
		memset((char*)&sin, '\0', sizeof(sin));
		sin.sin_family = AF_INET;
		sin.sin_port = p;
		memcpy((caddr_t)&sin.sin_addr, &b[i], sizeof(struct in_addr));
		if (sin.sin_addr.s_addr == 0) continue;

		if (tryHost(GDO_LOOKUP, len, name, &sin, &port, 0) == 0) {
		    if (port != 0) {
			memset((char*)&addr[found], '\0', sizeof(*addr));
			memcpy((caddr_t)&addr[found].sin_addr, &sin.sin_addr,
				sizeof(sin.sin_addr));
			addr[found].sin_family = AF_INET;
			addr[found].sin_port = htons(port);
			found++;
			if (found == max) {
			    break;
			}
		    }
		}
	    }
	    objc_free(b);
	    return(found);
	}
	else {
	    nameFail(rval);
	}
    }
    else {
        if (op == GDO_REGISTER) {
	    port = (unsigned short)pnum;
	}
	rval = tryHost(op, len, name, &sin, &port, 0);
	/*
	 *	If the connection to the local name server fails,
	 *	attempt to start it us and retry the lookup.
	 */
	if (rval != 0 && host == local_hostname) {
	    system(make_gdomap_cmd(GNUSTEP_INSTALL_PREFIX));
	    sleep(5);
            if (op == GDO_REGISTER) {
	        port = (unsigned short)pnum;
	    }
	    rval = tryHost(op, len, name, &sin, &port, 0);
	}
	nameFail(rval);
    }

    if (op == GDO_REGISTER) {
	if (port == 0 || (pnum != 0 && port != pnum)) {
	    [NSException raise: NSInternalInconsistencyException
		format: @"service already registered"];
	}
    }
    if (port == 0) {
	return 0;
    }
    memset((char*)addr, '\0', sizeof(*addr));
    memcpy((caddr_t)&addr->sin_addr, &sin.sin_addr, sizeof(sin.sin_addr));
    addr->sin_family = AF_INET;
    addr->sin_port = htons(port);
    return 1;
}

#else
/* The old hash code for a name server. */

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
#endif	/* GDOMAP */


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
    port_number_2_port = 
      NSCreateMapTable (NSIntMapKeyCallBacks,
			NSNonOwnedPointerMapValueCallBacks, 0);
  init_port_socket_2_port ();
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
      [NSException raise: NSInternalInconsistencyException
	  format: @"[TcpInPort +newForReceivingFromPortNumber:] socket(): %s",
	  strerror(errno)];
    }

  /* Register the port object according to its socket. */
  assert (!NSMapGet (socket_2_port, (void*)p->_port_socket));
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
    p->_listening_address.sin_addr.s_addr = htonl (INADDR_ANY);
    p->_listening_address.sin_family = AF_INET;
    p->_listening_address.sin_port = htons (n);
    /* N may be zero, in which case bind() will choose a port number
       for us. */
    if (bind (p->_port_socket,
	      (struct sockaddr*) &(p->_listening_address),
	      sizeof (p->_listening_address)) 
	< 0)
      {
	[NSException raise: NSInternalInconsistencyException
	  format: @"[TcpInPort +newForReceivingFromPortNumber:] bind(): %s",
	  strerror(errno)];
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
	    [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort +newForReceivingFromPortNumber:] getsockname(): %s",
	      strerror(errno)];

	  }
	assert (p->_listening_address.sin_port);
	n = ntohs(p->_listening_address.sin_port);
      }

    /* Now change _LISTENING_ADDRESS to the specific network address of this
       machine so that, when we encoded our _LISTENING_ADDRESS for a
       Distributed Objects connection to another machine, they get our
       unique host address that can identify us across the network. */
    if (gethostname (hostname, len) < 0)
      {
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
    assert (hp);
    memcpy (&(p->_listening_address.sin_addr), hp->h_addr, hp->h_length);
  }

  /* Set it up to accept connections, let 10 pending connections queue */
  /* xxx Make this "10" a class variable? */
  if (listen (p->_port_socket, 10) < 0)
    {
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
#ifdef	GDOMAP
  TcpInPort*		p = [self newForReceivingFromPortNumber: 0];
  struct sockaddr_in	sin;

  if (p) {
    int	port = [p portNumber];

    if (nameServer([name cStringNoCopy], 0, GDO_REGISTER, &sin, port, 1) == 0) {
      [p release];
      return nil;
    }
  }
  return p;
#else
  return [self newForReceivingFromPortNumber: 
		 name_2_port_number ([name cStringNoCopy])];
#endif	/* GDOMAP */
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
  assert (is_valid);
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
	  id reply_port;
	  [TcpInPacket _getPacketSize: &packet_size
		       andReplyPort: &reply_port
		       fromSocket: fd_index
		       inPort: self];
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
			 receivingInPort: self
			 replyOutPort: reply_port];
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
	  assert (packet && [packet class]);
          NSMapRemove(_client_sock_2_packet, (void*)fd_index);
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
  assert (*count > NSCountMapTable (_client_sock_2_out_port));

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

assert(type == ET_RPORT);

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

  assert (is_valid);
  /* Make sure it hasn't already been added. */
  assert (!NSMapGet (_client_sock_2_out_port, (void*)s));

 /* Add it, and put its socket in the set of file descriptors we poll. */
  NSMapInsert (_client_sock_2_out_port, (void*)s, p);
}

/* Called by an OutPort in its -invalidate method. */
- (void) _connectedOutPortInvalidated: p
{
  id packet;
  int s = [p _port_socket];

  assert (is_valid);
  if (debug_tcp_port)
    fprintf (stderr, 
	     "%s: Closed connection from\n %s\n",
	     object_get_class_name (self),
	     [[p description] cStringNoCopy]);

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
  return (int) ntohs (_listening_address.sin_port);
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

      for (i = 0; 
	   NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port);
	   i++)
	out_ports[i] = out_port;
      for (i = 0; i < count; i++)
	{
	  /* This will call [self _invalidateConnectedOutPort: for each. */
	  [out_ports[i] invalidate];
	}
      assert (!NSCountMapTable (_client_sock_2_out_port));

      /* xxx Perhaps should delay this close() to keep another port from
	 getting it.  This may help Connection invalidation confusion. 
	 However, then the process might run out of FD's if the close()
	 was delayed too long. */
#ifdef	__WIN32__
      closesocket (_port_socket);
#else
      close (_port_socket);
#endif	/* __WIN32__ */

      /* These are here, and not in -dealloc, to prevent 
	 +newForReceivingFromPortNumber: from returning invalid sockets. */
      NSMapRemove (socket_2_port, (void*)_port_socket);
      NSMapRemove (port_number_2_port,
		   (void*)(int) ntohs(_listening_address.sin_port));

      /* This also posts a NSPortDidBecomeInvalidNotification. */
      [super invalidate];
    }
}

- (void) dealloc
{
  [self invalidate];
  /* assert that these are empty? */
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
	   ntohs (_listening_address.sin_port),
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
  assert (is_valid);
  /* We are actually encoding a "send right" (ala Mach), 
     not a receive right.  
     These values must match those expected by [TcpOutPort +newWithCoder] */
  [super encodeWithCoder: aCoder];
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
	      if (debug_tcp_port)
		printf ("TcpOutPort setting remote address\n%s\n",
			[[self description] cStringNoCopy]);
	    }
	}
      assert (p->is_valid);
      return [p retain];
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
      p->_remote_in_port_address.sin_port = 0;
      p->_remote_in_port_address.sin_addr.s_addr = 0;
    }

  /* xxx Do I need to bind(_port_socket) to this address?  I don't think so. */

  /* Connect the socket to its destination, (if it hasn't been done 
     already by a previous accept() call. */
  if (!sock) {
      int	rval;

      assert (p->_remote_in_port_address.sin_family);

      if (connect (p->_port_socket,
		   (struct sockaddr*)&(p->_remote_in_port_address), 
		   sizeof(p->_remote_in_port_address)) 
	  < 0)
	{
	    close(p->_port_socket);
#if 0
	    [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] connect(): %s",
	      strerror(errno)];
#else
	[p release];
	return nil;
#endif
	}

      /*
       *	Ensure the socket is non-blocking.
       */
      if ((rval = fcntl(p->_port_socket, F_GETFL, 0)) >= 0) {
	rval |= NBLK_OPT;
	if (fcntl(p->_port_socket, F_SETFL, rval) < 0) {
	  close(p->_port_socket);
	  [NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] fcntl(SET): %s",
	      strerror(errno)];
	}
      }
      else {
	close(p->_port_socket);
	[NSException raise: NSInternalInconsistencyException
	      format: @"[TcpInPort newForSendingToSockaddr:...] fcntl(GET): %s",
	      strerror(errno)];
      }

    }

  /* Put it in the shared socket->port map table. */
  assert (!NSMapGet (socket_2_port, (void*)p->_port_socket));
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
    host_cstring = [hostname cStringNoCopy];
  hp = gethostbyname ((char*)host_cstring);
  if (!hp)
    [self error: "unknown host: \"%s\"", host_cstring];

  /* Get the sockaddr_in address. */
  memcpy (&addr.sin_addr, hp->h_addr, hp->h_length);
  addr.sin_family = AF_INET;
  addr.sin_port = htons (n);

  return [self newForSendingToSockaddr: &addr
	       withAcceptedSocket: 0
	       pollingInPort: nil];
}

+ newForSendingToRegisteredName: (NSString*)name 
			 onHost: (NSString*)hostname
{
#ifdef	GDOMAP
  struct sockaddr_in	sin[100];
  int			found;
  int			i;
  id			c = nil;

  found = nameServer([name cStringNoCopy], [hostname cStringNoCopy],
	GDO_LOOKUP, sin, 0, 100);
  for (i = 0; c == nil && i < found; i++)
    {
      c = [self newForSendingToSockaddr: &sin[i]
		     withAcceptedSocket: 0
		     pollingInPort: nil];
    }
  return c;
#else
  return [self newForSendingToPortNumber: 
		 name_2_port_number ([name cStringNoCopy])
	       onHost: hostname];;
#endif	/* GDOMAP */
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

- (BOOL) sendPacket: packet timeout: (NSTimeInterval)timeout
{
  id reply_port = [packet replyInPort];

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
     to this call with be NULL, and __writeToSocket:withReplySockaddr:timeout:
     will know that there is no reply port. */
  [packet _writeToSocket: _port_socket 
	  withReplySockaddr: [reply_port _listeningSockaddr]
		    timeout: timeout];
  return YES;
}

- (int) _port_socket
{
  return _port_socket;
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
  if (is_valid)
    {
      id	port = _polling_in_port;

      _polling_in_port = nil;

      /* This also posts a NSPortDidBecomeInvalidNotification. */
      [super invalidate];

      /* xxx Perhaps should delay this close() to keep another port from
	 getting it.  This may help Connection invalidation confusion. */
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

      /* This is here, and not in -dealloc, because invalidated
	 but not dealloc'ed ports should not be returned from
	 the out_port_bag in +newForSendingToSockaddr:... */
      NSMapRemove (out_port_bag, (void*)self);
      /* This is here, and not in -dealloc, because invalidated
	 but not dealloc'ed ports should not be returned from
	 the socket_2_port in +newForSendingToSockaddr:... */
      NSMapRemove (socket_2_port, (void*)_port_socket);

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
	   ntohs (_remote_in_port_address.sin_port),
	   _port_socket];
}

- (void) encodeWithCoder: aCoder
{
  assert (is_valid);
  [super encodeWithCoder: aCoder];
  assert (!_polling_in_port 
	  || (ntohs (_remote_in_port_address.sin_port)
	      != [_polling_in_port portNumber]));
  /* Encode these at bytes, not as C-variables, because they are
     already in "network byte-order". */
  [aCoder encodeBytes: &_remote_in_port_address.sin_port
	  count: sizeof (_remote_in_port_address.sin_port)
	  withName: @"socket number"];
  [aCoder encodeBytes: &_remote_in_port_address.sin_addr.s_addr
	  count: sizeof (_remote_in_port_address.sin_addr.s_addr)
	  withName: @"inet address"];
  if (debug_tcp_port)
    printf ("TcpOutPort encoded port %hd host %s\n",
	    ntohs (_remote_in_port_address.sin_port),
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
    printf ("TcpOutPort decoded port %hd host %s\n",
	    ntohs (addr.sin_port),
	    inet_ntoa (addr.sin_addr));
  return [TcpOutPort newForSendingToSockaddr: &addr
		     withAcceptedSocket: 0
		     pollingInPort: nil];
}

@end


/* In and Out Packet classes. */

/* If you change this "unsigned short", you must change the use
   of ntohs() and htons() below. */
#define PREFIX_LENGTH_TYPE unsigned short
#define PREFIX_LENGTH_SIZE sizeof (PREFIX_LENGTH_TYPE)
#define PREFIX_ADDRESS_TYPE struct sockaddr_in
#define PREFIX_ADDRESS_SIZE sizeof (PREFIX_ADDRESS_TYPE)
#define PREFIX_SIZE (PREFIX_LENGTH_SIZE + PREFIX_ADDRESS_SIZE)

@implementation TcpInPacket

+ (void) _getPacketSize: (int*)packet_size 
	   andReplyPort: (id*)rp
             fromSocket: (int)s
	         inPort: ip
{
  char prefix_buffer[PREFIX_SIZE];
  int c;
  
#ifdef	GDOMAP
  c = tryRead (s, 3, prefix_buffer, PREFIX_SIZE);
#else
#ifdef	__WIN32__
  c = recv (s, prefix_buffer, PREFIX_SIZE, 0);
#else
  c = read (s, prefix_buffer, PREFIX_SIZE);
#endif	/* __WIN32__ */
#endif	/* GDOMAP */
  if (c <= 0)
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
	       class_get_class_name (self), sel_get_name (_cmd), c);
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
    struct sockaddr_in addr;
    /* Do this memcpy instead of simply casting the pointer because
       some systems fail to do the cast correctly (due to alignment issues?) */
    memcpy (&addr, prefix_buffer + PREFIX_LENGTH_SIZE, sizeof (typeof (addr)));
    if (addr.sin_family)
      {
        *rp = [TcpOutPort newForSendingToSockaddr: &addr
			withAcceptedSocket: s
			pollingInPort: ip];
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
#ifdef	GDOMAP
  c = tryRead(s, 1, [data mutableBytes] + prefix + eof_position, -remaining);
#else
  /* xxx We need to make sure this read() is non-blocking. */
#ifdef	__WIN32__
  c = recv (s, [data mutableBytes] + prefix + eof_position, remaining, 0);
#else
  c = read (s, [data mutableBytes] + prefix + eof_position, remaining);
#endif	/* __WIN32 */
#endif	/* GDOMAP */
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
      withReplySockaddr: (struct sockaddr_in*)addr
                timeout: (NSTimeInterval)timeout
{
  int c;

  /* Put the packet size in the first two bytes of the packet. */
  assert (prefix == PREFIX_SIZE);
  *(PREFIX_LENGTH_TYPE*)[data mutableBytes] = htons (eof_position);

  /* Put the sockaddr_in for replies in the next bytes of the prefix
     region.  If there is no reply address specified, fill it with zeros. */
  if (addr)
    /* Do this memcpy instead of simply casting the pointer because
       some systems fail to do the cast correctly (due to alignment issues?) */
    memcpy ([data mutableBytes]+PREFIX_LENGTH_SIZE, addr, PREFIX_ADDRESS_SIZE);
  else
    memset ([data mutableBytes]+PREFIX_LENGTH_SIZE, 0, PREFIX_ADDRESS_SIZE);

  /* Write the packet on the socket. */
#ifdef	GDOMAP
  c = tryWrite (s, (int)timeout, [data bytes], prefix + eof_position);
#else
#ifdef	__WIN32__
  c = send (s, [data bytes], prefix + eof_position, 0);
#else
  c = write (s, [data bytes], prefix + eof_position);
#endif	/* __WIN32__ */
#endif	/* GDOMAP */
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
