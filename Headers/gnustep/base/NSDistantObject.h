/* Interface for GNU Objective-C version of NSDistantObject
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: August 1997
   
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

#ifndef __NSDistantObject_h_GNUSTEP_BASE_INCLUDE
#define __NSDistantObject_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSProxy.h>

@class	NSConnection;

@interface NSDistantObject : NSProxy <NSCoding>
{
@private
    NSConnection	*_connection;
    id			_object;
    BOOL		_isLocal;
    BOOL		_isVended;
    Protocol		*_protocol;
}

+ (NSDistantObject*) proxyWithLocal: anObject
			 connection: (NSConnection*)aConnection;
+ (NSDistantObject*) proxyWithTarget: anObject
			  connection: (NSConnection*)aConnection;

- (NSConnection*) connectionForProxy;
- initWithLocal:anObject connection: (NSConnection*)aConnection;
- initWithTarget:anObject connection: (NSConnection*)aConnection;
- (void) setProtocolForProxy: (Protocol*)aProtocol;

@end

@interface NSDistantObject(GNUstepExtensions)

+ newForRemoteTarget: (unsigned)target connection: (NSConnection*)conn;

- awakeAfterUsingCoder: aDecoder;
- classForPortCoder;
+ newWithCoder: aRmc;
- (const char *) selectorTypeForProxy: (SEL)selector;
- forward: (SEL)aSel :(arglist_t)frame;
- targetForProxy;
@end

#endif /* __NSDistantObject_h_GNUSTEP_BASE_INCLUDE */
