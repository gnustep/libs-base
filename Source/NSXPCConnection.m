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
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSProxy.h"

#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/GSConfig.h"

#import <objc/runtime.h>

#if GS_USE_LIBXPC
#include <xpc/xpc.h>
#endif

@interface NSXPCConnection (Private)
- (void) _setupLibXPCConnectionIfPossible;
- (void) _sendInvocation: (NSInvocation *)invocation
            errorHandler: (GSXPCProxyErrorHandler)errorHandler
             synchronous: (BOOL)synchronous;
- (NSMethodSignature *) _remoteMethodSignatureForSelector: (SEL)sel;
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

#define GS_ASSIGN_BLOCK(var, val) do { \
  if ((var) != (val)) { \
    if ((var) != 0) { Block_release(var); } \
    (var) = ((val) != 0) ? Block_copy(val) : 0; \
  } \
} while (0)

#define GS_DESTROY_BLOCK(var) do { \
  if ((var) != 0) { \
    Block_release(var); \
    (var) = 0; \
  } \
} while (0)

@interface GSXPCRemoteProxy : NSProxy
{
  NSXPCConnection *_connection;
  GSXPCProxyErrorHandler _errorHandler;
  BOOL _synchronous;
}

- (instancetype) initWithConnection: (NSXPCConnection *)connection
                       errorHandler: (GSXPCProxyErrorHandler)errorHandler
                        synchronous: (BOOL)synchronous;

@end

static NSError *
GSXPCProxyError(NSString *description)
{
  NSDictionary *userInfo;

  userInfo = [NSDictionary dictionaryWithObject: description
                                         forKey: NSLocalizedDescriptionKey];
  return [NSError errorWithDomain: @"NSXPCConnectionErrorDomain"
                             code: 1
                         userInfo: userInfo];
}

@implementation GSXPCRemoteProxy

- (instancetype) initWithConnection: (NSXPCConnection *)connection
                       errorHandler: (GSXPCProxyErrorHandler)errorHandler
                        synchronous: (BOOL)synchronous
{
  _connection = RETAIN(connection);
  GS_ASSIGN_BLOCK(_errorHandler, errorHandler);
  _synchronous = synchronous;
  return self;
}

- (void) dealloc
{
  DESTROY(_connection);
  GS_DESTROY_BLOCK(_errorHandler);
  [super dealloc];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)sel
{
  NSMethodSignature *sig;

  sig = [_connection _remoteMethodSignatureForSelector: sel];
  if (sig == nil)
    {
      sig = [NSMethodSignature signatureWithObjCTypes: "v@:"];
    }
  return sig;
}

- (void) forwardInvocation: (NSInvocation *)invocation
{
  [_connection _sendInvocation: invocation
                  errorHandler: _errorHandler
                   synchronous: _synchronous];
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
  return ([_connection _remoteMethodSignatureForSelector: aSelector] != nil);
}

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
  DESTROY(_exportedObject);
  DESTROY(_remoteObjectInterface);
  DESTROY(_remoteObjectProxy);
  GS_DESTROY_BLOCK(_interruptionHandler);
  GS_DESTROY_BLOCK(_invalidationHandler);
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
            CALL_BLOCK_NO_ARGS(connection->_interruptionHandler);
          }
      }
    else if (event == XPC_ERROR_CONNECTION_INVALID)
      {
        connection->_invalidated = YES;
        if (connection->_invalidationHandler != NULL)
          {
            CALL_BLOCK_NO_ARGS(connection->_invalidationHandler);
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

- (id) exportedObject
{
  return _exportedObject;
}

- (void) setExportedObject: (id)exportedObject
{
  ASSIGN(_exportedObject, exportedObject);
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
  if (_remoteObjectProxy == nil)
    {
      id proxy = [[GSXPCRemoteProxy alloc] initWithConnection: self
                                                 errorHandler: NULL
                                                  synchronous: NO];

      [self setRemoteObjectProxy: proxy];
      RELEASE(proxy);
    }
  return _remoteObjectProxy;
}

- (void) setRemoteObjectProxy: (id)remoteObjectProxy
{
  ASSIGN(_remoteObjectProxy, remoteObjectProxy);
}

- (id) remoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)handler
{
  if (handler == NULL)
    {
      return [self remoteObjectProxy];
    }
  return AUTORELEASE([[GSXPCRemoteProxy alloc] initWithConnection: self
                                                     errorHandler: handler
                                                      synchronous: NO]);
}

- (id) synchronousRemoteObjectProxyWithErrorHandler:
  (GSXPCProxyErrorHandler)handler
{
  return AUTORELEASE([[GSXPCRemoteProxy alloc] initWithConnection: self
                                                     errorHandler: handler
                                                      synchronous: YES]);
}

- (NSMethodSignature *) _remoteMethodSignatureForSelector: (SEL)sel
{
  Protocol *protocol;
  struct objc_method_description desc;

  if (_remoteObjectInterface == nil)
    {
      return nil;
    }

  protocol = [_remoteObjectInterface protocol];
  if (protocol == NULL)
    {
      return nil;
    }

  desc = protocol_getMethodDescription(protocol, sel, YES, YES);
  if (desc.name == NULL)
    {
      desc = protocol_getMethodDescription(protocol, sel, NO, YES);
    }
  if (desc.name == NULL || desc.types == NULL)
    {
      return nil;
    }

  return [NSMethodSignature signatureWithObjCTypes: desc.types];
}

- (void) _sendInvocation: (NSInvocation *)invocation
            errorHandler: (GSXPCProxyErrorHandler)errorHandler
             synchronous: (BOOL)synchronous
{
  NSMethodSignature *signature;

  if (invocation == nil)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler, GSXPCProxyError(@"Missing invocation."));
        }
      return;
    }

  signature = [invocation methodSignature];
  if (signature == nil)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler, GSXPCProxyError(@"Missing method signature."));
        }
      return;
    }

  if (synchronous == YES)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"Synchronous proxy messaging is not implemented yet."));
        }
      return;
    }

  if (strcmp([signature methodReturnType], "v") != 0)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"Only void-returning methods are currently supported."));
        }
      return;
    }

  [self _setupLibXPCConnectionIfPossible];

  if (_invalidated == YES)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler, GSXPCProxyError(@"Connection is invalidated."));
        }
      return;
    }

#if GS_USE_LIBXPC
  if (_xpcConnection == 0)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"XPC transport is unavailable for this connection."));
        }
      return;
    }

  {
    xpc_object_t message;
    const char *selectorName;
    NSUInteger count;
    NSUInteger index;

    message = xpc_dictionary_create(NULL, NULL, 0);
    selectorName = sel_getName([invocation selector]);
    xpc_dictionary_set_string(message, "gsxpc.selector", selectorName);

    count = [signature numberOfArguments];
    xpc_dictionary_set_uint64(message, "gsxpc.argumentCount", (uint64_t)(count - 2));

    for (index = 2; index < count; index++)
      {
        const char *argType;

        argType = [signature getArgumentTypeAtIndex: index];
        if (argType[0] != '@')
          {
            if (errorHandler != NULL)
              {
                NSString *reason;

                reason = [NSString stringWithFormat:
                  @"Only object arguments are currently supported (argument %lu).",
                  (unsigned long)(index - 2)];
                CALL_BLOCK(errorHandler, GSXPCProxyError(reason));
              }
            xpc_release(message);
            return;
          }

        {
          id value = nil;
          NSData *encoded = nil;
          NSString *key;

          [invocation getArgument: &value atIndex: index];
          encoded = [NSArchiver archivedDataWithRootObject: value];
          if (encoded == nil)
            {
              if (errorHandler != NULL)
                {
                  NSString *reason;

                  reason = [NSString stringWithFormat:
                    @"Unable to encode object argument %lu.",
                    (unsigned long)(index - 2)];
                  CALL_BLOCK(errorHandler, GSXPCProxyError(reason));
                }
              xpc_release(message);
              return;
            }

          key = [NSString stringWithFormat: @"gsxpc.arg.%lu",
                                          (unsigned long)(index - 2)];
          xpc_dictionary_set_data(message,
            [key UTF8String],
            [encoded bytes],
            (size_t)[encoded length]);
        }
      }

    xpc_connection_send_message((xpc_connection_t)_xpcConnection, message);
    xpc_release(message);
  }
#else
  if (errorHandler != NULL)
    {
      CALL_BLOCK(errorHandler,
        GSXPCProxyError(@"This build does not include libxpc support."));
    }
#endif
}

- (GSXPCInterruptionHandler) interruptionHandler 
{
  return _interruptionHandler;
}

- (void) setInterruptionHandler: (GSXPCInterruptionHandler)handler
{
  GS_ASSIGN_BLOCK(_interruptionHandler, handler);
}

- (GSXPCInvalidationHandler) invalidationHandler 
{
  return _invalidationHandler;
}

- (void) setInvalidationHandler: (GSXPCInvalidationHandler)handler
{
  GS_ASSIGN_BLOCK(_invalidationHandler, handler);
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
      CALL_BLOCK_NO_ARGS(_invalidationHandler);
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
  _delegate = delegate; // weak reference...
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
          serviceName = [coder decodeObjectForKey: @"GSServiceName"];
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
      [coder encodeObject: _serviceName forKey: @"GSServiceName"];
    }
  else
    {
      [coder encodeObject: _serviceName];
    }
}

@end
