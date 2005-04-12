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
#include "Foundation/NSException.h"
#include "Foundation/NSPortNameServer.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSUserDefaults.h"
#include "GSPrivate.h"


/**
 * The abstract port name server class.  This defines an API for
 * working with port name servers ... objects used to manage access
 * to ports in the distributed objects system (see [NSConnection]).
 */
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

/**
 * Returns the default port name server for the process.<br />
 * The MacOS-X documentation says that this is a nameserver
 * dealing with NSMessagePort objects, but that is incompatible
 * with OpenStep/OPENSTEP/NeXTstep behavior, so GNUstep returns
 * a name server which deals with NSSocketPort objects capable
 * of being used for inter-host communications... unless it
 * is running in compatibility mode.<br />
 * This may change in future releases.
 */
+ (id) systemDefaultPortNameServer
{
  /* Must be kept in sync with [NSPort +initialize]. */
  if (GSUserDefaultsFlag(GSMacOSXCompatible) == YES)
    {
#ifndef __MINGW__
      return [NSMessagePortNameServer sharedInstance];
#else
      return [NSSocketPortNameServer sharedInstance];
#endif
    }
  else
    {
      NSString	*def = [[NSUserDefaults standardUserDefaults]
	stringForKey: @"NSPortIsMessagePort"];

      if (def == nil)
	{
	  GSOnceMLog(
	    @"\nWARNING -\n"
	    @"while the default nameserver used by NSConnection\n"
	    @"currently provides ports which can be used for inter-host\n"
	    @"and inter-user communications, this will be changed so that\n"
	    @"nsconnections will only work between processes owned by the\n"
	    @"same account on the same machine.  This change is for\n"
	    @"MacOSX compatibility and for increased security.\n"
	    @"If your application actually needs to support inter-host\n"
	    @"or inter-user communications, you need to alter it to explicity\n"
	    @"use an instance of the NSSocketPortNameServer class to provide\n"
	    @"name service facilities.\n"
	    @"To stop this message appearing, set the NSPortIsMessagePort\n"
	    @"user default\n\n");
	  return [NSSocketPortNameServer sharedInstance];
	}
      else if ([def boolValue] == NO)
	{
	  return [NSSocketPortNameServer sharedInstance];
	}
      else
	{
#ifndef __MINGW__
	  return [NSMessagePortNameServer sharedInstance];
#else
	  return [NSSocketPortNameServer sharedInstance];
#endif
	}
    }
}

- (void) dealloc
{
  [NSException raise: NSGenericException
	      format: @"attempt to deallocate default port name server"];
}

/**
 * Looks up the port with the specified name on the local host and
 * returns it or nil if no port is found with that name.<br />
 * Different nameservers  have different namespaces appropriate to the
 * type of port they deal with, so failing to find a named port with one
 * nameserver does not guarantee that a port does with that name does
 * not exist.<br />
 * This is a convenience method calling -portForName:onHost: with a nil
 * host argument.
 */
- (NSPort*) portForName: (NSString*)name
{
  return [self portForName: name onHost: nil];
}

/** <override-subclass />
 * Looks up the port with the specified name on host and returns it
 * or nil if no port is found with that name.<br />
 * Different nameservers  have different namespaces appropriate to the
 * type of port they deal with, so failing to find a named port with one
 * nameserver does not guarantee that a port does with that name does
 * not exist.
 */
- (NSPort*) portForName: (NSString*)name
		 onHost: (NSString*)host
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/** <override-subclass />
 * Registers port with the supplied name, so that other processes can
 * look it up to contact it.  A port may be registered with more than
 * one name by making multiple calls to this method.<br />
 * Returns YES on success, NO otherwise.<br />
 * The common cause for failure is that another port is already registered
 * with the name.
 * Raises NSInvalidArgumentException if given bad arguments.
 */
- (BOOL) registerPort: (NSPort*)port
	      forName: (NSString*)name
{
  [self subclassResponsibility: _cmd];
  return NO;
}

/** <override-subclass />
 * Removes any port registration for the supplied name (whether
 * registered in the current process or another).<br />
 * The common cause for failure is that no port is registered
 * with the name.<br />
 * Raises NSInvalidArgumentException if given bad arguments.
 */
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
/** <override-subclass />
 * Return all names that have been registered with the receiver for port.
 */
- (NSArray*) namesForPort: (NSPort*)port
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Remove all names registered with the receiver for port.
 * Probably inefficient ... subclasses might want to override this.
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

/** <override-subclass />
 * Remove the name if and only if it is registered with the receiver
 * for the given port.
 */
- (BOOL) removePort: (NSPort*)port forName: (NSString*)name
{
  [self subclassResponsibility: _cmd];
  return NO;
}
@end

