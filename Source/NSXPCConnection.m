/* Implementation of class NSXPCConnection
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

#import "common.h"
#import "Foundation/NSXPCConnection.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/GSConfig.h"

#if GS_USE_LIBXPC
#include <xpc/xpc.h>
#endif

@interface NSXPCConnection ()
{
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
#if GS_USE_LIBXPC
  xpc_connection_t _xpcConnection;
#endif
}

- (void) _setupLibXPCConnectionIfPossible;
@end

@implementation NSXPCConnection

- (instancetype) init
{
  return [self initWithServiceName: nil];
}

- (void) dealloc
{
  [self invalidate];
  DESTROY(_serviceName);
  DESTROY(_endpoint);
  DESTROY(_exportedInterface);
  DESTROY(_remoteObjectInterface);
  DESTROY(_remoteObjectProxy);
  DESTROY(_interruptionHandler);
  DESTROY(_invalidationHandler);
  [super dealloc];
}

- (void) _setupLibXPCConnectionIfPossible
{
#if GS_USE_LIBXPC
  uint64_t flags = 0;
  NSXPCConnection *connection = self;

  if (_xpcConnection != NULL || _serviceName == nil || _invalidated == YES)
    {
      return;
    }
#ifdef XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
  if ((_options & NSXPCConnectionPrivileged) == NSXPCConnectionPrivileged)
    {
      flags |= XPC_CONNECTION_MACH_SERVICE_PRIVILEGED;
    }
#endif
  _xpcConnection = xpc_connection_create_mach_service([_serviceName UTF8String],
    NULL, flags);
  if (_xpcConnection == NULL)
    {
      return;
    }

  xpc_connection_set_event_handler(_xpcConnection, ^(xpc_object_t event) {
    if (event == XPC_ERROR_CONNECTION_INTERRUPTED)
      {
        if (connection->_interruptionHandler != NULL)
          {
            connection->_interruptionHandler();
          }
      }
    else if (event == XPC_ERROR_CONNECTION_INVALID)
      {
        connection->_invalidated = YES;
        if (connection->_invalidationHandler != NULL)
          {
            connection->_invalidationHandler();
          }
      }
  });

  if (_resumed == YES)
    {
      xpc_connection_resume(_xpcConnection);
    }
#endif
}

- (instancetype) initWithServiceName:(NSString *)serviceName
{
  return [self initWithMachServiceName: serviceName options: 0];
}

- (NSString *) serviceName
{
  return _serviceName;
}

- (void) setServiceName: (NSString *)serviceName
{
  ASSIGNCOPY(_serviceName, serviceName);
  [self _setupLibXPCConnectionIfPossible];
}

- (instancetype) initWithMachServiceName: (NSString *)name
				 options: (NSXPCConnectionOptions)options
{
  if ((self = [super init]) != nil)
    {
      _options = options;
      [self setServiceName: name];
    }
  return self;
}

- (instancetype) initWithListenerEndpoint: (NSXPCListenerEndpoint *)endpoint
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_endpoint, endpoint);
    }
  return self;
}


- (NSXPCListenerEndpoint *) endpoint
{
  return _endpoint;
}

- (void) setEndpoint: (NSXPCListenerEndpoint *) endpoint
{
  ASSIGN(_endpoint, endpoint);
}

- (NSXPCInterface *) exportedInterface
{
  return _exportedInterface;
}

- (void) setExportInterface: (NSXPCInterface *)exportedInterface
{
  ASSIGN(_exportedInterface, exportedInterface);
}

- (NSXPCInterface *) remoteObjectInterface
{
  return _remoteObjectInterface;
}

- (void) setRemoteObjectInterface: (NSXPCInterface *)remoteObjectInterface
{
  ASSIGN(_remoteObjectInterface, remoteObjectInterface);
}

- (id) remoteObjectProxy
{
  return _remoteObjectProxy;
}

- (void) setRemoteObjectProxy: (id)remoteObjectProxy
{
  ASSIGN(_remoteObjectProxy, remoteObjectProxy);
}

- (id) remoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)handler
{
  return [self remoteObjectProxy];
}

- (id) synchronousRemoteObjectProxyWithErrorHandler:
  (GSXPCProxyErrorHandler)handler
{
  return [self remoteObjectProxy];
}

- (GSXPCInterruptionHandler) interruptionHandler 
{
  return _interruptionHandler;
}

- (void) setInterruptionHandler: (GSXPCInterruptionHandler)handler
{
  ASSIGNCOPY(_interruptionHandler, handler);
}

- (GSXPCInvalidationHandler) invalidationHandler 
{
  return _invalidationHandler;
}

- (void) setInvalidationHandler: (GSXPCInvalidationHandler)handler
{
  ASSIGNCOPY(_invalidationHandler, handler);
}

- (void) resume
{
  _resumed = YES;
  [self _setupLibXPCConnectionIfPossible];
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      xpc_connection_resume(_xpcConnection);
    }
#endif
}

- (void) suspend
{
  _resumed = NO;
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      xpc_connection_suspend(_xpcConnection);
    }
#endif
}

- (void) invalidate
{
  BOOL wasInvalidated = _invalidated;

  _invalidated = YES;
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      xpc_connection_cancel(_xpcConnection);
      xpc_release(_xpcConnection);
      _xpcConnection = NULL;
    }
#endif
  if (wasInvalidated == NO && _invalidationHandler != NULL)
    {
      _invalidationHandler();
    }
}

- (NSUInteger) auditSessionIdentifier
{
  return 0;
}
- (pid_t) processIdentifier
{
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      return xpc_connection_get_pid(_xpcConnection);
    }
#endif
  return 0;
}
- (uid_t) effectiveUserIdentifier
{
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      return xpc_connection_get_euid(_xpcConnection);
    }
#endif
  return (uid_t)0;
}
- (gid_t) effectiveGroupIdentifier
{
#if GS_USE_LIBXPC
  if (_xpcConnection != NULL)
    {
      return xpc_connection_get_egid(_xpcConnection);
    }
#endif
  return (gid_t)0;
}
@end

@implementation NSXPCListener

+ (NSXPCListener *) serviceListener
{
  return [self notImplemented: _cmd];
}

+ (NSXPCListener *) anonymousListener
{
  return [self notImplemented: _cmd];
}

- (instancetype) initWithMachServiceName:(NSString *)name
{
  return [self notImplemented: _cmd];
}

- (id <NSXPCListenerDelegate>) delegate
{
  return [self notImplemented: _cmd];
}

- (void) setDelegate: (id <NSXPCListenerDelegate>) delegate
{
  [self notImplemented: _cmd];
}

- (NSXPCListenerEndpoint *) endpoint
{
  return [self notImplemented: _cmd];
}

- (void) setEndpoint: (NSXPCListenerEndpoint *)endpoint
{
  [self notImplemented: _cmd];
}

- (void) resume
{
  [self notImplemented: _cmd];
}

- (void) suspend
{
  [self notImplemented: _cmd];
}

- (void) invalidate
{
  [self notImplemented: _cmd];
}

@end

@implementation NSXPCInterface

+ (NSXPCInterface *) interfaceWithProtocol: (Protocol *)protocol
{
  return [self notImplemented: _cmd];
}

- (Protocol *) protocol
{
  return [self notImplemented: _cmd];
}

- (void) setProtocol: (Protocol *)protocol
{
  [self notImplemented: _cmd];
}

- (void) setClasses: (NSSet *)classes
	forSelector: (SEL)sel
      argumentIndex: (NSUInteger)arg
	    ofReply: (BOOL)ofReply
{
  [self notImplemented: _cmd];
}

- (NSSet *) classesForSelector: (SEL)sel
		 argumentIndex: (NSUInteger)arg
		       ofReply: (BOOL)ofReply
{
  return [self notImplemented: _cmd];
}

- (void) setInterface: (NSXPCInterface *)ifc
	  forSelector: (SEL)sel
	argumentIndex: (NSUInteger)arg
	      ofReply: (BOOL)ofReply
{
  [self notImplemented: _cmd];
}

- (NSXPCInterface *) interfaceForSelector: (SEL)sel
			    argumentIndex: (NSUInteger)arg
				  ofReply: (BOOL)ofReply
{
  return [self notImplemented: _cmd];
}

@end

@implementation NSXPCListenerEndpoint

- (instancetype) initWithCoder: (NSCoder *)coder
{
  return [self notImplemented: _cmd];
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [self notImplemented: _cmd];
}

@end

