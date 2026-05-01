/**Definition of class NSXPCConnection
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory Casamento <greg.casamento@gmail.com>
   Date: Tue Nov 12 23:50:29 EST 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSXPCConnection_h_GNUSTEP_BASE_INCLUDE
#define _NSXPCConnection_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSError.h>

#include <sys/types.h> // for gid_t and uid_t

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)

#if defined(_WIN32)
#if defined(_MSC_VER)
typedef int pid_t;
#endif
typedef unsigned gid_t;
typedef unsigned uid_t;
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSMutableDictionary, NSString, NSOperationQueue, NSSet, NSLock, NSError;
@class NSXPCConnection, NSXPCListener, NSXPCInterface, NSXPCListenerEndpoint;
@protocol NSXPCListenerDelegate;

/**
 * Handles asynchronous errors that occur while sending a message through
 * a remote object proxy.
 */
DEFINE_BLOCK_TYPE(GSXPCProxyErrorHandler, void, NSError *);

/**
 * Invoked when a connection is interrupted and may recover later.
 */
DEFINE_BLOCK_TYPE_NO_ARGS(GSXPCInterruptionHandler, void);

/**
 * Invoked when a connection is invalidated and can no longer be used.
 */
DEFINE_BLOCK_TYPE_NO_ARGS(GSXPCInvalidationHandler, void);


/**
 * Defines methods that create proxy objects for messaging a remote process.
 */
@protocol NSXPCProxyCreating

/**
 * Returns a proxy object used to invoke methods on the remote object
 * asynchronously.
 */
- (id) remoteObjectProxy;

/**
 * Returns an asynchronous remote proxy and installs an error handler that
 * receives communication failures for invocations sent through that proxy.
 */
- (id) remoteObjectProxyWithErrorHandler: (GSXPCProxyErrorHandler)handler;

/**
 * Returns a proxy that performs synchronous round trips and reports failures
 * through the supplied error handler.
 */
- (id) synchronousRemoteObjectProxyWithErrorHandler: (GSXPCProxyErrorHandler)handler;

@end

/**
 * Option flag used to request connection to a privileged service instance.
 */
enum
{
    NSXPCConnectionPrivileged = (1 << 12UL)
};

/**
 * Bitmask of options controlling how an XPC connection is created.
 */
typedef NSUInteger NSXPCConnectionOptions; 
  
/**
 * Represents a bidirectional communication channel to an XPC service or
 * listener endpoint.
 */
GS_EXPORT_CLASS
@interface NSXPCConnection : NSObject <NSXPCProxyCreating>
{
#if GS_EXPOSE(NSXPCConnection)
  @private
  NSString *_serviceName;
  NSXPCListenerEndpoint *_endpoint;
  NSXPCInterface *_exportedInterface;
  NSXPCInterface *_remoteObjectInterface;
  id _remoteObjectProxy;
  GSXPCInterruptionHandler _interruptionHandler;
  GSXPCInvalidationHandler _invalidationHandler;
  NSXPCConnectionOptions _options;
  BOOL _resumed;
  BOOL _invalidated;
  void *_xpcConnection;
#endif
}

/**
 * Initializes a connection that targets an existing listener endpoint.
 */
- (instancetype) initWithListenerEndpoint: (NSXPCListenerEndpoint *)endpoint;

/**
 * Initializes a connection to a Mach service name using the supplied
 * connection options.
 */
- (instancetype) initWithMachServiceName: (NSString *)name
				 options: (NSXPCConnectionOptions)options;

/**
 * Initializes a connection to a named service.
 */
- (instancetype) initWithServiceName:(NSString *)serviceName;
  
/**
 * Returns the listener endpoint currently associated with the connection.
 */
- (NSXPCListenerEndpoint *) endpoint;

/**
 * Sets the listener endpoint used by the connection.
 */
- (void) setEndpoint: (NSXPCListenerEndpoint *) endpoint;
  
/**
 * Returns the interface that describes objects exported by this process.
 */
- (NSXPCInterface *) exportedInterface;

/**
 * Sets the interface that describes methods this process exports to the
 * remote side.
 */
- (void) setExportInterface: (NSXPCInterface *)exportedInterface;
  
/**
 * Returns the interface that describes methods available on the remote
 * object.
 */
- (NSXPCInterface *) remoteObjectInterface;

/**
 * Sets the interface used to validate and encode messages sent to the remote
 * object.
 */
- (void) setRemoteObjectInterface: (NSXPCInterface *)remoteObjectInterface;


/**
 * Returns an asynchronous proxy for invoking methods on the remote object.
 */
- (id) remoteObjectProxy;

/**
 * Sets the underlying proxy object used for remote invocations.
 */
- (void) setRemoteObjectProxy: (id)remoteObjectProxy;

/**
 * Returns an asynchronous remote proxy that uses the supplied handler to
 * report transport or encoding failures.
 */
- (id) remoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)handler;

/**
 * Returns the service name currently associated with the connection.
 */
- (NSString *) serviceName;

/**
 * Sets the service name used when establishing the connection.
 */
- (void) setServiceName: (NSString *)serviceName;
  
/**
 * Returns a proxy that blocks for replies and reports failures through the
 * supplied handler.
 */
- (id) synchronousRemoteObjectProxyWithErrorHandler:
  (GSXPCProxyErrorHandler)handler;

/**
 * Returns the block invoked when the connection is interrupted.
 */
- (GSXPCInterruptionHandler) interruptionHandler; 

/**
 * Sets the block invoked when the connection is interrupted.
 */
- (void) setInterruptionHandler: (GSXPCInterruptionHandler)handler;
  
/**
 * Returns the block invoked after the connection becomes invalid.
 */
- (GSXPCInvalidationHandler) invalidationHandler; 

/**
 * Sets the block invoked when the connection is invalidated permanently.
 */
- (void) setInvalidationHandler: (GSXPCInvalidationHandler)handler;
  
/**
 * Activates the connection so it can begin receiving and sending messages.
 */
- (void) resume;

/**
 * Temporarily stops message delivery on the connection.
 */
- (void) suspend;

/**
 * Permanently tears down the connection and releases underlying resources.
 */
- (void) invalidate;

/**
 * Returns the audit session identifier associated with the remote process.
 */
- (NSUInteger) auditSessionIdentifier;

/**
 * Returns the process identifier of the connected peer.
 */
- (pid_t) processIdentifier;

/**
 * Returns the effective user identifier of the connected peer.
 */
- (uid_t) effectiveUserIdentifier;

/**
 * Returns the effective group identifier of the connected peer.
 */
- (gid_t) effectiveGroupIdentifier;

@end


/**
 * Accepts incoming XPC connections for a service and dispatches them to
 * a delegate for validation and configuration.
 */
@interface NSXPCListener : NSObject
{
#if GS_EXPOSE(NSXPCListener)
  @private
  id <NSXPCListenerDelegate> _delegate;
  NSXPCListenerEndpoint *_endpoint;
  NSString *_machServiceName;
  BOOL _resumed;
  BOOL _invalidated;
#endif
}

/**
 * Returns the listener for the current XPC service process.
 */
+ (NSXPCListener *) serviceListener;

/**
 * Creates and returns a listener with an endpoint that can be shared
 * manually with another process.
 */
+ (NSXPCListener *) anonymousListener;

/**
 * Initializes a listener that receives incoming connections for the named
 * Mach service.
 */
- (instancetype) initWithMachServiceName:(NSString *)name;

/**
 * Returns the delegate that decides whether new incoming connections are
 * accepted.
 */
- (id <NSXPCListenerDelegate>) delegate;

/**
 * Sets the delegate used to inspect and accept new incoming connections.
 */
- (void) setDelegate: (id <NSXPCListenerDelegate>) delegate;

/**
 * Returns the endpoint representing this listener.
 */
- (NSXPCListenerEndpoint *) endpoint;

/**
 * Sets the endpoint associated with this listener.
 */
- (void) setEndpoint: (NSXPCListenerEndpoint *)endpoint;
  
/**
 * Starts the listener so it can begin accepting incoming connections.
 */
- (void) resume;

/**
 * Temporarily stops the listener from accepting incoming connections.
 */
- (void) suspend;

/**
 * Permanently stops the listener and invalidates its endpoint.
 */
- (void) invalidate;

@end

/**
 * Receives connection acceptance decisions for an [NSXPCListener].
 */
@protocol NSXPCListenerDelegate <NSObject>

/**
 * Asks the delegate whether a newly arrived connection should be accepted.
 */
- (BOOL) listener: (NSXPCListener *)listener
  shouldAcceptNewConnection: (NSXPCConnection *)newConnection;

@end

/**
 * Describes the allowed methods and object classes that can be exchanged
 * over an XPC connection.
 */
@interface NSXPCInterface : NSObject
{
#if GS_EXPOSE(NSXPCInterface)
  @private
  Protocol *_protocol;
  NSMutableDictionary *_classes;
  NSMutableDictionary *_interfaces;
#endif
}

/**
 * Creates an interface description from an Objective-C protocol.
 */
+ (NSXPCInterface *) interfaceWithProtocol: (Protocol *)protocol;

/**
 * Returns the protocol used to define this interface.
 */
- (Protocol *) protocol;

/**
 * Sets the protocol used to define this interface.
 */
- (void) setProtocol: (Protocol *)protocol;

/**
 * Records which classes are permitted for a specific selector argument or
 * reply position.
 */
- (void) setClasses: (NSSet *)classes
	forSelector: (SEL)sel
      argumentIndex: (NSUInteger)arg
	    ofReply: (BOOL)ofReply;

/**
 * Returns the classes currently permitted for a selector argument or reply
 * position.
 */
- (NSSet *) classesForSelector: (SEL)sel
		 argumentIndex: (NSUInteger)arg
		       ofReply: (BOOL)ofReply;

/**
 * Associates a nested XPC interface with a selector argument or reply
 * position for proxying complex object graphs.
 */
- (void) setInterface: (NSXPCInterface *)ifc
	  forSelector: (SEL)sel
	argumentIndex: (NSUInteger)arg
	      ofReply: (BOOL)ofReply;

/**
 * Returns the nested XPC interface associated with a selector argument or
 * reply position.
 */
- (NSXPCInterface *) interfaceForSelector: (SEL)sel
			    argumentIndex: (NSUInteger)arg
				  ofReply: (BOOL)ofReply;

@end

/**
 * Serializable object that represents a listener endpoint which can be passed
 * to another process and used to create a connection back to a listener.
 */
GS_EXPORT_CLASS
@interface NSXPCListenerEndpoint : NSObject <NSCoding>  // NSSecureCoding
{
#if GS_EXPOSE(NSXPCListenerEndpoint)
  @private
  NSString *_serviceName;
#endif
}
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSXPCConnection_h_GNUSTEP_BASE_INCLUDE */
