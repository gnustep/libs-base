/* Implementation of socket-based port object for use with Connection
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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

#include <objects/SocketPort.h>
#include <netdb.h>
#include <objc/hash.h>
#include <objects/Lock.h>
#include <objc/List.h>
#include <sys/time.h>
#include <objects/Connection.h>
#include <objects/Coder.h>
#include <objects/ConnectedCoder.h>
#include <objects/String.h>
#include <assert.h>

#if _AIX
#include <sys/select.h>
#endif /* _AIX */

/* Deal with bcopy: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define index strchr
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

/* Make this a hashtable? */
static List* socketPortList;
static Lock*  socketPortListGate;

static BOOL socket_port_debug = NO;

/* xxx This function is just temporary.
   Eventually we should write a real name server for sockets */
static unsigned int
name_to_port_number (const char *name)
{
  unsigned int ret = 0;
  unsigned int ctr = 0;
        
  while (*name) 
    {
      ret ^= *name++ << ctr;
      ctr = (ctr + 1) % sizeof (void *);
    }
  return ret % (65535 - IPPORT_USERRESERVED - 1);
}

@implementation SocketPort 

+ (void) initialize
{
  if ([self class] == [SocketPort class])
    {
      socketPortList = [[List alloc] init];
      socketPortListGate = [Lock new];
    }
}

+ setDebug: (BOOL)f
{
  socket_port_debug = f;
  return self;
}

+ newPortFromRegisterWithName: (String*)name onHost: (String*)h
{
  id p;
  int n;

#if SOCKETPORT_NUMBER_NAMES_ONLY
  if ((n = atoi([name cString])) == 0)
    [self error:"Name (%s) is not a number", [name cString]];
#else
  n = name_to_port_number([name cString]);
#endif
  p = [SocketPort newRemoteWithNumber:n onHost:h];
  return p;
}

+ newRegisteredPortWithName: (String*)name
{
  int n;

#if SOCKET_NUMBER_NAMES_ONLY
  if ((n = atoi([name cString])) == 0)
    return nil;
#else
  n = name_to_port_number([name cString]);
#endif
  return [SocketPort newLocalWithNumber:n];
}

+ newPort
{
  return [self newLocal];
}

/* xxx Change this to consider INADDR_ANY and the localhost address
   to be equal. */
#define SOCKPORT_EQUAL(s1,s2) \
(s1.sin_port == s2.sin_port && \
s1.sin_addr.s_addr == s2.sin_addr.s_addr)
/* Assume that sin_family is equal */

/* (!memcmp(&s1, &s2, sizeof(sockport_t))) 
   didn't work because sin_zero's differ.  Does this matter? */

+ newForSockPort: (sockport_t)s close: (BOOL)f
{
  SocketPort* sp;
  int i, count;
  sockport_t a;

  [socketPortListGate lock];

  /* See if there is already one created */
  count = [socketPortList count];
  for (i = 0; i < count; i++)
    {
      sp = [socketPortList objectAt:i];
      a = [sp sockPort];
      if (SOCKPORT_EQUAL(a, s))
	{
	  [socketPortListGate unlock];
	  return sp;
	}
    }

  /* No, create a new one */
  if (s.sin_family != AF_INET)
    [self error:"we don't do non INET socket addresses"];
  sp = [[self alloc] init];
  sp->sockPort = s;
  sp->close_on_dealloc = f;
  /* Before we allowed (s.sin_addr.s_addr == htonl(INADDR_LOOPBACK) also,
     but then we couldn't have both server and client on the same
     machine.  It would think that the client's out port to the server's
     in port should be bind()'ed, but the server already did that. */
  if (s.sin_addr.s_addr == INADDR_ANY)
    {
      /* it's local */
      if ((sp->sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
        {
          perror("creating socket");
          [self error:"creating socket"];
        }
      i = sizeof(sockport_t);
      if (bind(sp->sock, (struct sockaddr*)&sp->sockPort, i))
	{
	  perror("bind");
	  [self error:"binding socket"];
	}
      if (getsockname(sp->sock, (struct sockaddr*)&sp->sockPort, &i))
	{
	  perror("getsockname");
	  [self error:"getsockname socket"];
	}
      if (socket_port_debug)
	fprintf(stderr, "new socket(), fd=%d\n", sp->sock);
    }
  if (socket_port_debug)
    fprintf(stderr, "created new SocketPort 0x%x, number %d\n",
	   (unsigned)sp, [sp socketPortNumber]);
  [socketPortList addObject:sp];
  [socketPortListGate unlock];

  return sp;
}

- (void) dealloc
{
  if (sock && close_on_dealloc)
    close(sock);
  [super dealloc];
  return;
}

+ newForSockPort: (sockport_t)s
{
  return [self newForSockPort:s close:YES];
}

+ newLocalWithNumber: (int)n
{
  sockport_t s;
  SocketPort* sp;

  /* xxx clean this up */
  if (n > 65535 - IPPORT_USERRESERVED - 1)
    [self error:"port number too high"];
  n += IPPORT_USERRESERVED + 1;

  /* xxx bzero(&s, sizeof(s)) necessary here? */
  s.sin_family = AF_INET;
  s.sin_addr.s_addr = INADDR_ANY;
  s.sin_port = htons(n);
  sp = [self newForSockPort:s close:YES];
  return sp;
}

+ newLocal
{
  id sp;
  sockport_t a;

  a.sin_family = AF_INET;
  a.sin_addr.s_addr = INADDR_ANY;
  a.sin_port = 0;
  sp = [self newForSockPort:a];
  return sp;
}

+ newRemoteWithNumber: (int)n onHost: (String*)h
{
  struct sockaddr_in remote_addr;
  struct hostent *hp;
  const char *hs;

  /* xxx clean this up */
  if (n > 65535 - IPPORT_USERRESERVED - 1)
    [self error:"port number too high"];
  n += IPPORT_USERRESERVED + 1;

  if (!h || ![h length])
    hs = "localhost";
  else
    hs = [h cString];

  hp = gethostbyname((char*)hs);
  if (hp == 0)
    [self error:"unknown host: \"%s\"", hs];
  bcopy(hp->h_addr, &remote_addr.sin_addr, hp->h_length);
  remote_addr.sin_family = AF_INET;
  remote_addr.sin_port = htons(n);
  return [self newForSockPort:remote_addr];
}


/* This currently ignores the timeout parameter */

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*)remote
   timeout: (int) milliseconds;
{
  int r;
  sockport_t a;

  if (![remote isKindOfClass:[SocketPort class]])
    [self error:"Trying to send to a non-SocketPort"];
  a = [(SocketPort*)remote sockPort];
  if (socket_port_debug)
    fprintf(stderr, "sending to %d\n", [(SocketPort*)remote socketPortNumber]);
  if ((r = sendto([self socket], (char*)b, l, 0, (struct sockaddr *)&a, 
		  sizeof(sockport_t))) 
      < 0)
    {
      perror("sendto");
      [self error:"sendto"];
    }
  return r;
}

/* Returns -1 on timeout.
   Pass -1 for milliseconds to ignore timeout parameter and block indefinitely.
*/

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
   timeout: (int) milliseconds;
{
  int r;
  struct sockaddr_in remote_addr;
  int remote_len;
  int local_sock;

  if (socket_port_debug)
    fprintf(stderr, "receiving from %d\n", [self socketPortNumber]);

  local_sock = [self socket];

  if (milliseconds >= 0)
    {
      struct timeval timeout;
      fd_set ready;

      timeout.tv_sec = milliseconds / 1000;
      timeout.tv_usec = (milliseconds % 1000) * 1000;
      FD_ZERO(&ready);
      FD_SET(local_sock, &ready);
      if ((r = select(local_sock + 1, &ready, 0, 0, &timeout)) < 0)
	{
	  perror("select");
	  [self error:"select"];
	}
      if (r == 0)		/* timeout */
	return -1;
      if (!FD_ISSET(local_sock, &ready))
	[self error:"select lied"];
    }

  remote_len = sizeof(sockport_t);
  if ((r = recvfrom(local_sock, b, l, 0, (struct sockaddr*)&remote_addr, 
		    &remote_len)) 
      < 0)
    {
      perror("recvfrom");
      [self error:"recvfrom"];
    }
  if (remote_len != sizeof(sockport_t))
    [self error:"remote address size mismatch"];
  *remote = [[self class] newForSockPort:remote_addr close:NO];
  return r;
}

- (sockport_t) sockPort
{
  return sockPort;
}

- classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfType:@encode(typeof(sockPort.sin_port))
	  at:&sockPort.sin_port 
	  withName:"socket number"];
  if (![self isSoft])
    {
      struct hostent *hp;
      sockport_t sp;

      /* xxx this could be cleaned up */
      hp = gethostbyname("localhost");
      if (hp == 0)
	[self error:"gethostbyname(): can't get host info"];
      bcopy(hp->h_addr, &sp.sin_addr, hp->h_length);
      [aCoder encodeValueOfType:@encode(typeof(sp.sin_addr.s_addr))
	      at:&sp.sin_addr.s_addr
	      withName:"inet address"];
    }
  else
    {
      [aCoder encodeValueOfType:@encode(typeof(sockPort.sin_addr.s_addr))
	      at:&sockPort.sin_addr.s_addr
	      withName:"inet address"];
    }
}

+ newWithCoder: aCoder
{
  sockport_t sp;

  sp.sin_family = AF_INET;
  [aCoder decodeValueOfType:@encode(typeof(sp.sin_port))
	  at:&sp.sin_port 
	  withName:NULL];
  [aCoder decodeValueOfType:@encode(typeof(sp.sin_addr.s_addr))
	  at:&sp.sin_addr.s_addr
	  withName:NULL];
  return [SocketPort newForSockPort:sp];
}

- (int) socket
{
  return sock;
}

- (BOOL) isSoft
{
  if (sock)
    return NO;
  else
    return YES;
}

- (int) socketPortNumber
{
  return (int) ntohs(sockPort.sin_port);
}

- (unsigned) hash
{
  unsigned h = [self socketPortNumber] + sockPort.sin_addr.s_addr;
  return h;
}

- (BOOL) isEqual: anotherPort
{
  sockport_t s = [anotherPort sockPort];
  if (SOCKPORT_EQUAL(s, sockPort))
    {
      /* xxx Is this really a problem? */
      if (self != anotherPort)
	[self error:
	      "Another SocketPort object with the same underlying address!"];
      return YES;
    }
  return NO;
}

@end
