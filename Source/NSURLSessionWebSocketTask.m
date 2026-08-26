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

static void
GSURLSessionWebSocketClearActiveSendEntryLocked(NSURLSessionWebSocketTask *task)
{
  task->_messageSendState.entry = NULL;
  task->_messageSendState.kind = GSURLSessionWebSocketSendQueueEntryKindData;
  task->_messageSendState.dataType = NSURLSessionWebSocketMessageTypeData;
  task->_messageSendState.payloadOffset = 0;
  task->_messageSendState.frameStarted = NO;
}

static size_t
ws_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  (void)ptr;
  (void)userdata;

  /* TODO(WS): Decode websocket frames and dispatch them to queued handlers. */
  return size * nmemb;
}

static size_t
ws_read_callback(char *buffer, size_t size, size_t nitems, void *userdata)
{
  (void)buffer;
  (void)size;
  (void)nitems;
  (void)userdata;

  /* TODO(WS): Serialize queued websocket frames onto the libcurl transport. */
  return CURL_READFUNC_PAUSE;
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
  /* TODO(WS): Resume a paused websocket write once a queued frame can continue. */
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
}

- (void) receiveMessageWithCompletionHandler:(void (^)(NSURLSessionWebSocketMessage *message, NSError *error)) completionHandler
{
  id handler;

  if (completionHandler == NULL)
    {
      return;
    }

  handler = (id)_Block_copy(completionHandler);

  GS_MUTEX_LOCK(_mutex);
  [_recvQueue addObject: handler];
  GS_MUTEX_UNLOCK(_mutex);

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
