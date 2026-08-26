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

static id
GSURLSessionWebSocketPopReceiveHandlerLocked(NSURLSessionWebSocketTask *task)
{
  id handler;

  if ([task->_recvQueue count] == 0)
    {
      return nil;
    }

  handler = RETAIN([task->_recvQueue objectAtIndex: 0]);
  [task->_recvQueue removeObjectAtIndex: 0];
  return AUTORELEASE(handler);
}

static void
GSURLSessionWebSocketCompleteReceive(
  NSURLSessionWebSocketTask *task,
  void (^completionHandler)(NSURLSessionWebSocketMessage *message, NSError *error),
  NSURLSessionWebSocketMessage *message,
  NSError *error)
{
  if (completionHandler == NULL)
    {
      return;
    }

  [[[task _session] delegateQueue] addOperationWithBlock:^{
    completionHandler(message, error);
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

static size_t
GSURLSessionWebSocketFailReceive(
  NSURLSessionWebSocketTask *task,
  void (^completionHandler)(NSURLSessionWebSocketMessage *message, NSError *error),
  NSInteger code,
  NSString *description)
{
  NSError *error;

  error = GSURLSessionWebSocketError(code, description);
  GS_MUTEX_LOCK(task->_mutex);
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketResetReceiveStateLocked(task);
  GS_MUTEX_UNLOCK(task->_mutex);

  GSURLSessionWebSocketCompleteReceive(task, completionHandler, nil, error);
  return 0;
}

static size_t
GSURLSessionWebSocketFailSend(
  NSURLSessionWebSocketTask *task,
  GSURLSessionWebSocketSendQueueEntry *entry,
  NSError *error)
{
  GS_MUTEX_LOCK(task->_mutex);
  [task _setStoredTaskError: error];
  GSURLSessionWebSocketClearActiveSendEntryLocked(task);
  GS_MUTEX_UNLOCK(task->_mutex);

  if (NULL != entry)
    {
      GSURLSessionWebSocketCompleteSend(task, entry->completionHandler, error);
      GSURLSessionWebSocketSendQueueEntryDestroy(entry);
    }

  return CURL_READFUNC_ABORT;
}

static size_t
ws_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionWebSocketTask *task;
  id handler;
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

  if ((meta->flags & (CURLWS_PING | CURLWS_PONG | CURLWS_CLOSE)) != 0)
    {
      /* TODO(WS): Handle websocket control frames separately. */
      return bytesInCallback;
    }

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
                    @"WebSocket frame offset mismatch: expected %lu but received %lld",
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
                    @"WebSocket callback length mismatch: received %lu bytes but curl "
                    @"metadata announced %lu",
                    (unsigned long)bytesInCallback,
                    (unsigned long)bytesInChunk]);
    }
  requiredLength = existingLength + bytesInChunk + (NSUInteger)meta->bytesleft;

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
                    @"WebSocket message length %lu exceeds maximumMessageSize %ld",
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
  if (handler == nil)
    {
      [task->_pendingReceivedMessages addObject: message];
    }
  GSURLSessionWebSocketResetReceiveStateLocked(task);
  GS_MUTEX_UNLOCK(task->_mutex);

  if (handler != nil)
    {
      GSURLSessionWebSocketCompleteReceive(task, handler, message, nil);
    }

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
                                          reason: @"Websocket send queue entry is missing payload"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, entry, error);
    }

  payloadLength = [payload length];
  if (task->_messageSendState.payloadOffset > payloadLength)
    {
      NSError *error;
      NSException *exception;

      GS_MUTEX_UNLOCK(task->_mutex);
      exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                          reason: @"Websocket payload offset exceeds payload length"
                                        userInfo: nil];
      error = GSURLSessionWebSocketErrorFromException(exception);
      return GSURLSessionWebSocketFailSend(task, entry, error);
    }

  if (NO == task->_messageSendState.frameStarted)
    {
      if (entry->kind != GSURLSessionWebSocketSendQueueEntryKindData)
        {
          GS_MUTEX_UNLOCK(task->_mutex);
          return CURL_READFUNC_PAUSE;
        }

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

              GS_MUTEX_UNLOCK(task->_mutex);
              exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                                  reason: [NSString stringWithFormat:
                                                      @"Queued websocket send has unsupported type %ld",
                                                      (long)entry->dataType]
                                                userInfo: nil];
              error = GSURLSessionWebSocketErrorFromException(exception);
              return GSURLSessionWebSocketFailSend(task, entry, error);
            }
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
          return GSURLSessionWebSocketFailSend(task, entry, error);
        }

      task->_messageSendState.frameStarted = YES;
    }

  bytesToWrite = MIN(bytesAvailable,
                     payloadLength - task->_messageSendState.payloadOffset);
  memcpy(buffer,
         ((const char *)[payload bytes]) + task->_messageSendState.payloadOffset,
         bytesToWrite);

  task->_messageSendState.payloadOffset += bytesToWrite;
  if (task->_messageSendState.payloadOffset == payloadLength)
    {
      GSURLSessionWebSocketClearActiveSendEntryLocked(task);
      GS_MUTEX_UNLOCK(task->_mutex);
      GSURLSessionWebSocketCompleteSend(task, entry->completionHandler, nil);
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
  /* TODO(WS): Propagate websocket-specific completion and drain queued work. */
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

  entry = GSURLSessionWebSocketDataSendQueueEntryCreate(message, completionHandler);

  GS_MUTEX_LOCK(_mutex);
  [_sendQueue addObject: [NSValue valueWithPointer: entry]];
  GS_MUTEX_UNLOCK(_mutex);

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
  /* TODO(WS): Queue ping control frames and complete handlers on matching pong. */
  if (pongReceiveHandler == NULL)
    {
      return;
    }
  pongReceiveHandler(nil);
}

- (void) cancelWithCloseCode: (NSURLSessionWebSocketCloseCode)closeCode
                      reason: (NSData *)reason
{
  /* TODO(WS): Send a websocket close control frame before stopping the task. */
  _closeCode = closeCode;
  ASSIGNCOPY(_closeReason, reason);
  [super cancel];
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
