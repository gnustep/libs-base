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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#ifndef __NSPort_h_GNUSTEP_BASE_INCLUDE
#define __NSPort_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

@class	NSMutableSet;

extern NSString *NSPortTimeoutException; /* OPENSTEP */

@interface NSPort : NSObject <NSCoding, NSCopying>
{
    BOOL	is_valid;
    id		delegate;
}

+ (NSPort*) port;
+ (NSPort*) portWithMachPort: (int)machPort;

- delegate;

- init;
- initWithMachPort: (int)machPort;

- (void) invalidate;
- (BOOL) isValid;
- machPort;
- (void) setDelegate: anObject;

@end

@interface NSPort (GNUstep)

- (void) close;

+ (Class) outPacketClass;
- (Class) outPacketClass;

@end

extern	NSString*	NSPortDidBecomeInvalidNotification;

#define	PortBecameInvalidNotification NSPortDidBecomeInvalidNotification

#endif /* __NSPort_h_GNUSTEP_BASE_INCLUDE */
