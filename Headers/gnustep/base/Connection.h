/* Interface for GNU Objective-C connection for remote object messaging
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

#include <gnustep/base/prefix.h>
#include <stdlib.h>
#include <stdarg.h>
#include <gnustep/base/Lock.h>
#include <gnustep/base/Collecting.h>
#include <gnustep/base/Dictionary.h>
#include <gnustep/base/NSString.h>
#include <Foundation/NSMapTable.h>

@class Proxy;
@class InPort, OutPort;

@interface Connection : NSObject
{
  unsigned is_valid:1;
  unsigned delay_dialog_interruptions:1;
  unsigned connection_filler:6;
  unsigned retain_count:24;
  unsigned reply_depth;
  InPort *in_port;
  OutPort *out_port;
  unsigned message_count;
  NSMapTable *local_targets;
  NSMapTable *remote_proxies;
  int in_timeout;
  int out_timeout;
  Class in_port_class;
  Class out_port_class;
  Class encoding_class;
  NSMapTable *incoming_xref_2_const_ptr;
  NSMapTable *outgoing_const_ptr_2_xref;
  id delegate;
}

/* Setting and getting class configuration */
+ (Class) defaultInPortClass;
+ (void) setDefaultInPortClass: (Class) aPortClass;
+ (Class) defaultOutPortClass;
+ (void) setDefaultOutPortClass: (Class) aPortClass;
+ (Class) defaultProxyClass;
+ (void) setDefaultProxyClass: (Class) aClass;
+ (int) defaultOutTimeout;
+ (void) setDefaultOutTimeout: (int)to;
+ (int) defaultInTimeout;
+ (void) setDefaultInTimeout: (int)to;

/* Querying the state of all the connections */
+ (int) messagesReceived;
+ (id <Collecting>) allConnections;
+ (unsigned) connectionsCount;
+ (unsigned) connectionsCountWithInPort: (InPort*)aPort;

/* Use these when you're release'ing an object that may have been vended
   or registered for invalidation notification */
+ (void) removeLocalObject: anObj;

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
+ (Connection*) newWithRootObject: anObj;
+ (Connection*) newRegisteringAtName: (id <String>)n withRootObject: anObj;

/* Get a proxy to a remote server object.
   A new connection is created if necessary. */
+ (Proxy*) rootProxyAtName: (id <String>)name onHost: (id <String>)host;
+ (Proxy*) rootProxyAtName: (id <String>)name;
+ (Proxy*) rootProxyAtPort: (OutPort*)anOutPort;
+ (Proxy*) rootProxyAtPort: (OutPort*)anOutPort withInPort: (InPort*)anInPort;

/* This is the designated initializer for the Connection class.
   You don't need to call it yourself. */
+ (Connection*) newForInPort: (InPort*)anInPort outPort: (OutPort*)anOutPort
   ancestorConnection: (Connection*)ancestor;

/* Make a connection object start listening for incoming requests.  After 
   after DATE. */
- (void) runConnectionUntilDate: date;

/* Same as above, but never time out. */
- (void) runConnection;

/* When you get an invalidation notification from a connection, use
   this method in order to find out if any of the proxy objects you're
   using are going away. */
- (id <Collecting>) proxies;

/* If you somehow have a connection to a server, but don't have it's
   a proxy to its root object yet, you can use this to get it. */
- (Proxy*) rootProxy;

/* For getting the root object of a connection or port */
- rootObject;
+ rootObjectForInPort: (InPort*)aPort;

/* Used for setting the root object of a connection that we
   created without one, or changing the root object of a connection
   that already has one. */
+ (void) setRootObject: anObj forInPort: (InPort*)aPort;
- setRootObject: anObj;

/* Querying and setting some instance variables */
- (int) outTimeout;
- (int) inTimeout;
- (void) setOutTimeout: (int)to;
- (void) setInTimeout: (int)to;
- (Class) inPortClass;
- (Class) outPortClass;
- (void) setInPortClass: (Class)aPortClass;
- (void) setOutPortClass: (Class)aPortClass;
- (Class) proxyClass;
- (Class) encodingClass;
- (Class) decodingClass;
- outPort;
- inPort;
- delegate;
- (void) setDelegate: anObj;

- (void) invalidate;
- (BOOL) isValid;

/* Only subclassers and power-users need worry about these */
- (Proxy*) proxyForTarget: (unsigned)target;
- (void) addProxy: (Proxy*)aProxy;
- (BOOL) includesProxyForTarget: (unsigned)target;
- (void) removeProxy: (Proxy*)aProxy;
- (id <Collecting>) localObjects;
- (void) addLocalObject: anObj;
- (BOOL) includesLocalObject: anObj;
- (void) removeLocalObject: anObj;
- (retval_t) forwardForProxy: (Proxy*)object 
    selector: (SEL)sel 
    argFrame: (arglist_t)frame;
- (const char *) typeForSelector: (SEL)sel remoteTarget: (unsigned)target;
- (unsigned) _encoderReferenceForConstPtr: (const void*)ptr;
- (const void*) _decoderConstPtrAtReference: (unsigned)xref;
- (unsigned) _encoderCreateReferenceForConstPtr: (const void*)ptr;
- (unsigned) _decoderCreateReferenceForConstPtr: (const void*)ptr;

@end

extern NSString *ConnectionBecameInvalidNotification;

@protocol ConnectedSelfCoding
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

extern NSString *ConnectionBecameInvalidNotification;
extern NSString *ConnectionWasCreatedNotification;

extern NSString *RunLoopConnectionReplyMode;

#endif /* __Connection_h_OBJECTS_INCLUDE */
