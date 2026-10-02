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

#if GS_HAVE_NSURLSESSION_WEBSOCKETS

@class NSMutableArray;
@class NSMutableData;
@class NSData;

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
} GSURLSessionWebSocketSendContext;

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

/**
 * Above the types for the instances variables of NSURLSessionWebSocket task are
 * defined. All the structs need to be defined above this line and the
 * NSURLSession.h header needs to be includes _after_ GSInternal.h. This is an
 * incredibily "fragile" way, to provide support for old runtimes.
 *
 * The mutex instance variable guards all other instance variables.
 */

#define GS_NSURLSessionWebSocketTask_IVARS \
  GSURLSessionWebSocketSendContext send; \
  GSURLSessionWebSocketReceiveContext receive; \
  GSURLSessionWebSocketLifecycleState lifecycle; \
  gs_mutex_t mutex;

#define GS_INTERNAL_NAME _internal2
#define GSInternal NSURLSessionWebSocketTaskInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLSessionWebSocketTask)

#import "Foundation/NSArray.h"
#import "Foundation/NSURLSession.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"

#import "GSURLPrivate.h"
#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"
#import "GSDispatch.h"

/**
 * GSURLSessionWebSocketSendQueueEntry
 */

typedef struct
{
  NSURLSessionWebSocketMessage *message;
  NSData *payload;
  GSNSURLSessionWebSocketTaskHandler completionHandler;
  GSURLSessionWebSocketSendQueueEntryKind kind;
  NSURLSessionWebSocketMessageType dataType;
} GSURLSessionWebSocketSendQueueEntry;

static GSURLSessionWebSocketSendQueueEntry *
dataSendQueueEntryCreate(
  NSURLSessionWebSocketMessage *message,
  GSNSURLSessionWebSocketTaskHandler completionHandler)
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
controlSendQueueEntryCreate(
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
sendQueueEntryDestroy(
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

/**
 * GSURLSessionWebSocketSendContext
 */

static void sendContextInit(GSURLSessionWebSocketSendContext *ctx)
{
  ctx->queue = [[NSMutableArray alloc] init];
  ctx->pingHandlers = [[NSMutableArray alloc] init];
  ctx->nextPingIdentifier = 1;
  ctx->frameStartRetryPending = NO;
}

static void sendContextClear(GSURLSessionWebSocketSendContext *ctx)
{
  [ctx->queue removeAllObjects];
  [ctx->pingHandlers removeAllObjects];
  DESTROY(ctx->pingPayload);
}

static void sendContextDestroy(GSURLSessionWebSocketSendContext *ctx)
{

  GS_FOR_IN(NSValue *, entry, ctx->queue)
      sendQueueEntryDestroy([entry pointerValue]);
  GS_END_FOR(state->queue)


  if (NULL != ctx->active.entry)
    {
      sendQueueEntryDestroy(
        (GSURLSessionWebSocketSendQueueEntry *)ctx->active.entry);
    }

  RELEASE(ctx->queue);
  RELEASE(ctx->pingHandlers);
  RELEASE(ctx->pingPayload);
}

/**
 * GSURLSessionWebSocketReceiveContext
 */

static void receiveContextInit(GSURLSessionWebSocketReceiveContext *ctx)
{
  ctx->handlers = [[NSMutableArray alloc] init];
  ctx->buffer = [[NSMutableData alloc] init];
  ctx->controlBuffer = [[NSMutableData alloc] init];
  ctx->maximumMessageSize = 1024 * 1024;
  ctx->phase = GSURLSessionWebSocketReceiveStateIdle;
  ctx->frameOffset = 0;
}

static void receiveContextClear(GSURLSessionWebSocketReceiveContext *ctx)
{
  [ctx->handlers removeAllObjects];
}

static void receiveContextDestroy(GSURLSessionWebSocketReceiveContext *ctx)
{
  RELEASE(ctx->handlers);
  RELEASE(ctx->buffer);
  RELEASE(ctx->controlBuffer);
}

/**
 * GSURLSessionWebSocketLifecycleState
 */

static void lifecycleStateInit(GSURLSessionWebSocketLifecycleState *state)
{
  state->phase = GSURLSessionWebSocketLifecycleStateOpen;
  state->closeFrameSent = NO;
  state->closeFrameReceived = NO;
}

static void lifecycleStateDestroy(GSURLSessionWebSocketLifecycleState *state)
{
  RELEASE(state->closeReason);
}

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
  GSURLSessionWebSocketReceiveContext *ctx;
  ctx = &GSIVar(task, receive);

  [ctx->buffer setLength: 0];
  [ctx->controlBuffer setLength: 0];

  ctx->phase = GSURLSessionWebSocketReceiveStateIdle;
  ctx->frameOffset = 0;
  ctx->controlOffset = 0;
  ctx->controlFlags = 0;
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
  GSURLSessionWebSocketSendContext *sendContext;

  sendContext = &GSIVar(task, send);

  if (NULL != sendContext->active.entry
      && sendContext->active.kind == kind)
    {
      return YES;
    }

  for (entryValue in sendContext->queue)
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
  GSURLSessionWebSocketLifecycleState *lifecycleState;
  GSURLSessionWebSocketSendContext *sendContext;
  NSData *payload;

  lifecycleState = &GSIVar(task, lifecycle);
  sendContext = &GSIVar(task, send);

  if (lifecycleState->phase != GSURLSessionWebSocketLifecycleStateOpen
      || nil != sendContext->pingPayload
      || [sendContext->pingHandlers count] == 0
      || YES == GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
        task,
        GSURLSessionWebSocketSendQueueEntryKindPing))
    {
      return;
    }

  payload = GSURLSessionWebSocketPingPayload(sendContext->nextPingIdentifier++);
  entry = controlSendQueueEntryCreate(
    GSURLSessionWebSocketSendQueueEntryKindPing,
    payload);
  [sendContext->queue insertObject: [NSValue valueWithPointer: entry] atIndex: 0];
}

/**
 * If the task's send state has an active send queue entry, this entry will be
 * returned. Otherwise, we attempt to pop the first object in the queue, and
 * make it the new active send queue entry.
 *
 * Returns:
 * - a valid send queue entry, or
 * - NULL, if there is no remaining entry ithe send queue.
 */
static GSURLSessionWebSocketSendQueueEntry *
GSURLSessionWebSocketPopNextSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  GSURLSessionWebSocketSendContext *sendContext;

  sendContext = &GSIVar(task, send);

  // Check if we already have an active entry.
  if (NULL != sendContext->active.entry)
    {
      return (GSURLSessionWebSocketSendQueueEntry *)sendContext->active.entry;
    }

  // Do we have a send entry in the queue?
  if ([sendContext->queue count] == 0)
    {
      return NULL;
    }

  // Pop first object...
  entry = [[sendContext->queue objectAtIndex: 0] pointerValue];
  [sendContext->queue removeObjectAtIndex: 0];

  // and move it into the active entry
  sendContext->active.entry = entry;
  sendContext->active.kind = entry->kind;
  sendContext->active.dataType = entry->dataType;
  sendContext->active.payloadOffset = 0;
  sendContext->active.frameStarted = NO;

  return entry;
}

/**
 * Clears the currently active send queue entry.
 */
static void
clearActiveSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketSendContext *sendContext;

  sendContext = &GSIVar(task, send);
  sendContext->active.entry = NULL;
  sendContext->active.kind = GSURLSessionWebSocketSendQueueEntryKindData;
  sendContext->active.dataType = NSURLSessionWebSocketMessageTypeData;
  sendContext->active.payloadOffset = 0;
  sendContext->active.frameStarted = NO;
}

/**
 * Clear all scheduled outstanding send entries, and push a close entry to the
 * send queue.
 */
static void
GSURLSessionWebSocketBeginClosingLocked(
  NSURLSessionWebSocketTask *task,
  NSData *closePayload,
  NSArray **sendEntries,
  NSArray **receiveHandlers,
  NSArray **pingHandlers)
{
  GSURLSessionWebSocketLifecycleState *lifecycleState;
  GSURLSessionWebSocketSendContext *sendContext;
  GSURLSessionWebSocketReceiveContext *receiveContext;
  GSURLSessionWebSocketSendQueueEntry *closeEntry;

  lifecycleState = &GSIVar(task, lifecycle);
  sendContext = &GSIVar(task, send);
  receiveContext = &GSIVar(task, receive);

  assert(lifecycleState->phase == GSURLSessionWebSocketLifecycleStateOpen);

  // Update the current phase in the task's WebSocket lifecycle
  lifecycleState->phase = GSURLSessionWebSocketLifecycleStateClosing;

  // Copy the queues holding all remaining send, receive, and ping entries
  *sendEntries = [sendContext->queue copy];
  *receiveHandlers = [receiveContext->handlers copy];
  *pingHandlers = [sendContext->pingHandlers copy];

  sendContextClear(sendContext);
  receiveContextClear(receiveContext);

  GSURLSessionWebSocketResetReceiveStateLocked(task);

  closeEntry = controlSendQueueEntryCreate(
    GSURLSessionWebSocketSendQueueEntryKindClose,
    closePayload);
  [sendContext->queue addObject: [NSValue valueWithPointer: closeEntry]];
}

/**
 * Transition from the 'closing' lifecycle state to 'closed', and return YES, if
 * - the current lifecycle state is 'closing',
 * - AND we sent the close frame,
 * - AND a close frame was received.
 * Otherwise, we return NO.
 */
static BOOL
WSTaskCompleteClosingIfReadyLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketLifecycleState *lifecycleState;

  lifecycleState = &GSIVar(task, lifecycle);
  if (lifecycleState->phase == GSURLSessionWebSocketLifecycleStateClosing
      && lifecycleState->closeFrameSent
      && lifecycleState->closeFrameReceived)
    {
      lifecycleState->phase = GSURLSessionWebSocketLifecycleStateClosed;
      return YES;
    }

  return NO;
}

/**
 * Pop the next receive handler from the handler queue.
 */
static GSNSURLSessionWebSocketTaskReceiveHandler
GSURLSessionWebSocketPopReceiveHandlerLocked(NSURLSessionWebSocketTask *task)
{
  GSNSURLSessionWebSocketTaskReceiveHandler handler;
  GSURLSessionWebSocketReceiveContext *receiveContext;

  receiveContext = &GSIVar(task, receive);

  if ([receiveContext->handlers count] == 0)
    {
      return nil;
    }

  handler = RETAIN((GSNSURLSessionWebSocketTaskReceiveHandler)
    [receiveContext->handlers objectAtIndex: 0]);
  [receiveContext->handlers removeObjectAtIndex: 0];
  return AUTORELEASE(handler);
}

/**
 * All outstanding send entries, including the active entry, receive, and ping
 * handlers, are copied out into arrays. The callee transfers the ownership of
 * the array references in `sendEntries`, `receiveHandlers`, and `pingHandlers`
 * to the caller. The caller is therefore responsible to release the resources
 * after use.
 */
static void
GSURLSessionWebSocketDrainOutstandingWorkLocked(
  NSURLSessionWebSocketTask *task,
  NSArray **sendEntries,
  NSArray **receiveHandlers,
  NSArray **pingHandlers)
{
  NSMutableArray *allSendEntries;
  GSURLSessionWebSocketSendContext *sendContext;
  GSURLSessionWebSocketReceiveContext *receiveContext;

  sendContext = &GSIVar(task, send);
  receiveContext = &GSIVar(task, receive);

  allSendEntries = nil;
  if (sendEntries != NULL)
    {
      allSendEntries = [[NSMutableArray alloc] init];
      if (NULL != sendContext->active.entry)
        {
          [allSendEntries addObject:
            [NSValue valueWithPointer: sendContext->active.entry]];
        }

      [allSendEntries addObjectsFromArray: sendContext->queue];
      *sendEntries = [allSendEntries copy];
      [allSendEntries release];
    }

  if (receiveHandlers != NULL)
    {
      *receiveHandlers = [receiveContext->handlers copy];
    }

  if (pingHandlers != NULL)
    {
      *pingHandlers = [sendContext->pingHandlers copy];
    }

  sendContextClear(sendContext);
  receiveContextClear(receiveContext);
  clearActiveSendEntryLocked(task);
  sendContext->frameStartRetryPending = NO;
  GSURLSessionWebSocketResetReceiveStateLocked(task);
}

/**
 * Dispatch the invocation of `handler`, by adding it to the session's delegate
 * queue.
 */
static void
WSTaskNotifyReceiveCompletionHandler(
  NSURLSessionWebSocketTask *task,
  GSNSURLSessionWebSocketTaskReceiveHandler handler,
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

/**
 * Dispatch the invocation of `completionHandler`, by adding it to the
 * sessions delegate queue.
 */
static void
WSTaskNotifyCompletionHandler(
  NSURLSessionWebSocketTask *task,
  GSNSURLSessionWebSocketTaskHandler completionHandler,
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


/**
 * Dispatch the invocation of ping handlers.
 */
static void
WSTaskNotifyPingCompletionHandlers(
  NSURLSessionWebSocketTask *task,
  NSArray *pingHandlers,
  NSError *error)
{
  GSNSURLSessionWebSocketTaskHandler handler;

  // FIXME(hugo): Fast iteration not supported in gcc
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
          sendQueueEntryDestroy(entry);
        }
    }
}

static void
WSTaskNotifyReceiveCompletionHandlers(
  NSArray *receiveHandlers,
  NSURLSessionWebSocketTask *task,
  NSError *error)
{
  GSNSURLSessionWebSocketTaskReceiveHandler handler;

  // FIXME(hugo): Fast iteration not supported in GCC
  for (handler in receiveHandlers)
    {
      WSTaskNotifyReceiveCompletionHandler(task, handler, nil, error);
    }
}

/**
 * Notify all outstanding send, receive, and ping completion handlers.
 */
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
}



/**
 * Pause or resume the task's underlying easy handle.
 */
static void
WSTaskResume(NSURLSessionWebSocketTask *task, int action)
{
  curl_easy_pause([task _easyHandle], action);
}

/**
 * Schedule the pausing or resumption of the task's underlying easyhandle on the
 * session's work thread.
 *
 * After initialization, all manipulation of CURL multi and easy handles happens
 * on this work thread
 */
static void
WSTaskScheduleResume(NSURLSessionWebSocketTask *task, int direction)
{
  NSInvocation	*inv;
  SEL resumeTaskSel;

  resumeTaskSel = @selector(_resumeTaskWithDirection:);

  inv = [NSInvocation invocationWithMethodSignature:
    [task methodSignatureForSelector: resumeTaskSel]];
  [inv setTarget: task];
  [inv setSelector: resumeTaskSel];
  [inv setArgument: &direction atIndex:2];

  [[task _session] _performInvocationOnWorkThread: inv];
}

/**
 * Handle an unrecoverable receive failure.
 * The task's lifecycle transitions to 'failed', we cancel all outstanding work,
 * and notify the respective completion handlers.
 */
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

  [task _setError: error];
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
  RELEASE(sendEntries);
  RELEASE(receiveHandlers);
  RELEASE(pingHandlers);
}

/**
 * Handle an unrecoverable transmission failure.
 */
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

  // FIXME(hugo): Does this require a lifecycle change?

  GS_MUTEX_LOCK(GSIVar(task, mutex));
  [task _setError: error];
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
  RELEASE(sendEntries);
  RELEASE(receiveHandlers);
  RELEASE(pingHandlers);
  return CURL_READFUNC_ABORT;
}

/**
 * The CURL easy handle write callback for data reception.
 */
static size_t
ws_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  GSURLSessionWebSocketReceiveContext *receiveContext;
  GSURLSessionWebSocketSendContext *sendContext;
  GSNSURLSessionWebSocketTaskReceiveHandler handler;
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
  receiveContext = &GSIVar(task, receive);
  sendContext = &GSIVar(task, send);
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
          [receiveContext->controlBuffer setLength: 0];
          receiveContext->controlOffset = 0;
          receiveContext->controlFlags =
            meta->flags & (CURLWS_PONG | CURLWS_CLOSE | CURLWS_PING);
        }

      if (meta->offset < 0
          || meta->bytesleft < 0
          || (meta->offset > 0
              && receiveContext->controlFlags
                   != (meta->flags & (CURLWS_PONG | CURLWS_CLOSE | CURLWS_PING)))
          || (unsigned long long)meta->offset
               > (unsigned long long)receiveContext->controlOffset
          || (NSUInteger)meta->offset != receiveContext->controlOffset
          || bytesInCallback > NSUIntegerMax - receiveContext->controlOffset)
        {
          controlFrameInvalid = YES;
        }
      else
        {
          [receiveContext->controlBuffer appendBytes: ptr
                                                    length: bytesInCallback];
          receiveContext->controlOffset += bytesInCallback;
          if (meta->bytesleft == 0)
            {
              controlPayload = [receiveContext->controlBuffer copy];
              controlFlags = receiveContext->controlFlags;
              controlFrameComplete = YES;
              [receiveContext->controlBuffer setLength: 0];
              receiveContext->controlOffset = 0;
              receiveContext->controlFlags = 0;
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
      GSNSURLSessionWebSocketTaskHandler pingHandler;
      BOOL shouldQueueNextPing;

      pingHandler = nil;
      shouldQueueNextPing = NO;

      GS_MUTEX_LOCK(GSIVar(task, mutex));
      if (nil != sendContext->pingPayload
          && YES == GSURLSessionWebSocketFramePayloadMatchesData(
            [controlPayload bytes],
            [controlPayload length],
            sendContext->pingPayload))
        {
          if ([sendContext->pingHandlers count] > 0)
            {
              pingHandler = RETAIN((GSNSURLSessionWebSocketTaskHandler)
                [sendContext->pingHandlers objectAtIndex: 0]);
              [sendContext->pingHandlers removeObjectAtIndex: 0];
            }

          DESTROY(sendContext->pingPayload);
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
      RELEASE(cancelledSendEntries);
      RELEASE(cancelledReceiveHandlers);
      RELEASE(cancelledPingHandlers);

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
  if ([receiveContext->handlers count] == 0)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return CURL_WRITEFUNC_PAUSE;
    }
  handler = nil;
  buffer = receiveContext->buffer;
  existingLength = [buffer length];
  messageContinuesInNextFrame = ((meta->flags & CURLWS_CONT) != 0);

  if (receiveContext->phase == GSURLSessionWebSocketReceiveStateIdle
      && receiveContext->frameOffset == 0)
    {
      receiveContext->phase = messageState;
    }
  else if (receiveContext->phase != messageState)
    {
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket message changed frame type from %lu to %lu",
                    (unsigned long)receiveContext->phase,
                    (unsigned long)messageState]);
      return 0;
    }

  if (receiveContext->frameOffset > 0
      && (NSUInteger)meta->offset != receiveContext->frameOffset)
    {
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket frame offset mismatch: expected %lu but "
                    @"received %lld",
                    (unsigned long)receiveContext->frameOffset,
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

  if (receiveContext->maximumMessageSize <= 0
      || requiredLength > (NSUInteger)receiveContext->maximumMessageSize)
    {
      GSURLSessionWebSocketFailReceiveLocked(
        task,
        NSURLErrorDataLengthExceedsMaximum,
        [NSString stringWithFormat:
                    @"WebSocket message length %lu exceeds maximumMessageSize "
                    @"%ld",
                    (unsigned long)requiredLength,
                    (long)receiveContext->maximumMessageSize]);
      return 0;
    }

  if ([buffer length] < requiredLength)
    {
      [buffer setCapacity: requiredLength];
    }

  [buffer appendBytes: ptr length: bytesInChunk];
  receiveContext->frameOffset += bytesInChunk;

  if (meta->bytesleft > 0)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return bytesInChunk;
    }

  receiveContext->frameOffset = 0;
  if (YES == messageContinuesInNextFrame)
    {
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));
      return bytesInChunk;
    }

  /* The full message is complete once the last chunk of the last frame arrives. */
  message = nil;
  if (receiveContext->phase == GSURLSessionWebSocketReceiveStateText)
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

/**
 * The CURL easy read callback for data transmission.
 */
static size_t
ws_read_callback(char *buffer, size_t size, size_t nitems, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  GSURLSessionWebSocketSendContext *sendContext;
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSData *payload;
  size_t bytesAvailable;
  size_t bytesToWrite;
  size_t payloadLength;
  unsigned int flags;
  CURLcode result;

  task = (NSURLSessionWebSocketTask *)userdata;
  sendContext = &GSIVar(task, send);
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

  if (sendContext->active.payloadOffset > payloadLength)
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

  if (NO == sendContext->active.frameStarted)
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

      result = curl_ws_start_frame([task _easyHandle],
                                   flags,
                                   (curl_off_t)payloadLength);
      if (result == CURLE_AGAIN)
        {
          sendContext->frameStartRetryPending = YES;
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

          // User tried to close the session with a payload that is too large. This is a protocol violation.
          // Foundation's NSURLSession happily violates the WebSocket spec.
          if (flags == CURLWS_CLOSE && result == CURLE_TOO_LARGE)
            {
              // FIXME!
              NSLog(@"OOOPS!!");
            }

          return GSURLSessionWebSocketFailSend(task, error);
        }

      sendContext->active.frameStarted = YES;
    }

  bytesToWrite = MIN(bytesAvailable,
                     payloadLength - sendContext->active.payloadOffset);
  if (bytesToWrite > 0)
    {
      memcpy(buffer,
             ((const char *)[payload bytes])
               + sendContext->active.payloadOffset,
             bytesToWrite);
    }

  sendContext->active.payloadOffset += bytesToWrite;

  if (sendContext->active.payloadOffset == payloadLength)
    {
      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindPing)
        {
          ASSIGNCOPY(sendContext->pingPayload, payload);
        }
      else if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindClose)
        {
          GSIVar(task, lifecycle).closeFrameSent = YES;
          if (YES == WSTaskCompleteClosingIfReadyLocked(task))
            {
              [task _setShouldStopTransfer: YES];
            }
        }

      clearActiveSendEntryLocked(task);
      GS_MUTEX_UNLOCK(GSIVar(task, mutex));

      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindData)
        {
          WSTaskNotifyCompletionHandler(task, entry->completionHandler, nil);
        }
      sendQueueEntryDestroy(entry);
      return bytesToWrite;
    }

  GS_MUTEX_UNLOCK(GSIVar(task, mutex));
  return bytesToWrite;
}

@implementation  NSURLSessionWebSocketTask

- (instancetype) initWebSocketTask: (NSURLSession *)session
                           request: (NSURLRequest *)request
                    taskIdentifier: (NSUInteger)identifier
{
  // Setup a new easy handle
  CURL *handle;

  handle = curl_easy_init();
  if (handle == NULL)
  {
    return nil;
  }

  self = [super initWithSession: session
                         request: request
                  taskIdentifier: identifier
                      easyHandle: handle];
  if (self != nil)
    {
      /* Configure the Curl easy handle
       */
      [self _initializeEasyHandleForRequest: request];
      [self _configureTransferCallbacks];
      [self _configureProtocolOptionsForRequest: request
                                    configuration: [session configuration]];

      /* Initialize all other ivars
       */
      GS_CREATE_INTERNAL(NSURLSessionWebSocketTask);
      GS_MUTEX_INIT(internal->mutex);
      sendContextInit(&internal->send);
      clearActiveSendEntryLocked(self);
      receiveContextInit(&internal->receive);
      lifecycleStateInit(&internal->lifecycle);
    }

  return self;
}

/*
 * Private methods for initializing the Curl easy handle
 */

- (void) _initializeEasyHandleForRequest: (NSURLRequest *)request
{
  NSURL *url;
  CURL *handle;

  url = [request URL];
  handle = [self _easyHandle];

  /* WebSocket tasks represent a single upgraded connection. */
  curl_easy_setopt(handle, CURLOPT_CUSTOMREQUEST, "GET");
  curl_easy_setopt(handle,
                   CURLOPT_URL,
                   [[url absoluteString] UTF8String]);
  curl_easy_setopt(handle, CURLOPT_CONNECT_ONLY, 0L);

  /* WebSocket upgrade is a single GET request; do not follow redirects. */
  curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, 0L);

  /* Set timeout in connect phase */
  curl_easy_setopt(handle,
                   CURLOPT_CONNECTTIMEOUT,
                   (long)[request timeoutInterval]);
}

- (void) _configureTransferCallbacks
{
  CURL *handle;
  handle = [self _easyHandle];

  /* The task is associated with the easy handle for completion/error lookup. */
  curl_easy_setopt(handle, CURLOPT_ERRORBUFFER, [self _curlErrorBuffer]);
  curl_easy_setopt(handle, CURLOPT_PRIVATE, self);

  curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, ws_write_callback);
  curl_easy_setopt(handle, CURLOPT_WRITEDATA, self);

  curl_easy_setopt(handle, CURLOPT_READFUNCTION, ws_read_callback);
  curl_easy_setopt(handle, CURLOPT_READDATA, self);

  curl_easy_setopt(handle, CURLOPT_UPLOAD, 1L);
  curl_easy_setopt(handle, CURLOPT_POSTFIELDSIZE, -1L);
}

- (void) _configureProtocolOptionsForRequest: (NSURLRequest *)request
                               configuration:
  (NSURLSessionConfiguration *)configuration
{
  NSData *certificateBlob;
  CURL *handle;

  handle = [self _easyHandle];
  /* Set overall timeout */
  curl_easy_setopt(handle,
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

      curl_easy_setopt(handle, CURLOPT_CAINFO_BLOB, &blob);
#else
      curl_easy_setopt(handle,
                       CURLOPT_CAINFO,
                       [[self _session] _certificatePath]);
#endif
    }

  /* TODO(WS): Configure websocket protocol options and handshake behavior. */
}

- (void) _resumeTaskWithDirection: (int) direction
{
  WSTaskResume(self, direction);
}

/*
 * Public Methods
 */

- (void) cancel
{
  [self cancelWithCloseCode: NSURLSessionWebSocketCloseCodeNormalClosure
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

  entry = dataSendQueueEntryCreate(message, completionHandler);
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
      sendQueueEntryDestroy(entry);
      return;
    }

  if ([self state] == NSURLSessionTaskStateRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_SEND_CONT);
    }
}

- (void) receiveMessageWithCompletionHandler:(GSNSURLSessionWebSocketTaskReceiveHandler) completionHandler
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

- (void) sendPingWithPongReceiveHandler:(GSNSURLSessionWebSocketTaskHandler) pongReceiveHandler
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
  NSURLSessionTaskState oldState;
  BOOL wasRunning;
  BOOL shouldResumeSend;

  cancelledSendEntries = nil;
  cancelledReceiveHandlers = nil;
  cancelledPingHandlers = nil;
  cancelError = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
    @"WebSocket task was canceled before queued work completed");
  shouldResumeSend = NO;

  oldState = [self _compareAndExchangeState: NSURLSessionTaskStateCanceling];
  wasRunning = (oldState == NSURLSessionTaskStateRunning);

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
  RELEASE(cancelledSendEntries);
  RELEASE(cancelledReceiveHandlers);
  RELEASE(cancelledPingHandlers);

  if (YES == shouldResumeSend && YES == wasRunning)
    {
      WSTaskScheduleResume(self, CURLPAUSE_SEND_CONT);
    }
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

- (NSURLSessionWebSocketCloseCode) closeCode
{
  NSURLSessionWebSocketCloseCode closeCode;

  GS_MUTEX_LOCK(internal->mutex);
  closeCode = internal->lifecycle.closeCode;
  GS_MUTEX_UNLOCK(internal->mutex);
  return closeCode;
}


- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      GS_MUTEX_DESTROY(internal->mutex);
      sendContextDestroy(&internal->send);
      receiveContextDestroy(&internal->receive);
      lifecycleStateDestroy(&internal->lifecycle);
      GS_DESTROY_INTERNAL(NSURLSessionWebSocketTask);
    }

  [super dealloc];
}

/*
 * Private Methods
 */

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

  CURL *handle = [self _easyHandle];
  char *errorBuffer = [self _curlErrorBuffer];

  error = GSURLSessionErrorForCURLcode(handle, code, errorBuffer);
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
      [self _setError: error];
    }
  else if (error == nil
           && internal->lifecycle.phase != GSURLSessionWebSocketLifecycleStateClosed)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket connection closed without completing the closing "
        @"handshake");
      [self _setError: error];
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
  RELEASE(sendEntries);
  RELEASE(receiveHandlers);
  RELEASE(pingHandlers);

  if (YES == shouldNotifyClose)
    {
      GSURLSessionWebSocketNotifyDidClose(self, closeCode, closeReason);
    }
  [closeReason release];

  [super _transferFinishedWithCode: code];
}


@end
#endif
