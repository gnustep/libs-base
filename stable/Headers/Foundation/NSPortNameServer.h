/** Interface of NSPortNameServer class for Distributed Objects
   Copyright (C) 1998,1999,2003 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.

   <title>NSPortNameServer class reference</title>

   AutogsdocSource: NSPortNameServer.m
   AutogsdocSource: NSSocketPortNameServer.m
   AutogsdocSource: NSMessagePortNameServer.m

   */

#ifndef __NSPortNameServer_h_GNUSTEP_BASE_INCLUDE
#define __NSPortNameServer_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>

@class	NSPort, NSString, NSMutableArray;

@interface	NSPortNameServer : NSObject
{
}
+ (id) systemDefaultPortNameServer;
- (NSPort*) portForName: (NSString*)name;
- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host;
- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name;
- (BOOL) removePortForName: (NSString*)name;
@end

@interface NSSocketPortNameServer : NSPortNameServer
{
  NSMapTable	*_portMap;	/* Registered ports information.	*/
  NSMapTable	*_nameMap;	/* Registered names information.	*/
}
+ (id) sharedInstance;
- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host;
- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name;
- (BOOL) removePortForName: (NSString*)name;
@end


@interface NSMessagePortNameServer : NSPortNameServer
+ (id) sharedInstance;
@end

#endif

