/* Implementation of coder object for remote messaging
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
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

#include <objects/stdobjects.h>
#include <objects/ConnectedCoder.h>
#include <objects/SocketPort.h>
#include <objects/MemoryStream.h>
#include <objects/Connection.h>
#include <objects/Proxy.h>
#include <assert.h>

#define PTR2LONG(P) (((char*)(P))-(char*)0)
#define LONG2PTR(L) (((char*)0)+(L))

//#define DEFAULT_SIZE 256
//#define DEFAULT_SIZE 1024
#define DEFAULT_SIZE 2000

static BOOL debug_connected_coder = NO;

@implementation ConnectedCoder

+ newEncodingWithConnection: (Connection*)c
   sequenceNumber: (int)n
   identifier: (int)i
{
  ConnectedCoder *newsp;
  char *b;
  MemoryStream* ms;

  b = (char*) (*objc_malloc)(DEFAULT_SIZE);
  ms = [[MemoryStream alloc] 
	_initOnMallocBuffer:b
	size:DEFAULT_SIZE
	eofPosition:0
	prefix:2
	position:0];

  newsp = [[self alloc] initEncodingOnStream:ms];
  newsp->connection = c;
  newsp->sequence_number = n;
  newsp->identifier = i;
  [newsp encodeValueOfSimpleType:@encode(typeof(newsp->sequence_number))
	 at:&(newsp->sequence_number)
	 withName:"ConnectedCoder sequence number"];
  [newsp encodeValueOfSimpleType:@encode(typeof(newsp->identifier))
	 at:&(newsp->identifier)
	 withName:"ConnectedCoder identifier"];
  return newsp;
}

+ newDecodingWithConnection: (Connection*)c
   timeout: (int) timeout
{
  ConnectedCoder *newsp;
  int len;
  char *b;
  id inPort = [c inPort];
  MemoryStream *ms;
  id rp;
  unsigned sent_size;

  b = (char*) (*objc_malloc)(DEFAULT_SIZE);
  if (!inPort) [self error:"no inPort"];
  len = [inPort
	 receivePacket:b
	 length:DEFAULT_SIZE
	 fromPort:&rp
	 timeout:timeout];
  if (len < 0)			/* timeout */
    {
      (*objc_free)(b);
      return nil;
    }
  
  /* xxx We need to do something if DEFAULT_SIZE is too small for this msg.
     Change the interface to Port. */
  sent_size = *(unsigned char*)(b+1);
  sent_size = (sent_size * 0x100) + *(unsigned char*)(b);
  if (sent_size != len)
    [self error:"received packet size overflow?\n"
	  "packet size sent (%d) != packet size received (%d)",
	  sent_size, len];

  ms = [[MemoryStream alloc] 
	_initOnMallocBuffer:b
	size:DEFAULT_SIZE
	eofPosition:len-2
	prefix:2
	position:0];
  newsp = [[self alloc] initDecodingOnStream:ms];
  newsp->remotePort = rp;
  newsp->connection = [Connection newForInPort:inPort
				  outPort:newsp->remotePort
				  ancestorConnection:c];
  [newsp decodeValueOfSimpleType:@encode(typeof(newsp->sequence_number))
	 at:&(newsp->sequence_number)
	 withName:NULL];
  [newsp decodeValueOfSimpleType:@encode(typeof(newsp->identifier))
	 at:&(newsp->identifier)
	 withName:NULL];

  b[len] = '\0';		/* xxx dangerous, but pretty debug output */
  if (debug_connected_coder)
    fprintf(stderr, "startDecoding #=%d id=%d: (%s)\n", 
	   newsp->sequence_number, newsp->identifier, b);
  return newsp;
}

- dismiss
{
  if (![self isDecoding])
    {
      int buffer_len;
      int sent_len;
      id ip, op;
      char *b;

      ip = [connection inPort];
      if (!ip) [self error:"no inPort"];
      op = [connection outPort];
      if (!op) [self error:"no outPort"];
      buffer_len = [(MemoryStream*)stream streamBufferLength];
      b = [(MemoryStream*)stream streamBuffer];
      /* Put the packet length in the first two bytes */
      b[0] = buffer_len % 0x100;
      b[1] = buffer_len / 0x100;
      assert(!(buffer_len / 0x10000));
      sent_len = [ip
		  sendPacket:b
		  length:buffer_len
		  toPort:op
		  timeout:[connection outTimeout]];
      assert(sent_len == buffer_len);
      b[sent_len] = '\0';	/* xxx oooo, dangerous.  fix this */
      if (debug_connected_coder)
	fprintf(stderr, "finishEncoding 0x%x: #=%d i=%d %d/%d (%s)\n", 
	       (unsigned)self, sequence_number, identifier, 
	       buffer_len, sent_len, b);
    }
  return [self free];
}

static elt 
exc_return_null(arglist_t f)
{
  return (void*)0;
}

- (BOOL) _coderHasConstPtrReference: (unsigned)xref
{
  if (is_decoding)
    return [[connection _incomingConstPtrs] includesKey:xref];
  else
    return [[connection _outgoingConstPtrs] includesKey:xref];
}

- (const void*) _coderConstPtrAtReference: (unsigned)xref;
{
  if (is_decoding)
    return [[connection _incomingConstPtrs] 
	    elementAtKey:xref
	    ifAbsentCall:exc_return_null].void_ptr_u;
  else
    return [[connection _outgoingConstPtrs] 
	    elementAtKey:xref
	    ifAbsentCall:exc_return_null].void_ptr_u;
}

- (void) _coderPutConstPtr: (const void*)p atReference: (unsigned)xref
{
  if (is_decoding)
    {
      assert(![[connection _incomingConstPtrs] includesKey:xref]);
      [[connection _incomingConstPtrs] putElement:(void*)p atKey:xref];
    }
  else
    {
      assert(![[connection _outgoingConstPtrs] includesKey:xref]);
      [[connection _outgoingConstPtrs] putElement:(void*)p atKey:xref];
    }
  return;
}

#if CONNECTION_WIDE_OBJECT_REFERENCES

/* We need to think carefully about reference counts, bycopy and
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

- (BOOL) _coderHasObjectReference: (unsigned)xref
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

- free
{
  /* Anything else? */
  return [super free];
}

- (int) identifier
{
  return identifier;
}

- connection
{
  return connection;
}

- remotePort
{
  return remotePort;
}

- (unsigned) sequenceNumber
{
  return sequence_number;
}

/* This is called by Coder's designated object encoder */
- (void) _doEncodeObject: anObj
{
  id c = [anObj classForConnectedCoder:self];
  [self encodeClass:c];
  [c encodeObject:anObj withConnectedCoder:self];
}

- (void) resetConnectedCoder	/* xxx rename resetCoder */
{
  [self notImplemented:_cmd];
  /* prepare the receiver to do it's stuff again,
     save time by doing this instead of free/malloc for each message */
}

@end
