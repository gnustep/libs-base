/* Implementation of abstract superclass port for use with Connection
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
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

#include <objects/Port.h>
#include <objects/Coder.h>	/* for Coding protocol in Object category */

@implementation Port

+ newRegisteredPortWithName: (id <String>)n
{
  [self subclassResponsibility:_cmd];
  return nil;
}

+ newPortFromRegisterWithName: (id <String>)n onHost: (id <String>)host
{
  [self subclassResponsibility:_cmd];
  return nil;
}

+ newPort
{
  [self subclassResponsibility:_cmd];
  return nil;
}

/* These sending and receiving interfaces will change */

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*) remote
   timeout: (int) milliseconds
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*) remote
{
  return [self sendPacket:b length:l toPort:remote timeout:-1];
}

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
   timeout: (int) milliseconds
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
{
  return [self receivePacket:b length:l fromPort:remote timeout:-1];
}

- (BOOL) isSoft
{
  [self subclassResponsibility:_cmd];
  return YES;
}

- (BOOL) isEqual: anotherPort
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (unsigned) hash
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) encodeWithCoder: (id <Encoding>)anEncoder
{
  [super encodeWithCoder:anEncoder];
}

@end
