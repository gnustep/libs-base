/* Interface for socket-based port object for use with Connection
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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

#ifndef __SocketPort_h_GNUSTEP_BASE_INCLUDE
#define __SocketPort_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/Port.h>

#include <sys/types.h>

#ifndef WIN32
# include <sys/socket.h>
# include <netinet/in.h>
#endif /* !WIN32 */

typedef struct sockaddr_in sockport_t;

@interface SocketPort : Port
{
  sockport_t sockPort;
  int sock;			/* socket if local, 0 if remote */
  BOOL close_on_dealloc;
}


+ newForSockPort: (sockport_t)s close: (BOOL)f;
+ newForSockPort: (sockport_t)s;
+ newLocalWithNumber: (int)n;
+ newLocal;
+ newRemoteWithNumber: (int)n onHost: (id <String>)h;

- (sockport_t) sockPort;

- (int) socket;
- (int) socketPortNumber;

@end

#endif /* __SocketPort_h_GNUSTEP_BASE_INCLUDE */
