/* Interface for GNU Objective-C connection for remote object messaging
   Copyright (C) 1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
   This file is part of the GNU Objective C Class Library.

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

#ifndef __Connection_h_OBJECTS_INCLUDE
#define __Connection_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <stdlib.h>
#include <stdarg.h>
#include <objc/hash.h>
#include <objc/Protocol.h>
#include <objects/Lock.h>
#include <objects/InvalidationListening.h>
#include <objects/RetainingNotifier.h>
#include <objects/Collecting.h>
#include <objects/Dictionary.h>
#include <objects/NSString.h>

@class Proxy;
@class Port;
@class ConnectedCoder;

@interface Connection : RetainingNotifier <InvalidationListening>
{
  id delegate;
  Port *in_port;
  Port *out_port;
  unsigned message_count;
  Dictionary *local_targets;
  Dictionary *remote_proxies;
  int in_timeout;
  int out_timeout;
  id port_class;
  int queue_dialog_interruptions;
  Dictionary *incoming_const_ptrs;
  Dictionary *outgoing_const_ptrs;
}

+ setDefaultPortClass: aPortClass;
+ defaultProxyClass;
+ setDefaultProxyClass: aClass;
+ (int) defaultOutTimeout;
+ setDefaultOutTimeout: (int)to;
+ (int) defaultInTimeout;
+ setDefaultInTimeout: (int)to;
/* Setting and getting class configuration */

+ (int) messagesReceived;
+ (id <Collecting>) allConnections;
+ (unsigned) connectionsCount;
+ (unsigned) connectionsCountWithInPort: (Port*)aPort;
/* Querying the state of all the connections */

+ removeObject: anObj;
+ unregisterForInvalidationNotification: anObj;
/* Use these when you're release'ing an object that may have been vended
   or registered for invalidation notification */

+ (Connection*) newWithRootObject: anObj;
+ (Connection*) newRegisteringAtName: (id <String>)n withRootObject: anObj;
/* Registering your server object on the network.
   These methods create a new connection object that must be "run" in order
   to start handling requests from clients. 
   These method names may change when we get the capability to register
   ports with names after the ports have been created. */
/* I want the second method name to clearly indicate that we're not
   connecting to a pre-existing registration name, we're registering a
   new name, and this method will fail if that name has already been
   registered.  This is why I don't like "newWithRegisteredName:" ---
   it's unclear if we're connecting to another Connection that already
   registered with that name. */

+ (Proxy*) rootProxyAtName: (id <String>)name onHost: (id <String>)host;
+ (Proxy*) rootProxyAtName: (id <String>)name;
+ (Proxy*) rootProxyAtPort: (Port*)anOutPort;
+ (Proxy*) rootProxyAtPort: (Port*)anOutPort withInPort: (Port*)anInPort;
/* Get a proxy to a remote server object.
   A new connection is created if necessary. */

+ (Connection*) newForInPort: (Port*)anInPort outPort: (Port*)anOutPort
   ancestorConnection: (Connection*)ancestor;
/* This is the designated initializer for the Connection class.
   You don't need to call it yourself. */

- (void) runConnectionWithTimeout: (int)timeout;
/* Make a connection object start listening for incoming requests.  After 
   `timeout' milliseconds without receiving anything, return. */

- (void) runConnection;
/* Same as above, but never time out. */

- (id <Collecting>) proxies;
/* When you get an invalidation notification from a connection, use
   this method in order to find out if any of the proxy objects you're
   using are going away. */

- (Proxy*) rootProxy;
/* If you somehow have a connection to a server, but don't have it's
   a proxy to its root object yet, you can use this to get it. */

- rootObject;
+ rootObjectForInPort: (Port*)aPort;
/* For getting the root object of a connection or port */

+ setRootObject: anObj forInPort: (Port*)aPort;
- setRootObject: anObj;
/* Used for setting the root object of a connection that we
   created without one, or changing the root object of a connection
   that already has one. */

- (int) outTimeout;
- (int) inTimeout;
- setOutTimeout: (int)to;
- setInTimeout: (int)to;
- portClass;
- setPortClass: aPortClass;
- proxyClass;
- coderClass;
- (Port*) outPort;
- (Port*) inPort;
- delegate;
- setDelegate: anObj;
/* Querying and setting some instance variables */

- (Proxy*) proxyForTarget: (unsigned)target;
- addProxy: (Proxy*)aProxy;
- (BOOL) includesProxyForTarget: (unsigned)target;
- removeProxy: (Proxy*)aProxy;
- (id <Collecting>) localObjects;
- addLocalObject: anObj;
- (BOOL) includesLocalObject: anObj;
- removeLocalObject: anObj;
- (retval_t) connectionForward: (Proxy*)object : (SEL)sel : (arglist_t)frame;
- (const char *) _typeForSelector: (SEL)sel remoteTarget: (unsigned)target;
- (Dictionary*) _incomingConstPtrs;
- (Dictionary*) _outgoingConstPtrs;
/* Only subclassers and power-users need worry about these */

@end

@protocol ConnectedCoding
+ (void) encodeObject: anObj withConnectedCoder: aRmc;
@end

@interface Object (ConnectionDelegate)
- (Connection*) connection: ancestorConn didConnect: newConn;
/* If the delegate responds to this method, it will be used to ask the
   delegate's permission to establish a new connection from the old one.
   Often this is used so that the delegate can register for invalidation 
   notification on new child connections.
   Normally return newConn. */
@end

#if 0 /* Put in Coder.m until ObjC runtime category-loading bug is fixed */

@interface Object (ConnectionRequests)
- classForConnectedCoder: aRmc;
/* Must return the class that will be created on the remote side
   of the connection.
   Used by the remote objects system to determine how the receiver
   should be encoded across the network.
   In general, you can:
     return [Proxy class] to send a proxy of the receiver;
     return [self class] to send the receiver bycopy. 
   The Object class implementation returns [Proxy class]. */
+ (void) encodeObject: anObject withConnectedCoder: aRmc;
/* This message is sent to the class returned by -classForConnectedCoder:
   The Proxy class implementation encodes a proxy for anObject.
   The Object class implementation encodes the receiver itself. */
@end

@interface Object (Retaining) <Retaining>
/* Make sure objects don't crash when you send them <Retaining> messages.
   These implementations, however, do nothing. */
@end

#endif /* 0 Put in Coder.m */

#define CONNECTION_DEFAULT_TIMEOUT   15000 /* in milliseconds */

#endif /* __Connection_h_OBJECTS_INCLUDE */
