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
#import "Foundation/NSArray.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSProxy.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSLock.h"

#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/GSConfig.h"

#import <objc/runtime.h>

#if GS_USE_LIBXPC
#include <xpc/xpc.h>
#endif

@interface NSXPCConnection (Private)
- (void) _setupLibXPCConnectionIfPossible;
- (void) _initializeReplyTracking;
- (NSNumber *) _nextMessageIdentifierObject;
- (void) _registerPendingReply: (id)pending forMessageID: (NSNumber *)messageID;
- (id) _takePendingReplyForMessageID: (NSNumber *)messageID;
- (void) _failAllPendingRepliesWithError: (NSError *)error;
- (void) _handleIncomingXPCEvent: (void *)event;
- (void) _handleIncomingInvokeEvent: (void *)event;
- (void) _sendInvokeReplyForEvent: (void *)event
            withReturnObject: (id)returnObject
              returnData: (NSData *)returnData
              returnType: (const char *)returnType
                             error: (NSError *)error;
- (void) _sendInvocation: (NSInvocation *)invocation
            errorHandler: (GSXPCProxyErrorHandler)errorHandler
             synchronous: (BOOL)synchronous;
- (NSMethodSignature *) _remoteMethodSignatureForSelector: (SEL)sel;
- (NSMethodSignature *) _exportedMethodSignatureForSelector: (SEL)sel;
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

static const char *
GSXPCStrippedTypeEncoding(const char *type)
{
  while (*type == 'r' || *type == 'n' || *type == 'N'
    || *type == 'o' || *type == 'O' || *type == 'R'
    || *type == 'V')
    {
      type++;
    }
  return type;
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

static BOOL
GSXPCObjectMatchesAllowedClasses(id object, NSSet *allowedClasses)
{
  NSEnumerator *enumerator;
  id candidate;

  if (object == nil || allowedClasses == nil || [allowedClasses count] == 0)
    {
      return YES;
    }

  enumerator = [allowedClasses objectEnumerator];
  while ((candidate = [enumerator nextObject]) != nil)
    {
      if (class_isMetaClass(object_getClass(candidate))
        && [object isKindOfClass: candidate])
        {
          return YES;
        }
    }
  return NO;
}

static BOOL
GSXPCValidateDecodedObjectGraph(id object, NSSet *allowedClasses)
{
  NSEnumerator *enumerator;
  id child;

  if (object == nil || allowedClasses == nil || [allowedClasses count] == 0)
    {
      return YES;
    }

  if (GSXPCObjectMatchesAllowedClasses(object, allowedClasses) == NO)
    {
      return NO;
    }

  if ([object isKindOfClass: [NSArray class]])
    {
      enumerator = [object objectEnumerator];
      while ((child = [enumerator nextObject]) != nil)
        {
          if (GSXPCValidateDecodedObjectGraph(child, allowedClasses) == NO)
            {
              return NO;
            }
        }
    }
  else if ([object isKindOfClass: [NSSet class]])
    {
      enumerator = [object objectEnumerator];
      while ((child = [enumerator nextObject]) != nil)
        {
          if (GSXPCValidateDecodedObjectGraph(child, allowedClasses) == NO)
            {
              return NO;
            }
        }
    }
  else if ([object isKindOfClass: [NSDictionary class]])
    {
      id key;
      id value;

      enumerator = [object keyEnumerator];
      while ((key = [enumerator nextObject]) != nil)
        {
          value = [object objectForKey: key];
          if (GSXPCValidateDecodedObjectGraph(key, allowedClasses) == NO
            || GSXPCValidateDecodedObjectGraph(value, allowedClasses) == NO)
            {
              return NO;
            }
        }
    }

  return YES;
}

static BOOL
GSXPCTypeSize(const char *type, NSUInteger *size)
{
  NSUInteger localSize;

  if (type == 0 || type[0] == '\0')
    {
      return NO;
    }
  localSize = 0;
  NSGetSizeAndAlignment(type, &localSize, NULL);
  if (localSize == 0)
    {
      return NO;
    }
  if (size != 0)
    {
      *size = localSize;
    }
  return YES;
}

@implementation NSXPCCoder

+ (NSData *) archivedDataWithRootObject: (id)object
{
  return [NSArchiver archivedDataWithRootObject: object];
}

+ (id) unarchivedObjectWithData: (NSData *)data
{
  return [self unarchivedObjectWithData: data error: NULL];
}

+ (id) unarchivedObjectWithData: (NSData *)data
                          error: (NSError **)error
{
  return [self unarchivedObjectWithData: data
                         allowedClasses: nil
                                  error: error];
}

+ (id) unarchivedObjectWithData: (NSData *)data
                 allowedClasses: (NSSet *)allowedClasses
                          error: (NSError **)error
{
  id value;

  value = [NSUnarchiver unarchiveObjectWithData: data];
  if (value == nil && data != nil && [data length] > 0)
    {
      if (error != NULL)
        {
          NSDictionary *userInfo;

          userInfo = [NSDictionary dictionaryWithObject:
            @"Unable to decode XPC payload data."
            forKey: NSLocalizedDescriptionKey];
          *error = [NSError errorWithDomain: @"NSXPCConnectionErrorDomain"
                                       code: 2
                                   userInfo: userInfo];
        }
      return nil;
    }

  if (GSXPCValidateDecodedObjectGraph(value, allowedClasses) == NO)
    {
      if (error != NULL)
        {
          NSDictionary *userInfo;

          userInfo = [NSDictionary dictionaryWithObject:
            @"Decoded XPC object is not in the allowed class set."
            forKey: NSLocalizedDescriptionKey];
          *error = [NSError errorWithDomain: @"NSXPCConnectionErrorDomain"
                                       code: 3
                                   userInfo: userInfo];
        }
      return nil;
    }
  return value;
}

@end

@interface GSXPCPendingReply : NSObject
{
  NSCondition *_condition;
  BOOL _resolved;
  NSSet *_allowedClasses;
  id _returnObject;
  NSData *_returnData;
  NSString *_returnType;
  NSError *_error;
}

- (instancetype) initWithAllowedClasses: (NSSet *)allowedClasses;
- (NSSet *) allowedClasses;

- (void) resolveWithReturnObject: (id)returnObject
        returnData: (NSData *)returnData
        returnType: (NSString *)returnType
          error: (NSError *)error;
- (BOOL) waitForResolutionUntilDate: (NSDate *)limitDate
                       returnObject: (id *)returnObject
          returnData: (NSData **)returnData
          returnType: (NSString **)returnType
                              error: (NSError **)error;

@end

@implementation GSXPCPendingReply

- (instancetype) initWithAllowedClasses: (NSSet *)allowedClasses
{
  if ((self = [super init]) != nil)
    {
      _condition = [NSCondition new];
      ASSIGN(_allowedClasses, allowedClasses);
      _resolved = NO;
    }
  return self;
}

- (void) dealloc
{
  DESTROY(_condition);
  DESTROY(_allowedClasses);
  DESTROY(_returnObject);
  DESTROY(_returnData);
  DESTROY(_returnType);
  DESTROY(_error);
  [super dealloc];
}

- (NSSet *) allowedClasses
{
  return _allowedClasses;
}

- (void) resolveWithReturnObject: (id)returnObject
                    returnData: (NSData *)returnData
                    returnType: (NSString *)returnType
                         error: (NSError *)error
{
  [_condition lock];
  if (_resolved == NO)
    {
      ASSIGN(_returnObject, returnObject);
      ASSIGN(_returnData, returnData);
      ASSIGN(_returnType, returnType);
      ASSIGN(_error, error);
      _resolved = YES;
      [_condition broadcast];
    }
  [_condition unlock];
}

- (BOOL) waitForResolutionUntilDate: (NSDate *)limitDate
                       returnObject: (id *)returnObject
                         returnData: (NSData **)returnData
                         returnType: (NSString **)returnType
                              error: (NSError **)error
{
  BOOL resolved;

  [_condition lock];
  while (_resolved == NO)
    {
      if (limitDate == nil)
        {
          [_condition wait];
        }
      else if ([_condition waitUntilDate: limitDate] == NO)
        {
          break;
        }
    }
  resolved = _resolved;
  if (resolved == YES)
    {
      if (returnObject != 0)
        {
          *returnObject = [[_returnObject retain] autorelease];
        }
      if (returnData != 0)
        {
          *returnData = [[_returnData retain] autorelease];
        }
      if (returnType != 0)
        {
          *returnType = [[_returnType retain] autorelease];
        }
      if (error != 0)
        {
          *error = [[_error retain] autorelease];
        }
    }
  [_condition unlock];
  return resolved;
}

@end

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
  DESTROY(_pendingReplies);
  DESTROY(_pendingRepliesLock);
  GS_DESTROY_BLOCK(_interruptionHandler);
  GS_DESTROY_BLOCK(_invalidationHandler);
  [super dealloc];
}

- (void) _initializeReplyTracking
{
  if (_pendingRepliesLock == nil)
    {
      _pendingRepliesLock = [NSLock new];
    }
  if (_pendingReplies == nil)
    {
      _pendingReplies = [NSMutableDictionary new];
    }
  if (_nextMessageIdentifier == 0)
    {
      _nextMessageIdentifier = 1;
    }
}

- (NSNumber *) _nextMessageIdentifierObject
{
  NSNumber *value;

  [self _initializeReplyTracking];
  [_pendingRepliesLock lock];
  value = [NSNumber numberWithUnsignedLongLong: _nextMessageIdentifier++];
  [_pendingRepliesLock unlock];
  return value;
}

- (void) _registerPendingReply: (id)pending forMessageID: (NSNumber *)messageID
{
  if (pending == nil || messageID == nil)
    {
      return;
    }
  [self _initializeReplyTracking];
  [_pendingRepliesLock lock];
  [_pendingReplies setObject: pending forKey: messageID];
  [_pendingRepliesLock unlock];
}

- (id) _takePendingReplyForMessageID: (NSNumber *)messageID
{
  id pending;

  if (messageID == nil)
    {
      return nil;
    }
  [self _initializeReplyTracking];
  [_pendingRepliesLock lock];
  pending = [[[_pendingReplies objectForKey: messageID] retain] autorelease];
  if (pending != nil)
    {
      [_pendingReplies removeObjectForKey: messageID];
    }
  [_pendingRepliesLock unlock];
  return pending;
}

- (void) _failAllPendingRepliesWithError: (NSError *)error
{
  NSArray *pending;
  NSUInteger index;

  [self _initializeReplyTracking];
  [_pendingRepliesLock lock];
  pending = [[_pendingReplies allValues] retain];
  [_pendingReplies removeAllObjects];
  [_pendingRepliesLock unlock];

  for (index = 0; index < [pending count]; index++)
    {
      GSXPCPendingReply *entry;

      entry = [pending objectAtIndex: index];
      [entry resolveWithReturnObject: nil
              returnData: nil
              returnType: nil
               error: error];
    }
  RELEASE(pending);
}

- (void) _handleIncomingXPCEvent: (void *)eventPtr
{
#if GS_USE_LIBXPC
  xpc_object_t event;

  event = (xpc_object_t)eventPtr;
  if (xpc_get_type(event) == XPC_TYPE_DICTIONARY)
    {
      const char *kind;

      kind = xpc_dictionary_get_string(event, "gsxpc.kind");
      if (kind != NULL && strcmp(kind, "reply") == 0)
        {
          NSNumber *messageID;
          GSXPCPendingReply *pending;
          const char *errorText;
          NSError *error;
          id returnObject;
          NSData *returnValueData;
          NSString *returnValueType;
          const char *returnTypeCString;
          const void *returnData;
          size_t returnDataLength;

          messageID = [NSNumber numberWithUnsignedLongLong:
            xpc_dictionary_get_uint64(event, "gsxpc.messageID")];
          pending = [self _takePendingReplyForMessageID: messageID];
          if (pending == nil)
            {
              return;
            }

          error = nil;
          returnObject = nil;
          returnValueData = nil;
          returnValueType = nil;
          errorText = xpc_dictionary_get_string(event, "gsxpc.error");
          if (errorText != NULL)
            {
              NSString *reason;

              reason = [NSString stringWithUTF8String: errorText];
              error = GSXPCProxyError(reason);
            }

          returnTypeCString = xpc_dictionary_get_string(event, "gsxpc.returnType");
          if (returnTypeCString != NULL)
            {
              returnValueType = [NSString stringWithUTF8String: returnTypeCString];
            }

          returnData = xpc_dictionary_get_data(event,
            "gsxpc.return",
            &returnDataLength);
          if (returnData != NULL && returnDataLength > 0 && error == nil)
            {
              NSData *payload;

              payload = [NSData dataWithBytes: returnData
                                      length: (NSUInteger)returnDataLength];
              if (returnTypeCString != NULL
                && GSXPCStrippedTypeEncoding(returnTypeCString)[0] != '@')
                {
                  returnValueData = payload;
                }
              else
                {
                  NSError *decodeError;

                  decodeError = nil;
                  returnObject = [NSXPCCoder unarchivedObjectWithData: payload
                                                       allowedClasses: [pending allowedClasses]
                                                                error: &decodeError];
                  if (decodeError != nil && error == nil)
                    {
                      error = decodeError;
                    }
                }
            }

          [pending resolveWithReturnObject: returnObject
                              returnData: returnValueData
                              returnType: returnValueType
                                   error: error];
          return;
        }
      if (kind != NULL && strcmp(kind, "invoke") == 0)
        {
          [self _handleIncomingInvokeEvent: eventPtr];
          return;
        }
    }
#else
  (void)eventPtr;
#endif
}

- (void) _sendInvokeReplyForEvent: (void *)eventPtr
                  withReturnObject: (id)returnObject
                     returnData: (NSData *)returnData
                     returnType: (const char *)returnType
                             error: (NSError *)error
{
#if GS_USE_LIBXPC
  xpc_object_t event;
  xpc_object_t reply;
  NSData *encoded;

  if (_xpcConnection == 0)
    {
      return;
    }

  event = (xpc_object_t)eventPtr;
  reply = xpc_dictionary_create(NULL, NULL, 0);
  xpc_dictionary_set_string(reply, "gsxpc.kind", "reply");
  xpc_dictionary_set_uint64(reply, "gsxpc.messageID",
    xpc_dictionary_get_uint64(event, "gsxpc.messageID"));

  if (error != nil)
    {
      xpc_dictionary_set_string(reply,
        "gsxpc.error",
        [[error localizedDescription] UTF8String]);
    }
  else if (returnType != NULL)
    {
      xpc_dictionary_set_string(reply, "gsxpc.returnType", returnType);
      if (GSXPCStrippedTypeEncoding(returnType)[0] == '@')
        {
          encoded = [NSXPCCoder archivedDataWithRootObject: returnObject];
          if (encoded != nil)
            {
              xpc_dictionary_set_data(reply,
                "gsxpc.return",
                [encoded bytes],
                (size_t)[encoded length]);
            }
          else if (returnObject != nil)
            {
              xpc_dictionary_set_string(reply,
                "gsxpc.error",
                "Unable to encode return object.");
            }
        }
      else if (returnData != nil)
        {
          xpc_dictionary_set_data(reply,
            "gsxpc.return",
            [returnData bytes],
            (size_t)[returnData length]);
        }
    }

  xpc_connection_send_message((xpc_connection_t)_xpcConnection, reply);
  xpc_release(reply);
#else
  (void)eventPtr;
  (void)returnObject;
  (void)returnData;
  (void)returnType;
  (void)error;
#endif
}

- (NSMethodSignature *) _exportedMethodSignatureForSelector: (SEL)sel
{
  Protocol *protocol;
  struct objc_method_description desc;

  if (_exportedInterface != nil)
    {
      protocol = [_exportedInterface protocol];
      if (protocol != NULL)
        {
          desc = protocol_getMethodDescription(protocol, sel, YES, YES);
          if (desc.name == NULL)
            {
              desc = protocol_getMethodDescription(protocol, sel, NO, YES);
            }
          if (desc.name != NULL && desc.types != NULL)
            {
              return [NSMethodSignature signatureWithObjCTypes: desc.types];
            }
          return nil;
        }
    }

  if (_exportedObject != nil && [_exportedObject respondsToSelector: sel])
    {
      return [_exportedObject methodSignatureForSelector: sel];
    }
  return nil;
}

- (void) _handleIncomingInvokeEvent: (void *)eventPtr
{
#if GS_USE_LIBXPC
  xpc_object_t event;
  const char *selectorName;
  SEL selector;
  NSMethodSignature *signature;
  NSInvocation *invocation;
  NSUInteger argumentCount;
  NSUInteger messageArgumentCount;
  NSUInteger index;
  NSError *error;
  BOOL expectsReply;
  id returnObject;
  NSData *returnData;
  const char *returnType;

  event = (xpc_object_t)eventPtr;
  expectsReply = xpc_dictionary_get_bool(event, "gsxpc.expectsReply") ? YES : NO;
  error = nil;
  returnObject = nil;
  returnData = nil;

  if (_exportedObject == nil)
    {
      error = GSXPCProxyError(@"No exported object is configured.");
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  selectorName = xpc_dictionary_get_string(event, "gsxpc.selector");
  if (selectorName == NULL)
    {
      error = GSXPCProxyError(@"Missing selector in incoming invoke message.");
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  selector = sel_getUid(selectorName);
  signature = [self _exportedMethodSignatureForSelector: selector];
  if (signature == nil)
    {
      NSString *reason;

      reason = [NSString stringWithFormat:
        @"Exported interface does not allow selector '%s'.",
        selectorName];
      error = GSXPCProxyError(reason);
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  if ([_exportedObject respondsToSelector: selector] == NO)
    {
      NSString *reason;

      reason = [NSString stringWithFormat:
        @"Exported object does not respond to selector '%s'.",
        selectorName];
      error = GSXPCProxyError(reason);
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  argumentCount = [signature numberOfArguments] - 2;
  messageArgumentCount = (NSUInteger)xpc_dictionary_get_uint64(event,
    "gsxpc.argumentCount");
  if (argumentCount != messageArgumentCount)
    {
      error = GSXPCProxyError(@"Incoming argument count does not match exported selector.");
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  returnType = GSXPCStrippedTypeEncoding([signature methodReturnType]);
  if (returnType[0] != 'v' && GSXPCTypeSize(returnType, NULL) == NO)
    {
      error = GSXPCProxyError(@"Unsupported return type for exported method.");
      if (expectsReply == YES)
        {
          [self _sendInvokeReplyForEvent: eventPtr
                        withReturnObject: nil
                           returnData: nil
                           returnType: nil
                                   error: error];
        }
      return;
    }

  invocation = [NSInvocation invocationWithMethodSignature: signature];
  [invocation setTarget: _exportedObject];
  [invocation setSelector: selector];

  for (index = 0; index < argumentCount; index++)
    {
      NSString *key;
      const void *argData;
      size_t argDataLength;
      const char *argType;
      const char *argTypeFromMessage;
      NSString *typeKey;
      BOOL hasNilObject;
      NSString *nilKey;

      argType = GSXPCStrippedTypeEncoding([signature getArgumentTypeAtIndex: index + 2]);
      typeKey = [NSString stringWithFormat: @"gsxpc.argtype.%lu", (unsigned long)index];
      argTypeFromMessage = xpc_dictionary_get_string(event, [typeKey UTF8String]);
      if (argTypeFromMessage != NULL)
        {
          const char *normalized;

          normalized = GSXPCStrippedTypeEncoding(argTypeFromMessage);
          if (normalized[0] != argType[0])
            {
              error = GSXPCProxyError(@"Incoming argument type does not match exported selector signature.");
              if (expectsReply == YES)
                {
                  [self _sendInvokeReplyForEvent: eventPtr
                                withReturnObject: nil
                                   returnData: nil
                                   returnType: nil
                                       error: error];
                }
              return;
            }
        }

      key = [NSString stringWithFormat: @"gsxpc.arg.%lu", (unsigned long)index];
      argData = xpc_dictionary_get_data(event, [key UTF8String], &argDataLength);
      nilKey = [NSString stringWithFormat: @"gsxpc.argnil.%lu", (unsigned long)index];
      hasNilObject = xpc_dictionary_get_bool(event, [nilKey UTF8String]) ? YES : NO;

      if (argType[0] == '@')
        {
          id decoded;

          decoded = nil;
          if (hasNilObject == NO && argData != NULL && argDataLength > 0)
            {
              NSData *encoded;
              NSSet *allowedClasses;
              NSError *decodeError;

              encoded = [NSData dataWithBytes: argData length: (NSUInteger)argDataLength];
              allowedClasses = nil;
              if (_exportedInterface != nil)
                {
                  allowedClasses = [_exportedInterface classesForSelector: selector
                                                             argumentIndex: index
                                                                   ofReply: NO];
                }
              decodeError = nil;
              decoded = [NSXPCCoder unarchivedObjectWithData: encoded
                                               allowedClasses: allowedClasses
                                                        error: &decodeError];
              if (decodeError != nil)
                {
                  if (expectsReply == YES)
                    {
                      [self _sendInvokeReplyForEvent: eventPtr
                                    withReturnObject: nil
                                       returnData: nil
                                       returnType: nil
                                           error: decodeError];
                    }
                  return;
                }
            }
          [invocation setArgument: &decoded atIndex: index + 2];
        }
      else
        {
          NSUInteger expectedSize;
          void *buffer;

          if (GSXPCTypeSize(argType, &expectedSize) == NO)
            {
              error = GSXPCProxyError(@"Unsupported argument type in exported selector.");
              if (expectsReply == YES)
                {
                  [self _sendInvokeReplyForEvent: eventPtr
                                withReturnObject: nil
                                   returnData: nil
                                   returnType: nil
                                       error: error];
                }
              return;
            }
          if (argData == NULL || argDataLength != expectedSize)
            {
              error = GSXPCProxyError(@"Incoming argument payload size does not match selector signature.");
              if (expectsReply == YES)
                {
                  [self _sendInvokeReplyForEvent: eventPtr
                                withReturnObject: nil
                                   returnData: nil
                                   returnType: nil
                                       error: error];
                }
              return;
            }

          buffer = malloc(expectedSize);
          if (buffer == NULL)
            {
              error = GSXPCProxyError(@"Unable to allocate memory for incoming argument decode.");
              if (expectsReply == YES)
                {
                  [self _sendInvokeReplyForEvent: eventPtr
                                withReturnObject: nil
                                   returnData: nil
                                   returnType: nil
                                       error: error];
                }
              return;
            }
          memcpy(buffer, argData, expectedSize);
          [invocation setArgument: buffer atIndex: index + 2];
          free(buffer);
        }
    }

  @try
    {
      [invocation invoke];
      if (returnType[0] == '@')
        {
          id returned;

          returned = nil;
          [invocation getReturnValue: &returned];
          returnObject = returned;
        }
      else if (returnType[0] != 'v')
        {
          NSUInteger returnSize;

          if (GSXPCTypeSize(returnType, &returnSize) == YES)
            {
              void *buffer;

              buffer = malloc(returnSize);
              if (buffer != NULL)
                {
                  [invocation getReturnValue: buffer];
                  returnData = [NSData dataWithBytes: buffer
                                              length: returnSize];
                  free(buffer);
                }
              else
                {
                  error = GSXPCProxyError(@"Unable to allocate memory for return value encoding.");
                }
            }
          else
            {
              error = GSXPCProxyError(@"Unsupported return type for exported method.");
            }
        }
    }
  @catch (id exception)
    {
      NSString *reason;

      reason = [NSString stringWithFormat:
        @"Exception while invoking exported selector '%s': %@",
        selectorName,
        [exception description]];
      error = GSXPCProxyError(reason);
    }

  if (expectsReply == YES)
    {
      [self _sendInvokeReplyForEvent: eventPtr
                    withReturnObject: returnObject
                       returnData: returnData
                       returnType: returnType
                               error: error];
    }
#else
  (void)eventPtr;
#endif
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
    [connection _handleIncomingXPCEvent: (void *)event];
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
        [connection _failAllPendingRepliesWithError:
          GSXPCProxyError(@"Connection was invalidated.")];
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
      [self _initializeReplyTracking];
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
      [self _initializeReplyTracking];
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
  const char *returnType;

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

  returnType = GSXPCStrippedTypeEncoding([signature methodReturnType]);
  if (returnType[0] != 'v' && GSXPCTypeSize(returnType, NULL) == NO)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"Unsupported method return type."));
        }
      return;
    }

  if (synchronous == NO && returnType[0] != 'v')
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"Non-void methods require a synchronous proxy."));
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
  BOOL expectsReply;
  NSNumber *messageID;
  GSXPCPendingReply *pending;
  id returnObject;
  NSData *returnValueData;
  NSString *returnValueType;
  NSError *replyError;

  if (_xpcConnection == 0)
    {
      if (errorHandler != NULL)
        {
          CALL_BLOCK(errorHandler,
            GSXPCProxyError(@"XPC transport is unavailable for this connection."));
        }
      return;
    }

  expectsReply = (synchronous == YES || returnType[0] != 'v');
  returnObject = nil;
  returnValueData = nil;
  returnValueType = nil;
  replyError = nil;
  messageID = [self _nextMessageIdentifierObject];
  pending = nil;
  if (expectsReply == YES)
    {
      NSSet *allowedClasses;

      allowedClasses = nil;
      if (returnType[0] == '@' && _remoteObjectInterface != nil)
        {
          allowedClasses = [_remoteObjectInterface classesForSelector: [invocation selector]
                                                         argumentIndex: 0
                                                               ofReply: YES];
        }
      pending = [[GSXPCPendingReply alloc] initWithAllowedClasses: allowedClasses];
      [self _registerPendingReply: pending forMessageID: messageID];
    }

  {
    xpc_object_t message;
    const char *selectorName;
    NSUInteger count;
    NSUInteger index;

    message = xpc_dictionary_create(NULL, NULL, 0);
    selectorName = sel_getName([invocation selector]);
    xpc_dictionary_set_string(message, "gsxpc.kind", "invoke");
    xpc_dictionary_set_uint64(message, "gsxpc.messageID",
      [messageID unsignedLongLongValue]);
    xpc_dictionary_set_string(message, "gsxpc.selector", selectorName);
    xpc_dictionary_set_bool(message, "gsxpc.expectsReply",
      expectsReply ? true : false);

    count = [signature numberOfArguments];
    xpc_dictionary_set_uint64(message, "gsxpc.argumentCount", (uint64_t)(count - 2));

    for (index = 2; index < count; index++)
      {
        const char *argType;
        NSString *typeKey;
        NSString *nilKey;
        NSString *dataKey;

        argType = GSXPCStrippedTypeEncoding([signature getArgumentTypeAtIndex: index]);
        typeKey = [NSString stringWithFormat: @"gsxpc.argtype.%lu",
                                              (unsigned long)(index - 2)];
        xpc_dictionary_set_string(message, [typeKey UTF8String], argType);
        dataKey = [NSString stringWithFormat: @"gsxpc.arg.%lu",
                                              (unsigned long)(index - 2)];
        nilKey = [NSString stringWithFormat: @"gsxpc.argnil.%lu",
                                             (unsigned long)(index - 2)];

        if (argType[0] == '@')
          {
            id value;
            NSData *encoded;

            value = nil;
            [invocation getArgument: &value atIndex: index];
            if (value == nil)
              {
                xpc_dictionary_set_bool(message, [nilKey UTF8String], true);
                continue;
              }

            encoded = [NSXPCCoder archivedDataWithRootObject: value];
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
                if (pending != nil)
                  {
                    [self _takePendingReplyForMessageID: messageID];
                    RELEASE(pending);
                  }
                xpc_release(message);
                return;
              }

            xpc_dictionary_set_data(message,
              [dataKey UTF8String],
              [encoded bytes],
              (size_t)[encoded length]);
          }
        else
          {
            NSUInteger argSize;
            void *buffer;
            NSData *encoded;

            if (GSXPCTypeSize(argType, &argSize) == NO)
              {
                if (errorHandler != NULL)
                  {
                    NSString *reason;

                    reason = [NSString stringWithFormat:
                      @"Unsupported argument type at index %lu.",
                      (unsigned long)(index - 2)];
                    CALL_BLOCK(errorHandler, GSXPCProxyError(reason));
                  }
                if (pending != nil)
                  {
                    [self _takePendingReplyForMessageID: messageID];
                    RELEASE(pending);
                  }
                xpc_release(message);
                return;
              }

            buffer = malloc(argSize);
            if (buffer == NULL)
              {
                if (errorHandler != NULL)
                  {
                    CALL_BLOCK(errorHandler,
                      GSXPCProxyError(@"Unable to allocate memory for argument encoding."));
                  }
                if (pending != nil)
                  {
                    [self _takePendingReplyForMessageID: messageID];
                    RELEASE(pending);
                  }
                xpc_release(message);
                return;
              }
            [invocation getArgument: buffer atIndex: index];
            encoded = [NSData dataWithBytes: buffer length: argSize];
            free(buffer);

            if (encoded == nil)
              {
                if (errorHandler != NULL)
                  {
                    CALL_BLOCK(errorHandler,
                      GSXPCProxyError(@"Unable to encode non-object argument payload."));
                  }
                if (pending != nil)
                  {
                    [self _takePendingReplyForMessageID: messageID];
                    RELEASE(pending);
                  }
                xpc_release(message);
                return;
              }

            xpc_dictionary_set_data(message,
              [dataKey UTF8String],
              [encoded bytes],
              (size_t)[encoded length]);
          }
      }

    xpc_connection_send_message((xpc_connection_t)_xpcConnection, message);
    xpc_release(message);
  }

  if (expectsReply == YES)
    {
      BOOL didResolve;

      didResolve = [pending waitForResolutionUntilDate:
        [NSDate dateWithTimeIntervalSinceNow: 30.0]
        returnObject: &returnObject
        returnData: &returnValueData
        returnType: &returnValueType
        error: &replyError];
      if (didResolve == NO)
        {
          [self _takePendingReplyForMessageID: messageID];
          replyError = GSXPCProxyError(@"Timed out waiting for reply.");
        }

      if (replyError != nil)
        {
          if (errorHandler != NULL)
            {
              CALL_BLOCK(errorHandler, replyError);
            }
          RELEASE(pending);
          return;
        }

      if (synchronous == YES && returnType[0] == '@')
        {
          id returned;

          returned = returnObject;
          [invocation setReturnValue: &returned];
        }
      else if (synchronous == YES && returnType[0] != 'v')
        {
          const char *resolvedType;
          NSUInteger expectedSize;

          resolvedType = returnType;
          if (returnValueType != nil)
            {
              resolvedType = GSXPCStrippedTypeEncoding([returnValueType UTF8String]);
            }

          if (resolvedType[0] != returnType[0])
            {
              if (errorHandler != NULL)
                {
                  CALL_BLOCK(errorHandler,
                    GSXPCProxyError(@"Reply type does not match method return type."));
                }
              RELEASE(pending);
              return;
            }

          if (GSXPCTypeSize(returnType, &expectedSize) == NO)
            {
              if (errorHandler != NULL)
                {
                  CALL_BLOCK(errorHandler,
                    GSXPCProxyError(@"Unsupported method return type."));
                }
              RELEASE(pending);
              return;
            }

          if (returnValueData == nil)
            {
              void *empty;

              empty = calloc(1, expectedSize);
              if (empty != NULL)
                {
                  [invocation setReturnValue: empty];
                  free(empty);
                }
            }
          else if ([returnValueData length] != expectedSize)
            {
              if (errorHandler != NULL)
                {
                  CALL_BLOCK(errorHandler,
                    GSXPCProxyError(@"Reply payload size does not match method return type."));
                }
              RELEASE(pending);
              return;
            }
          else
            {
              [invocation setReturnValue: (void *)[returnValueData bytes]];
            }
        }

      RELEASE(pending);
      return;
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
