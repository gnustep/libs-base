/** Implementation of a port based on BSD sockets
   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Jonathan Gapen <jagapen@wisc.edu>
   Created: December 2002

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

   <title>NSSocketPort class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSZone.h>

#ifndef __MINGW__
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/param.h>
#include <sys/types.h>
#include <netdb.h>
#include <unistd.h>
#else
#include <winsock2.h>
#include <wininet.h>
#define close closesocket
#endif /* __MINGW__ */


/**
 * <p>
 *   <code>NSSocketPort</code> on MacOS X(tm) is a concrete subclass of
 *   NSPort which implements Distributed Objects communication between
 *   hosts on a network.  However, the GNUstep distributed objects system's 
 *   NSPort class uses TCP/IP for all of its communication.  The GNUstep
 *   <code>NSSocketPort</code>, then, is useful as a convenient method to
 *   create and encapsulate BSD sockets:
 * </p>
 * <example>
 *   int fileDesc;
 *   NSFileHandle *smtpHandle;
 *   
 *   fileDesc = [[NSSocketPort alloc] initRemoteWithTCPPort: 25
 *                                       host: @"mail.example.com"];
 *   smtpHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileDesc];
 * </example>
 */
@implementation NSSocketPort

+ (void) initialize
{
  if (self == [NSSocketPort class])
    {
      [self setVersion: 1];
    }
}

/**
 *   Initialize the receiver with a local socket to accept TCP connections
 *   on a non-conflicting port number chosen by the system.
 */
- (id) init
{
  return [self initWithTCPPort: 0];
}

- (void) dealloc
{
  if (_socket > -1)
  {
    NSDebugMLLog(@"NSSocketPort", @"closing socket descriptor %d", _socket);
    close(_socket);
  }
}

/**
 *   Initialize the receiver as a local socket to accept connections on
 *   TCP port <em>portNumber</em>.  If <em>portNumber</em> is zero,
 *   the system will chose a non-conflicting port number. <br />
 *   NOTE: This method currently does not support IPv6 connections.
 */
- (id) initWithTCPPort: (unsigned short)portNumber
{
  struct sockaddr_in sa;
  NSData *saData;

  /* Clear memory, as recommended. */
  memset(&sa, 0, sizeof(struct sockaddr_in));
  sa.sin_len = sizeof(struct sockaddr_in);
  sa.sin_family = PF_INET;
  sa.sin_port = htons(portNumber);
  sa.sin_addr.s_addr = INADDR_ANY;

  saData = [NSData dataWithBytes: &sa length: sizeof(struct sockaddr_in)];
  if (saData == nil)
  {
    RELEASE(self);
    return nil;
  }

  return [self initWithProtocolFamily: PF_INET
                           socketType: SOCK_STREAM
                             protocol: 0
                              address: saData];
}

/**
 *   Initialize the receiver as a local socket to accept connections on a
 *   socket of <em>type</em> with the <em>protocol</em> from the protocol
 *   family <em>family</em>.  The <em>addrData</em> should contain a copy
 *   of the protocol family-specific address data in an NSData object.
 */
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                      address: (NSData *)addrData
{
  int s = -1;

  if (addrData == nil)
  {
    NSDebugMLLog(@"NSSocketPort", @"Nil value passed for address.");
    goto iWPFAFailed;
  }

  s = socket(family, type, protocol);
  if (s == -1)
  {
    NSLog(@"socket: %s", GSLastErrorStr(errno));
    goto iWPFAFailed;
  }

  if (bind(s, (struct sockaddr *)[addrData bytes], [addrData length]) == -1)
  {
    NSLog(@"bind: %s", GSLastErrorStr(errno));
    goto iWPFAFailed;
  }

  if (listen(s, SOMAXCONN) == -1)
  {
    NSLog(@"listen: %s", GSLastErrorStr(errno));
    goto iWPFAFailed;
  }

  return [self initWithProtocolFamily: family
                           socketType: type
                             protocol: protocol
                               socket: (NSSocketNativeHandle)s];

iWPFAFailed:
  if (s > -1)
    close(s);
  RELEASE(self);
  return nil;
}

/**
 *   Initialize the receiver with <em>socket</em>, the platform-native handle
 *   to a previously initialized listen-mode socket of type <em>type</em>
 *   with the protocol <em>protocol</em> from the protocol family
 *   <em>family</em>. <br />
 *   The receiver will close the socket upon deallocation.
 */
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                       socket: (NSSocketNativeHandle)socket
{
  _protocolFamily = family;
  _socketType = type;
  _protocol = protocol;
  _socket = socket;

  return self;
}

/**
 *   Initialize the receiver to connect to a remote TCP socket on port
 *   <em>portNumber</em> of host <em>hostname</em>.  The receiver delays
 *   initiation of the connection until it has data to send. <br />
 *   NOTE: This method currently does not support IPv6 connections.
 */
- (id) initRemoteWithTCPPort: (unsigned short)portNumber
                        host: (NSString *)hostname
{
  struct sockaddr_in sa;
  const char *address;
  NSData *addrData;

  address = [[[NSHost hostWithName: hostname] address] cString];
  if (address == NULL)
  {
    RELEASE(self);
    return nil;
  }

  /* Clear memory, as recommended. */
  memset(&sa, 0, sizeof(struct sockaddr_in));

  sa.sin_len = sizeof(struct sockaddr_in);
  sa.sin_family = PF_INET;
  sa.sin_port = htons(portNumber);
  sa.sin_addr.s_addr = inet_addr(address);

  addrData = [NSData dataWithBytes: &sa length: sizeof(struct sockaddr_in)];
  if (addrData == nil)
  {
    RELEASE(self);
    return nil;
  }

  return [self initRemoteWithProtocolFamily: PF_INET
                                 socketType: SOCK_STREAM
                                   protocol: 0
                                    address: addrData];
}

/**
 *   Initialize the receiver to connect to a remote socket of <em>type</em>
 *   with <em>protocol</em> from the protocol family <em>family</em>.  The
 *   <em>addrData</em> should contain a copy of the protocol family-specific
 *   address data in an NSData object.
 */
- (id) initRemoteWithProtocolFamily: (int)family
                         socketType: (int)type
                           protocol: (int)protocol
                            address: (NSData *)addrData
{
  if (addrData == nil)
  {
    NSDebugMLLog(@"NSSocketPort", @"Nil value passed for address.");
    RELEASE(self);
    return nil;
  }

  _socket = socket(family, type, protocol);
  if (_socket == -1)
  {
    NSLog(@"socket: %s", GSLastErrorStr(errno));
    RELEASE(self);
    return nil;
  }

  _protocolFamily = family;
  _socketType = type;
  _protocol = protocol;
  _remoteAddrData = RETAIN(addrData);

  return self;
}

/**
 *   Return the protocol family-specific socket address in an NSData object.
 */
- (NSData *) address
{
  char sa[SOCK_MAXADDRLEN];
  int len = SOCK_MAXADDRLEN;

  if (_remoteAddrData != nil)
  {
    return _remoteAddrData;
  }
  else if (getsockname(_socket, (struct sockaddr *)&sa, &len) == 0)
  {
    return [NSData dataWithBytes: &sa length: len];
  }
  else
  { 
    NSLog(@"getsockname: %s", GSLastErrorStr(errno));
    return nil;
  }
}

/**
 *   Return the socket protocol.
 */
- (int) protocol
{
  return _protocol;
}

/**
 *   Return the socket protocol family.
 */
- (int) protocolFamily
{
  return _protocolFamily;
}

/**
 *   Return the platform-native socket handle.
 */
- (NSSocketNativeHandle) socket
{
  return _socket;
}

/**
 *   Return the socket type.
 */
- (int) socketType
{
  return _socketType;
}

/* Concrete NSPort method implementations. */
- (void) invalidate
{
  /* Sockets don't close when the connection drops, they time out.
     Invalidation is not possible; the caller must notice the error. */
  return;
}

/* Experimentation */
- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  NSDebugLog(@"NSSocketPort", @"NSSocketPort does not recognize selector %@\n",
                     NSStringFromSelector(aSelector));
}

/* NSCopying */
/**
 *   FIXME: The Apple documentation does not explain what it means to copy an
 *   NSSocketPort and I do not have access to a MacOS X system to check.
 */
- (id) copyWithZone: (NSZone *)zone
{
  if (zone == NULL)
    zone = NSDefaultMallocZone();

  if (NSShouldRetainWithZone(self, zone) == YES)
    return RETAIN(self);
  else
  {
    NSSocketPort *copy = NSAllocateObject([self class], 0, zone);

    if (copy != nil)
    {
      /* Insulate against NSPort changes. */
      [copy setDelegate: [self delegate]];

      copy->_socket = dup(_socket);
      copy->_protocolFamily = _protocolFamily;
      copy->_socketType = _socketType;
      copy->_protocol = _protocol;
      _remoteAddrData = [_remoteAddrData copyWithZone: zone];
    }

    return RETAIN(copy);
  }
}

/* NSCoding */
- (void) encodeWithCoder: (NSCoder *)encoder
{
  NSParameterAssert([encoder isKindOfClass: [NSPortCoder class]]);
  NSDebugMLLog(@"NSSocketPort", @"called");
}

- (id) initWithCoder: (NSCoder *)decoder
{
  NSParameterAssert([decoder isKindOfClass: [NSPortCoder class]]);
  NSDebugMLLog(@"NSSocketPort", @"called");
  return nil;
}

@end
