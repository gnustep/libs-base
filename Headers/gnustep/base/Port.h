/* Interface for abstract superclass port for use with Connection
   Copyright (C) 1994 Free Software Foundation, Inc.
   
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

#ifndef __Port_h_OBJECTS_INCLUDE
#define __Port_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/RetainingNotifier.h>
#include <objects/Coding.h>

@class Connection;

@interface Port : RetainingNotifier <Coding>

/* xxx These will probably change */
+ newRegisteredPortWithName: (const char *)n;
+ newPortFromRegisterWithName: (const char *)n onHost: (const char *)host;
+ newPort;

/* xxx These sending and receiving interfaces will change */

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*) remote;
- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*)remote
   timeout: (int) milliseconds;

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote;
- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
   timeout: (int) milliseconds;

- (BOOL) isSoft;

- (unsigned) hash;
- (BOOL) isEqual: anotherPort;

@end

#endif /* __Port_h_OBJECTS_INCLUDE */
