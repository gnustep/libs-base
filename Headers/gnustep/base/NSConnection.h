/* Interface for GNU Objective-C version of NSConnection
   Copyright (C) 1997,2000 Free Software Foundation, Inc.
   
   Original by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Version for OPENSTEP by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997, updated June 2000
   
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

#ifndef __NSConnection_h_GNUSTEP_BASE_INCLUDE
#define __NSConnection_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSMapTable.h>

@class NSDistantObject;
@class NSPort;
@class NSPortNameServer;
@class NSData;
@class NSInvocation;

/*
 *	Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
GS_EXPORT NSString *NSConnectionRepliesReceived;
GS_EXPORT NSString *NSConnectionRepliesSent;
GS_EXPORT NSString *NSConnectionRequestsReceived;
GS_EXPORT NSString *NSConnectionRequestsSent;
/* These Are GNUstep extras */
GS_EXPORT NSString *NSConnectionLocalCount;	/* Objects sent out	*/
GS_EXPORT NSString *NSConnectionProxyCount;	/* Objects received	*/



/*
 *	NSConnection class interface.
 *
 *	A few methods are in the specification but not yet implemented.
 */
@interface NSConnection : NSObject
{
@private
  BOOL			_isValid;
  BOOL			_independentQueueing;
  BOOL			_authenticateIn;
  BOOL			_authenticateOut;
  BOOL			_multipleThreads;
  NSPort		*_receivePort;
  NSPort		*_sendPort;
  unsigned		_requestDepth;
  unsigned		_messageCount;
  unsigned		_reqOutCount;
  unsigned		_reqInCount;
  unsigned		_repOutCount;
  unsigned		_repInCount;
#ifndef	_IN_CONNECTION_M
#define	GSIMapTable	void*
#endif
  GSIMapTable		_localObjects;
  GSIMapTable		_localTargets;
  GSIMapTable		_remoteProxies;
  GSIMapTable		_replyMap;
#ifndef	_IN_CONNECTION_M
#undef	GSIMapTable
#endif
  NSTimeInterval	_replyTimeout;
  NSTimeInterval	_requestTimeout;
  NSMutableArray	*_requestModes;
  NSMutableArray	*_runLoops;
  NSMutableArray	*_requestQueue;
  id			_delegate;
  NSRecursiveLock	*_refGate;
  NSMutableArray	*_cachedDecoders;
  NSMutableArray	*_cachedEncoders;
  NSString		*_registeredName;
  NSPortNameServer	*_nameServer;
}

+ (NSArray*) allConnections;
+ (NSConnection*) connectionWithReceivePort: (NSPort*)r
                                   sendPort: (NSPort*)s;
+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
                                          host: (NSString*)h;
+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
                                          host: (NSString*)h
			       usingNameServer: (NSPortNameServer*)s;
+ (id) currentConversation;
+ (NSConnection*) defaultConnection;
+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
                                                         host: (NSString*)h;
+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)n
  host: (NSString*)h usingNameServer: (NSPortNameServer*)s;


- (void) addRequestMode: (NSString*)mode;
- (void) addRunLoop: (NSRunLoop*)loop;
- (id) delegate;
- (void) enableMultipleThreads;
- (BOOL) independentConversationQueueing;
- (id) initWithReceivePort: (NSPort*)r
		  sendPort: (NSPort*)s;
- (void) invalidate;
- (BOOL) isValid;
- (NSArray*)localObjects;
- (BOOL) multipleThreadsEnabled;
- (NSPort*) receivePort;
- (BOOL) registerName: (NSString*)name;
- (BOOL) registerName: (NSString*)name withNameServer: (NSPortNameServer*)svr;
- (NSArray*) remoteObjects;
- (void) removeRequestMode: (NSString*)mode;
- (void) removeRunLoop: (NSRunLoop *)loop;
- (NSTimeInterval) replyTimeout;
- (NSArray*) requestModes;
- (NSTimeInterval) requestTimeout;
- (id) rootObject;
- (NSDistantObject*) rootProxy;
- (void) runInNewThread;
- (NSPort*) sendPort;
- (void) setDelegate: anObj;
- (void) setIndependentConversationQueueing: (BOOL)flag;
- (void) setReplyTimeout: (NSTimeInterval)to;
- (void) setRequestMode: (NSString*)mode;
- (void) setRequestTimeout: (NSTimeInterval)to;
- (void) setRootObject: anObj;
- (NSDictionary*) statistics;
@end


/*
 *	This catagory contains legacy methods from the original GNU 'Connection'
 *	class, and useful extensions to NSConnection.
 */
@interface NSConnection (GNUstepExtensions) <GCFinalization>

+ (NSConnection*) newRegisteringAtName: (NSString*)name
			withRootObject: (id)anObject;

- (void) gcFinalize;

- (retval_t) forwardForProxy: (NSDistantObject*)object 
		    selector: (SEL)sel 
		    argFrame: (arglist_t)argframe;
- (void) forwardInvocation: (NSInvocation *)inv 
		  forProxy: (NSDistantObject*)object;
- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target;

@end

GS_EXPORT NSString *ConnectionBecameInvalidNotification;

@interface Object (NSConnectionDelegate)
/*
 *	This method may be used to ask a delegates permission to create
 *	a new connection from the old one.
 *	This method should be implemented in preference to the
 *	[makeNewConnection:sender:] which is obsolete.
 */
- (BOOL) connection: (NSConnection*)parent
  shouldMakeNewConnection: (NSConnection*)newConnection;

/*
 *	This is the old way of doing the same thing as
 *	[connection:shouldMakeNewConnection:]
 *	It is obsolete - don't use it.
 */
- (BOOL) makeNewConnection: (NSConnection*)newConnection
		    sender: (NSConnection*)parent;

/*
 *	If the delegate responds to this method, it will be used to ask the
 *	delegate's permission to establish a new connection from the old one.
 *	Often this is used so that the delegate can register for invalidation 
 *	notification on new child connections.
 *	This is a GNUstep extension
 *	Normally return newConn.
 */
- (NSConnection*) connection: (NSConnection*)ancestorConn
		  didConnect: (NSConnection*)newConn;

/*
 * These are like the MacOS-X delegate methods, except that we provide the
 * components in mutable arrays, so that the delegate can alter the data
 * items in the array.  Of course, you must do that WITH CARE.
 */ 
- (BOOL) authenticateComponents: (NSMutableArray*)components
		       withData: (NSData*)authenticationData;
- (NSData*) authenticationDataForComponents: (NSMutableArray*)components;

@end

@interface Object (NSPortCoder)
- (Class) classForPortCoder;
/*
 *	Must return the class that will be created on the remote side
 *	of the connection.  If the class to be created is not the same
 *	as that of the object returned by replacementObjectForPortCoder:
 *	then the class must be capable of recognising the object it
 *	actually gets in its initWithCoder: method.
 *	The default operation is to return NSDistantObject unless the
 *	object is being sent bycopy, in which case the objects actual
 *	class is returned.  To force bycopy operation the object should
 *	return its own class.
 */
- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder;
/*
 *	This message is sent to an object about to be encoded for sending
 *	over the wire.  The default action is to return an NSDistantObject
 *	which is a local proxy for the object unless the object is being
 *	sent bycopy, in which case the actual object is returned.
 *	To force bycopy, an object should return itsself.
 */

@end

/*
 *	NSRunLoop mode, NSNotification name and NSException strings.
 */
GS_EXPORT NSString	*NSConnectionReplyMode;
GS_EXPORT NSString	*NSConnectionDidDieNotification;
GS_EXPORT NSString	*NSConnectionDidInitializeNotification;	/* OPENSTEP */
GS_EXPORT NSString	*NSFailedAuthenticationException;	/* MacOS-X  */

#endif /* __NSConnection_h_GNUSTEP_BASE_INCLUDE */
