/* Implementation of abstract superclass port for use with Connection
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <config.h>
#include <gnustep/base/Port.h>
#include <gnustep/base/Coder.h>	/* for Coding protocol in Object category */
#include <gnustep/base/Notification.h>

@implementation Port

/* This is the designated initializer. */
- init
{
  [super init];
  is_valid = YES;
  return self;
}

- (void) close
{
  [self invalidate];
}

- (void) invalidate
{
  assert (is_valid);

  is_valid = NO;
  [NotificationDispatcher
    postNotificationName: NSPortDidBecomeInvalidNotification
    object: self];
}

+ (Class) outPacketClass
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (Class) outPacketClass
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

- (Class) classForPortCoder
{
  return [self class];
}
- replacementObjectForPortCoder: aRmc
{
  return self;
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

- init
{
  [super init];
  _packet_invocation = nil;
  return self;
}

+ newForReceivingFromRegisteredName: (NSString*)name
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

- (void) setReceivedPacketInvocation: (id <Invoking>)invocation
{
  assert (!_packet_invocation);
  _packet_invocation = invocation;
}

- (void) addToRunLoop: run_loop forMode: (NSString*)mode
{
  [self subclassResponsibility:_cmd];
}

- (void) removeFromRunLoop: run_loop forMode: (NSString*)mode
{
  [self subclassResponsibility:_cmd];
}

@end


@implementation OutPort

+ newForSendingToRegisteredName: (NSString*)name 
                         onHost: (NSString*)hostname
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL) sendPacket: packet timeout: (NSTimeInterval)t
{
  [self subclassResponsibility:_cmd];
  return NO;
}

@end


@implementation InPacket

/* The designated initializer. */
- initForReceivingWithCapacity: (unsigned)c
	       receivingInPort: ip
		  replyOutPort: op
{
  self = [super initWithCapacity: c prefix: 0];
  if (self)
    {
      assert ([op isValid]);
      assert (!ip || [ip isValid]);
      _reply_out_port = op;
      _receiving_in_port = ip;
    }
  return self;
}

- replyOutPort
{
  return _reply_out_port;
}

- receivingInPort
{
  return _receiving_in_port;
}

@end


@implementation OutPacket

/* The designated initializer. */
- initForSendingWithCapacity: (unsigned)c
		replyInPort: ip
{
  self = [super initWithCapacity: c prefix: [[self class] prefixSize]];
  if (self)
    {
      assert ([ip isValid]);
      _reply_in_port = ip;
    }
  return self;
}

+ (unsigned) prefixSize
{
  return 0;
}

- replyInPort
{
  return _reply_in_port;
}

@end

