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

#import "common.h"
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
  NSMutableData *controlBuffer;
  GSURLSessionWebSocketReceivePhase phase;
  size_t frameOffset;
  size_t controlOffset;
  unsigned int controlFlags;
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
  assert(type == NSURLSessionWebSocketMessageTypeString
    || type == NSURLSessionWebSocketMessageTypeData);

  if (type == NSURLSessionWebSocketMessageTypeString)
    {
      payload = [[message string] dataUsingEncoding: NSUTF8StringEncoding];
    }
  else
    {
      payload = [message data];
    }

  assert(nil != payload);

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

  assert(kind == GSURLSessionWebSocketSendQueueEntryKindPing
    || kind == GSURLSessionWebSocketSendQueueEntryKindClose);
  assert(nil != payload);

  entry = calloc(1, sizeof (*entry));
  assert(NULL != entry);
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
  [GSIVar(task, receive).controlBuffer setLength: 0];
  GSIVar(task, receive).phase = GSURLSessionWebSocketReceiveStateIdle;
  GSIVar(task, receive).frameOffset = 0;
  GSIVar(task, receive).controlOffset = 0;
  GSIVar(task, receive).controlFlags = 0;
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

static BOOL
WSTaskCompleteClosingIfReadyLocked(NSURLSessionWebSocketTask *task)
{
  if (GSIVar(task, lifecycle).phase == GSURLSessionWebSocketLifecycleStateClosing
      && GSIVar(task, lifecycle).closeFrameSent
      && GSIVar(task, lifecycle).closeFrameReceived)
    {
      GSIVar(task, lifecycle).phase = GSURLSessionWebSocketLifecycleStateClosed;
      return YES;
    }

  return NO;
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
WSTaskNotifyReceiveCompletionHandler(
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
WSTaskNotifyCompletionHandler(
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
WSTaskResume(NSURLSessionWebSocketTask *task, int direction)
{
  curl_easy_pause([task _easyHandle], direction);
}

static void
WSTaskScheduleResume(NSURLSessionWebSocketTask *task, int direction)
{
  [[task _session] _performOnWorkThread: ^{
      WSTaskResume(task, direction);
    }];
}

static void
WSTaskNotifyPingCompletionHandlers(
  NSURLSessionWebSocketTask *task,
  NSArray *pingHandlers,
  NSError *error)
{
  GSURLSessionWebSocketPingHandler handler;

  for (handler in pingHandlers)
    {
      WSTaskNotifyCompletionHandler(task, handler, error);
    }
}

static void
WSTaskDestroySendEntriesAndNotifyCompletionHandlers(
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
              WSTaskNotifyCompletionHandler(task,
                                                entry->completionHandler,
                                                error);
            }
          GSURLSessionWebSocketSendQueueEntryDestroy(entry);
        }
    }
}

static void
WSTaskNotifyReceiveCompletionHandlers(
  NSArray *receiveHandlers,
  NSURLSessionWebSocketTask *task,
  NSError *error)
{
  GSURLSessionWebSocketReceiveHandler handler;

  for (handler in receiveHandlers)
    {
      WSTaskNotifyReceiveCompletionHandler(task, handler, nil, error);
    }
}

static void
WSTaskNotifyOutstandingCompletionHandlers(
  NSURLSessionWebSocketTask *task,
  NSArray *sendEntries,
  NSArray *receiveHandlers,
  NSArray *pingHandlers,
  NSError *error)
{
  WSTaskDestroySendEntriesAndNotifyCompletionHandlers(sendEntries, task, error);
  WSTaskNotifyReceiveCompletionHandlers(receiveHandlers, task, error);
  WSTaskNotifyPingCompletionHandlers(task, pingHandlers, error);
  [sendEntries release];
  [receiveHandlers release];
  [pingHandlers release];
}

static void
GSURLSessionWebSocketFailReceiveLocked(
  NSURLSessionWebSocketTask *task,
  NSInteger code,
  NSString *description)
{
  NSArray *sendEntries;
  NSArray *receiveHandlers;
  NSArray *pingHandlers;
  NSError *error;

  error = GSURLSessionWebSocketError(code, description);
  NSDebugLLog(GS_NSURLSESSION_DEBUG_KEY,
              @"task=%@ websocket receive failed: %@",
              task,
              description);

  [task _setStoredTaskError: error];
  GSIVar(task, lifecycle).phase = GSURLSessionWebSocketLifecycleStateFailed;
  GSURLSessionWebSocketDrainOutstandingWorkLocked(task,
                                                  &sendEntries,
                                                  &receiveHandlers,
                                                  &pingHandlers);
  GS_MUTEX_UNLOCK(GSIVar(task, mutex));

  WSTaskNotifyOutstandingCompletionHandlers(task,
                                             sendEntries,
                                             receiveHandlers,
                                             pingHandlers,
                                             error);
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

  WSTaskNotifyOutstandingCompletionHandlers(task,
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
  NSData *controlPayload;
  BOOL controlFrameComplete;
  BOOL controlFrameInvalid;
  unsigned int controlFlags;
  NSString *string;

  task = (NSURLSessionWebSocketTask *)userdata;
  bytesInCallback = size * nmemb;
  controlPayload = nil;
  controlFrameComplete = NO;
  controlFrameInvalid = NO;
  controlFlags = 0;

  /* Extract websocket frame metadata */
  meta = curl_ws_meta([task _easyHandle]);
  if (NULL == meta)
    {
      GS_MUTEX_LOCK(GSIVar(task, mutex));
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        @"curl_ws_meta returned NULL while receiving WebSocket data");
      return 0;
    }

  if (meta->len != bytesInCallback || meta->len != nmemb)
    {
      GS_MUTEX_LOCK(GSIVar(task, mutex));
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket callback length mismatch: received %lu bytes "
                    @"(%lu items) but curl metadata announced %lu",
                    (unsigned long)bytesInCallback,
                    (unsigned long)nmemb,
                    (unsigned long)meta->len]);
      [NSException raise: NSInternalInconsistencyException
                  format: @"libcurl delivered a WebSocket callback whose "
                          @"length did not match curl_ws_meta()->len. "
                          @"Please upgrade libcurl."];
    }

  if ((meta->flags & (CURLWS_PONG | CURLWS_CLOSE | CURLWS_PING)) != 0)
    {
      GS_MUTEX_LOCK(GSIVar(task, mutex));
      if (meta->offset == 0)
        {
          [GSIVar(task, receive).controlBuffer setLength: 0];
          GSIVar(task, receive).controlOffset = 0;
          GSIVar(task, receive).controlFlags =
            meta->flags & (CURLWS_PONG | CURLWS_CLOSE | CURLWS_PING);
        }

      if (meta->offset < 0
          || meta->bytesleft < 0
          || (meta->offset > 0
              && GSIVar(task, receive).controlFlags
                   != (meta->flags & (CURLWS_PONG | CURLWS_CLOSE | CURLWS_PING)))
          || (unsigned long long)meta->offset
               > (unsigned long long)GSIVar(task, receive).controlOffset
          || (NSUInteger)meta->offset != GSIVar(task, receive).controlOffset
          || bytesInCallback > NSUIntegerMax - GSIVar(task, receive).controlOffset)
        {
          controlFrameInvalid = YES;
        }
      else
        {
          [GSIVar(task, receive).controlBuffer appendBytes: ptr
                                                    length: bytesInCallback];
          GSIVar(task, receive).controlOffset += bytesInCallback;
          if (meta->bytesleft == 0)
            {
              controlPayload = [GSIVar(task, receive).controlBuffer copy];
              controlFlags = GSIVar(task, receive).controlFlags;
              controlFrameComplete = YES;
              [GSIVar(task, receive).controlBuffer setLength: 0];
              GSIVar(task, receive).controlOffset = 0;
              GSIVar(task, receive).controlFlags = 0;
            }
        }
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      if (YES == controlFrameInvalid)
        {
          GS_MUTEX_LOCK(GSIVar(task, mutex));
          GSURLSessionWebSocketFailReceiveLocked(
            task,
            NSURLErrorCannotParseResponse,
            @"WebSocket control-frame callback metadata was inconsistent");
          return 0;
        }
      if (NO == controlFrameComplete)
        {
          return bytesInCallback;
        }
    }

  if ((controlFlags & CURLWS_PONG) != 0)
    {
      GSURLSessionWebSocketPingHandler pingHandler;
      BOOL shouldQueueNextPing;

      pingHandler = nil;
      shouldQueueNextPing = NO;

      GS_MUTEX_LOCK(GSIVar(task, mutex));
      if (nil != GSIVar(task, send).pingPayload
          && YES == GSURLSessionWebSocketFramePayloadMatchesData(
            [controlPayload bytes],
            [controlPayload length],
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
          WSTaskNotifyCompletionHandler(task, pingHandler, nil);
          [pingHandler release];
        }

      if (YES == shouldQueueNextPing)
        {
          WSTaskScheduleResume(task, CURLPAUSE_SEND_CONT);
        }

      [controlPayload release];
      return bytesInCallback;
    }

  if ((controlFlags & CURLWS_CLOSE) != 0)
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
      payloadLength = [controlPayload length];

      if (payloadLength >= 2)
        {
          const unsigned char *closeBytes;

          closeBytes = (const unsigned char *)[controlPayload bytes];
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
          closePayload = controlPayload;
          GSURLSessionWebSocketBeginClosingLocked(task,
                                                  closePayload,
                                                  &cancelledSendEntries,
                                                  &cancelledReceiveHandlers,
                                                  &cancelledPingHandlers);
          shouldSendCloseReply = YES;
        }
      if (YES == WSTaskCompleteClosingIfReadyLocked(task))
        {
          [task _setShouldStopTransfer: YES];
        }
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      WSTaskNotifyOutstandingCompletionHandlers(task,
                                                   cancelledSendEntries,
                                                   cancelledReceiveHandlers,
                                                   cancelledPingHandlers,
                                                   cancelError);

      if (YES == shouldSendCloseReply)
        {
          WSTaskScheduleResume(task, CURLPAUSE_SEND_CONT);
        }

      if (YES == shouldNotifyClose)
        {
          GSURLSessionWebSocketNotifyDidClose(task, closeCode, closeReason);
        }

      [controlPayload release];
      return bytesInCallback;
    }

  if ((controlFlags & CURLWS_PING) != 0)
    {
      [controlPayload release];
      return bytesInCallback;
    }

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
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"Unsupported websocket frame flags 0x%x", meta->flags]);
      return 0;
    }

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
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket message changed frame type from %lu to %lu",
                    (unsigned long)GSIVar(task, receive).phase,
                    (unsigned long)messageState]);
      return 0;
    }

  if (GSIVar(task, receive).frameOffset > 0
      && (NSUInteger)meta->offset != GSIVar(task, receive).frameOffset)
    {
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket frame offset mismatch: expected %lu but "
                    @"received %lld",
                    (unsigned long)GSIVar(task, receive).frameOffset,
                    (long long)meta->offset]);
      return 0;
    }

  bytesInChunk = meta->len;
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
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorDataLengthExceedsMaximum,
        [NSString stringWithFormat:
                    @"WebSocket message length %lu exceeds maximumMessageSize "
                    @"%ld",
                    (unsigned long)requiredLength,
                    (long)GSIVar(task, receive).maximumMessageSize]);
      return 0;
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
          GSURLSessionWebSocketFailReceiveLocked(
            task,
            NSURLErrorCannotDecodeContentData,
            @"WebSocket text message is not valid UTF-8");
          return 0;
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

  WSTaskNotifyReceiveCompletionHandler(task, handler, message, nil);
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
            assert(entry->dataType == NSURLSessionWebSocketMessageTypeString
              || entry->dataType == NSURLSessionWebSocketMessageTypeData);
            flags = entry->dataType == NSURLSessionWebSocketMessageTypeString
              ? CURLWS_TEXT : CURLWS_BINARY;
            break;
          case GSURLSessionWebSocketSendQueueEntryKindPing:
            flags = CURLWS_PING;
            break;
          case GSURLSessionWebSocketSendQueueEntryKindClose:
            flags = CURLWS_CLOSE;
            break;
          default:
            assert(0);
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
          if (YES == WSTaskCompleteClosingIfReadyLocked(task))
            {
              [task _setShouldStopTransfer: YES];
            }
        }

      GSURLSessionWebSocketClearActiveSendEntryLocked(task);
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindData)
        {
          WSTaskNotifyCompletionHandler(task, entry->completionHandler, nil);
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
  self = [super initWithSession: session
                         request: request
                  taskIdentifier: identifier];
  if (self != nil)
    {
      curl_easy_cleanup([self _easyHandle]);
      [self _setEasyHandle: NULL];
      [self _initializeEasyhandleForRequest: request];
      [self _configureTransferCallbacks];
      [self _configureProtocolOptionsForRequest: request
                                    configuration: [session configuration]];
      GS_CREATE_INTERNAL(NSURLSessionWebSocketTask);
      GS_MUTEX_INIT(internal->mutex);
      internal->send.queue = [[NSMutableArray alloc] init];
      internal->receive.handlers = [[NSMutableArray alloc] init];
      internal->send.pingHandlers = [[NSMutableArray alloc] init];
      internal->receive.buffer = [[NSMutableData alloc] init];
      internal->receive.controlBuffer = [[NSMutableData alloc] init];
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
  NSInteger maximumMessageSize;

  GS_MUTEX_LOCK(internal->mutex);
  maximumMessageSize = internal->receive.maximumMessageSize;
  GS_MUTEX_UNLOCK(internal->mutex);
  return maximumMessageSize;
}

- (void) setMaximumMessageSize: (NSInteger)maximumMessageSize
{
  GS_MUTEX_LOCK(internal->mutex);
  internal->receive.maximumMessageSize = maximumMessageSize;
  GS_MUTEX_UNLOCK(internal->mutex);
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
      WSTaskResume(self, CURLPAUSE_SEND_CONT);
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
  if (internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateClosed
      && (code == CURLE_ABORTED_BY_CALLBACK || code == CURLE_WRITE_ERROR))
    {
      /* The completed close handshake asks the progress callback to stop the
       * transfer. libcurl reports that intentional stop as an abort/write
       * error, which is a clean WebSocket completion here. */
      error = nil;
    }
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
  else if (error == nil
           && internal->lifecycle.phase != GSURLSessionWebSocketLifecycleStateClosed)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket connection closed without completing the closing "
        @"handshake");
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

  WSTaskNotifyOutstandingCompletionHandlers(self,
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
  NSURLSessionWebSocketCloseCode closeCode;

  GS_MUTEX_LOCK(internal->mutex);
  closeCode = internal->lifecycle.closeCode;
  GS_MUTEX_UNLOCK(internal->mutex);
  return closeCode;
}

- (void) cancel
{
  [self cancelWithCloseCode: NSURLSessionWebSocketCloseCodeInvalid
                     reason: nil];
}

- (NSData *) closeReason
{
  NSData *closeReason;

  GS_MUTEX_LOCK(internal->mutex);
  closeReason = RETAIN(internal->lifecycle.closeReason);
  GS_MUTEX_UNLOCK(internal->mutex);
  return AUTORELEASE(closeReason);
}

- (void) sendMessage:(NSURLSessionWebSocketMessage *) message
   completionHandler:(void (^)(NSError *error)) completionHandler
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSError *error;

  entry = GSURLSessionWebSocketDataSendQueueEntryCreate(message, completionHandler);
  error = nil;

  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateOpen)
    {
      [internal->send.queue addObject: [NSValue valueWithPointer: entry]];
    }
  else
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  if (nil != error)
    {
      WSTaskNotifyCompletionHandler(self, completionHandler, error);
      GSURLSessionWebSocketSendQueueEntryDestroy(entry);
      return;
    }

  if ([self state] == NSURLSessionTaskStateRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_SEND_CONT);
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
      WSTaskNotifyReceiveCompletionHandler(self, handler, nil, error);
    }
  else if ([self state] == NSURLSessionTaskStateRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_RECV_CONT);
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
      WSTaskNotifyCompletionHandler(self, handler, error);
      [handler release];
      return;
    }

  if (YES == shouldResumeSend && [self state] == NSURLSessionTaskStateRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_SEND_CONT);
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
  GS_MUTEX_LOCK(internal->mutex);
  if (internal->lifecycle.phase == GSURLSessionWebSocketLifecycleStateOpen)
    {
      internal->lifecycle.closeCode = closeCode;
      ASSIGNCOPY(internal->lifecycle.closeReason, reason);
      GSURLSessionWebSocketBeginClosingLocked(
        self,
        GSURLSessionWebSocketClosePayload(closeCode, reason),
        &cancelledSendEntries,
        &cancelledReceiveHandlers,
        &cancelledPingHandlers);
      shouldResumeSend = YES;
    }
  GS_MUTEX_UNLOCK(internal->mutex);

  WSTaskNotifyOutstandingCompletionHandlers(self,
                                               cancelledSendEntries,
                                               cancelledReceiveHandlers,
                                               cancelledPingHandlers,
                                               cancelError);

  if (YES == shouldResumeSend && YES == wasRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_SEND_CONT);
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
      RELEASE(internal->receive.controlBuffer);
      RELEASE(internal->lifecycle.closeReason);
      GS_DESTROY_INTERNAL(NSURLSessionWebSocketTask);
    }

  [super dealloc];
}

@end
#endif
