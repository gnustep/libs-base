/* Implementation of NSPortCoder object for remote messaging
   Copyright (C) 1997 Free Software Foundation, Inc.

   This implementation for OPENSTEP conformance written by
	Richard Frith-Macdonald <richard@brainstorm.co.u>
        Created: August 1997

   based on original code -

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <base/preface.h>
#include <base/Coder.h>
#include <base/CStream.h>
#include <base/Port.h>
#include <base/MemoryStream.h>
#include <Foundation/NSException.h>
#include <Foundation/DistributedObjects.h>

#define DEFAULT_SIZE 256

#define PORT_CODER_FORMAT_VERSION ((((GNUSTEP_BASE_MAJOR_VERSION * 100) + \
	GNUSTEP_BASE_MINOR_VERSION) * 100) + GNUSTEP_BASE_SUBMINOR_VERSION)

static BOOL debug_connected_coder = NO;

/*
 *	The PortEncoder class is essentially the old ConnectedEncoder class
 *	with a name change.
 *	It uses the OPENSTEP method [-classForPortCoder] rather than the
 *	[-classForConnectedCoder] method to ask an object what class to encode.
 */
@interface PortEncoder : Encoder
{
  NSConnection *connection;
  unsigned sequence_number;
  int identifier;
  BOOL _is_by_copy;
  BOOL _is_by_ref;
}

+ newForWritingWithConnection: (NSConnection*)c
	       sequenceNumber: (int)n
		   identifier: (int)i;
- (void) dismiss;
- (NSConnection*) connection;
- (unsigned) sequenceNumber;
- (int) identifier;
@end

@implementation PortEncoder

- _initForWritingWithConnection: (NSConnection*)c
   sequenceNumber: (int)n
   identifier: (int)i
{
  OutPacket* packet = [[[(OutPort*)[c sendPort] outPacketClass] alloc]
			initForSendingWithCapacity: DEFAULT_SIZE
			replyInPort: [c receivePort]];
  [super initForWritingToStream: packet];
  [packet release];
  connection = c;
  sequence_number = n;
  identifier = i;
  [self encodeValueOfCType: @encode(typeof(sequence_number))
	at: &sequence_number
	withName: @"PortCoder sequence number"];
  [self encodeValueOfCType: @encode(typeof(identifier))
	at: &identifier
	withName: @"PortCoder identifier"];
  return self;
}

+ newForWritingWithConnection: (NSConnection*)c
   sequenceNumber: (int)n
   identifier: (int)i
{
  /* Export this method and not the -init... method because eventually
     we may do some caching of old PortEncoder's to speed things up. */
  return [[self alloc] _initForWritingWithConnection: c
		       sequenceNumber: n
		       identifier: i];
}

- (void) dismiss
{
  id packet = [cstream stream];
  NS_DURING
  {
    [(OutPort*)[connection sendPort] sendPacket: packet
				      timeout: [connection requestTimeout]];
  }
  NS_HANDLER
  {
    if (debug_connected_coder)
      fprintf(stderr, "dismiss 0x%x: #=%d i=%d write failed - %s\n",
	        (unsigned)self, sequence_number, identifier,
		[[localException reason] cString]);
    if ([[connection sendPort] isValid])
      [[connection sendPort] invalidate];
  }
  NS_ENDHANDLER
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

- (NSConnection*) connection
{
  return connection;
}

- (BOOL) isBycopy
{
  return _is_by_copy;
}

- (BOOL) isByref
{
  return _is_by_ref;
}

- (unsigned) sequenceNumber
{
  return sequence_number;
}


/*
 *	These three methods are called by Coder's designated object encoder when
 *	an object is to be sent over the wire with/without bycopy/byref.
 *	We make sure that if the object asks us whether it is to be sent bycopy
 *	or byref it is told the right thing.
 */
- (void) _doEncodeObject: anObj
{
    id		obj;
    Class	cls;

    obj = [anObj replacementObjectForPortCoder: (NSPortCoder*)self];
    cls = [obj classForPortCoder];
    [self encodeClass: cls];
    [obj encodeWithCoder: (NSCoder*)self];
}

- (void) _doEncodeBycopyObject: anObj
{
    BOOL        oldBycopy = _is_by_copy;
    BOOL        oldByref = _is_by_ref;
    id          obj;
    Class       cls;

    _is_by_copy = YES;
    _is_by_ref = NO;
    obj = [anObj replacementObjectForPortCoder: (NSPortCoder*)self];
    cls = [obj classForPortCoder];
    [self encodeClass: cls];
    [obj encodeWithCoder: (NSCoder*)self];
    _is_by_copy = oldBycopy;
    _is_by_ref = oldByref;
}

- (void) _doEncodeByrefObject: anObj
{
    BOOL        oldBycopy = _is_by_copy;
    BOOL        oldByref = _is_by_ref;
    id          obj;
    Class       cls;

    _is_by_copy = NO;
    _is_by_ref = YES;
    obj = [anObj replacementObjectForPortCoder: (NSPortCoder*)self];
    cls = [obj classForPortCoder];
    [self encodeClass: cls];
    [obj encodeWithCoder: (NSCoder*)self];
    _is_by_copy = oldBycopy;
    _is_by_ref = oldByref;
}

- (void) writeSignature
{
  return;
}

@end



/*
 *	The PortDecoder class is essentially the old ConnectedDecoder class
 *	with a name change.
 */
@interface PortDecoder : Decoder
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
- (NSConnection*) connection;
- (unsigned) sequenceNumber;
- (int) identifier;
- (NSPort*) replyPort;
@end

@implementation PortDecoder

+ (void) readSignatureFromCStream: (id <CStreaming>) cs
		     getClassname: (char *) name
		    formatVersion: (int*) version
{
  const char *classname = class_get_class_name (self);
  strcpy (name, classname);
  *version = PORT_CODER_FORMAT_VERSION;
}

+ newDecodingWithConnection: (NSConnection*)c
   timeout: (int) timeout
{
  PortDecoder *cd;
  id in_port;
  id packet;
  id reply_port;

  /* Try to get a packet. */
  in_port = [c receivePort];
  packet = [in_port receivePacketWithTimeout: timeout];
  if (!packet)
    return nil;			/* timeout */

  /* Create the new PortDecoder */
  cd = [self newReadingFromStream: packet];
  [packet release];
  reply_port = [packet replyPort];
  cd->connection = [NSConnection newForInPort: in_port
			       outPort: reply_port
			       ancestorConnection: c];

  [cd->connection setNotOwned];

  /* Decode the PortDecoder's ivars. */
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
	     connection: (NSConnection*)c
{
  PortDecoder *cd;
  id in_port;
  id reply_port;

  in_port = [c receivePort];

  /* Create the new PortDecoder */
  cd = [self newReadingFromStream: packet];
  [packet release];
  reply_port = [packet replyOutPort];
  cd->connection = [NSConnection newForInPort: in_port
			       outPort: reply_port
			       ancestorConnection: c];

  [cd->connection setNotOwned];

  /* Decode the PortDecoder's ivars. */
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


/* Access to ivars. */

- (int) identifier
{
  return identifier;
}

- (NSConnection*) connection
{
  return connection;
}

- (NSPort*) replyPort
{
  return (NSPort*)[(id)[cstream stream] replyPort];
}

- (unsigned) sequenceNumber
{
  return sequence_number;
}

- (void) dealloc
{
  [connection release];
  [super dealloc];
}

- (void) dismiss
{
  [self release];
}

@end



/*
 *	The NSPortCoder class is an abstract class which is used to create
 *	instances of PortEncoder or PortDecoder depending on what factory
 *	method is used.
 */
@implementation NSPortCoder

+ newDecodingWithConnection: (NSConnection*)c
		    timeout: (int) timeout
{
  return [PortDecoder newDecodingWithConnection:c timeout:timeout];
}

+ newDecodingWithPacket: (InPacket*)packet
	     connection: (NSConnection*)c
{
  return [PortDecoder newDecodingWithPacket:packet connection:c];
}

+ newForWritingWithConnection: (NSConnection*)c
	       sequenceNumber: (int)n
                   identifier: (int)i
{
  return [[PortEncoder alloc] _initForWritingWithConnection: c
		       sequenceNumber: n
		       identifier: i];
}

- allocWithZone: (NSZone*)z
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSConnection*) connection
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSPort*) decodePortObject
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (void) dismiss
{
  [self subclassResponsibility:_cmd];
}

- (void) encodePortObject: (NSPort*)aPort
{
  [self subclassResponsibility:_cmd];
}

- (int) identifier
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (BOOL) isBycopy
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (BOOL) isByref
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (NSPort*) replyPort
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (unsigned) sequenceNumber
{
  [self subclassResponsibility:_cmd];
  return 0;
}

@end

