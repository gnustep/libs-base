/* Implementation of abstract superclass port for use with Connection
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

/* This is the designated initializer. */
- init
{
  [super init];
  is_valid = YES;
  retain_count = 0;
  return self;
}

- retain
{
  retain_count++;
  return self;
}

- (oneway void) release
{
  if (!retain_count--)
    [self dealloc];
}

- (unsigned) retainCount
{
  return retain_count;
}

- (BOOL) isValid
{
  return is_valid;
}

- (void) close
{
  [self invalidate];
}

- (void) invalidate
{
  is_valid = NO;
}

- (Class) packetClass
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (void) encodeWithCoder: (id <Encoding>)anEncoder
{
  [super encodeWithCoder: anEncoder];
  /* xxx What else? */
}

- initWithCoder: (id <Decoding>)coder
{
  self = [super initWithCoder: coder];
  /* xxx What else? */
  return self;
}

@end


@implementation InPort

+ newForReceivingFromRegisteredName: (id <String>)name
{
  [self subclassResponsibility:_cmd];
  return nil;
}

+ newForReceiving
{
  return [self newForReceivingFromRegisteredName: nil];
}

- receivePacketWithTimeout: (int)milliseconds
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end


@implementation OutPort

+ newForSendingToRegisteredName: (id <String>)name 
                         onHost: (id <String>)hostname
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL) sendPacket: packet withTimeout: (int)milliseconds
{
  [self subclassResponsibility:_cmd];
  return NO;
}

@end


@implementation Packet

/* xxx There should be a designated initializer for the Packet class.
   Currently some subclasses and users, bypass this by calling
   MemoryStream initializers. */

- initForSendingWithCapacity: (unsigned)c
   replyPort: p
{
  [super initWithCapacity: c];
  reply_port = p;
  return self;
}

- replyPort
{
  return reply_port;
}

@end
