/**
 * NSURLSession.m
 *
 * Copyright (C) 2017-2024 Free Software Foundation, Inc.
 *
 * Written by: Hugo Melder <hugo@algoriddim.com>
 * Date: May 2024
 * Author: Hugo Melder <hugo@algoriddim.com>
 *
 * This file is part of GNUStep-base
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * If you are interested in a warranty or support for this source code,
 * contact Scott Christley <scottc@net-community.com> for more information.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSBundle.h"
#import "Foundation/NSData.h"

#import "GNUstepBase/NSDebug+GNUstepBase.h"  /* For NSDebugMLLog */
#import "GNUstepBase/NSObject+GNUstepBase.h" /* For -notImplemented */
#import "GSPThread.h"                        /* For nextSessionIdentifier() */

NSString * GS_NSURLSESSION_DEBUG_KEY = @"NSURLSession";

/* We need a globably unique label for the NSURLSession workQueues.
 */
static NSUInteger
nextSessionIdentifier()
{
  static gs_mutex_t lock = GS_MUTEX_INIT_STATIC;
  static NSUInteger sessionCounter = 0;

  GS_MUTEX_LOCK(lock);
  sessionCounter += 1;
  GS_MUTEX_UNLOCK(lock);

  return sessionCounter;
}

#pragma mark - libcurl callbacks

/* CURLMOPT_TIMERFUNCTION: Callback to receive timer requests from libcurl */
static int
timer_callback(CURLM * multi,      /* multi handle */
               long timeout_ms,   /* timeout in number of ms */
               void * clientp)     /* private callback pointer */
{
  NSURLSession * session = (NSURLSession *)clientp;

  NSDebugLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Timer Callback for Session %@: multi=%p timeout_ms=%ld",
    session,
    multi,
    timeout_ms);

  /*
   * if timeout_ms is -1, just delete the timer
   *
   * For all other values of timeout_ms, this should set or *update* the timer
   * to the new value
   */
  if (timeout_ms == -1)
    [session _suspendTimer];
  else
    [session _setTimer: timeout_ms];
  return 0;
}

/* CURLMOPT_SOCKETFUNCTION: libcurl requests socket monitoring using this
 * callback */
static int
socket_callback(CURL * easy,           /* easy handle */
                curl_socket_t s,       /* socket */
                int what,              /* describes the socket */
                void * clientp,        /* private callback pointer */
                void * socketp)                /* private socket pointer */
{
  NSURLSession * session = clientp;
  const char * whatstr[] = { "none", "IN", "OUT", "INOUT", "REMOVE" };

  NSDebugLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Socket Callback for Session %@: socket=%d easy:%p what=%s",
    session,
    s,
    easy,
    whatstr[what]);

  if (NULL == socketp)
    {
      return [session _addSocket: s easyHandle: easy what: what];
    }
  else if (CURL_POLL_REMOVE == what)
    {
      [session _removeSocket: (struct SourceInfo *)socketp];
      return 0;
    }
  else
    {
      return [session _setSocket: s
                         sources: (struct SourceInfo *)socketp
                            what: what];
    }
} /* socket_callback */

#pragma mark - Work thread trampoline

/* Runs the run loop for an NSURLSession's work thread.  It deliberately
 * holds no reference to the session, so that the session's lifetime is not
 * extended by the running thread; -[NSURLSession dealloc] stops and joins
 * the thread before releasing anything the thread might touch.
 */
@interface GSURLSessionWorkThread : NSObject
{
@public
  NSThread * thread;
  NSPort * port;
  BOOL shouldExit;
}
- (void) run;
- (void) stop;
@end

@implementation GSURLSessionWorkThread
- (void) run
{
  NSAutoreleasePool * pool = [NSAutoreleasePool new];
  NSRunLoop * rl = [NSRunLoop currentRunLoop];

  [rl addPort: port forMode: NSDefaultRunLoopMode];
  while (!shouldExit)
    {
      NSAutoreleasePool * inner = [NSAutoreleasePool new];

      [rl runMode: NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
      [inner release];
    }
  [rl removePort: port forMode: NSDefaultRunLoopMode];
  [pool release];
}

- (void) stop
{
  shouldExit = YES;
}
@end

#pragma mark - NSURLSession Implementation

/* The session acts as its own run loop watcher for the sockets libcurl
 * asks us to monitor. */
@interface NSURLSession () <RunLoopEvents>
@end

@implementation NSURLSession
{
  /* The libcurl multi handle associated with this session.
   * We use the curl_multi_socket_action API as we utilise our
   * own event-handling system integrated with the work thread run loop.
   *
   * Event creation and deletion is driven by the various callbacks
   * registered during initialisation of the multi handle.
   */
  CURLM * _multiHandle;
  /* Drives a dedicated thread running an NSRunLoop.  All libcurl multi
   * handle activity (adding handles, socket events and the timer) happens on
   * that thread, which serialises access in place of a dispatch queue and
   * keeps GNUstep free of a libdispatch dependency.  The helper holds the
   * session unretained so that it does not keep the session alive.
   */
  GSURLSessionWorkThread * _workHelper;

#if	defined(_WIN32)
  /* Maps a registered WSAEVENT back to its socket, since the run loop only
   * hands the event handle back to -receivedEvent:type:extra:forMode:.
   */
  NSMapTable * _socketForEvent;
#endif

  /* This timer is driven by libcurl and used by
   * libcurl's multi API.
   *
   * The handler notifies libcurl using curl_multi_socket_action
   * and checks for completed requests by calling
   * _checkForCompletion.
   *
   * See https://curl.se/libcurl/c/CURLMOPT_TIMERFUNCTION.html
   * and https://curl.se/libcurl/c/curl_multi_socket_action.html
   * respectively.  It is scheduled on the work thread run loop.
   */
  NSTimer * _timer;

  /* Only set when session originates from +[NSURLSession sharedSession] */
  BOOL _isSharedSession;
  BOOL _invalidated;

  /*
   * Number of currently running handles.
   * This number is updated by curl_multi_socket_action
   * in the socket source handlers.
   */
  int _stillRunning;

  /* List of active tasks. Access is synchronised via the work thread.
   */
  NSMutableArray<NSURLSessionTask *> * _tasks;

  /* PEM encoded blob of one or more certificates.
   *
   * See GSCACertificateFilePath in NSUserDefaults.h
   */
  NSData * _certificateBlob;
  /* Path to PEM encoded CA certificate file. */
  NSString * _certificatePath;

  /* The task identifier for the next task
   */
  _Atomic(NSInteger) _taskIdentifier;
  /* Lock for _taskIdentifier and _tasks
   */
  gs_mutex_t _taskLock;
}

static NSURLSession * sharedSession = nil;

+ (NSURLSession *) sharedSession
{
  static gs_mutex_t lock = GS_MUTEX_INIT_STATIC;

  GS_MUTEX_LOCK(lock);
  if (nil == sharedSession)
    {
      NSURLSessionConfiguration * configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];

      sharedSession
        = [[NSURLSession alloc] initWithConfiguration: configuration
                                             delegate: nil
                                        delegateQueue: nil];
      [sharedSession _setSharedSession: YES];
    }
  GS_MUTEX_UNLOCK(lock);

  return sharedSession;
}

+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration
{
  NSURLSession * session;

  session = [[NSURLSession alloc] initWithConfiguration: configuration
                                               delegate: nil
                                          delegateQueue: nil];

  return AUTORELEASE(session);
}

+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration
  delegate: (id<NSURLSessionDelegate>)delegate
  delegateQueue: (NSOperationQueue *)queue
{
  NSURLSession * session;

  session = [[NSURLSession alloc] initWithConfiguration: configuration
                                               delegate: delegate
                                          delegateQueue: queue];

  return AUTORELEASE(session);
}

- (instancetype) initWithConfiguration: (NSURLSessionConfiguration *)
  configuration
  delegate: (id<NSURLSessionDelegate>)delegate
  delegateQueue: (NSOperationQueue *)queue
{
  self = [super init];

  if (self)
    {
      NSString * queueLabel;
      NSString * caPath;
      NSUInteger sessionIdentifier;

      sessionIdentifier = nextSessionIdentifier();
      queueLabel = [[NSString alloc]
                    initWithFormat: @"org.gnustep.NSURLSession.WorkQueue%ld",
                    sessionIdentifier];
      ASSIGN(_delegate, delegate);
      ASSIGNCOPY(_configuration, configuration);

      _tasks = [[NSMutableArray alloc] init];
      GS_MUTEX_INIT(_taskLock);

      _timer = nil;
#if	defined(_WIN32)
      _socketForEvent = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
        NSIntegerMapValueCallBacks, 0);
#endif
      /* A port keeps the work thread run loop from exiting when it has no
       * other input sources. */
      _workHelper = [[GSURLSessionWorkThread alloc] init];
      _workHelper->port = [[NSPort port] retain];
      _workHelper->thread = [[NSThread alloc] initWithTarget: _workHelper
                                                    selector: @selector(run)
                                                      object: nil];
      [_workHelper->thread setName: queueLabel];
      [queueLabel release];
      [_workHelper->thread start];

      /* Use the provided delegateQueue if available */
      if (queue)
        {
          _delegateQueue = queue;
        }
      else
        {
          /* This (serial) NSOperationQueue is only used for dispatching
           * delegate callbacks and is orthogonal to the workQueue.
           */
          _delegateQueue = [[NSOperationQueue alloc] init];
          [_delegateQueue setMaxConcurrentOperationCount: 1];
        }

      /* libcurl Configuration */
      curl_global_init(CURL_GLOBAL_SSL);

      _multiHandle = curl_multi_init();

      // Set up CURL multi callbacks
      curl_multi_setopt(_multiHandle, CURLMOPT_SOCKETFUNCTION, socket_callback);
      curl_multi_setopt(_multiHandle, CURLMOPT_SOCKETDATA, self);
      curl_multi_setopt(_multiHandle, CURLMOPT_TIMERFUNCTION, timer_callback);
      curl_multi_setopt(_multiHandle, CURLMOPT_TIMERDATA, self);

      // Configure Multi Handle
      curl_multi_setopt(
        _multiHandle,
        CURLMOPT_MAX_HOST_CONNECTIONS,
        [_configuration HTTPMaximumConnectionsPerHost]);

      /* Check if GSCACertificateFilePath is set */

      caPath = [[NSUserDefaults standardUserDefaults]
                objectForKey: GSCACertificateFilePath];
      if (caPath)
        {
          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Found a GSCACertificateFilePath entry in UserDefaults");

          _certificateBlob = [[NSData alloc] initWithContentsOfFile: caPath];
          if (!_certificateBlob)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Could not open file at GSCACertificateFilePath=%@",
                caPath);
            }
          else
            {
              ASSIGN(_certificatePath, caPath);
            }
        }
    }

  return self;
} /* initWithConfiguration */

#pragma mark - Private Methods

- (NSData *) _certificateBlob
{
  return _certificateBlob;
}

- (NSString *) _certificatePath
{
  return _certificatePath;
}

- (void) _setSharedSession: (BOOL)flag
{
  _isSharedSession = flag;
}

- (NSInteger) _nextTaskIdentifier
{
  NSInteger identifier;

  GS_MUTEX_LOCK(_taskLock);
  identifier = _taskIdentifier;
  _taskIdentifier += 1;
  GS_MUTEX_UNLOCK(_taskLock);

  return identifier;
}

- (void) _resumeTask: (NSURLSessionTask *)task
{
  [self _performOnWorkThread: ^{
    CURLMcode code;
    CURLM * multiHandle = _multiHandle;

    code = curl_multi_add_handle(multiHandle, [task _easyHandle]);

    NSDebugMLLog(
      GS_NSURLSESSION_DEBUG_KEY,
      @"Added task=%@ easy=%p to multi=%p with return value %d",
      task,
      [task _easyHandle],
      multiHandle,
      code);

    /* Kick the transfer off now rather than waiting for the timer callback
     * (see -_addHandle:). */
    curl_multi_socket_action(multiHandle, CURL_SOCKET_TIMEOUT, 0,
      &_stillRunning);
    [self _checkForCompletion];
  }];
}

- (void) _addHandle: (CURL *)easy
{
  curl_multi_add_handle(_multiHandle, easy);

  /* Kick the added transfer off now rather than waiting for libcurl to fire
   * the timer callback.  Relying on the timer alone races with the run loop,
   * which shows up most on a handle that is re-added after a redirect: the
   * transfer can stall until an unrelated event drives the multi handle.
   * See https://curl.se/libcurl/c/curl_multi_socket_action.html . */
  curl_multi_socket_action(_multiHandle, CURL_SOCKET_TIMEOUT, 0,
    &_stillRunning);
  [self _checkForCompletion];
}
- (void) _removeHandle: (CURL *)easy
{
  curl_multi_remove_handle(_multiHandle, easy);
}

/* Called on the work thread from libcurl's timer_callback.  Schedules a
 * one-shot timer on the work thread run loop; libcurl re-arms it as needed.
 */
- (void) _setTimer: (NSInteger)timeoutMs
{
  [_timer invalidate];
  _timer = [NSTimer scheduledTimerWithTimeInterval: (double)timeoutMs / 1000.0
                                            target: self
                                          selector: @selector(_timerFired:)
                                          userInfo: nil
                                           repeats: NO];
}

- (void) _suspendTimer
{
  [_timer invalidate];
  _timer = nil;
}

- (void) _timerFired: (NSTimer *)timer
{
  /* The run loop releases the fired non-repeating timer. */
  _timer = nil;

  curl_multi_socket_action(
    _multiHandle,
    CURL_SOCKET_TIMEOUT,
    0,
    &_stillRunning);
  [self _checkForCompletion];
}

#pragma mark - Work thread

- (void) _runWorkBlock: (id)block
{
  ((GSURLSessionWorkBlock)block)();
}

- (void) _performOnWorkThread: (GSURLSessionWorkBlock)block
{
  /* Run immediately if we are already on the work thread (e.g. called from
   * a libcurl callback), otherwise schedule on its run loop. */
  if ([NSThread currentThread] == _workHelper->thread)
    {
      block();
    }
  else
    {
      id copy = [block copy];

      [self performSelector: @selector(_runWorkBlock:)
                   onThread: _workHelper->thread
                 withObject: copy
              waitUntilDone: NO];
      [copy release];
    }
}

#pragma mark - Socket monitoring

/* This method is called when receiving CURL_POLL_REMOVE in socket_callback.
 * We remove any run loop watchers and release the SourceInfo structure
 * previously allocated in _addSocket:easyHandle:what:
 */
- (void) _removeSocket: (struct SourceInfo *)sources
{
  NSRunLoop * rl = [NSRunLoop currentRunLoop];

  NSDebugMLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Remove socket with SourceInfo: %p",
    sources);

#if	defined(_WIN32)
  if (WSA_INVALID_EVENT != sources->event)
    {
      [rl removeEvent: (void*)sources->event
                 type: ET_HANDLE
              forMode: NSDefaultRunLoopMode
                  all: YES];
      WSAEventSelect(sources->socket, sources->event, 0);
      NSMapRemove(_socketForEvent, (void*)sources->event);
      WSACloseEvent(sources->event);
      sources->event = WSA_INVALID_EVENT;
    }
#else
  if (sources->readReady)
    {
      [rl removeEvent: (void*)(intptr_t)sources->socket
                 type: ET_RDESC
              forMode: NSDefaultRunLoopMode
                  all: YES];
    }
  if (sources->writeReady)
    {
      [rl removeEvent: (void*)(intptr_t)sources->socket
                 type: ET_WDESC
              forMode: NSDefaultRunLoopMode
                  all: YES];
    }
#endif

  free(sources);
}

/* A socket needs to be configured and the private socket pointer
 * (socketp) in socket_callback is NULL, meaning we first need to
 * allocate our SourceInfo structure.
 */
- (int) _addSocket: (curl_socket_t)socket easyHandle: (CURL *)easy what: (int)
  what
{
  struct SourceInfo * info;

  NSDebugMLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Add Socket: %d easy: %p",
    socket,
    easy);

  /* Allocate a new SourceInfo structure on the heap */
  if (!(info = calloc(1, sizeof(struct SourceInfo))))
    {
      NSDebugMLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"Failed to allocate SourceInfo structure!");
      return -1;
    }
  info->socket = socket;
#if	defined(_WIN32)
  info->event = WSA_INVALID_EVENT;
#endif

  /* We can now configure the run loop watchers */
  if (-1 == [self _setSocket: socket sources: info what: what])
    {
      NSDebugMLLog(GS_NSURLSESSION_DEBUG_KEY, @"Failed to setup sockets!");
      free(info);
      return -1;
    }
  /* Assign the SourceInfo for access in subsequent socket_callback calls */
  curl_multi_assign(_multiHandle, socket, info);
  return 0;
} /* _addSocket */

/* Register or update run loop watchers for the socket according to the
 * direction(s) libcurl requests.  We only add or remove a watcher on an
 * actual transition, so a still-wanted watcher is left in place rather
 * than being torn down and recreated.
 */
- (int) _setSocket: (curl_socket_t)socket
  sources: (struct SourceInfo *)sources
  what: (int)what
{
  NSRunLoop * rl = [NSRunLoop currentRunLoop];
  BOOL wantRead = (CURL_POLL_IN == what || CURL_POLL_INOUT == what);
  BOOL wantWrite = (CURL_POLL_OUT == what || CURL_POLL_INOUT == what);

  sources->socket = socket;

  NSDebugMLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Set socket=%d sources=%p what=%d",
    socket,
    sources,
    what);

#if	defined(_WIN32)
  {
    long mask = FD_CLOSE;

    if (wantRead)
      mask |= FD_READ | FD_ACCEPT | FD_OOB;
    if (wantWrite)
      mask |= FD_WRITE | FD_CONNECT;

    if (mask != sources->networkEvents)
      {
        if (WSA_INVALID_EVENT == sources->event)
          {
            sources->event = WSACreateEvent();
            if (WSA_INVALID_EVENT == sources->event)
              {
                return -1;
              }
            [rl addEvent: (void*)sources->event
                    type: ET_HANDLE
                 watcher: self
                 forMode: NSDefaultRunLoopMode];
            NSMapInsert(_socketForEvent, (void*)sources->event,
              (void*)(intptr_t)socket);
          }
        if (SOCKET_ERROR == WSAEventSelect(socket, sources->event, mask))
          {
            return -1;
          }
        sources->networkEvents = mask;
      }
  }
#else
  if (wantRead && !sources->readReady)
    {
      [rl addEvent: (void*)(intptr_t)socket
              type: ET_RDESC
           watcher: self
           forMode: NSDefaultRunLoopMode];
      sources->readReady = YES;
    }
  else if (!wantRead && sources->readReady)
    {
      [rl removeEvent: (void*)(intptr_t)socket
                 type: ET_RDESC
              forMode: NSDefaultRunLoopMode
                  all: YES];
      sources->readReady = NO;
    }

  if (wantWrite && !sources->writeReady)
    {
      [rl addEvent: (void*)(intptr_t)socket
              type: ET_WDESC
           watcher: self
           forMode: NSDefaultRunLoopMode];
      sources->writeReady = YES;
    }
  else if (!wantWrite && sources->writeReady)
    {
      [rl removeEvent: (void*)(intptr_t)socket
                 type: ET_WDESC
              forMode: NSDefaultRunLoopMode
                  all: YES];
      sources->writeReady = NO;
    }
#endif

  return 0;
} /* _setSocket */

/* Run loop callback: a watched socket became ready.  Notify libcurl and
 * check whether any transfers have completed.  Runs on the work thread.
 */
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  curl_socket_t socket;
  int action = 0;

#if	defined(_WIN32)
  WSANETWORKEVENTS occurred;

  socket = (curl_socket_t)(intptr_t)NSMapGet(_socketForEvent, data);
  if (0 == WSAEnumNetworkEvents(socket, (WSAEVENT)data, &occurred))
    {
      if (occurred.lNetworkEvents & (FD_READ | FD_ACCEPT | FD_OOB))
        action |= CURL_CSELECT_IN;
      if (occurred.lNetworkEvents & (FD_WRITE | FD_CONNECT))
        action |= CURL_CSELECT_OUT;
      if (occurred.lNetworkEvents & FD_CLOSE)
        action |= CURL_CSELECT_IN;
    }
#else
  socket = (curl_socket_t)(intptr_t)data;
  if (ET_WDESC == type)
    action = CURL_CSELECT_OUT;
  else
    action = CURL_CSELECT_IN;
#endif

  curl_multi_socket_action(_multiHandle, socket, action, &_stillRunning);
  [self _checkForCompletion];

  /* When _stillRunning reaches zero, all transfers are complete/done */
  if (_stillRunning <= 0)
    {
      [self _suspendTimer];
    }
}

/* Called by a socket event handler or by a firing timer set by timer_callback.
 *
 * The socket event handler is executed on the work thread.
 */
- (void) _checkForCompletion
{
  CURLMsg * msg;
  int msgs_left;
  CURL * easyHandle;
  CURLcode res;
  char * eff_url = NULL;
  NSURLSessionTask * task = nil;

  /* Ask the multi handle if there are any messages from the individual
   * transfers.
   *
   * Remove the associated easy handle and release the task if the transfer is
   * done. This completes the life-cycle of a task added to NSURLSession.
   */
  while ((msg = curl_multi_info_read(_multiHandle, &msgs_left)))
    {
      if (msg->msg == CURLMSG_DONE)
        {
          CURLcode rc;
          easyHandle = msg->easy_handle;
          res = msg->data.result;

          /* Get the NSURLSessionTask instance */
          rc = curl_easy_getinfo(easyHandle, CURLINFO_PRIVATE, &task);
          if (CURLE_OK != rc)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Failed to retrieve task from easy handle %p using "
                @"CURLINFO_PRIVATE",
                easyHandle);
            }
          rc = curl_easy_getinfo(easyHandle, CURLINFO_EFFECTIVE_URL, &eff_url);
          if (CURLE_OK != rc)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Failed to retrieve effective URL from easy handle %p using "
                @"CURLINFO_PRIVATE",
                easyHandle);
            }

          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Transfer finished for Task %@ with effective url %s "
            @"and CURLcode: %s",
            task,
            eff_url,
            curl_easy_strerror(res));

          curl_multi_remove_handle(_multiHandle, easyHandle);

          /* This session might be released in _transferFinishedWithCode. Better
           * retain it first. */
          RETAIN(self);

          RETAIN(task);
          [_tasks removeObject: task];
          [task _transferFinishedWithCode: res];
          RELEASE(task);

          /* Send URLSession: didBecomeInvalidWithError: to delegate if this
           * session was invalidated */
          if (_invalidated && [_tasks count] == 0 &&
              [_delegate respondsToSelector: @selector(URLSession:
                                                       didBecomeInvalidWithError
                                                       :)])
            {
              [_delegateQueue addOperationWithBlock:^{
                 /* We only support explicit Invalidation for now. Error is set
                  * to nil in this case. */
                 [_delegate URLSession: self didBecomeInvalidWithError: nil];
               }];
            }

          RELEASE(self);
        }
    }
} /* _checkForCompletion */

/* Adds task to _tasks and updates the delegate */
- (void) _didCreateTask: (NSURLSessionTask *)task
{
  [self _performOnWorkThread: ^{
    [_tasks addObject: task];
  }];

  if ([_delegate respondsToSelector: @selector(URLSession:didCreateTask:)])
    {
      [_delegateQueue addOperationWithBlock:^{
         [(id<NSURLSessionTaskDelegate>) _delegate URLSession: self
                                                didCreateTask  : task];
       }];
    }
}

#pragma mark - Public API

- (void) finishTasksAndInvalidate
{
  if (_isSharedSession)
    {
      return;
    }

  [self _performOnWorkThread: ^{
    _invalidated = YES;
  }];
}

- (void) invalidateAndCancel
{
  if (_isSharedSession)
    {
      return;
    }

  [self _performOnWorkThread: ^{
    _invalidated = YES;

    /* Cancel all tasks */
    for (NSURLSessionTask * task in _tasks)
    {
      [task cancel];
    }
  }];
}

- (NSURLSessionDataTask *) dataTaskWithRequest: (NSURLRequest *)request
{
  NSURLSessionDataTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDataTask alloc] initWithSession: self
                                               request: request
                                        taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionUpdatesDelegate];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url
{
  NSURLRequest * request;

  request = [NSURLRequest requestWithURL: url];
  return [self dataTaskWithRequest: request];
}

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromFile: (NSURL *)fileURL
{
  NSURLSessionUploadTask * task;
  NSInputStream * stream;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  stream = [NSInputStream inputStreamWithURL: fileURL];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionUpdatesDelegate | GSURLSessionHasInputStream];
  [task _setBodyStream: stream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
} /* uploadTaskWithRequest */

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromData: (NSData *)bodyData
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task _setProperties: GSURLSessionUpdatesDelegate];
  [task _enableUploadWithData: bodyData];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionUploadTask *) uploadTaskWithStreamedRequest:
  (NSURLRequest *)request
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionUpdatesDelegate | GSURLSessionHasInputStream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request
{
  NSURLSessionDownloadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDownloadTask alloc] initWithSession: self
                                                   request: request
                                            taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionWritesDataToFile | GSURLSessionUpdatesDelegate];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithURL: (NSURL *)url
{
  NSURLRequest * request;

  request = [NSURLRequest requestWithURL: url];
  return [self downloadTaskWithRequest: request];
}

- (NSURLSessionDownloadTask *) downloadTaskWithResumeData: (NSData *)resumeData
{
  return [self notImplemented: _cmd];
}

- (void) getTasksWithCompletionHandler:
  (void (^)(
     NSArray<NSURLSessionDataTask *> * dataTasks,
     NSArray<NSURLSessionUploadTask *> * uploadTasks,
     NSArray<NSURLSessionDownloadTask *> * downloadTasks))
  completionHandler
{
  [self _performOnWorkThread: ^{
    NSMutableArray<NSURLSessionDataTask *> * dataTasks;
    NSMutableArray<NSURLSessionUploadTask *> * uploadTasks;
    NSMutableArray<NSURLSessionDownloadTask *> * downloadTasks;
    NSInteger numberOfTasks;

    Class dataTaskClass;
    Class uploadTaskClass;
    Class downloadTaskClass;

    numberOfTasks = [_tasks count];
    dataTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];
    uploadTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];
    downloadTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];

    dataTaskClass = [NSURLSessionDataTask class];
    uploadTaskClass = [NSURLSessionUploadTask class];
    downloadTaskClass = [NSURLSessionDownloadTask class];

    for (NSURLSessionTask * task in _tasks)
    {
      if ([task isKindOfClass: dataTaskClass])
      {
        [dataTasks addObject: (NSURLSessionDataTask *)task];
      }
      else if ([task isKindOfClass: uploadTaskClass])
      {
        [uploadTasks addObject: (NSURLSessionUploadTask *)task];
      }
      else if ([task isKindOfClass: downloadTaskClass])
      {
        [downloadTasks addObject: (NSURLSessionDownloadTask *)task];
      }
    }

    completionHandler(dataTasks, uploadTasks, downloadTasks);
  }];
} /* getTasksWithCompletionHandler */

- (void) getAllTasksWithCompletionHandler:
  (void (^)(NSArray<__kindof NSURLSessionTask *> * tasks))completionHandler
{
  [self _performOnWorkThread: ^{
    completionHandler(_tasks);
  }];
}

#pragma mark - Getter and Setter

- (NSOperationQueue *) delegateQueue
{
  return _delegateQueue;
}

- (id<NSURLSessionDelegate>) delegate
{
  return _delegate;
}

- (NSURLSessionConfiguration *) configuration
{
  return AUTORELEASE([_configuration copy]);
}

- (NSString *) sessionDescription
{
  return _sessionDescription;
}

- (void) setSessionDescription: (NSString *)sessionDescription
{
  ASSIGNCOPY(_sessionDescription, sessionDescription);
}

- (void) dealloc
{
  /* Stop the work thread and wait for it to finish before releasing state
   * it might touch.  We target the helper (not self) so this does not
   * transiently resurrect a session already at zero retain count.  A
   * pending timer would retain self and defer dealloc, so none is pending
   * here.
   */
  if (_workHelper != nil)
    {
      [_workHelper performSelector: @selector(stop)
                          onThread: _workHelper->thread
                        withObject: nil
                     waitUntilDone: YES];
      while (![_workHelper->thread isFinished])
        {
          [NSThread sleepForTimeInterval: 0.001];
        }
      RELEASE(_workHelper->thread);
      RELEASE(_workHelper->port);
      RELEASE(_workHelper);
    }

  RELEASE(_delegateQueue);
  RELEASE(_delegate);
  RELEASE(_configuration);
  RELEASE(_tasks);
  RELEASE(_certificateBlob);
  RELEASE(_certificatePath);

  curl_multi_cleanup(_multiHandle);

#if	defined(_WIN32)
  if (_socketForEvent != NULL)
    {
      NSFreeMapTable(_socketForEvent);
    }
#endif

  [super dealloc];
}

@end

@implementation
NSURLSession (NSURLSessionAsynchronousConvenience)

- (NSURLSessionDataTask *)
  dataTaskWithRequest: (NSURLRequest *)request
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionDataTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDataTask alloc] initWithSession: self
                                               request: request
                                        taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setProperties: GSURLSessionStoresDataInMemory |
   GSURLSessionHasCompletionHandler];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url
  completionHandler:
  (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLRequest * request = [NSURLRequest requestWithURL: url];

  return [self dataTaskWithRequest: request completionHandler: completionHandler];
}

- (NSURLSessionUploadTask *)
  uploadTaskWithRequest: (NSURLRequest *)request
  fromFile: (NSURL *)fileURL
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionUploadTask * task;
  NSInputStream * stream;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  stream = [NSInputStream inputStreamWithURL: fileURL];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionStoresDataInMemory
   | GSURLSessionHasInputStream |
   GSURLSessionHasCompletionHandler];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setBodyStream: stream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
} /* uploadTaskWithRequest */

- (NSURLSessionUploadTask *)
  uploadTaskWithRequest: (NSURLRequest *)request
  fromData: (NSData *)bodyData
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionStoresDataInMemory |
   GSURLSessionHasCompletionHandler];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _enableUploadWithData: bodyData];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request
  completionHandler:
  (GSNSURLSessionDownloadCompletionHandler)
  completionHandler
{
  NSURLSessionDownloadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDownloadTask alloc] initWithSession: self
                                                   request: request
                                            taskIdentifier: identifier];

  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionWritesDataToFile |
   GSURLSessionHasCompletionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setCompletionHandler: completionHandler];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *)
  downloadTaskWithURL: (NSURL *)url
  completionHandler: (GSNSURLSessionDownloadCompletionHandler)completionHandler
{
  NSURLRequest * request = [NSURLRequest requestWithURL: url];

  return [self downloadTaskWithRequest: request
                     completionHandler: completionHandler];
}

- (NSURLSessionDownloadTask *)
  downloadTaskWithResumeData: (NSData *)resumeData
  completionHandler:
  (GSNSURLSessionDownloadCompletionHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

@end
