/* Interface for abstract superclass NSPort for use with NSConnection
   Copyright (C) 1997 Free Software Foundation, Inc.

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
   */

#ifndef __NSPort_h_GNUSTEP_BASE_INCLUDE
#define __NSPort_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

@class	NSMutableArray;
@class	NSConnection;
@class	NSDate;
@class	NSRunLoop;
@class	NSString;

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

#endif /* __NSPort_h_GNUSTEP_BASE_INCLUDE */
