/* Implementation of NSURLSessionWebSocketTask.
   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of the GNUstep Library.
   This library is free software; you can redistribute it and/or modify it
   under the terms of the GNU Lesser General Public License as published by
   the Free Software Foundation; either version 2 of the License, or (at
   your option) any later version.
*/

#include "Foundation/NSURLSession.h"
#include "Foundation/NSData.h"
#include "Foundation/NSString.h"
#include "Foundation/NSNull.h"
#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"

#if GS_HAVE_NSURLSESSION_WEBSOCKETS

@implementation NSURLSessionWebSocketMessage

- (instancetype) initWithData: (NSData *)data
{
  self = [super init];
  if (self != nil)
    {
      _type = NSURLSessionWebSocketMessageTypeData;
      ASSIGNCOPY(_data, data);
      DESTROY(_string);
    }
  return self;
}

- (instancetype) initWithString: (NSString *)string
{
  self = [super init];
  if (self != nil)
    {
      _type = NSURLSessionWebSocketMessageTypeString;
      ASSIGNCOPY(_string, string);
      DESTROY(_data);
    }
  return self;
}

- (NSURLSessionWebSocketMessageType) type { return _type; }
- (NSData *) data { return _data; }
- (NSString *) string { return _string; }

- (void) dealloc
{
  RELEASE(_data);
  RELEASE(_string);
  [super dealloc];
}

@end

@implementation NSURLSessionWebSocketTask

- (NSInteger) maximumMessageSize { return _maximumMessageSize; }

- (void) setMaximumMessageSize: (NSInteger)maximumMessageSize
{
  _maximumMessageSize = maximumMessageSize;
}

- (NSURLSessionWebSocketCloseCode) closeCode { return _closeCode; }
- (NSData *) closeReason { return _closeReason; }

- (void) sendMessage: (NSURLSessionWebSocketMessage *)message
   completionHandler: (void (^)(NSError *error))completionHandler
{
  (void)message;
  if (completionHandler != NULL)
    completionHandler(nil);
}

- (void) receiveMessageWithCompletionHandler:
  (void (^)(NSURLSessionWebSocketMessage *message, NSError *error))completionHandler
{
  if (completionHandler != NULL)
    completionHandler(nil, nil);
}

- (void) sendPingWithPongReceiveHandler: (void (^)(NSError *error))handler
{
  if (handler != NULL)
    handler(nil);
}

- (void) cancelWithCloseCode: (NSURLSessionWebSocketCloseCode)closeCode
                      reason: (NSData *)reason
{
  _closeCode = closeCode;
  ASSIGNCOPY(_closeReason, reason);
  [super cancel];
}

- (void) dealloc
{
  RELEASE(_closeReason);
  [super dealloc];
}

@end

#endif
