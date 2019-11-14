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
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include <Foundation/NSXPCConnection.h>
  
@implementation NSXPCConnection

- (instancetype)initWithServiceName:(NSString *)serviceName
{
  return nil;
}

- (NSString *) serviceName
{
  return nil;
}

- (void) setServiceName: (NSString *)serviceName
{
}

- (instancetype)initWithMachServiceName:(NSString *)name options:(NSXPCConnectionOptions)options
{
  return nil;
}

- (instancetype)initWithListenerEndpoint:(NSXPCListenerEndpoint *)endpoint
{
  return nil;
}


- (NSXPCListenerEndpoint *) endpoint
{
  return nil;
}

- (void) setEndpoint: (NSXPCListenerEndpoint *) endpoint
{
}

- (NSXPCInterface *) exportedInterface
{
  return nil;
}

- (void) setExportInterface: (NSXPCInterface *)exportedInterface
{
}

- (NSXPCInterface *) remoteObjectInterface
{
  return nil;
}

- (void) setRemoteObjectInterface: (NSXPCInterface *)remoteObjectInterface
{
}

- (id) remoteObjectProxy
{
  return nil;
}

- (void) setRemoteObjectProxy: (id)remoteObjectProxy
{
}

- (id) remoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)handler
{
  return nil;
}

- (id) synchronousRemoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)handler
{
  return nil;
}

- (GSXPCInterruptionHandler) interruptionHandler 
{
  return NULL;
}

- (void) setInterruptionHandler: (GSXPCInterruptionHandler)handler
{
}

- (GSXPCInvalidationHandler) invalidationHandler 
{
  return NULL;
}

- (void) setInvalidationHandler: (GSXPCInvalidationHandler)handler
{
}

- (void) resume
{
}

- (void) suspend
{
}

- (void) invalidate
{
}

- (NSUInteger) auditSessionIdentifier
{
  return 0;
}
- (NSUInteger) processIdentifier
{
  return 0;
}
- (NSUInteger) effectiveUserIdentifier
{
  return 0;
}
- (NSUInteger) effectiveGroupIdentifier
{
  return 0;
}
@end

@implementation NSXPCListener

+ (NSXPCListener *) serviceListener
{
  return nil;
}

+ (NSXPCListener *) anonymousListener
{
  return nil;
}

- (instancetype) initWithMachServiceName:(NSString *)name
{
  return nil;
}

- (id <NSXPCListenerDelegate>) delegate
{
  return nil;
}

- (void) setDelegate: (id <NSXPCListenerDelegate>) delegate
{
}

- (NSXPCListenerEndpoint *) endpoint
{
  return nil;
}

- (void) setEndpoint: (NSXPCListenerEndpoint *)endpoint
{
}

- (void) resume
{
}

- (void) suspend
{
}

- (void) invalidate
{
}

@end

@implementation NSXPCInterface

+ (NSXPCInterface *) interfaceWithProtocol: (Protocol *)protocol
{
  return nil;
}

- (Protocol *) protocol
{
  return nil;
}

- (void) setProtocol: (Protocol *)protocol
{
}

- (void) setClasses: (NSSet *)classes forSelector: (SEL)sel argumentIndex: (NSUInteger)arg ofReply: (BOOL)ofReply
{
}

- (NSSet *) classesForSelector: (SEL)sel argumentIndex: (NSUInteger)arg ofReply: (BOOL)ofReply
{
  return nil;
}

- (void) setInterface: (NSXPCInterface *)ifc forSelector: (SEL)sel argumentIndex: (NSUInteger)arg ofReply: (BOOL)ofReply
{
}

- (NSXPCInterface *) interfaceForSelector: (SEL)sel argumentIndex: (NSUInteger)arg ofReply: (BOOL)ofReply
{
  return nil;
}

@end

@implementation NSXPCListenerEndpoint

- (instancetype) initWithCoder: (NSCoder *)coder
{
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

@end

