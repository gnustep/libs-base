/* Implementation of coder object for remote messaging
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
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

#include <gnustep/base/preface.h>
#include <gnustep/base/ConnectedCoder.h>
#include <gnustep/base/CStream.h>
#include <gnustep/base/Port.h>
#include <gnustep/base/MemoryStream.h>
#include <gnustep/base/Connection.h>
#include <gnustep/base/Proxy.h>
#include <assert.h>

#define PTR2LONG(P) (((char*)(P))-(char*)0)
#define LONG2PTR(L) (((char*)0)+(L))

#define DEFAULT_SIZE 256

#define CONNECTED_CODER_FORMAT_VERSION 0

static BOOL debug_connected_coder = NO;

@implementation ConnectedEncoder

- (void) writeSignature
{
  return;
}

- _initForWritingWithConnection: (Connection*)c
   sequenceNumber: (int)n
   identifier: (int)i
{
  OutPacket* packet = [[[[c outPort] outPacketClass] alloc]
			initForSendingWithCapacity: DEFAULT_SIZE
			replyInPort: [c inPort]];
  [super initForWritingToStream: packet];
  connection = c;
  sequence_number = n;
  identifier = i;
  [self encodeValueOfCType: @encode(typeof(sequence_number))
	at: &sequence_number
	withName: @"ConnectedCoder sequence number"];
  [self encodeValueOfCType: @encode(typeof(identifier))
	at: &identifier
	withName: @"ConnectedCoder sequence number"];
  return self;
}

+ newForWritingWithConnection: (Connection*)c
   sequenceNumber: (int)n
   identifier: (int)i
{
  /* Export this method and not the -init... method because eventually
     we may do some caching of old ConnectedEncoder's to speed things up. */
  return [[self alloc] _initForWritingWithConnection: c
		       sequenceNumber: n
		       identifier: i];
}

- (void) dismiss
{
  id packet = [cstream stream];
  [[connection outPort] sendPacket: packet];
  if (debug_connected_coder)
    fprintf(stderr, "dismiss 0x%x: #=%d i=%d %d\n", 
	    (unsigned)self, sequence_number, identifier, 
	    [packet streamEofPosition]);
  [self release];
}


/* Access to ivars. */

- (int) identifier
{
  return identifier;
}

- connection
{
  return connection;
}

- (unsigned) sequenceNumber
{
  return sequence_number;
}


/* Cache the const ptr's in the Connection, not separately for each 
   created ConnectedCoder. */

- (unsigned) _coderReferenceForConstPtr: (const void*)ptr
{
  return [connection _encoderReferenceForConstPtr: ptr];
}

- (unsigned) _coderCreateReferenceForConstPtr: (const void*)ptr
{
  return [connection _encoderCreateReferenceForConstPtr: ptr];
}


/* This is called by Coder's designated object encoder */
- (void) _doEncodeObject: anObj
{
  id c = [anObj classForConnectedCoder: self];
  /* xxx Should I also do classname substition here? */
  [self encodeClass: c];
  [c encodeObject: anObj withConnectedCoder: self];
}

@end


@implementation ConnectedDecoder

+ (void) readSignatureFromCStream: (id <CStreaming>) cs
		     getClassname: (char *) name
		    formatVersion: (int*) version
{
  const char *classname = class_get_class_name (self);
  strcpy (name, classname);
  *version = CONNECTED_CODER_FORMAT_VERSION;
}


+ newDecodingWithConnection: (Connection*)c
   timeout: (int) timeout
{
  ConnectedDecoder *cd;
  id in_port;
  id packet;
  id reply_port;

  /* Try to get a packet. */
  in_port = [c inPort];
  packet = [in_port receivePacketWithTimeout: timeout];
  if (!packet)
    return nil;			/* timeout */

  /* Create the new ConnectedDecoder */
  cd = [self newReadingFromStream: packet];
  reply_port = [packet replyPort];
  cd->connection = [Connection newForInPort: in_port
			       outPort: reply_port
			       ancestorConnection: c];

  /* Decode the ConnectedDecoder's ivars. */
  [cd decodeValueOfCType: @encode(typeof(cd->sequence_number))
      at: &(cd->sequence_number)
      withName: NULL];
  [cd decodeValueOfCType: @encode(typeof(cd->identifier))
      at: &(cd->identifier)
      withName: NULL];

  if (debug_connected_coder)
    fprintf(stderr, "newDecoding #=%d id=%d\n", 
	    cd->sequence_number, cd->identifier);
  return cd;
}

+ newDecodingWithPacket: (InPacket*)packet
	     connection: (Connection*)c
{
  ConnectedDecoder *cd;
  id in_port;
  id reply_port;

  in_port = [c inPort];

  /* Create the new ConnectedDecoder */
  cd = [self newReadingFromStream: packet];
  reply_port = [packet replyOutPort];
  cd->connection = [Connection newForInPort: in_port
			       outPort: reply_port
			       ancestorConnection: c];

  /* Decode the ConnectedDecoder's ivars. */
  [cd decodeValueOfCType: @encode(typeof(cd->sequence_number))
      at: &(cd->sequence_number)
      withName: NULL];
  [cd decodeValueOfCType: @encode(typeof(cd->identifier))
      at: &(cd->identifier)
      withName: NULL];

  if (debug_connected_coder)
    fprintf(stderr, "newDecoding #=%d id=%d\n", 
	    cd->sequence_number, cd->identifier);
  return cd;
}



/* Cache the const ptr's in the Connection, not separately for each 
   created ConnectedCoder. */

- (unsigned) _coderCreateReferenceForConstPtr: (const void*)ptr
{
  return [connection _decoderCreateReferenceForConstPtr: ptr];
}

- (const void*) _coderConstPtrAtReference: (unsigned)xref
{
  return [connection _decoderConstPtrAtReference: xref];
}


#if CONNECTION_WIDE_OBJECT_REFERENCES

/* xxx We need to think carefully about reference counts, bycopy and
   remote objects before we do this. */

/* Some notes:

   Is it really more efficient to send "retain" messages across the
   wire than to resend the object?

   How is this related to bycopy objects?  Yipes.

   Never let a Proxy be free'd completely until the connection does
   down?  The other connection is assuming we'll keep track of it and
   be able to access it simply by the reference number.

   Even if this is unacceptable, and we always have to sent enough info
   to be able to recreate the proxy, we still win with the choice of
   +encodeObject:withConnectedCoder because we avoid having
   to keep around the local proxies.  */

#warning These names need to be updated for the new xref scheme.

- (BOOL) _coderReferenceForObject: xref
{
  if (is_decoding)
    return [connection includesProxyForTarget:xref];
  else
    return [connection includesLocalObject:(id)LONG2PTR(xref)];
}

- _coderObjectAtReference: (unsigned)xref;
{
  if (is_decoding)
    return [connection proxyForTarget:xref];
  else
    return (id)LONG2PTR(xref);
}

- (void) _coderPutObject: anObj atReference: (unsigned)xref
{
  /* xxx But we need to deal with bycopy's too!!!  Not all of the
     "anObj"s are Proxies! */
  if (is_decoding)
    {
      assert([anObj isProxy]);
      assert([anObj targetForProxy] == xref);
      /* This gets done in Proxy +newForRemote:connection:
	 [connection addProxy:anObj]; */
    }
  else
    {
      assert(PTR2LONG(anObj) == xref);
      [connection addLocalObject:anObj];
    }
}

#endif /* CONNECTION_WIDE_REFERENCES */


/* Access to ivars. */

- (int) identifier
{
  return identifier;
}

- connection
{
  return connection;
}

- replyPort
{
  return [(id)[cstream stream] replyPort];
}

- (unsigned) sequenceNumber
{
  return sequence_number;
}

- (void) resetConnectedCoder	/* xxx rename resetCoder */
{
  [self notImplemented:_cmd];
  /* prepare the receiver to do it's stuff again,
     save time by doing this instead of free/malloc for each message */
}

- (void) dismiss
{
  [self release];
}

@end


@implementation NSObject (ConnectedCoderCallbacks)

/* By default, Object's encode themselves as proxies across Connection's */
- classForConnectedCoder: aRmc
{
  return [[aRmc connection] proxyClass];
}

/* But if any object overrides the above method to return [Object class]
   instead, the Object implementation of the coding method will actually
   encode the object itself, not a proxy */
+ (void) encodeObject: anObject withConnectedCoder: aRmc
{
  [anObject encodeWithCoder: aRmc];
}

@end
