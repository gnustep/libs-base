/* Implementation of class NSURLSessionWebSocketTask
   Copyright (C) 2026 Free Software Foundation, Inc.
   
   By: Hendrik Huebner <hendrik.huebner@algoriddim.com>
   Date: July 2026

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

#import "GSPThread.h"

@class NSData;
@class NSMutableArray;
@class NSMutableData;

typedef NS_ENUM(NSUInteger, GSURLSessionWebSocketSendQueueEntryKind) {
  GSURLSessionWebSocketSendQueueEntryKindData = 0,
  GSURLSessionWebSocketSendQueueEntryKindPing = 1,
  GSURLSessionWebSocketSendQueueEntryKindClose = 2,
};

typedef NS_ENUM(NSUInteger, GSURLSessionWebSocketLifecyclePhase) {
  GSURLSessionWebSocketLifecycleStateOpen = 0,
  GSURLSessionWebSocketLifecycleStateClosing = 1,
  GSURLSessionWebSocketLifecycleStateClosed = 2,
  GSURLSessionWebSocketLifecycleStateFailed = 3,
};

typedef NS_ENUM(NSUInteger, GSURLSessionWebSocketReceivePhase) {
  GSURLSessionWebSocketReceiveStateIdle = 0,
  GSURLSessionWebSocketReceiveStateText = 1,
  GSURLSessionWebSocketReceiveStateBinary = 2,
};

typedef struct
{
  void *entry;
  GSURLSessionWebSocketSendQueueEntryKind kind;
  NSInteger dataType;
  size_t payloadOffset;
  BOOL frameStarted;
} GSURLSessionWebSocketMessageSendState;

typedef struct
{
  NSMutableArray *queue;
  NSMutableArray *pingHandlers;
  NSData *pingPayload;
  GSURLSessionWebSocketMessageSendState active;
  unsigned long long nextPingIdentifier;
  BOOL frameStartRetryPending;
} GSURLSessionWebSocketSendState;

typedef struct
{
  NSMutableArray *handlers;
  NSMutableData *buffer;
  GSURLSessionWebSocketReceivePhase phase;
  size_t frameOffset;
  NSInteger maximumMessageSize;
} GSURLSessionWebSocketReceiveContext;

typedef struct
{
  GSURLSessionWebSocketLifecyclePhase phase;
  NSInteger closeCode;
  NSData *closeReason;
  BOOL closeFrameSent;
  BOOL closeFrameReceived;
} GSURLSessionWebSocketLifecycleState;

#define GS_NSURLSessionWebSocketTask_IVARS \
  GSURLSessionWebSocketSendState send; \
  GSURLSessionWebSocketReceiveContext receive; \
  GSURLSessionWebSocketLifecycleState lifecycle; \
  gs_mutex_t mutex;

#include "Foundation/NSArray.h"
#include "Foundation/NSURLSession.h"
#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"
#import "GSDispatch.h"

#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSValue.h"

#import "GSURLPrivate.h"
#include <assert.h>

#define GSInternal NSURLSessionWebSocketTaskInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLSessionWebSocketTask)

#if GS_HAVE_NSURLSESSION_WEBSOCKETS
static NSString *taskWebSocketDidOpenKey = @"webSocketDidOpen";
static NSString *taskWebSocketDidCloseKey = @"webSocketDidClose";

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

- (NSURLSessionWebSocketMessageType) type
{
  return _type;
}

- (NSData *) data
{
  return _data;
}

- (NSString *) string
{
  return _string;
}

- (void) dealloc
{
  RELEASE(_data);
  RELEASE(_string);
  [super dealloc];
}

@end

typedef struct
{
  NSURLSessionWebSocketMessage *message;
  NSData *payload;
  void (^completionHandler)(NSError *error);
  GSURLSessionWebSocketSendQueueEntryKind kind;
  NSURLSessionWebSocketMessageType dataType;
} GSURLSessionWebSocketSendQueueEntry;

static GSURLSessionWebSocketSendQueueEntry *
GSURLSessionWebSocketDataSendQueueEntryCreate(
  NSURLSessionWebSocketMessage *message,
  void (^completionHandler)(NSError *error))
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSData *payload;
  NSURLSessionWebSocketMessageType type;

  entry = malloc(sizeof (*entry));
  if (NULL == entry)
    {
      [NSException raise: NSMallocException
                  format: @"Unable to allocate WebSocket send queue entry"];
      return NULL;
    }
  entry->message = RETAIN(message);
  type = [message type];

  if (type == NSURLSessionWebSocketMessageTypeString)
    {
      payload = [[message string] dataUsingEncoding: NSUTF8StringEncoding];
    }
  else if (type == NSURLSessionWebSocketMessageTypeData)
    {
      payload = [message data];
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Unsupported websocket message type %ld",
                  (long)type];
      RELEASE(entry->message);
      free(entry);
      return NULL;
    }

  if (nil == payload)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Websocket message payload could not be encoded"];
      RELEASE(entry->message);
      free(entry);
      return NULL;
    }

  entry->kind = GSURLSessionWebSocketSendQueueEntryKindData;
  entry->payload = RETAIN(payload);
  entry->completionHandler = _Block_copy(completionHandler);
  entry->dataType = type;
  return entry;
}

static GSURLSessionWebSocketSendQueueEntry *
GSURLSessionWebSocketControlSendQueueEntryCreate(
  GSURLSessionWebSocketSendQueueEntryKind kind,
  NSData *payload)
{
  GSURLSessionWebSocketSendQueueEntry *entry;

  if (kind != GSURLSessionWebSocketSendQueueEntryKindPing
      && kind != GSURLSessionWebSocketSendQueueEntryKindClose)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Unsupported websocket control frame kind %lu",
                  (unsigned long)kind];
      return NULL;
    }

  if (nil == payload)
    {
      payload = [NSData data];
    }

  entry = calloc(1, sizeof (*entry));
  if (NULL == entry)
    {
      [NSException raise: NSMallocException
                  format: @"Unable to allocate WebSocket send queue entry"];
      return NULL;
    }
  entry->kind = kind;
  entry->payload = RETAIN(payload);
  return entry;
}

static void
GSURLSessionWebSocketSendQueueEntryDestroy(
  GSURLSessionWebSocketSendQueueEntry *entry)
{
  if (NULL == entry)
    {
      return;
    }

  RELEASE(entry->message);
  RELEASE(entry->payload);
  _Block_release(entry->completionHandler);
  free(entry);
}

typedef void (^GSURLSessionWebSocketReceiveHandler)(
  NSURLSessionWebSocketMessage *message,
  NSError *error);

typedef void (^GSURLSessionWebSocketPingHandler)(NSError *error);

static NSString *GSURLSessionWebSocketExceptionKey = @"GSWebSocketException";

static BOOL
GSURLSessionWebSocketMarkDelegateCallback(
  NSURLSessionWebSocketTask *task,
  NSString *key)
{
  NSMutableDictionary *taskData;

  taskData = [task _taskData];
  if ([[taskData objectForKey: key] boolValue])
    {
      return NO;
    }

  [taskData setObject: [NSNumber numberWithBool: YES] forKey: key];
  return YES;
}

static void
GSURLSessionWebSocketNotifyDidClose(
  NSURLSessionWebSocketTask *task,
  NSURLSessionWebSocketCloseCode closeCode,
  NSData *reason)
{
  id delegate;
  NSURLSession *session;
  BOOL shouldNotify;

  delegate = [task delegate];
  session = [task _session];
  shouldNotify = NO;

  GS_MUTEX_LOCK(GSIVar(task, mutex));
  shouldNotify = GSURLSessionWebSocketMarkDelegateCallback(task,
    taskWebSocketDidCloseKey);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  if (NO == shouldNotify
      || ![delegate respondsToSelector:
        @selector(URLSession:webSocketTask:didCloseWithCode:reason:)])
    {
      return;
    }

  [[session delegateQueue] addOperationWithBlock:^{
    [(id<NSURLSessionWebSocketDelegate>)delegate URLSession: session
                                              webSocketTask: task
                                           didCloseWithCode: closeCode
                                                     reason: reason];
  }];
}

static NSError *
GSURLSessionWebSocketError(NSInteger code, NSString *description)
{
  return [NSError errorWithDomain: NSURLErrorDomain
                             code: code
                         userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                      description, NSLocalizedDescriptionKey,
                                      nil]];
}

static NSError *
GSURLSessionWebSocketErrorFromException(NSException *exception)
{
  return [NSError errorWithDomain: NSURLErrorDomain
                             code: NSURLErrorUnknown
                         userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                      [exception reason],
                                      NSLocalizedDescriptionKey,
                                      exception,
                                      GSURLSessionWebSocketExceptionKey,
                                      nil]];
}

static void
GSURLSessionWebSocketResetReceiveStateLocked(NSURLSessionWebSocketTask *task)
{
  [GSIVar(task, receive).buffer setLength: 0];
  GSIVar(task, receive).phase = GSURLSessionWebSocketReceiveStateIdle;
  GSIVar(task, receive).frameOffset = 0;
}

static NSData *
GSURLSessionWebSocketPingPayload(unsigned long long identifier)
{
  unsigned char bytes[8];
  int idx;

  for (idx = 0; idx < 8; idx++)
    {
      bytes[7 - idx] = (unsigned char)(identifier & 0xff);
      identifier >>= 8;
    }

  return [NSData dataWithBytes: bytes length: sizeof(bytes)];
}

static NSData *
GSURLSessionWebSocketClosePayload(
  NSURLSessionWebSocketCloseCode closeCode,
  NSData *reason)
{
  NSMutableData *payload;
  unsigned char statusBytes[2];
  NSUInteger statusCode;

  if (closeCode == NSURLSessionWebSocketCloseCodeInvalid)
    {
      if (nil == reason)
        {
          return [NSData data];
        }

      return [NSData dataWithData: reason];
    }

  statusCode = (NSUInteger)closeCode;
  statusBytes[0] = (unsigned char)((statusCode >> 8) & 0xff);
  statusBytes[1] = (unsigned char)(statusCode & 0xff);
  payload = [NSMutableData dataWithBytes: statusBytes length: sizeof(statusBytes)];
  if (nil != reason)
    {
      [payload appendData: reason];
    }

  return payload;
}

static BOOL
GSURLSessionWebSocketFramePayloadMatchesData(
  const char *bytes,
  NSUInteger length,
  NSData *data)
{
  return (nil != data
    && [data length] == length
    && (0 == length || 0 == memcmp(bytes, [data bytes], length)));
}

static BOOL
GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketSendQueueEntryKind kind)
{
  NSValue *entryValue;

  if (NULL != GSIVar(task, send).active.entry
      && GSIVar(task, send).active.kind == kind)
    {
      return YES;
    }

  for (entryValue in GSIVar(task, send).queue)
    {
      GSURLSessionWebSocketSendQueueEntry *entry;

      entry = [entryValue pointerValue];
      if (NULL != entry && entry->kind == kind)
        {
          return YES;
        }
    }

  return NO;
}

static void
GSURLSessionWebSocketQueueNextPingLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSData *payload;

  if (GSIVar(task, lifecycle).phase != GSURLSessionWebSocketLifecycleStateOpen
      || nil != GSIVar(task, send).pingPayload
      || [GSIVar(task, send).pingHandlers count] == 0
      || YES == GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
        task,
        GSURLSessionWebSocketSendQueueEntryKindPing))
    {
      return;
    }

  payload = GSURLSessionWebSocketPingPayload(GSIVar(task, send).nextPingIdentifier++);
  entry = GSURLSessionWebSocketControlSendQueueEntryCreate(
    GSURLSessionWebSocketSendQueueEntryKindPing,
    payload);
  [GSIVar(task, send).queue insertObject: [NSValue valueWithPointer: entry] atIndex: 0];
}

static GSURLSessionWebSocketSendQueueEntry *
GSURLSessionWebSocketPopNextSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketSendQueueEntry *entry;

  if (NULL != GSIVar(task, send).active.entry)
    {
      return (GSURLSessionWebSocketSendQueueEntry *)GSIVar(task, send).active.entry;
    }

  if ([GSIVar(task, send).queue count] == 0)
    {
      return NULL;
    }

  entry = [[GSIVar(task, send).queue objectAtIndex: 0] pointerValue];
  [GSIVar(task, send).queue removeObjectAtIndex: 0];
  GSIVar(task, send).active.entry = entry;
  GSIVar(task, send).active.kind = entry->kind;
  GSIVar(task, send).active.dataType = entry->dataType;
  GSIVar(task, send).active.payloadOffset = 0;
  GSIVar(task, send).active.frameStarted = NO;
  return entry;
}

static void
GSURLSessionWebSocketClearActiveSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  GSIVar(task, send).active.entry = NULL;
  GSIVar(task, send).active.kind = GSURLSessionWebSocketSendQueueEntryKindData;
  GSIVar(task, send).active.dataType = NSURLSessionWebSocketMessageTypeData;
  GSIVar(task, send).active.payloadOffset = 0;
  GSIVar(task, send).active.frameStarted = NO;
}

static void
GSURLSessionWebSocketBeginClosingLocked(
  NSURLSessionWebSocketTask *task,
  NSData *closePayload,
  NSArray **sendEntries,
  NSArray **receiveHandlers,
  NSArray **pingHandlers)
{
  GSURLSessionWebSocketSendQueueEntry *closeEntry;

  assert(GSIVar(task, lifecycle).phase == GSURLSessionWebSocketLifecycleStateOpen);
  GSIVar(task, lifecycle).phase = GSURLSessionWebSocketLifecycleStateClosing;
  *sendEntries = [GSIVar(task, send).queue copy];
  *receiveHandlers = [GSIVar(task, receive).handlers copy];
  *pingHandlers = [GSIVar(task, send).pingHandlers copy];
  [GSIVar(task, send).queue removeAllObjects];
  [GSIVar(task, receive).handlers removeAllObjects];
  [GSIVar(task, send).pingHandlers removeAllObjects];
  DESTROY(GSIVar(task, send).pingPayload);
  GSURLSessionWebSocketResetReceiveStateLocked(task);

  closeEntry = GSURLSessionWebSocketControlSendQueueEntryCreate(
    GSURLSessionWebSocketSendQueueEntryKindClose,
    closePayload);
  [GSIVar(task, send).queue addObject: [NSValue valueWithPointer: closeEntry]];
}

static GSURLSessionWebSocketReceiveHandler
GSURLSessionWebSocketPopReceiveHandlerLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketReceiveHandler handler;

  if ([GSIVar(task, receive).handlers count] == 0)
    {
      return nil;
    }

  handler = RETAIN((GSURLSessionWebSocketReceiveHandler)
    [GSIVar(task, receive).handlers objectAtIndex: 0]);
  [GSIVar(task, receive).handlers removeObjectAtIndex: 0];
  return AUTORELEASE(handler);
}

static void
GSURLSessionWebSocketDrainOutstandingWorkLocked(
  NSURLSessionWebSocketTask *task,
  NSArray **sendEntries,
  NSArray **receiveHandlers,
  NSArray **pingHandlers)
{
  NSMutableArray *allSendEntries;

  allSendEntries = nil;
  if (sendEntries != NULL)
    {
      allSendEntries = [[NSMutableArray alloc] init];
      if (NULL != GSIVar(task, send).active.entry)
        {
          [allSendEntries addObject:
            [NSValue valueWithPointer: GSIVar(task, send).active.entry]];
        }
      [allSendEntries addObjectsFromArray: GSIVar(task, send).queue];
      *sendEntries = [allSendEntries copy];
      [allSendEntries release];
    }

  if (receiveHandlers != NULL)
    {
      *receiveHandlers = [GSIVar(task, receive).handlers copy];
    }

  if (pingHandlers != NULL)
    {
      *pingHandlers = [GSIVar(task, send).pingHandlers copy];
    }

  [GSIVar(task, send).queue removeAllObjects];
  [GSIVar(task, receive).handlers removeAllObjects];
  [GSIVar(task, send).pingHandlers removeAllObjects];
  DESTROY(GSIVar(task, send).pingPayload);
  GSURLSessionWebSocketClearActiveSendEntryLocked(task);
  GSIVar(task, send).frameStartRetryPending = NO;
  GSURLSessionWebSocketResetReceiveStateLocked(task);
}

static void
GSURLSessionWebSocketCompleteReceive(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketReceiveHandler handler,
  NSURLSessionWebSocketMessage *message,
  NSError *error)
{
  if (nil == handler)
    {
      return;
    }

  [[[task _session] delegateQueue] addOperationWithBlock:^{
    handler(message, error);
  }];
}

static void
GSURLSessionWebSocketCompleteSend(
  NSURLSessionWebSocketTask *task,
  void (^completionHandler)(NSError *error),
  NSError *error)
{
  if (completionHandler == NULL)
    {
      return;
    }

  [[[task _session] delegateQueue] addOperationWithBlock:^{
    completionHandler(error);
  }];
}

static void
GSURLSessionWebSocketCompletePingHandlers(
  NSURLSessionWebSocketTask *task,
  NSArray *pingHandlers,
  NSError *error)
{
  GSURLSessionWebSocketPingHandler handler;

  for (handler in pingHandlers)
    {
      GSURLSessionWebSocketCompleteSend(task, handler, error);
    }
}

static void
GSURLSessionWebSocketDestroySendEntries(
  NSArray *sendEntries,
  NSURLSessionWebSocketTask *task,
  NSError *error)
{
  NSValue *entryValue;

  for (entryValue in sendEntries)
    {
      GSURLSessionWebSocketSendQueueEntry *entry;

      entry = [entryValue pointerValue];
      if (entry != NULL)
        {
          if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindData)
            {
              GSURLSessionWebSocketCompleteSend(task,
                                                entry->completionHandler,
                                                error);
            }
          GSURLSessionWebSocketSendQueueEntryDestroy(entry);
        }
    }
}

static void
GSURLSessionWebSocketCompleteReceiveHandlers(
  NSArray *receiveHandlers,
  NSURLSessionWebSocketTask *task,
  NSError *error)
{
  GSURLSessionWebSocketReceiveHandler handler;

  for (handler in receiveHandlers)
    {
      GSURLSessionWebSocketCompleteReceive(task, handler, nil, error);
    }
}

static void
GSURLSessionWebSocketCompleteOutstandingWork(
  NSURLSessionWebSocketTask *task,
  NSArray *sendEntries,
  NSArray *receiveHandlers,
  NSArray *pingHandlers,
  NSError *error)
{
  GSURLSessionWebSocketDestroySendEntries(sendEntries, task, error);
  GSURLSessionWebSocketCompleteReceiveHandlers(receiveHandlers, task, error);
  GSURLSessionWebSocketCompletePingHandlers(task, pingHandlers, error);
  [sendEntries release];
  [receiveHandlers release];
  [pingHandlers release];
}

static size_t
GSURLSessionWebSocketFailReceive(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketReceiveHandler handler,
  NSInteger code,
  NSString *description)
{
  NSError *error;

  error = GSURLSessionWebSocketError(code, description);
  NSDebugLLog(GS_NSURLSESSION_DEBUG_KEY,
              @"task=%@ websocket receive failed: %@",
              task,
              description);

  GS_MUTEX_LOCK(GSIVar(task, mutex));
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketResetReceiveStateLocked(task);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  GSURLSessionWebSocketCompleteReceive(task, handler, nil, error);
  return 0;
}

static size_t
GSURLSessionWebSocketFailReceiveLocked(
  NSURLSessionWebSocketTask *task,
  NSInteger code,
  NSString *description)
{
  GSURLSessionWebSocketReceiveHandler handler;

  handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));
  return GSURLSessionWebSocketFailReceive(task, handler, code, description);
}

static size_t
GSURLSessionWebSocketFailSend(
  NSURLSessionWebSocketTask *task,
  NSError *error)
{
  NSArray *sendEntries;
  NSArray *receiveHandlers;
  NSArray *pingHandlers;
  NSString *description;

  description = [error localizedDescription];
  if (description == nil)
    {
      description = @"Unknown websocket send failure";
    }

  NSDebugLLog(GS_NSURLSESSION_DEBUG_KEY,
              @"task=%@ websocket send failed: %@",
              task,
              description);

  GS_MUTEX_LOCK(GSIVar(task, mutex));
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketDrainOutstandingWorkLocked(task,
                                                  &sendEntries,
                                                  &receiveHandlers,
                                                  &pingHandlers);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  GSURLSessionWebSocketCompleteOutstandingWork(task,
                                               sendEntries,
                                               receiveHandlers,
                                               pingHandlers,
                                               error);
  return CURL_READFUNC_ABORT;
}

static size_t
ws_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  GSURLSessionWebSocketReceiveHandler handler;
  const struct curl_ws_frame *meta;
  NSURLSessionWebSocketMessage *message;
  GSURLSessionWebSocketReceivePhase messageState;
  NSMutableData *buffer;
  NSUInteger bytesInCallback;
  NSUInteger bytesInChunk;
  NSUInteger existingLength;
  NSUInteger requiredLength;
  BOOL messageContinuesInNextFrame;
  NSString *string;

  task = (NSURLSessionWebSocketTask *)userdata;
  bytesInCallback = size * nmemb;

  /* Extract websocket frame metadata */
  meta = curl_ws_meta([task _easyHandle]);
  if (NULL == meta)
    {
      GS_MUTEX_LOCK(GSIVar(task, mutex));
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        @"curl_ws_meta returned NULL while receiving WebSocket data");
    }

  if ((meta->flags & CURLWS_PONG) != 0)
    {
      GSURLSessionWebSocketPingHandler pingHandler;
      BOOL shouldQueueNextPing;

      pingHandler = nil;
      shouldQueueNextPing = NO;

      GS_MUTEX_LOCK(GSIVar(task, mutex));
      if (nil != GSIVar(task, send).pingPayload
          && YES == GSURLSessionWebSocketFramePayloadMatchesData(
            ptr,
            bytesInCallback,
            GSIVar(task, send).pingPayload))
        {
          if ([GSIVar(task, send).pingHandlers count] > 0)
            {
              pingHandler = RETAIN((GSURLSessionWebSocketPingHandler)
                [GSIVar(task, send).pingHandlers objectAtIndex: 0]);
              [GSIVar(task, send).pingHandlers removeObjectAtIndex: 0];
            }

          DESTROY(GSIVar(task, send).pingPayload);
          GSURLSessionWebSocketQueueNextPingLocked(task);
          shouldQueueNextPing = GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
            task,
            GSURLSessionWebSocketSendQueueEntryKindPing);
        }
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      if (nil != pingHandler)
        {
          GSURLSessionWebSocketCompleteSend(task, pingHandler, nil);
          [pingHandler release];
        }

      if (YES == shouldQueueNextPing)
        {
          curl_easy_pause([task _easyHandle], CURLPAUSE_SEND_CONT);
        }

      return bytesInCallback;
    }

  if ((meta->flags & CURLWS_CLOSE) != 0)
    {
      NSArray *cancelledSendEntries;
      NSArray *cancelledReceiveHandlers;
      NSArray *cancelledPingHandlers;
      NSError *cancelError;
      NSData *closeReason;
      NSData *closePayload;
      NSUInteger payloadLength;
      NSURLSessionWebSocketCloseCode closeCode;
      BOOL shouldNotifyClose;
      BOOL shouldSendCloseReply;

      cancelledSendEntries = nil;
      cancelledReceiveHandlers = nil;
      cancelledPingHandlers = nil;
      cancelError = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket closing handshake canceled queued work");
      closeReason = nil;
      closePayload = nil;
      closeCode = NSURLSessionWebSocketCloseCodeInvalid;
      shouldNotifyClose = NO;
      shouldSendCloseReply = NO;
      payloadLength = bytesInCallback;

      if (payloadLength >= 2)
        {
          const unsigned char *closeBytes;

          closeBytes = (const unsigned char *)ptr;
          closeCode = (NSURLSessionWebSocketCloseCode)
            (((NSUInteger)closeBytes[0] << 8) | (NSUInteger)closeBytes[1]);
          if (payloadLength > 2)
            {
              closeReason = [NSData dataWithBytes: closeBytes + 2
                                           length: payloadLength - 2];
            }
        }

      GS_MUTEX_LOCK(GSIVar(task, mutex));
      GSIVar(task, lifecycle).closeCode = closeCode;
      ASSIGNCOPY(GSIVar(task, lifecycle).closeReason, closeReason);
      shouldNotifyClose = !GSIVar(task, lifecycle).closeFrameReceived;
      GSIVar(task, lifecycle).closeFrameReceived = YES;
      if (GSIVar(task, lifecycle).phase == GSURLSessionWebSocketLifecycleStateOpen)
        {
          closePayload = [NSData dataWithBytes: ptr length: payloadLength];
          GSURLSessionWebSocketBeginClosingLocked(task,
                                                  closePayload,
                                                  &cancelledSendEntries,
                                                  &cancelledReceiveHandlers,
                                                  &cancelledPingHandlers);
          shouldSendCloseReply = YES;
        }
      if (GSIVar(task, lifecycle).phase == GSURLSessionWebSocketLifecycleStateClosing
          && GSIVar(task, lifecycle).closeFrameSent)
        {
          GSIVar(task, lifecycle).phase = GSURLSessionWebSocketLifecycleStateClosed;
          [task _setShouldStopTransfer: YES];
        }
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      GSURLSessionWebSocketCompleteOutstandingWork(task,
                                                   cancelledSendEntries,
                                                   cancelledReceiveHandlers,
                                                   cancelledPingHandlers,
                                                   cancelError);

      if (YES == shouldSendCloseReply)
        {
          curl_easy_pause([task _easyHandle], CURLPAUSE_SEND_CONT);
        }

      if (YES == shouldNotifyClose)
        {
          GSURLSessionWebSocketNotifyDidClose(task, closeCode, closeReason);
        }

      return bytesInCallback;
    }

  if ((meta->flags & CURLWS_PING) != 0)
    {
      return bytesInCallback;
    }

  /* First, check if there is a receive handler in the queue */
  GS_MUTEX_LOCK(GSIVar(task, mutex));
  if (GSIVar(task, lifecycle).phase != GSURLSessionWebSocketLifecycleStateOpen)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return bytesInCallback;
    }
  if ([GSIVar(task, receive).handlers count] == 0)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return CURL_WRITEFUNC_PAUSE;
    }
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  if ((meta->flags & CURLWS_TEXT) != 0)
    {
      messageState = GSURLSessionWebSocketReceiveStateText;
    }
  else if ((meta->flags & CURLWS_BINARY) != 0)
    {
      messageState = GSURLSessionWebSocketReceiveStateBinary;
    }
  else
    {
      GS_MUTEX_LOCK(GSIVar(task, mutex));
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"Unsupported websocket frame flags 0x%x", meta->flags]);
    }

  GS_MUTEX_LOCK(GSIVar(task, mutex));
  handler = nil;
  buffer = GSIVar(task, receive).buffer;
  existingLength = [buffer length];
  messageContinuesInNextFrame = ((meta->flags & CURLWS_CONT) != 0);

  if (GSIVar(task, receive).phase == GSURLSessionWebSocketReceiveStateIdle
      && GSIVar(task, receive).frameOffset == 0)
    {
      GSIVar(task, receive).phase = messageState;
    }
  else if (GSIVar(task, receive).phase != messageState)
    {
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket message changed frame type from %lu to %lu",
                    (unsigned long)GSIVar(task, receive).phase,
                    (unsigned long)messageState]);
    }

  if (GSIVar(task, receive).frameOffset > 0
      && (NSUInteger)meta->offset != GSIVar(task, receive).frameOffset)
    {
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket frame offset mismatch: expected %lu but "
                    @"received %lld",
                    (unsigned long)GSIVar(task, receive).frameOffset,
                    (long long)meta->offset]);
    }

  bytesInChunk = meta->len;
  if (bytesInChunk != bytesInCallback)
    {
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket callback length mismatch: received %lu bytes "
                    @"but curl metadata announced %lu",
                    (unsigned long)bytesInCallback,
                    (unsigned long)bytesInChunk]);
    }
  assert(meta->bytesleft >= 0);
  assert((unsigned long long)meta->bytesleft
    <= (unsigned long long)NSUIntegerMax);
  assert(bytesInChunk <= NSUIntegerMax - existingLength);
  assert((NSUInteger)meta->bytesleft
    <= NSUIntegerMax - existingLength - bytesInChunk);

  requiredLength = existingLength + bytesInChunk + (NSUInteger)meta->bytesleft;

  if (GSIVar(task, receive).maximumMessageSize <= 0
      || requiredLength > (NSUInteger)GSIVar(task, receive).maximumMessageSize)
    {
      return GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorDataLengthExceedsMaximum,
        [NSString stringWithFormat:
                    @"WebSocket message length %lu exceeds maximumMessageSize "
                    @"%ld",
                    (unsigned long)requiredLength,
                    (long)GSIVar(task, receive).maximumMessageSize]);
    }

  if ([buffer length] < requiredLength)
    {
      [buffer setCapacity: requiredLength];
    }

  [buffer appendBytes: ptr length: bytesInChunk];
  GSIVar(task, receive).frameOffset += bytesInChunk;

  if (meta->bytesleft > 0)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return bytesInChunk;
    }

  GSIVar(task, receive).frameOffset = 0;
  if (YES == messageContinuesInNextFrame)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return bytesInChunk;
    }

  /* The full message is complete once the last chunk of the last frame arrives. */
  message = nil;
  if (GSIVar(task, receive).phase == GSURLSessionWebSocketReceiveStateText)
    {
      string = AUTORELEASE([[NSString alloc] initWithData: buffer
                                                 encoding: NSUTF8StringEncoding]);
      if (nil == string)
        {
          return GSURLSessionWebSocketFailReceiveLocked(
            task,
            NSURLErrorCannotDecodeContentData,
            @"WebSocket text message is not valid UTF-8");
        }

      message = AUTORELEASE([[NSURLSessionWebSocketMessage alloc]
        initWithString: string]);
    }
  else
    {
      NSData *data;

      data = [NSData dataWithData: buffer];
      message = AUTORELEASE([[NSURLSessionWebSocketMessage alloc]
        initWithData: data]);
    }

  handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
  GSURLSessionWebSocketResetReceiveStateLocked(task);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  GSURLSessionWebSocketCompleteReceive(task, handler, message, nil);
  return bytesInChunk;
}

static size_t
ws_read_callback(char *buffer, size_t size, size_t nitems, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSData *payload;
  size_t bytesAvailable;
  size_t bytesToWrite;
  size_t payloadLength;
  unsigned int flags;
  CURLcode result;

  task = (NSURLSessionWebSocketTask *)userdata;
  bytesAvailable = size * nitems;

  if (0 == bytesAvailable)
    {
      return 0;
    }

  GS_MUTEX_LOCK(GSIVar(task, mutex));

  entry = GSURLSessionWebSocketPopNextSendEntryLocked(task);
  if (NULL == entry)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return CURL_READFUNC_PAUSE;
    }
  payload = entry->payload;
  if (nil == payload)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket send queue entry "
                                                  @"is missing payload"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, error);
    }

  payloadLength = [payload length];

  if (GSIVar(task, send).active.payloadOffset > payloadLength)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket send queue entry "
                                                  @"payload offset exceeds "
                                                  @"payload length"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, error);
    }

  if (NO == GSIVar(task, send).active.frameStarted)
    {
      switch (entry->kind)
        {
          case GSURLSessionWebSocketSendQueueEntryKindData:
            switch (entry->dataType)
              {
                case NSURLSessionWebSocketMessageTypeString:
                  flags = CURLWS_TEXT;
                  break;
                case NSURLSessionWebSocketMessageTypeData:
                  flags = CURLWS_BINARY;
                  break;
                default:
                  {
                    NSError *error;
                    NSException *exception;

                    exception = [NSException
                      exceptionWithName: NSInternalInconsistencyException
                                 reason: [NSString stringWithFormat:
                                                    @"Queued websocket send "
                                                    @"has unsupported type %ld",
                                                    (long)entry->dataType]
                               userInfo: nil];
                    GS_MUTEX_UNLOCK(GSIVar(task, mutex));
                    error = GSURLSessionWebSocketErrorFromException(exception);
                    return GSURLSessionWebSocketFailSend(task, error);
                  }
              }
            break;
          case GSURLSessionWebSocketSendQueueEntryKindPing:
            flags = CURLWS_PING;
            break;
          case GSURLSessionWebSocketSendQueueEntryKindClose:
            flags = CURLWS_CLOSE;
            break;
          default:
            flags = CURLWS_BINARY;
            break;
        }

      [task _clearErrorBuffer];
      result = curl_ws_start_frame([task _easyHandle],
                                   flags,
                                   (curl_off_t)payloadLength);
      if (result == CURLE_AGAIN)
        {
          GSIVar(task, send).frameStartRetryPending = YES;
          GS_MUTEX_UNLOCK(GSIVar(task, mutex));
          return CURL_READFUNC_PAUSE;
        }
      if (result != CURLE_OK)
        {
          NSError *error;

          GS_MUTEX_UNLOCK(GSIVar(task, mutex));
          error = [task _errorForCURLcode: result];
          if (error == nil)
            {
              error = GSURLSessionWebSocketError(NSURLErrorUnknown,
                [NSString stringWithFormat:
                            @"curl_ws_start_frame failed with CURLcode %d",
                            (int)result]);
            }
          return GSURLSessionWebSocketFailSend(task, error);
        }

      GSIVar(task, send).active.frameStarted = YES;
    }

  bytesToWrite = MIN(bytesAvailable,
                     payloadLength - GSIVar(task, send).active.payloadOffset);
  if (bytesToWrite > 0)
    {
      memcpy(buffer,
             ((const char *)[payload bytes])
               + GSIVar(task, send).active.payloadOffset,
             bytesToWrite);
    }

  GSIVar(task, send).active.payloadOffset += bytesToWrite;

  if (GSIVar(task, send).active.payloadOffset == payloadLength)
    {
      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindPing)
        {
          ASSIGNCOPY(GSIVar(task, send).pingPayload, payload);
        }
      else if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindClose)
        {
          GSIVar(task, lifecycle).closeFrameSent = YES;
          if (GSIVar(task, lifecycle).phase
                == GSURLSessionWebSocketLifecycleStateClosing
              && GSIVar(task, lifecycle).closeFrameReceived)
            {
              GSIVar(task, lifecycle).phase = GSURLSessionWebSocketLifecycleStateClosed;
              [task _setShouldStopTransfer: YES];
            }
        }

      GSURLSessionWebSocketClearActiveSendEntryLocked(task);
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindData)
        {
          GSURLSessionWebSocketCompleteSend(task, entry->completionHandler, nil);
        }
      GSURLSessionWebSocketSendQueueEntryDestroy(entry);
      return bytesToWrite;
    }

  GS_MUTEX_UNLOCK(GSIVar(task, mutex));
  return bytesToWrite;
}

@implementation  NSURLSessionWebSocketTask

- (void) _notifyDidOpenWithProtocol: (NSString *)protocol
{
  id delegate;
  NSURLSession *session;
  BOOL shouldNotify;

  delegate = [self delegate];
  session = [self _session];
  if (![delegate respondsToSelector:
    @selector(URLSession:webSocketTask:didOpenWithProtocol:)])
    {
      return;
    }

  GS_MUTEX_LOCK(internal->mutex);
  shouldNotify = GSURLSessionWebSocketMarkDelegateCallback(self,
    taskWebSocketDidOpenKey);
  GS_MUTEX_UNLOCK(internal->mutex);
  if (YES == shouldNotify)
    {
      [[session delegateQueue] addOperationWithBlock:^{
        [(id<NSURLSessionWebSocketDelegate>)delegate URLSession: session
                                                  webSocketTask: self
                                               didOpenWithProtocol: protocol];
      }];
    }
}

- (instancetype) initWebSocketTask: (NSURLSession *)session
                           request: (NSURLRequest *)request
                    taskIdentifier: (NSUInteger)identifier
{
  self = [super initRequestTask: session
                        request: request
                 taskIdentifier: identifier];
  if (self != nil)
    {
      GS_CREATE_INTERNAL(NSURLSessionWebSocketTask);
      GS_MUTEX_INIT(internal->mutex);
      internal->send.queue = [[NSMutableArray alloc] init];
      internal->receive.handlers = [[NSMutableArray alloc] init];
      internal->send.pingHandlers = [[NSMutableArray alloc] init];
      internal->receive.buffer = [[NSMutableData alloc] init];
      internal->receive.maximumMessageSize = 1024 * 1024;
      GSURLSessionWebSocketClearActiveSendEntryLocked(self);
      internal->lifecycle.phase = GSURLSessionWebSocketLifecycleStateOpen;
      internal->receive.phase = GSURLSessionWebSocketReceiveStateIdle;
      internal->send.nextPingIdentifier = 1;
      internal->receive.frameOffset = 0;
      internal->send.frameStartRetryPending = NO;
      internal->lifecycle.closeFrameSent = NO;
      internal->lifecycle.closeFrameReceived = NO;
    }

  return self;
}

- (void) _initializeEasyhandleForRequest: (NSURLRequest *)request
{
  NSURL *url;

  url = [request URL];
  [self _setEasyHandle: curl_easy_init()];

  /* WebSocket tasks represent a single upgraded connection. */
  curl_easy_setopt([self _easyHandle], CURLOPT_CUSTOMREQUEST, "GET");
  curl_easy_setopt([self _easyHandle],
                   CURLOPT_URL,
                   [[url absoluteString] UTF8String]);
  curl_easy_setopt([self _easyHandle], CURLOPT_CONNECT_ONLY, 0L);

  /* WebSocket upgrade is a single GET request; do not follow redirects. */
  curl_easy_setopt([self _easyHandle], CURLOPT_FOLLOWLOCATION, 0L);

  /* Set timeout in connect phase */
  curl_easy_setopt([self _easyHandle],
                   CURLOPT_CONNECTTIMEOUT,
                   (long)[request timeoutInterval]);
}

- (void) _configureTransferCallbacks
{
  /* The task is associated with the easy handle for completion/error lookup. */
  curl_easy_setopt([self _easyHandle], CURLOPT_ERRORBUFFER, [self _errorBuffer]);
  curl_easy_setopt([self _easyHandle], CURLOPT_PRIVATE, self);

  curl_easy_setopt([self _easyHandle], CURLOPT_WRITEFUNCTION, ws_write_callback);
  curl_easy_setopt([self _easyHandle], CURLOPT_WRITEDATA, self);

  curl_easy_setopt([self _easyHandle], CURLOPT_READFUNCTION, ws_read_callback);
  curl_easy_setopt([self _easyHandle], CURLOPT_READDATA, self);

  curl_easy_setopt([self _easyHandle], CURLOPT_UPLOAD, 1L);
  curl_easy_setopt([self _easyHandle], CURLOPT_POSTFIELDSIZE, -1L);
}

- (void) _configureProtocolOptionsForRequest: (NSURLRequest *)request
                               configuration:
  (NSURLSessionConfiguration *)configuration
{
  NSData *certificateBlob;

  /* Set overall timeout */
  curl_easy_setopt([self _easyHandle],
                   CURLOPT_TIMEOUT,
                   (long)[configuration timeoutIntervalForResource]);

  certificateBlob = [[self _session] _certificateBlob];
  if (nil != certificateBlob)
    {
#if LIBCURL_VERSION_NUM >= 0x074D00
      struct curl_blob blob;

      blob.data = (void *)[certificateBlob bytes];
      blob.len = [certificateBlob length];
      blob.flags = CURL_BLOB_NOCOPY;

      curl_easy_setopt([self _easyHandle], CURLOPT_CAINFO_BLOB, &blob);
#else
      curl_easy_setopt([self _easyHandle],
                       CURLOPT_CAINFO,
                       [[self _session] _certificatePath]);
#endif
    }

  /* TODO(WS): Configure websocket protocol options and handshake behavior. */
}

- (NSInteger) maximumMessageSize
{
  return internal->receive.maximumMessageSize;
}

- (void) setMaximumMessageSize: (NSInteger)maximumMessageSize
{
  internal->receive.maximumMessageSize = maximumMessageSize;
}

- (void) _resumeSendIfWaitingForReadableSocket
{
  BOOL shouldResume;

  GS_MUTEX_LOCK(internal->mutex);
  shouldResume = internal->send.frameStartRetryPending;
  if (YES == shouldResume)
    {
      internal->send.frameStartRetryPending = NO;
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  if (YES == shouldResume)
    {
      curl_easy_pause([self _easyHandle], CURLPAUSE_SEND_CONT);
    }
}

- (void) _transferFinishedWithCode: (CURLcode)code
{
  NSArray *sendEntries;
  NSArray *receiveHandlers;
  NSArray *pingHandlers;
  NSError *error;
  BOOL hasOutstandingWork;
  NSURLSessionWebSocketCloseCode closeCode;
  NSData *closeReason;
  BOOL shouldNotifyClose;

  error = [self _errorForCURLcode: code];
  closeCode = NSURLSessionWebSocketCloseCodeInvalid;
  closeReason = nil;
  shouldNotifyClose = NO;

  GS_MUTEX_LOCK(internal->mutex);
  hasOutstandingWork = ([internal->send.queue count] > 0
    || [internal->receive.handlers count] > 0
    || [internal->send.pingHandlers count] > 0
    || nil != internal->send.pingPayload
    || NULL != internal->send.active.entry
    || internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateClosing);
  if (error == nil && YES == hasOutstandingWork)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task finished before queued work completed");
      [self _setStoredTaskError: error];
    }
  if (error == nil)
    {
      internal->lifecycle.phase = GSURLSessionWebSocketLifecycleStateClosed;
    }
  else
    {
      internal->lifecycle.phase = GSURLSessionWebSocketLifecycleStateFailed;
    }
  closeCode = internal->lifecycle.closeCode;
  closeReason = RETAIN(internal->lifecycle.closeReason);
  shouldNotifyClose = (error == nil
    && internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateClosed);
  GSURLSessionWebSocketDrainOutstandingWorkLocked(self,
                                                  &sendEntries,
                                                  &receiveHandlers,
                                                  &pingHandlers);
  GS_MUTEX_UNLOCK(internal->mutex);

  GSURLSessionWebSocketCompleteOutstandingWork(self,
                                               sendEntries,
                                               receiveHandlers,
                                               pingHandlers,
                                               error);

  if (YES == shouldNotifyClose)
    {
      GSURLSessionWebSocketNotifyDidClose(self, closeCode, closeReason);
    }
  [closeReason release];

  [super _transferFinishedWithCode: code];
}

- (NSURLSessionWebSocketCloseCode) closeCode
{
  return internal->lifecycle.closeCode;
}

- (void) cancel
{
  [self cancelWithCloseCode: NSURLSessionWebSocketCloseCodeInvalid
                     reason: nil];
}

- (NSData *) closeReason
{
  return internal->lifecycle.closeReason;
}

- (void) sendMessage:(NSURLSessionWebSocketMessage *) message 
   completionHandler:(void (^)(NSError *error)) completionHandler
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSError *error;

  entry = GSURLSessionWebSocketDataSendQueueEntryCreate(message, completionHandler);
  error = nil;

  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase != GSURLSessionWebSocketLifecycleStateOpen)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  else
    {
      [internal->send.queue addObject: [NSValue valueWithPointer: entry]];
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  if (nil != error)
    {
      GSURLSessionWebSocketCompleteSend(self, completionHandler, error);
      GSURLSessionWebSocketSendQueueEntryDestroy(entry);
      return;
    }

  if ([self state] == NSURLSessionTaskStateRunning)
    {
      dispatch_async(
        [[self _session] _workQueue],
        ^{
          curl_easy_pause([self _easyHandle], CURLPAUSE_SEND_CONT);
        });
    }
}

- (void) receiveMessageWithCompletionHandler:(void (^)(NSURLSessionWebSocketMessage *message, NSError *error)) completionHandler
{
  id handler;
  NSError *error;

  if (completionHandler == NULL)
    {
      return;
    }

  handler = (id)_Block_copy(completionHandler);
  error = nil;

  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase != GSURLSessionWebSocketLifecycleStateOpen)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  else
    {
      [internal->receive.handlers addObject: handler];
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  if (nil != error)
    {
      GSURLSessionWebSocketCompleteReceive(self, handler, nil, error);
    }
  else if ([self state] == NSURLSessionTaskStateRunning)
    {
      dispatch_async(
        [[self _session] _workQueue],
        ^{
          curl_easy_pause([self _easyHandle], CURLPAUSE_RECV_CONT);
        });
    }

  [handler release];
}

- (void) sendPingWithPongReceiveHandler:(void (^)(NSError *error)) pongReceiveHandler
{
  id handler;
  NSError *error;
  BOOL shouldResumeSend;

  if (pongReceiveHandler == NULL)
    {
      return;
    }

  handler = (id)_Block_copy(pongReceiveHandler);
  error = nil;
  shouldResumeSend = NO;

  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase != GSURLSessionWebSocketLifecycleStateOpen)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  else
    {
      [internal->send.pingHandlers addObject: handler];
      GSURLSessionWebSocketQueueNextPingLocked(self);
      shouldResumeSend = GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
        self,
        GSURLSessionWebSocketSendQueueEntryKindPing);
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  if (nil != error)
    {
      GSURLSessionWebSocketCompleteSend(self, handler, error);
      [handler release];
      return;
    }

  if (YES == shouldResumeSend && [self state] == NSURLSessionTaskStateRunning)
    {
      dispatch_async(
        [[self _session] _workQueue],
        ^{
          curl_easy_pause([self _easyHandle], CURLPAUSE_SEND_CONT);
        });
    }

  [handler release];
}

- (void) cancelWithCloseCode: (NSURLSessionWebSocketCloseCode)closeCode
                      reason: (NSData *)reason
{
  NSArray *cancelledSendEntries;
  NSArray *cancelledReceiveHandlers;
  NSArray *cancelledPingHandlers;
  NSError *cancelError;
  BOOL wasRunning;
  BOOL shouldResumeSend;

  cancelledSendEntries = nil;
  cancelledReceiveHandlers = nil;
  cancelledPingHandlers = nil;
  cancelError = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
    @"WebSocket task was canceled before queued work completed");
  shouldResumeSend = NO;

  wasRunning = ([self state] == NSURLSessionTaskStateRunning);
  _state = NSURLSessionTaskStateCanceling;
  internal->lifecycle.closeCode = closeCode;
  ASSIGNCOPY(internal->lifecycle.closeReason, reason);
  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateOpen)
    {
      GSURLSessionWebSocketBeginClosingLocked(
        self,
        GSURLSessionWebSocketClosePayload(closeCode, reason),
        &cancelledSendEntries,
        &cancelledReceiveHandlers,
        &cancelledPingHandlers);
      shouldResumeSend = YES;
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  GSURLSessionWebSocketCompleteOutstandingWork(self,
                                               cancelledSendEntries,
                                               cancelledReceiveHandlers,
                                               cancelledPingHandlers,
                                               cancelError);

  if (YES == shouldResumeSend && YES == wasRunning)
    {
      dispatch_async(
        [[self _session] _workQueue],
        ^{
          curl_easy_pause([self _easyHandle], CURLPAUSE_SEND_CONT);
        });
    }
}

- (void) dealloc
{
  NSValue *entryValue;

  if (GS_EXISTS_INTERNAL)
    {
      GS_MUTEX_DESTROY(internal->mutex);

      for (entryValue in internal->send.queue)
        {
          GSURLSessionWebSocketSendQueueEntryDestroy([entryValue pointerValue]);
        }
      if (NULL != internal->send.active.entry)
        {
          GSURLSessionWebSocketSendQueueEntryDestroy(
            (GSURLSessionWebSocketSendQueueEntry *)internal->send.active.entry);
        }

      RELEASE(internal->receive.handlers);
      RELEASE(internal->send.queue);
      RELEASE(internal->send.pingHandlers);
      RELEASE(internal->send.pingPayload);
      RELEASE(internal->receive.buffer);
      RELEASE(internal->lifecycle.closeReason);
      GS_DESTROY_INTERNAL(NSURLSessionWebSocketTask);
    }

  [super dealloc];
}

@end
#endif
