/* Implementation of NSPortMessage for GNUstep
   Copyright (C) 1998,2000 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <richard@brainstorm.co.Ik>
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

#include <config.h>
#include <objc/objc-api.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPortMessage.h>

@implementation	NSPortMessage

- (void) dealloc
{
  RELEASE(_recv);
  RELEASE(_send);
  RELEASE(_components);
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat:
    @"NSPortMessage (Id %u)\n  Send: %@\n  Recv: %@\n  Components -\n%@",
    _msgid, _send, _recv, _components];
}

/*	PortMessages MUST be initialised with ports and data.	*/
- (id) init
{
  [self shouldNotImplement: _cmd];
  return nil;
}

/*	PortMessages MUST be initialised with ports and data.	*/
- (id) initWithMachMessage: (void*)buffer
{
  [self shouldNotImplement: _cmd];
  return nil;
}

/*	This is the designated initialiser.	*/
- (id) initWithSendPort: (NSPort*)aPort
	    receivePort: (NSPort*)anotherPort
	     components: (NSArray*)items
{
  self = [super init];
  if (self != nil)
    {
      _send = RETAIN(aPort);
      _recv = RETAIN(anotherPort);
      _components = [[NSMutableArray allocWithZone: [self zone]]
				     initWithArray: items];
    }
  return self;
}

- (NSArray*) components
{
  return AUTORELEASE([_components copy]);
}

- (unsigned) msgid
{
  return _msgid;
}

- (NSPort*) receivePort
{
  return _recv;
}

- (BOOL) sendBeforeDate: (NSDate*)when
{
  return [_send sendBeforeDate: when
		    components: _components
			  from: _recv
		      reserved: 0];
}

- (NSPort*) sendPort
{
  return _send;
}

- (void) setMsgid: (unsigned)anId
{
  _msgid = anId;
}
@end

@implementation	NSPortMessage (Private)
- (NSMutableArray*) _components
{
  return _components;
}
@end

