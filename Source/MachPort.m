/* Implementation of Machport-based port object for use with Connection
   Copyright (C) 1994, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: September 1994
   
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

/* This old code really needs work; it does not currently compile. */

#if __mach__

#include <config.h>
#include <base/MachPort.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSException.h>
#include <base/Set.h>

#include <mach/cthreads.h>
#include <mach/notify.h>

static Dictionary *portDictionary;
static NSLock *portDictionaryGate;

@implementation MachPort

+ initialize
{
  portDictionaryGate = [NSLock new];
  NSAssert(sizeof(int) == sizeof(port_t), NSInternalInconsistencyException);
  portDictionary = [[Dictionary alloc] 
		    initWithType:@encode(id)
		    keyType:@encode(int)];
  return self;
}

/* This not tested */
static int 
listen_for_invalidation (any_t arg)
{
  kern_return_t r;
  notification_t m;
  m.notify_header.msg_size = sizeof(notification_t);
  m.notify_header.msg_local_port = task_notify();
  for (;;)
    {
      r = msg_receive((msg_header_t*)&m, MSG_OPTION_NONE, 0);
      switch (r)
	{
	case RCV_SUCCESS:
	  fprintf(stderr, "notification id %d\n", (int)m.notify_header.msg_id);
	  break;
	case RCV_TIMED_OUT:
	  fprintf(stderr, "notification msg_receive timed out\n");
	  exit(-1);
	default:
	  mach_error("notification", r);
	  exit(-1);
	}
      switch (m.notify_header.msg_id)
	{
	case NOTIFY_PORT_DELETED:
	  [[MachPort newFromMachPort:m.notify_port] invalidate];
	  break;
	case NOTIFY_MSG_ACCEPTED:
	  break;
	case NOTIFY_PORT_DESTROYED:
	  [[MachPort newFromMachPort:m.notify_port] invalidate];
	  break;
	default:
	  mach_error("notification", r);
	  exit(-1);
	}
      /* Where do we free the object? */
    }
  return 0;
}

/* This not tested */
+ listenForPortInvalidation
{
  MachPort *listenPort = [MachPort new];
  task_set_special_port(task_self(), TASK_NOTIFY_PORT, [listenPort mach_port]);
  cthread_detach(cthread_fork((any_t)listen_for_invalidation, (any_t)0));
  return self;
}

/* designated initializer */
+ newFromMachPort: (port_t)p dealloc: (BOOL)f
{
  MachPort *aPort;
  [portDictionaryGate lock];
  if ((aPort = [portDictionary elementAtKey:(int)p]))
    {
      [portDictionaryGate unlock];
      [aPort addReference];
      return aPort;
    }
  aPort = [[self alloc] init];
  aPort->mach_port = p;
  aPort->deallocate = f;
  [portDictionary addElement:aPort atKey:(int)p];
  [portDictionaryGate unlock];
  return aPort;
}

+ newFromMachPort: (port_t)p
{
  return [self newFromMachPort:p dealloc:NO];
}

+ new
{
  kern_return_t  error;
  port_t p;

  if ((error=port_allocate(task_self(), &p)) != KERN_SUCCESS) {
    mach_error("port_allocate failed", error); 
    exit(1);
  }
  return [self newFromMachPort:p];
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfCType: @encode(BOOL)
	  at: &deallocate
	  withName: @""];
  [aCoder encodeMachPort: mach_port];
}

+ newWithCoder: aCoder
{
  BOOL f;
  port_t mp;
  MachPort *p;

  [aCoder decodeValueOfCType: @encode(BOOL)
	  at: &f
	  withName: NULL];
  [aCoder decodeMachPort: &mp];

  p = [MachPort newFromMachPort:mp dealloc:f];
  return p;
}

- (unsigned) hash
{
  /* What should this be? */
  return (unsigned)self;
}

- (void) dealloc
{
  if (refcount-1 == 0)
    {
      [portDictionaryGate lock];
      [portDictionaryGate removeElementAtKey:(int)machPort];
      [portDictionaryGate unlock];
      if (deallocate)
	{
	  kern_return_t  error;
	  error = port_deallocate(task_self(), machPort);
	  if (error != KERN_SUCCESS) {
	    mach_error("port_deallocate failed", error); 
	    exit(1);
	  }
	}
    }
  [super dealloc];
  return self;
}

- (mach_port_t) machPort
{
  return mach_port;
}

@end

#endif /* __mach__ */
