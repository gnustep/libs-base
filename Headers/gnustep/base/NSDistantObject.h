/* NSDistantObject 
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: Mar 1997
   
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

@class NSConnection;

@interface NSDistantObject : NSObject
{
}

+ (NSDistantObject*) proxyWithLocal: target connection: (NSConnection*)conn;
+ (NSDistantObject*) proxyWithTarget: target connection: (NSConnection*) conn;

- initWithLocal: target connection: (NSConnection*) connection;
- initWithTarget: target connection: (NSConnection*) connection;

- (void) setProtocolForProxy: (Protocol*)proto;

- (NSConnection*) connectionForProxy;

@end
