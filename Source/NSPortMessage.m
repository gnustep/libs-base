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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
    [components release];
    [super dealloc];
}

/*	PortMessages MUST be initialised with ports and data.	*/
- (id) init
{
    [self notImplemented: _cmd];
    return nil;
}

- (id) initWithMachMessage: (void*)buffer
{
    [self notImplemented: _cmd];
    return nil;
}

/*	This is the designated initialiser.	*/
- (id) initWithSendPort: (NSPort*)aPort
	    receivePort: (NSPort*)anotherPort
	     components: (NSArray*)items
{
    self = [super init];
    if (self) {
	components = [[NSMutableArray allocWithZone: [self zone]]
			initWithCapacity: [items count] + 2];
	[components addObject: aPort];
	[components addObject: anotherPort];
	[components addObjectsFromArray: items];
    }
    return self;
}

- (void) sendBeforeDate: (NSDate*)when
{
    [self notImplemented: _cmd];
}

- (NSArray*) components
{
    NSRange	r = NSMakeRange(2, [components count]-2);

    return [components subarrayWithRange: r];
}

- (NSPort*) sendPort
{
    return [components objectAtIndex: 0];
}

- (NSPort*) receivePort
{
    return [components objectAtIndex: 1];
}

- (void) setMsgid: (unsigned)anId
{
    msgid = anId;
}

- (unsigned) msgid
{
    return msgid;
}
@end

@implementation	NSPortMessage (GNUstep)
- (void) setSequence: (unsigned)seq
{
    sequence = seq;
}

- (unsigned) sequence
{
    return sequence;
}
@end

