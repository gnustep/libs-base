/* Interface for coder object for distributed objects
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __ConnectedCoder_h
#define __ConnectedCoder_h

#include <base/preface.h>
#include <base/Coder.h>
#include <base/Port.h>

/* ConnectedCoder identifiers */
enum {
 METHOD_REQUEST = 0,
 METHOD_REPLY,
 ROOTPROXY_REQUEST,
 ROOTPROXY_REPLY,
 CONNECTION_SHUTDOWN,
 METHODTYPE_REQUEST,	/* these two only needed with NeXT runtime */
 METHODTYPE_REPLY
};

@class NSConnection;

@interface ConnectedEncoder : Encoder
{
  NSConnection *connection;
  unsigned sequence_number;
  int identifier;
}

+ newForWritingWithConnection: (NSConnection*)c
   sequenceNumber: (int)n
   identifier: (int)i;
- (void) dismiss;

- connection;
- (unsigned) sequenceNumber;
- (int) identifier;

@end

@interface ConnectedDecoder : Decoder
{
  NSConnection *connection;
  unsigned sequence_number;
  int identifier;
}

+ newDecodingWithPacket: (InPacket*)packet
	     connection: (NSConnection*)c;
+ newDecodingWithConnection: (NSConnection*)c
   timeout: (int) timeout;
- (void) dismiss;

- connection;
- (unsigned) sequenceNumber;
- (int) identifier;

- replyPort;

@end

#endif /* __ConnectedCoder_h */
