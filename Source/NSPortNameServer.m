/** Implementation of NSPortNameServer class for Distributed Objects
   Copyright (C) 1998,1999,2000 Free Software Foundation, Inc.

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

   <title>NSPortNameServer class reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "Foundation/NSString.h"
#include "Foundation/NSByteOrder.h"
#include "Foundation/NSException.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSFileHandle.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSNotificationQueue.h"
#include "Foundation/NSPort.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSSet.h"
#include "Foundation/NSHost.h"
#include "Foundation/NSTask.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSTimer.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSPortNameServer.h"
#include "Foundation/NSDebug.h"
#ifdef __MINGW__
#include <winsock2.h>
#include <wininet.h>
#else
#include <netinet/in.h>
#include <arpa/inet.h>
#endif

/*
 *	Protocol definition stuff for talking to gdomap process.
 */
#include        "../Tools/gdomap.h"

#define stringify_it(X) #X
#define	make_gdomap_port(X)	stringify_it(X)



@implementation NSPortNameServer

+ (id) allocWithZone: (NSZone*)aZone
{
  [NSException raise: NSGenericException
	      format: @"attempt to create extra port name server"]; 
  return nil;
}

+ (void) initialize
{
  if (self == [NSPortNameServer class])
    {
    }
}

+ (id) systemDefaultPortNameServer
{
  return [NSSocketPortNameServer sharedInstance];
  // return [NSMessagePortNameServer sharedInstance];
}

- (void) dealloc
{
  [NSException raise: NSGenericException
	      format: @"attempt to deallocate default port name server"]; 
}

- (NSPort*) portForName: (NSString*)name
{
  return [self portForName: name onHost: nil];
}

- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) removePortForName: (NSString*)name
{
  [self subclassResponsibility: _cmd];
  return NO;
}
@end

/**
 * Some extensions to make cleaning up port names easier.
 */
@implementation	NSPortNameServer (GNUstep)
/** Return all names for port
 */
- (NSArray*) namesForPort: (NSPort*)port
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Remove all names for port.  Probably inefficient ... subclasses 
 * should override this.
 */
- (BOOL) removePort: (NSPort*)port
{
  NSEnumerator	*e = [[self namesForPort: port] objectEnumerator];
  NSString	*n;
  BOOL		removed = NO;

  while ((n = [e nextObject]) != nil)
    {
      if ([self removePort: port forName: n] == YES)
	{
	  removed = YES;
	}
    }
  return removed;
}

/**
 * Remove the name if and only if it is registered by the given port.
 */
- (BOOL) removePort: (NSPort*)port forName: (NSString*)name
{
  [self subclassResponsibility: _cmd];
  return NO;
}
@end

