/* NSConnection - OpenStep front-end to GNU Distributed Objects
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

@interface NSConnection : NSObject
{
}

- init;

+ (NSConnection*) connectionWithRegisteredName: (NSString*)name 
  host: (NSString*)host;
+ (NSConnection*) defaultConnection;
+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)name
  host: (NSString*)host;
   
+ (NSArray*) allConnections;
- (BOOL) isValid;

- (BOOL) registerName: (NSString*)name;

- (id) delegate;
- (void) setDelegate: (id)anObject;

- (id) rootObject;
- (NSDistantObject*) rootProxy;
- (void) setRootObject: (id)anObject;

- (NSString*) requestMode;
- (void) setRequestMode: (NSString*)mode;

- (BOOL) independentConversationQueueing;
- (void) setIndependentConversationQueueing: (BOOL)f;

- (NSTimeInterval) replyTimeout;
- (NSTimeInterval) requestTimeout;
- (void) setReplyTimeout: (NSTimeInterval)i;
- (void) setRequestTimeout: (NSTimeInterval)i;

- (NSDictionary*) statistics;

@end

@interface Object (NSConnection_Delegate)
- (BOOL) makeNewConnection: (NSConnection*)c sender: (NSConnection*)ancester;
@end

#define NSConnectionDeath ConnectionBecameInvalid
