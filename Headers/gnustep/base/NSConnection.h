/* Interface for GNU Objective-C version of NSConnection
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Original by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Version for OPENSTEP by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
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
@class NSData;

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
  BOOL is_valid;
  BOOL independent_queueing;
  unsigned request_depth;
  NSPort *receive_port;
  NSPort *send_port;
  unsigned message_count;
  unsigned req_out_count;
  unsigned req_in_count;
  unsigned rep_out_count;
  unsigned rep_in_count;
  NSMapTable *local_objects;
  NSMapTable *local_targets;
  NSMapTable *remote_proxies;
  NSTimeInterval reply_timeout;
  NSTimeInterval request_timeout;
  Class receive_port_class;
  Class send_port_class;
  Class encoding_class;
  id delegate;
  NSMutableArray *request_modes;
}

+ (NSArray*) allConnections;
+ (NSConnection*) connectionWithRegisteredName: (NSString*)n
                                          host: (NSString*)h;
+ (id)currentConversation;
+ (NSConnection*) defaultConnection;
+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)name
                                                         host: (NSString*)host;

- (void) addRequestMode: (NSString*)mode;
- (void) addRunLoop: (NSRunLoop *)runloop;
- (id) delegate;
- (void) enableMultipleThreads;
- (BOOL) multipleThreadsEnabled;
- (BOOL) independentConversationQueueing;
- (void) invalidate;
- (BOOL) isValid;
- (BOOL) registerName: (NSString*)name;
- (NSArray *) remoteObjects;
- (void) removeRequestMode: (NSString*)mode;
- (void) removeRunLoop: (NSRunLoop *)runloop;
- (NSTimeInterval) replyTimeout;
- (NSArray*) requestModes;
- (NSTimeInterval) requestTimeout;
- (id) rootObject;
- (NSDistantObject*) rootProxy;
- (void) setDelegate: anObj;
- (void) setIndependentConversationQueueing: (BOOL)flag;
- (void) setReplyTimeout: (NSTimeInterval)seconds;
- (void) setRequestMode: (NSString*)mode;
- (void) setRequestTimeout: (NSTimeInterval)seconds;
- (void) setRootObject: anObj;
- (NSDictionary*) statistics;
@end


/*
 *	This catagory contains methods which were not in the original
 *	OpenStep specification, but which are in OPENSTEP.
 *	Some methods are not yet implemented.
 */
@interface NSConnection (OPENSTEP)
+ (NSConnection*) connectionWithReceivePort: (NSPort*)r
                                   sendPort: (NSPort*)s;
- initWithReceivePort: (NSPort*)r
             sendPort: (NSPort*)s;
- (NSPort*) receivePort;
- (void) runInNewThread;
- (NSPort*) sendPort;
@end


/*
 *	This catagory contains legacy methods from the original GNU 'Connection'
 *	class, and useful extensions to NSConnection.
 */
@interface NSConnection (GNUstepExtensions) <GCFinalization>

- (void) gcFinalize;

/* Setting and getting class configuration */
+ (Class) defaultReceivePortClass;
+ (void) setDefaultReceivePortClass: (Class) aPortClass;
+ (Class) defaultSendPortClass;
+ (void) setDefaultSendPortClass: (Class) aPortClass;
+ (Class) defaultProxyClass;
+ (void) setDefaultProxyClass: (Class) aClass;
+ (int) defaultOutTimeout;
+ (void) setDefaultOutTimeout: (int)to;
+ (int) defaultInTimeout;
+ (void) setDefaultInTimeout: (int)to;

/* Querying the state of all the connections */
+ (int) messagesReceived;
+ (unsigned) connectionsCount;
+ (unsigned) connectionsCountWithInPort: (NSPort*)aPort;

/* Registering your server object on the network.
   These methods create a new connection object that must be "run" in order
   to start handling requests from clients. 
   These method names may change when we get the capability to register
   ports with names after the ports have been created. */
/* I want the second method name to clearly indicate that we're not
   connecting to a pre-existing registration name, we're registering a
   new name, and this method will fail if that name has already been
   registered.  This is why I don't like "newWithRegisteredName:" ---
   it's unclear if we're connecting to another NSConnection that already
   registered with that name. */
+ (NSConnection*) newWithRootObject: anObj;
+ (NSConnection*) newRegisteringAtName: (NSString*)n
			withRootObject: anObj;
+ (NSConnection*) newRegisteringAtName: (NSString*)n
				atPort: (int)portn
			withRootObject: anObj;

/* Get a proxy to a remote server object.
   A new connection is created if necessary. */
+ (NSDistantObject*) rootProxyAtName: (NSString*)name onHost: (NSString*)host;
+ (NSDistantObject*) rootProxyAtName: (NSString*)name;
+ (NSDistantObject*) rootProxyAtPort: (NSPort*)anOutPort;
+ (NSDistantObject*) rootProxyAtPort: (NSPort*)anOutPort withInPort: (NSPort*)anInPort;

/* This is the designated initializer for the NSConnection class.
   You don't need to call it yourself. */
+ (NSConnection*) newForInPort: (NSPort*)anInPort outPort: (NSPort*)anOutPort
   ancestorConnection: (NSConnection*)ancestor;

/* Make a connection object start listening for incoming requests.  After 
   after DATE. */
- (void) runConnectionUntilDate: date;

/* Same as above, but never time out. */
- (void) runConnection;

/* When you get an invalidation notification from a connection, use
   this method in order to find out if any of the proxy objects you're
   using are going away. */
- (id) proxies;


/* For getting the root object of a connection or port */
+ rootObjectForInPort: (NSPort*)aPort;

/* Used for setting the root object of a connection that we
   created without one, or changing the root object of a connection
   that already has one. */
+ (void) setRootObject: anObj forInPort: (NSPort*)aPort;

/* Querying and setting some instance variables */
- (Class) receivePortClass;
- (Class) sendPortClass;
- (void) setReceivePortClass: (Class)aPortClass;
- (void) setSendPortClass: (Class)aPortClass;
- (Class) proxyClass;
- (Class) encodingClass;
- (Class) decodingClass;


/* Only subclassers and power-users need worry about these */
- (void) addProxy: (NSDistantObject*)aProxy;
- (id) includesProxyForTarget: (gsu32)target;
- (void) removeProxy: (NSDistantObject*)aProxy;

// It seems to be a non pure-OPENSTEP definition...
//
// new def :
- (NSArray*)localObjects;
- (void) addLocalObject: anObj;
- (id) includesLocalObject: anObj;
- (void) removeLocalObject: anObj;
- (retval_t) forwardForProxy: (NSDistantObject*)object 
    selector: (SEL)sel 
    argFrame: (arglist_t)frame;
- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target;

@end

GS_EXPORT NSString *ConnectionBecameInvalidNotification;

@interface Object (NSConnectionDelegate)
- (BOOL) connection: (NSConnection*)parent
	shouldMakeNewConnection: (NSConnection*)newConnection;
/*
 *	This method may be used to ask a delegates permission to create
 *	a new connection from the old one.
 *	This method should be implemented in preference to the
 *	[makeNewConnection:sender:] which is obsolete.
 */
- (BOOL) makeNewConnection: (NSConnection*)newConnection
		    sender: (NSConnection*)parent;
/*
 *	This is the old way of doing the same thing as
 *	[connection:shouldMakeNewConnection:]
 *	It is obsolete - don't use it.
 */
- (NSConnection*) connection: ancestorConn didConnect: newConn;
/*
 *	If the delegate responds to this method, it will be used to ask the
 *	delegate's permission to establish a new connection from the old one.
 *	Often this is used so that the delegate can register for invalidation 
 *	notification on new child connections.
 *	This is a GNUstep extension
 *	Normally return newConn.
 */
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


- (BOOL)authenticateComponents: (NSArray *)components
                      withData: (NSData *)authenticationData;
- (NSData *)authenticationDataForComponents: (NSArray *)components;

@end

#define CONNECTION_DEFAULT_TIMEOUT   15.0 /* in seconds */

/*
 *	NSRunLoop mode, NSNotification name and NSException strings.
 */
GS_EXPORT NSString	*NSConnectionReplyMode;
GS_EXPORT NSString *NSConnectionDidDieNotification;
GS_EXPORT NSString *NSConnectionDidInitializeNotification;	/* OPENSTEP	*/

/*
 *	For compatibility with old GNU DO code -
 */
#define	RunLoopConnectionReplyMode NSConnectionReplyMode
#define	ConnectionBecameInvalidNotification NSConnectionDidDieNotification
#define	ConnectionWasCreatedNotification NSConnectionDidInitializeNotification

#endif /* __NSConnection_h_GNUSTEP_BASE_INCLUDE */
