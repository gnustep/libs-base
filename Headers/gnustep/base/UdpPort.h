/* Interface for socket-based port object for use with Connection
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __UdpPort_h_GNUSTEP_BASE_INCLUDE
#define __UdpPort_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/Port.h>
#include <sys/types.h>
#ifndef WIN32
# include <sys/socket.h>
# include <netinet/in.h>
#endif /* !WIN32 */

@interface UdpInPort : InPort
{
  int _port_socket;
  struct sockaddr_in _address;
}

- (int) portNumber;
- (int) socket;

@end

@interface UdpOutPort : OutPort
{
  struct sockaddr_in _address;
}

- (int) portNumber;
- (NSString*) hostname;

@end

@interface UdpInPacket : InPacket
@end
@interface UdpOutPacket : OutPacket
@end

#endif /* __UdpPort_h_GNUSTEP_BASE_INCLUDE */
