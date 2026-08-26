/* WebSocket task implementation. */
#include <curl/curl.h>
#include "Foundation/NSURLSession.h"
#include "Foundation/NSData.h"
#include "Foundation/NSOperation.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSError.h"
#include "Foundation/NSException.h"
#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"
#import "GSDispatch.h"
#import "GSURLPrivate.h"
#import "GSPThread.h"
#include <assert.h>

@interface _GSMutableInsensitiveDictionary : NSMutableDictionary
@end

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

  if (nil == payload || [payload length] == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Websocket message payload must not be empty"];
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
  [task->_receiveBuffer setLength: 0];
  task->_receiveState = GSURLSessionWebSocketReceiveStateIdle;
  task->_receiveFrameOffset = 0;
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
  if (nil == data)
    {
      return NO;
    }

  if ([data length] != length)
    {
      return NO;
    }

  if (0 == length)
    {
      return YES;
    }

  return (0 == memcmp(bytes, [data bytes], length));
}

static NSUInteger
GSURLSessionWebSocketPriorityInsertionIndexLocked(NSURLSessionWebSocketTask *task)
{
  if (NULL != task->_messageSendState.entry)
    {
      return 1;
    }

  return 0;
}

static void
GSURLSessionWebSocketInsertPrioritySendEntryLocked(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketSendQueueEntry *entry)
{
  NSUInteger index;

  index = GSURLSessionWebSocketPriorityInsertionIndexLocked(task);
  [task->_sendQueue insertObject: [NSValue valueWithPointer: entry] atIndex: index];
}

static BOOL
GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketSendQueueEntryKind kind)
{
  NSValue *entryValue;

  if (NULL != task->_messageSendState.entry
      && task->_messageSendState.kind == kind)
    {
      return YES;
    }

  for (entryValue in task->_sendQueue)
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

  if (task->_lifecycleState != GSURLSessionWebSocketLifecycleStateOpen
      || nil != task->_currentPingPayload
      || YES == GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
        task,
        GSURLSessionWebSocketSendQueueEntryKindPing))
    {
      return;
    }

  if ([task->_pendingPingHandlers count] == 0)
    {
      return;
    }

  payload = GSURLSessionWebSocketPingPayload(task->_nextPingIdentifier++);
  entry = GSURLSessionWebSocketControlSendQueueEntryCreate(
    GSURLSessionWebSocketSendQueueEntryKindPing,
    payload);
  GSURLSessionWebSocketInsertPrioritySendEntryLocked(task, entry);
}

static NSArray *
GSURLSessionWebSocketTakeQueuedSendEntriesFromIndexLocked(
  NSURLSessionWebSocketTask *task,
  NSUInteger firstIndex)
{
  NSArray *sendEntries;
  NSRange range;

  if ([task->_sendQueue count] <= firstIndex)
    {
      return [[NSArray alloc] init];
    }

  range = NSMakeRange(firstIndex, [task->_sendQueue count] - firstIndex);
  sendEntries = [[task->_sendQueue subarrayWithRange: range] copy];
  [task->_sendQueue removeObjectsInRange: range];
  return sendEntries;
}

static NSArray *
GSURLSessionWebSocketTakePendingPingHandlersLocked(
  NSURLSessionWebSocketTask *task,
  NSUInteger keepCount)
{
  NSArray *handlers;
  NSRange range;

  if ([task->_pendingPingHandlers count] <= keepCount)
    {
      return [[NSArray alloc] init];
    }

  range = NSMakeRange(keepCount, [task->_pendingPingHandlers count] - keepCount);
  handlers = [[task->_pendingPingHandlers subarrayWithRange: range] copy];
  [task->_pendingPingHandlers removeObjectsInRange: range];
  return handlers;
}

static GSURLSessionWebSocketSendQueueEntry *
GSURLSessionWebSocketPopNextSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketSendQueueEntry *entry;

  if (NULL != task->_messageSendState.entry)
    {
      return (GSURLSessionWebSocketSendQueueEntry *)task->_messageSendState.entry;
    }

  if ([task->_sendQueue count] == 0)
    {
      return NULL;
    }

  entry = [[task->_sendQueue objectAtIndex: 0] pointerValue];
  [task->_sendQueue removeObjectAtIndex: 0];
  task->_messageSendState.entry = entry;
  task->_messageSendState.kind = entry->kind;
  task->_messageSendState.dataType = entry->dataType;
  task->_messageSendState.payloadOffset = 0;
  task->_messageSendState.frameStarted = NO;
  return entry;
}

static void
GSURLSessionWebSocketClearActiveSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  task->_messageSendState.entry = NULL;
  task->_messageSendState.kind = GSURLSessionWebSocketSendQueueEntryKindData;
  task->_messageSendState.dataType = NSURLSessionWebSocketMessageTypeData;
  task->_messageSendState.payloadOffset = 0;
  task->_messageSendState.frameStarted = NO;
}

static GSURLSessionWebSocketReceiveHandler
GSURLSessionWebSocketPopReceiveHandlerLocked(NSURLSessionWebSocketTask *task)
{
  GSURLSessionWebSocketReceiveHandler handler;

  if ([task->_recvQueue count] == 0)
    {
      return nil;
    }

  handler = RETAIN((GSURLSessionWebSocketReceiveHandler)
    [task->_recvQueue objectAtIndex: 0]);
  [task->_recvQueue removeObjectAtIndex: 0];
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
      if (NULL != task->_messageSendState.entry)
        {
          [allSendEntries addObject:
            [NSValue valueWithPointer: task->_messageSendState.entry]];
        }
      [allSendEntries addObjectsFromArray: task->_sendQueue];
      *sendEntries = [allSendEntries copy];
      [allSendEntries release];
    }

  if (receiveHandlers != NULL)
    {
      *receiveHandlers = [task->_recvQueue copy];
    }

  if (pingHandlers != NULL)
    {
      *pingHandlers = [task->_pendingPingHandlers copy];
    }

  [task->_sendQueue removeAllObjects];
  [task->_recvQueue removeAllObjects];
  [task->_pendingPingHandlers removeAllObjects];
  [task->_pendingReceivedMessages removeAllObjects];
  DESTROY(task->_currentPingPayload);
  GSURLSessionWebSocketClearActiveSendEntryLocked(task);
  task->_sendFrameStartRetryPending = NO;
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

  GS_MUTEX_LOCK(task->_mutex);
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketResetReceiveStateLocked(task);
  GS_MUTEX_UNLOCK(task->_mutex);

  GSURLSessionWebSocketCompleteReceive(task, handler, nil, error);
  return 0;
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

  GS_MUTEX_LOCK(task->_mutex);
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketDrainOutstandingWorkLocked(task,
                                                  &sendEntries,
                                                  &receiveHandlers,
                                                  &pingHandlers);
  GS_MUTEX_UNLOCK(task->_mutex);

  GSURLSessionWebSocketDestroySendEntries(sendEntries, task, error);
  GSURLSessionWebSocketCompleteReceiveHandlers(receiveHandlers, task, error);
  GSURLSessionWebSocketCompletePingHandlers(task, pingHandlers, error);
  [sendEntries release];
  [receiveHandlers release];
  [pingHandlers release];
  return CURL_READFUNC_ABORT;
}

static size_t
ws_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  GSURLSessionWebSocketReceiveHandler handler;
  const struct curl_ws_frame *meta;
  NSURLSessionWebSocketMessage *message;
  GSURLSessionWebSocketReceiveState messageState;
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
      GS_MUTEX_LOCK(task->_mutex);
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorCannotParseResponse,
        @"curl_ws_meta returned NULL while receiving WebSocket data");
    }

  if ((meta->flags & CURLWS_PONG) != 0)
    {
      GSURLSessionWebSocketPingHandler pingHandler;
      BOOL shouldQueueNextPing;

      pingHandler = nil;
      shouldQueueNextPing = NO;

      GS_MUTEX_LOCK(task->_mutex);
      if (nil != task->_currentPingPayload
          && YES == GSURLSessionWebSocketFramePayloadMatchesData(
            ptr,
            bytesInCallback,
            task->_currentPingPayload))
        {
          if ([task->_pendingPingHandlers count] > 0)
            {
              pingHandler = RETAIN((GSURLSessionWebSocketPingHandler)
                [task->_pendingPingHandlers objectAtIndex: 0]);
              [task->_pendingPingHandlers removeObjectAtIndex: 0];
            }

          DESTROY(task->_currentPingPayload);
          GSURLSessionWebSocketQueueNextPingLocked(task);
          shouldQueueNextPing = GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
            task,
            GSURLSessionWebSocketSendQueueEntryKindPing);
        }
      GS_MUTEX_UNLOCK(task->_mutex);

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
      NSArray *cancelledPingHandlers;
      NSError *cancelError;
      NSData *closeReason;
      NSData *closePayload;
      GSURLSessionWebSocketSendQueueEntry *closeEntry;
      NSUInteger preservedSendCount;
      NSUInteger preservedPingCount;
      NSUInteger payloadLength;
      NSURLSessionWebSocketCloseCode closeCode;
      BOOL shouldSendCloseReply;

      cancelledSendEntries = nil;
      cancelledPingHandlers = nil;
      cancelError = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket closing handshake canceled queued work");
      closeReason = nil;
      closePayload = nil;
      closeEntry = NULL;
      closeCode = NSURLSessionWebSocketCloseCodeInvalid;
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

      GS_MUTEX_LOCK(task->_mutex);
      task->_closeCode = closeCode;
      ASSIGNCOPY(task->_closeReason, closeReason);

      if (task->_lifecycleState == GSURLSessionWebSocketLifecycleStateCloseSent)
        {
          task->_lifecycleState = GSURLSessionWebSocketLifecycleStateClosed;
          DESTROY(task->_currentPingPayload);
          cancelledPingHandlers = [task->_pendingPingHandlers copy];
          [task->_pendingPingHandlers removeAllObjects];
          [task _setShouldStopTransfer: YES];
        }
      else
        {
          if (task->_lifecycleState == GSURLSessionWebSocketLifecycleStateOpen
              || task->_lifecycleState == GSURLSessionWebSocketLifecycleStateCloseRequested)
            {
              task->_lifecycleState = GSURLSessionWebSocketLifecycleStatePeerCloseReceived;
            }

          if (NO == GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
            task,
            GSURLSessionWebSocketSendQueueEntryKindClose))
            {
              if (payloadLength > 0)
                {
                  closePayload = [NSData dataWithBytes: ptr length: payloadLength];
                }
              else
                {
                  closePayload = [NSData data];
                }
              closeEntry = GSURLSessionWebSocketControlSendQueueEntryCreate(
                GSURLSessionWebSocketSendQueueEntryKindClose,
                closePayload);
              preservedSendCount = GSURLSessionWebSocketPriorityInsertionIndexLocked(task);
              cancelledSendEntries = GSURLSessionWebSocketTakeQueuedSendEntriesFromIndexLocked(
                task,
                preservedSendCount);
              [task->_sendQueue insertObject: [NSValue valueWithPointer: closeEntry]
                                     atIndex: preservedSendCount];
              shouldSendCloseReply = YES;
            }
          else
            {
              preservedSendCount = GSURLSessionWebSocketPriorityInsertionIndexLocked(task);
              cancelledSendEntries = GSURLSessionWebSocketTakeQueuedSendEntriesFromIndexLocked(
                task,
                preservedSendCount);
            }
          preservedPingCount = (nil != task->_currentPingPayload
            || GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
              task,
              GSURLSessionWebSocketSendQueueEntryKindPing)) ? 1 : 0;
          cancelledPingHandlers = GSURLSessionWebSocketTakePendingPingHandlersLocked(
            task,
            preservedPingCount);
        }
      GS_MUTEX_UNLOCK(task->_mutex);

      if (nil != cancelledSendEntries)
        {
          GSURLSessionWebSocketDestroySendEntries(cancelledSendEntries,
                                                  task,
                                                  cancelError);
          [cancelledSendEntries release];
        }

      if (nil != cancelledPingHandlers)
        {
          GSURLSessionWebSocketCompletePingHandlers(task,
                                                    cancelledPingHandlers,
                                                    cancelError);
          [cancelledPingHandlers release];
        }

      if (YES == shouldSendCloseReply)
        {
          curl_easy_pause([task _easyHandle], CURLPAUSE_SEND_CONT);
        }

      return bytesInCallback;
    }

  if ((meta->flags & CURLWS_PING) != 0)
    {
      return bytesInCallback;
    }

  /* First, check if there is a receive handler in the queue */
  GS_MUTEX_LOCK(task->_mutex);
  if ([task->_recvQueue count] == 0)
    {
      GS_MUTEX_UNLOCK(task->_mutex);
      return CURL_WRITEFUNC_PAUSE;
    }
  GS_MUTEX_UNLOCK(task->_mutex);

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
      GS_MUTEX_LOCK(task->_mutex);
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"Unsupported websocket frame flags 0x%x", meta->flags]);
    }

  GS_MUTEX_LOCK(task->_mutex);
  handler = nil;
  buffer = task->_receiveBuffer;
  existingLength = [buffer length];
  messageContinuesInNextFrame = ((meta->flags & CURLWS_CONT) != 0);

  if (task->_receiveState == GSURLSessionWebSocketReceiveStateIdle
      && task->_receiveFrameOffset == 0)
    {
      task->_receiveState = messageState;
    }
  else if (task->_receiveState != messageState)
    {
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket message changed frame type from %lu to %lu",
                    (unsigned long)task->_receiveState,
                    (unsigned long)messageState]);
    }

  if (task->_receiveFrameOffset > 0
      && (NSUInteger)meta->offset != task->_receiveFrameOffset)
    {
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket frame offset mismatch: expected %lu but "
                    @"received %lld",
                    (unsigned long)task->_receiveFrameOffset,
                    (long long)meta->offset]);
    }

  bytesInChunk = meta->len;
  if (bytesInChunk != bytesInCallback)
    {
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorCannotParseResponse,
        [NSString stringWithFormat:
                    @"WebSocket callback length mismatch: received %lu bytes "
                    @"but curl metadata announced %lu",
                    (unsigned long)bytesInCallback,
                    (unsigned long)bytesInChunk]);
    }
  requiredLength = existingLength + bytesInChunk + (NSUInteger)meta->bytesleft;

  /* Weird parameters need to be handled during task creation / assignment */
  NSCAssert(task->_maximumMessageSize > 0,
            @"WebSocket task maximumMessageSize must be positive");

  if (requiredLength > (NSUInteger)task->_maximumMessageSize)
    {
      handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      return GSURLSessionWebSocketFailReceive(
        task,
        handler,
        NSURLErrorDataLengthExceedsMaximum,
        [NSString stringWithFormat:
                    @"WebSocket message length %lu exceeds maximumMessageSize "
                    @"%ld",
                    (unsigned long)requiredLength,
                    (long)task->_maximumMessageSize]);
    }

  if ([buffer length] < requiredLength)
    {
      [buffer setCapacity: requiredLength];
    }

  [buffer appendBytes: ptr length: bytesInChunk];
  task->_receiveFrameOffset += bytesInChunk;

  if (meta->bytesleft > 0)
    {
      GS_MUTEX_UNLOCK(task->_mutex);
      return bytesInChunk;
    }

  task->_receiveFrameOffset = 0;
  if (YES == messageContinuesInNextFrame)
    {
      GS_MUTEX_UNLOCK(task->_mutex);
      return bytesInChunk;
    }

  /* The full message is complete once the last chunk of the last frame arrives. */
  message = nil;
  if (task->_receiveState == GSURLSessionWebSocketReceiveStateText)
    {
      string = AUTORELEASE([[NSString alloc] initWithData: buffer
                                                 encoding: NSUTF8StringEncoding]);
      if (nil == string)
        {
          handler = GSURLSessionWebSocketPopReceiveHandlerLocked(task);
          GS_MUTEX_UNLOCK(task->_mutex);

          return GSURLSessionWebSocketFailReceive(
            task,
            handler,
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
  GS_MUTEX_UNLOCK(task->_mutex);

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

  GS_MUTEX_LOCK(task->_mutex);

  entry = GSURLSessionWebSocketPopNextSendEntryLocked(task);
  if (NULL == entry)
    {
      GS_MUTEX_UNLOCK(task->_mutex);
      return CURL_READFUNC_PAUSE;
    }
  payload = entry->payload;
  if (nil == payload)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(task->_mutex);
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket send queue entry "
                                                  @"is missing payload"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, error);
    }

  payloadLength = [payload length];

  if (task->_messageSendState.payloadOffset > payloadLength)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(task->_mutex);
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket send queue entry "
                                                  @"payload offset exceeds "
                                                  @"payload length"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, error);
    }

  if (task->_messageSendState.payloadOffset == payloadLength)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(task->_mutex);
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket send queue entry "
                                                  @"should have been popped "
                                                  @"immediately after the "
                                                  @"last payload bytes were "
                                                  @"sent"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, error);
    }

  if (NO == task->_messageSendState.frameStarted)
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
                    GS_MUTEX_UNLOCK(task->_mutex);
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
          task->_sendFrameStartRetryPending = YES;
          GS_MUTEX_UNLOCK(task->_mutex);
          return CURL_READFUNC_PAUSE;
        }
      NSLog(@"ws_read_callback start_frame_result=%d", (int)result);
      if (result != CURLE_OK)
        {
          NSError *error;

          GS_MUTEX_UNLOCK(task->_mutex);
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

      task->_messageSendState.frameStarted = YES;
    }

  bytesToWrite = MIN(bytesAvailable,
                     payloadLength - task->_messageSendState.payloadOffset);
  NSLog(@"ws_read_callback write_chunk: payloadOffset=%lu bytesToWrite=%lu "
        @"payloadLength=%lu bytesAvailable=%lu",
        (unsigned long)task->_messageSendState.payloadOffset,
        (unsigned long)bytesToWrite,
        (unsigned long)payloadLength,
        (unsigned long)bytesAvailable);
  memcpy(buffer,
         ((const char *)[payload bytes]) + task->_messageSendState.payloadOffset,
         bytesToWrite);

  task->_messageSendState.payloadOffset += bytesToWrite;

  if (task->_messageSendState.payloadOffset == payloadLength)
    {
      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindPing)
        {
          ASSIGNCOPY(task->_currentPingPayload, payload);
        }
      else if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindClose)
        {
          if (task->_lifecycleState == GSURLSessionWebSocketLifecycleStateCloseRequested)
            {
              task->_lifecycleState = GSURLSessionWebSocketLifecycleStateCloseSent;
            }
          else if (task->_lifecycleState
            == GSURLSessionWebSocketLifecycleStatePeerCloseReceived)
            {
              task->_lifecycleState = GSURLSessionWebSocketLifecycleStateClosed;
              [task _setShouldStopTransfer: YES];
            }
        }

      GSURLSessionWebSocketClearActiveSendEntryLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);

      if (entry->kind == GSURLSessionWebSocketSendQueueEntryKindData)
        {
          GSURLSessionWebSocketCompleteSend(task, entry->completionHandler, nil);
        }
      GSURLSessionWebSocketSendQueueEntryDestroy(entry);
      return bytesToWrite;
    }

  GS_MUTEX_UNLOCK(task->_mutex);
  return bytesToWrite;
}

@implementation  NSURLSessionWebSocketTask

- (instancetype) initWebSocketTask: (NSURLSession *)session
                           request: (NSURLRequest *)request
                    taskIdentifier: (NSUInteger)identifier
{
  NSURL *url;
  NSURLSessionConfiguration *configuration;
  NSMutableDictionary *requestHeaders = nil;

  self = [super init];
  if (self != nil)
    {
      ENTER_POOL
      [self _initTaskStateWithSession: session
                              request: request
                       taskIdentifier: identifier];

      url = [request URL];
      configuration = [session configuration];

      [self _initializeEasyhandleForRequest: request];

      /* Set the read / write / header callbacks */
      [self _configureTransferCallbacks];
      [self _configureProtocolOptionsForRequest: request
                                  configuration: configuration];

      requestHeaders = [self _mergedRequestHeadersForRequest: request
                                               configuration: configuration
                                                         URL: url];
      [self _installRequestHeaders: requestHeaders];

      _sendQueue = [[NSMutableArray alloc] init];
      _recvQueue = [[NSMutableArray alloc] init];
      _pendingPingHandlers = [[NSMutableArray alloc] init];
      _pendingReceivedMessages = [[NSMutableArray alloc] init];
      _receiveBuffer = [[NSMutableData alloc] init];
      _maximumMessageSize = NSIntegerMax;
      GSURLSessionWebSocketClearActiveSendEntryLocked(self);
      _lifecycleState = GSURLSessionWebSocketLifecycleStateOpen;
      _receiveState = GSURLSessionWebSocketReceiveStateIdle;
      _nextPingIdentifier = 1;
      _receiveFrameOffset = 0;
      _sendFrameStartRetryPending = NO;
      GS_MUTEX_INIT(_mutex);
      LEAVE_POOL
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
                   (NSInteger)[request timeoutInterval]);
}

- (void) _configureTransferCallbacks
{
  /* The task is associated with the easy handle for completion/error lookup. */
  curl_easy_setopt([self _easyHandle], CURLOPT_ERRORBUFFER, [self _errorBuffer]);
  curl_easy_setopt([self _easyHandle], CURLOPT_PRIVATE, self);

  /* TODO(WS): Parse incoming websocket frame chunks in ws_write_callback. */
  curl_easy_setopt([self _easyHandle], CURLOPT_WRITEFUNCTION, ws_write_callback);
  curl_easy_setopt([self _easyHandle], CURLOPT_WRITEDATA, self);

  /* TODO(WS): Drain queued outbound websocket messages in ws_read_callback. */
  curl_easy_setopt([self _easyHandle], CURLOPT_READFUNCTION, ws_read_callback);
  curl_easy_setopt([self _easyHandle], CURLOPT_READDATA, self);

  curl_easy_setopt([self _easyHandle], CURLOPT_UPLOAD, 1L);
  curl_easy_setopt([self _easyHandle], CURLOPT_POSTFIELDSIZE, -1);
}

- (void) _configureProtocolOptionsForRequest: (NSURLRequest *)request
                               configuration: (NSURLSessionConfiguration *)configuration
{
  NSData *certificateBlob;

  /* Set overall timeout */
  curl_easy_setopt([self _easyHandle],
                   CURLOPT_TIMEOUT,
                   [configuration timeoutIntervalForResource]);

  /* Set to HTTP/3 if requested */
  if ([request assumesHTTP3Capable])
    {
#if CURL_AT_LEAST_VERSION(7, 66, 0)
      curl_easy_setopt([self _easyHandle],
                       CURLOPT_HTTP_VERSION,
                       CURL_HTTP_VERSION_3);
#endif
    }

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

- (NSMutableDictionary *) _mergedRequestHeadersForRequest: (NSURLRequest *)request
                                       configuration: (NSURLSessionConfiguration *)configuration
                                                 URL: (NSURL *)url
{
  NSDictionary *immConfigHeaders;
  NSHTTPCookieStorage *storage;
  _GSMutableInsensitiveDictionary *requestHeaders;
  _GSMutableInsensitiveDictionary *configHeaders = nil;

  requestHeaders = AUTORELEASE([[request _insensitiveHeaders] mutableCopy]);

  immConfigHeaders = [configuration HTTPAdditionalHeaders];
  if (nil != immConfigHeaders)
    {
      configHeaders = AUTORELEASE([[_GSMutableInsensitiveDictionary alloc]
                       initWithDictionary: immConfigHeaders
                                copyItems: NO]);
      [configHeaders addEntriesFromDictionary: (NSDictionary *)requestHeaders];
      requestHeaders = configHeaders;
    }

  storage = [configuration HTTPCookieStorage];
  if (nil != storage && [configuration HTTPShouldSetCookies])
    {
      NSDictionary *cookieHeaders;
      NSArray<NSHTTPCookie *> *cookies;

      if (nil == requestHeaders)
        {
          requestHeaders = [_GSMutableInsensitiveDictionary dictionary];
        }

      cookies = [storage cookiesForURL: url];
      if ([cookies count] > 0)
        {
          cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
          [requestHeaders addEntriesFromDictionary: cookieHeaders];
        }
    }

  return requestHeaders;
}

- (void) _installRequestHeaders: (NSDictionary *)requestHeaders
{
  for (id key in requestHeaders)
    {
      NSString *headerLine;
      id object = [requestHeaders objectForKey: key];

      headerLine = [NSString stringWithFormat: @"%@: %@", key, object];
      [self _setHeaderList:
        curl_slist_append([self _headerList], [headerLine UTF8String])];
    }

  curl_easy_setopt([self _easyHandle], CURLOPT_HTTPHEADER, [self _headerList]);
}

- (NSInteger) maximumMessageSize
{
  return _maximumMessageSize;
}

- (void) setMaximumMessageSize: (NSInteger)maximumMessageSize
{
  if (maximumMessageSize <= 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"WebSocket maximumMessageSize must be positive"];
    }
  _maximumMessageSize = maximumMessageSize;
}

- (void) _resumeSendIfWaitingForReadableSocket
{
  BOOL shouldResume;

  GS_MUTEX_LOCK(_mutex);
  shouldResume = _sendFrameStartRetryPending;
  if (YES == shouldResume)
    {
      _sendFrameStartRetryPending = NO;
    }
  GS_MUTEX_UNLOCK(_mutex);

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

  error = [self _errorForCURLcode: code];

  GS_MUTEX_LOCK(_mutex);
  hasOutstandingWork = ([_sendQueue count] > 0
    || [_recvQueue count] > 0
    || [_pendingPingHandlers count] > 0
    || nil != _currentPingPayload
    || NULL != _messageSendState.entry);
  if (error == nil && YES == hasOutstandingWork)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task finished before queued work completed");
      [self _setStoredTaskError: error];
    }
  if (error == nil)
    {
      _lifecycleState = GSURLSessionWebSocketLifecycleStateClosed;
    }
  else
    {
      _lifecycleState = GSURLSessionWebSocketLifecycleStateFailed;
    }
  GSURLSessionWebSocketDrainOutstandingWorkLocked(self,
                                                  &sendEntries,
                                                  &receiveHandlers,
                                                  &pingHandlers);
  GS_MUTEX_UNLOCK(_mutex);

  GSURLSessionWebSocketDestroySendEntries(sendEntries, self, error);
  GSURLSessionWebSocketCompleteReceiveHandlers(receiveHandlers, self, error);
  GSURLSessionWebSocketCompletePingHandlers(self, pingHandlers, error);
  [sendEntries release];
  [receiveHandlers release];
  [pingHandlers release];

  [super _transferFinishedWithCode: code];
}

- (NSURLSessionWebSocketCloseCode) closeCode
{
  return _closeCode;
}

- (NSData *) closeReason
{
  return _closeReason;
}

- (void) sendMessage:(NSURLSessionWebSocketMessage *) message
   completionHandler:(void (^)(NSError *error)) completionHandler
{
  GSURLSessionWebSocketSendQueueEntry *entry;
  NSError *error;

  entry = GSURLSessionWebSocketDataSendQueueEntryCreate(message, completionHandler);
  error = nil;

  GS_MUTEX_LOCK(_mutex);
  if (_lifecycleState != GSURLSessionWebSocketLifecycleStateOpen)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  else
    {
      [_sendQueue addObject: [NSValue valueWithPointer: entry]];
    }
  GS_MUTEX_UNLOCK(_mutex);

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
  NSURLSessionWebSocketMessage *pendingMessage;

  if (completionHandler == NULL)
    {
      return;
    }

  handler = (id)_Block_copy(completionHandler);
  pendingMessage = nil;

  GS_MUTEX_LOCK(_mutex);
  if ([_pendingReceivedMessages count] > 0)
    {
      pendingMessage = RETAIN([_pendingReceivedMessages objectAtIndex: 0]);
      [_pendingReceivedMessages removeObjectAtIndex: 0];
    }
  else
    {
      [_recvQueue addObject: handler];
    }
  GS_MUTEX_UNLOCK(_mutex);

  if (nil != pendingMessage)
    {
      GSURLSessionWebSocketCompleteReceive(self, handler, pendingMessage, nil);
      [pendingMessage release];
      [handler release];
      return;
    }

  if ([self state] == NSURLSessionTaskStateRunning)
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

  GS_MUTEX_LOCK(_mutex);
  if (_lifecycleState != GSURLSessionWebSocketLifecycleStateOpen)
    {
      error = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
        @"WebSocket task is closing");
    }
  else
    {
      [_pendingPingHandlers addObject: handler];
      GSURLSessionWebSocketQueueNextPingLocked(self);
      shouldResumeSend = GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
        self,
        GSURLSessionWebSocketSendQueueEntryKindPing);
    }
  GS_MUTEX_UNLOCK(_mutex);

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
  NSArray *cancelledPingHandlers;
  NSError *cancelError;
  GSURLSessionWebSocketSendQueueEntry *closeEntry;
  NSUInteger preservedSendCount;
  NSUInteger preservedPingCount;
  BOOL shouldResumeSend;

  cancelledSendEntries = nil;
  cancelledPingHandlers = nil;
  cancelError = GSURLSessionWebSocketError(NSURLErrorNetworkConnectionLost,
    @"WebSocket task was canceled before queued work completed");
  closeEntry = NULL;
  shouldResumeSend = NO;

  _closeCode = closeCode;
  ASSIGNCOPY(_closeReason, reason);
  GS_MUTEX_LOCK(_mutex);
  if (_lifecycleState == GSURLSessionWebSocketLifecycleStateOpen)
    {
      _lifecycleState = GSURLSessionWebSocketLifecycleStateCloseRequested;
      closeEntry = GSURLSessionWebSocketControlSendQueueEntryCreate(
        GSURLSessionWebSocketSendQueueEntryKindClose,
        GSURLSessionWebSocketClosePayload(closeCode, reason));
      preservedSendCount = GSURLSessionWebSocketPriorityInsertionIndexLocked(self);
      cancelledSendEntries = GSURLSessionWebSocketTakeQueuedSendEntriesFromIndexLocked(
        self,
        preservedSendCount);
      [_sendQueue insertObject: [NSValue valueWithPointer: closeEntry]
                       atIndex: preservedSendCount];
      preservedPingCount = (nil != _currentPingPayload
        || GSURLSessionWebSocketHasOutstandingQueuedKindLocked(
          self,
          GSURLSessionWebSocketSendQueueEntryKindPing)) ? 1 : 0;
      cancelledPingHandlers = GSURLSessionWebSocketTakePendingPingHandlersLocked(
        self,
        preservedPingCount);
      shouldResumeSend = YES;
    }
  GS_MUTEX_UNLOCK(_mutex);

  if (nil != cancelledSendEntries)
    {
      GSURLSessionWebSocketDestroySendEntries(cancelledSendEntries,
                                              self,
                                              cancelError);
      [cancelledSendEntries release];
    }

  if (nil != cancelledPingHandlers)
    {
      GSURLSessionWebSocketCompletePingHandlers(self,
                                                cancelledPingHandlers,
                                                cancelError);
      [cancelledPingHandlers release];
    }

  if (YES == shouldResumeSend && [self state] == NSURLSessionTaskStateRunning)
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

  GS_MUTEX_DESTROY(_mutex);

  for (entryValue in _sendQueue)
    {
      GSURLSessionWebSocketSendQueueEntryDestroy([entryValue pointerValue]);
    }
  if (NULL != _messageSendState.entry)
    {
      GSURLSessionWebSocketSendQueueEntryDestroy(
        (GSURLSessionWebSocketSendQueueEntry *)_messageSendState.entry);
    }

  RELEASE(_recvQueue);
  RELEASE(_sendQueue);
  RELEASE(_pendingPingHandlers);
  RELEASE(_pendingReceivedMessages);
  RELEASE(_currentPingPayload);
  RELEASE(_receiveBuffer);
  RELEASE(_closeReason);
  [super dealloc];
}

@end
#endif
