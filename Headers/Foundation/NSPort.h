/** Interface for abstract superclass NSPort for use with NSConnection
   Copyright (C) 1997,2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

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

  AutogsdocSource: NSPort.m
  AutogsdocSource: NSSocketPort.m
  AutogsdocSource: NSMessagePort.m
*/

#ifndef __NSPort_h_GNUSTEP_BASE_INCLUDE
#define __NSPort_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>
#include	<Foundation/NSMapTable.h>

#ifdef __MINGW__
#include	<winsock2.h>
#include	<wininet.h>
#else
#include	<sys/socket.h>
#define	SOCKET	int
#endif

@class	NSMutableArray;
@class	NSConnection;
@class	NSDate;
@class	NSRunLoop;
@class	NSString;
@class	NSPortMessage;
@class	NSHost;

GS_EXPORT NSString * const NSPortTimeoutException; /* OPENSTEP */

@interface NSPort : NSObject <NSCoding, NSCopying>
{
  BOOL		_is_valid;
  id		_delegate;
}

+ (NSPort*) port;
+ (NSPort*) portWithMachPort: (int)machPort;

- (id) delegate;

- (id) init;
- (id) initWithMachPort: (int)machPort;

- (void) invalidate;
- (BOOL) isValid;
- (int) machPort;
- (void) setDelegate: (id)anObject;

#ifndef	STRICT_OPENSTEP
- (void) addConnection: (NSConnection*)aConnection
	     toRunLoop: (NSRunLoop*)aLoop
	       forMode: (NSString*)aMode;
- (void) removeConnection: (NSConnection*)aConnection
	      fromRunLoop: (NSRunLoop*)aLoop
		  forMode: (NSString*)aMode;
- (unsigned) reservedSpaceLength;
- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgid
	     components: (NSMutableArray*)components
		   from: (NSPort*)receivingPort
	       reserved: (unsigned)length;
- (BOOL) sendBeforeDate: (NSDate*)when
	     components: (NSMutableArray*)components
		   from: (NSPort*)receivingPort
	       reserved: (unsigned)length;
#endif
@end

#ifndef	NO_GNUSTEP
@interface NSPort (GNUstep)
- (void) close;
+ (Class) outPacketClass;
- (Class) outPacketClass;
@end
#endif

GS_EXPORT	NSString*	NSPortDidBecomeInvalidNotification;

#define	PortBecameInvalidNotification NSPortDidBecomeInvalidNotification

#ifndef	STRICT_OPENSTEP

typedef SOCKET NSSocketNativeHandle;

@class GSTcpHandle;
@interface NSSocketPort : NSPort <GCFinalization>
{
  NSRecursiveLock	*myLock;
  NSHost		*host;		/* OpenStep host for this port.	*/
  NSString		*address;	/* Forced internet address.	*/
  gsu16			portNum;	/* TCP port in host byte order.	*/
  SOCKET		listener;
  NSMapTable		*handles;	/* Handles indexed by socket.	*/
}

+ (NSSocketPort*) existingPortWithNumber: (gsu16)number
				  onHost: (NSHost*)aHost;
+ (NSSocketPort*) portWithNumber: (gsu16)number
			  onHost: (NSHost*)aHost
		    forceAddress: (NSString*)addr
			listener: (BOOL)shouldListen;

- (void) addHandle: (GSTcpHandle*)handle forSend: (BOOL)send;
- (NSString*) address;
- (void) getFds: (int*)fds count: (int*)count;
- (GSTcpHandle*) handleForPort: (NSSocketPort*)recvPort
		    beforeDate: (NSDate*)when;
- (void) handlePortMessage: (NSPortMessage*)m;
- (NSHost*) host;
- (gsu16) portNumber;
- (void) removeHandle: (GSTcpHandle*)handle;

/*
{
  NSSocketNativeHandle _socket;
  int _protocolFamily;
  int _socketType;
  int _protocol;
  NSData *_remoteAddrData;
}
- (id) init;
- (id) initWithTCPPort: (unsigned short)portNumber;
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                      address: (NSData *)addrData;
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                       socket: (NSSocketNativeHandle)socket;
- (id) initRemoteWithTCPPort: (unsigned short)portNumber
                        host: (NSString *)hostname;
- (id) initRemoteWithProtocolFamily: (int)family
                         socketType: (int)type
                           protocol: (int)protocol
                            address: (NSData *)addrData;

- (NSData *) address;
- (int) protocol;
- (int) protocolFamily;
- (NSSocketNativeHandle) socket;
- (int) socketType;
*/

@end


@class GSMessageHandle;

@interface NSMessagePort : NSPort <GCFinalization>
{
  NSData		*name;
  NSRecursiveLock	*myLock;
  NSMapTable		*handles;	/* Handles indexed by socket.	*/
  int			listener;	/* Descriptor to listen on.	*/
}

- (int) _listener;
- (const unsigned char *) _name;
+ (NSMessagePort*) _portWithName: (const unsigned char *)socketName
			listener: (BOOL)shouldListen;

- (void) addHandle: (GSMessageHandle*)handle forSend: (BOOL)send;
- (void) removeHandle: (GSMessageHandle*)handle;
- (void) handlePortMessage: (NSPortMessage*)m;

@end


#endif


#endif /* __NSPort_h_GNUSTEP_BASE_INCLUDE */

