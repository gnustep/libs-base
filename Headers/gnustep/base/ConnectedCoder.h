/* Interface for coder object for distributed objects
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
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

#ifndef __ConnectedCoder_h
#define __ConnectedCoder_h

#include <objects/stdobjects.h>
#include <objects/Coder.h>

/* ConnectedCoder identifiers */
#define METHOD_REQUEST 0
#define METHOD_REPLY 1
#define ROOTPROXY_REQUEST 2
#define ROOTPROXY_REPLY 3
#define CONNECTION_SHUTDOWN 4
#define METHODTYPE_REQUEST 5	/* these two only needed with NeXT runtime */
#define METHODTYPE_REPLY 6

@class Connection;

@interface ConnectedCoder : Coder
{
  Connection *connection;
  unsigned sequence_number;
  int identifier;

  /* only used for incoming ConnectedCoder's */
  id remotePort;
}

+ newEncodingWithConnection: (Connection*)c
   sequenceNumber: (int)n
   identifier: (int)i;
+ newDecodingWithConnection: (Connection*)c
   timeout: (int) timeout;
- dismiss;

- connection;
- (unsigned) sequenceNumber;
- (int) identifier;

- remotePort;

@end

#endif /* __ConnectedCoder_h */
