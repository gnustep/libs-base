/* Interface of NSPortNameServer class for Distributed Objects
   Copyright (C) 1998,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

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

#ifndef __NSPortNameServer_h_GNUSTEP_BASE_INCLUDE
#define __NSPortNameServer_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

@class	NSPort, NSString, NSMutableArray;

@interface	NSPortNameServer : NSObject
{
  NSMapTable	*_portMap;	/* Registered ports information.	*/
  NSMapTable	*_nameMap;	/* Registered names information.	*/
}
+ (id) systemDefaultPortNameServer;
- (NSPort*) portForName: (NSString*)name;
- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host;
- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name;
- (void) removePortForName: (NSString*)name;
@end

#ifndef	NO_GNUSTEP
@interface	NSPortNameServer (GNUstep)
- (NSArray*) namesForPort: (NSPort*)port;	/* return all names for port */
- (void) removePort: (NSPort*)port;		/* remove all names for port */
- (void) removePort: (NSPort*)port forName: (NSString*)name;
@end
#endif

#endif

