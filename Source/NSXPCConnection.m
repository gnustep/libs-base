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
#define EXPOSE_NSXPCConnection_IVARS 1
#define EXPOSE_NSXPCListener_IVARS 1
#define EXPOSE_NSXPCInterface_IVARS 1
#define EXPOSE_NSXPCListenerEndpoint_IVARS 1

#import "Foundation/NSXPCConnection.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArchiver.h"

#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/GSConfig.h"

#if GS_USE_LIBXPC
#include <xpc/xpc.h>
#endif

@interface NSXPCConnection (Private)
- (void) _setupLibXPCConnectionIfPossible;
@end

@interface NSXPCListenerEndpoint (Private)
- (instancetype) initWithServiceName: (NSString *)serviceName;
- (NSString *) _serviceName;
@end

static NSString *
GSXPCSignatureKey(SEL sel, NSUInteger arg, BOOL ofReply)
{
  return [NSString stringWithFormat: @"%s:%lu:%u",
    (sel == 0 ? "" : sel_getName(sel)),
    (unsigned long)arg,
    (unsigned int)(ofReply ? 1 : 0)];
}

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

  if (_xpcConnection != 0 || _serviceName == nil || _invalidated == YES)
    {
      return;
    }
#ifdef XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
  if ((_options & NSXPCConnectionPrivileged) == NSXPCConnectionPrivileged)
    {
      flags |= XPC_CONNECTION_MACH_SERVICE_PRIVILEGED;
    }
#endif
  _xpcConnection = (void *)xpc_connection_create_mach_service(
    [_serviceName UTF8String], NULL, flags);
  if (_xpcConnection == 0)
    {
      return;
    }

  xpc_connection_set_event_handler((xpc_connection_t)_xpcConnection,
    ^(xpc_object_t event) {
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
      xpc_connection_resume((xpc_connection_t)_xpcConnection);
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
      NSString *serviceName = nil;

      ASSIGN(_endpoint, endpoint);
      if ([_endpoint respondsToSelector: @selector(_serviceName)])
        {
          serviceName = [_endpoint performSelector: @selector(_serviceName)];
        }
      if (serviceName != nil)
        {
          [self setServiceName: serviceName];
        }
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
  if (_xpcConnection != 0)
    {
      xpc_connection_resume((xpc_connection_t)_xpcConnection);
    }
#endif
}

- (void) suspend
{
  _resumed = NO;
#if GS_USE_LIBXPC
  if (_xpcConnection != 0)
    {
      xpc_connection_suspend((xpc_connection_t)_xpcConnection);
    }
#endif
}

- (void) invalidate
{
  BOOL wasInvalidated = _invalidated;

  _invalidated = YES;
#if GS_USE_LIBXPC
  if (_xpcConnection != 0)
    {
      xpc_connection_cancel((xpc_connection_t)_xpcConnection);
      xpc_release((xpc_connection_t)_xpcConnection);
      _xpcConnection = 0;
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
  if (_xpcConnection != 0)
    {
      return xpc_connection_get_pid((xpc_connection_t)_xpcConnection);
    }
#endif
  return 0;
}
- (uid_t) effectiveUserIdentifier
{
#if GS_USE_LIBXPC
  if (_xpcConnection != 0)
    {
      return xpc_connection_get_euid((xpc_connection_t)_xpcConnection);
    }
#endif
  return (uid_t)0;
}
- (gid_t) effectiveGroupIdentifier
{
#if GS_USE_LIBXPC
  if (_xpcConnection != 0)
    {
      return xpc_connection_get_egid((xpc_connection_t)_xpcConnection);
    }
#endif
  return (gid_t)0;
}
@end

@implementation NSXPCListener

+ (NSXPCListener *) serviceListener
{
  return AUTORELEASE([[self alloc] initWithMachServiceName: nil]);
}

+ (NSXPCListener *) anonymousListener
{
  return AUTORELEASE([[self alloc] initWithMachServiceName: nil]);
}

- (instancetype) initWithMachServiceName:(NSString *)name
{
  if ((self = [super init]) != nil)
    {
      NSXPCListenerEndpoint *ep;

      ASSIGNCOPY(_machServiceName, name);
      ep = [[NSXPCListenerEndpoint alloc] initWithServiceName: _machServiceName];
      ASSIGN(_endpoint, ep);
      RELEASE(ep);
      _resumed = NO;
      _invalidated = NO;
    }
  return self;
}

- (instancetype) init
{
  return [self initWithMachServiceName: nil];
}

- (void) dealloc
{
  DESTROY(_delegate);
  DESTROY(_endpoint);
  DESTROY(_machServiceName);
  [super dealloc];
}

- (id <NSXPCListenerDelegate>) delegate
{
  return _delegate;
}

- (void) setDelegate: (id <NSXPCListenerDelegate>) delegate
{
  ASSIGN(_delegate, delegate);
}

- (NSXPCListenerEndpoint *) endpoint
{
  return _endpoint;
}

- (void) setEndpoint: (NSXPCListenerEndpoint *)endpoint
{
  ASSIGN(_endpoint, endpoint);
}

- (void) resume
{
  if (_invalidated == NO)
    {
      _resumed = YES;
    }
}

- (void) suspend
{
  _resumed = NO;
}

- (void) invalidate
{
  _resumed = NO;
  _invalidated = YES;
}

@end

@implementation NSXPCInterface

+ (NSXPCInterface *) interfaceWithProtocol: (Protocol *)protocol
{
  NSXPCInterface *ifc;

  ifc = AUTORELEASE([[self alloc] init]);
  [ifc setProtocol: protocol];
  return ifc;
}

- (instancetype) init
{
  if ((self = [super init]) != nil)
    {
      _classes = [NSMutableDictionary new];
      _interfaces = [NSMutableDictionary new];
    }
  return self;
}

- (void) dealloc
{
  DESTROY(_classes);
  DESTROY(_interfaces);
  [super dealloc];
}

- (Protocol *) protocol
{
  return _protocol;
}

- (void) setProtocol: (Protocol *)protocol
{
  _protocol = protocol;
}

- (void) setClasses: (NSSet *)classes
	forSelector: (SEL)sel
      argumentIndex: (NSUInteger)arg
	    ofReply: (BOOL)ofReply
{
  NSString *key = GSXPCSignatureKey(sel, arg, ofReply);

  if (classes == nil)
    {
      [_classes removeObjectForKey: key];
    }
  else
    {
      [_classes setObject: [[classes copy] autorelease] forKey: key];
    }
}

- (NSSet *) classesForSelector: (SEL)sel
		 argumentIndex: (NSUInteger)arg
		       ofReply: (BOOL)ofReply
{
  NSString *key = GSXPCSignatureKey(sel, arg, ofReply);

  return [_classes objectForKey: key];
}

- (void) setInterface: (NSXPCInterface *)ifc
	  forSelector: (SEL)sel
	argumentIndex: (NSUInteger)arg
	      ofReply: (BOOL)ofReply
{
  NSString *key = GSXPCSignatureKey(sel, arg, ofReply);

  if (ifc == nil)
    {
      [_interfaces removeObjectForKey: key];
    }
  else
    {
      [_interfaces setObject: ifc forKey: key];
    }
}

- (NSXPCInterface *) interfaceForSelector: (SEL)sel
			    argumentIndex: (NSUInteger)arg
				  ofReply: (BOOL)ofReply
{
  NSString *key = GSXPCSignatureKey(sel, arg, ofReply);

  return [_interfaces objectForKey: key];
}

@end

@implementation NSXPCListenerEndpoint

- (instancetype) initWithServiceName: (NSString *)serviceName
{
  if ((self = [super init]) != nil)
    {
      ASSIGNCOPY(_serviceName, serviceName);
    }
  return self;
}

- (instancetype) init
{
  return [self initWithServiceName: nil];
}

- (void) dealloc
{
  DESTROY(_serviceName);
  [super dealloc];
}

- (NSString *) _serviceName
{
  return _serviceName;
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  NSString *serviceName = nil;

  if ((self = [super init]) != nil)
    {
      if ([coder respondsToSelector: @selector(decodeObjectForKey:)])
        {
          serviceName = [coder decodeObjectForKey: @"serviceName"];
        }
      else
        {
          serviceName = [coder decodeObject];
        }
      ASSIGNCOPY(_serviceName, serviceName);
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder respondsToSelector: @selector(encodeObject:forKey:)])
    {
      [coder encodeObject: _serviceName forKey: @"serviceName"];
    }
  else
    {
      [coder encodeObject: _serviceName];
    }
}

@end
