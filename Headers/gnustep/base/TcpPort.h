/* Interface for stream based on TCP sockets
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

#ifndef __TcpPort_h__OBJECTS_INCLUDE
#define __TcpPort_h__OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Port.h>
#include <objects/RunLoop.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <Foundation/NSMapTable.h>

/* A concrete implementation of a Port object implemented on top of
   SOCK_STREAM connections. */

@interface TcpInPort : InPort
{
  int _socket;
  struct sockaddr_in _listening_address;
  NSMapTable *_client_sock_2_out_port;
  NSMapTable *_client_sock_2_packet;
}

+ newForReceivingFromPortNumber: (unsigned short)n;

/* Get a packet from the net and return it.  If no packet is received 
   within MILLISECONDS, then return nil.  The caller is responsible 
   for releasing the packet. */
- newPacketReceivedBeforeDate: date;

- (int) portNumber;
- (id <Collecting>) connectedOutPorts;
- (unsigned) numberOfConnectedOutPorts;

@end


@interface TcpOutPort : OutPort
{
  int _socket;
  /* This is actually the address of the listen()'ing socket of the remote
     TcpInPort we are connected to, not the address of the _socket ivar. */
  struct sockaddr_in _remote_in_port_address;
  /* This is the address of our remote peer socket. */
  struct sockaddr_in _peer_address;
  /* The TcpInPort that is polling our _socket with select(). */
  id _polling_in_port;
}

+ newForSendingToPortNumber: (unsigned short)n 
		     onHost: (id <String>)hostname;
- (int) portNumber;

@end


/* Holders of sent and received data. */

@interface TcpInPacket : InPacket
@end
@interface TcpOutPacket : OutPacket
@end


/* Notification Strings. */
extern NSString *InPortClientBecameInvalidNotification;
extern NSString *InPortAcceptedClientNotification;

#endif /* __TcpPort_h__OBJECTS_INCLUDE */

