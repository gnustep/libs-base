/* Implementation of NSPortMessage for GNUstep
   Copyright (C) 1998 Free Software Foundation, Inc.
   
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
  RELEASE(_components);
  [super dealloc];
}

/*	PortMessages MUST be initialised with ports and data.	*/
- (id) init
{
  [self shouldNotImplement: _cmd];
  return nil;
}

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
  if (self)
    {
      _components = [[NSMutableArray allocWithZone: [self zone]]
				 initWithCapacity: [items count] + 2];
      [_components addObject: aPort];
      [_components addObject: anotherPort];
      [_components addObjectsFromArray: items];
    }
  return self;
}

- (void) addComponent: (id)aComponent
{
  NSAssert([aComponent isKindOfClass: [NSData class]]
	|| [aComponent isKindOfClass: [NSPort class]],
	NSInvalidArgumentException);
  [_components addObject: aComponent];
}

- (NSArray*) components
{
  NSRange	r = NSMakeRange(2, [_components count]-2);

  return [_components subarrayWithRange: r];
}

- (unsigned) msgid
{
  return _msgid;
}

- (NSPort*) receivePort
{
  return [_components objectAtIndex: 1];
}

- (BOOL) sendBeforeDate: (NSDate*)when
{
  NSPort	*port = [self sendPort];

  return [port sendBeforeDate: when
	    components: [self components]
		  from: [self receivePort]
	      reserved: [port reservedSpaceLength]];
}

- (NSPort*) sendPort
{
  return [_components objectAtIndex: 0];
}

- (void) setMsgid: (unsigned)anId
{
  _msgid = anId;
}
@end

