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

/* The ivar macro below is expanded by Foundation/NSURLSession.h, so the types
 * it names have to be known before that header is imported.
 */
#import "common.h"
#import <curl/curl.h>
#import "GSPThread.h"

@class GSURLSessionWorkThread;
@class NSMapTable;
@class NSTimer;

/* The socket-to-event map is only needed where the run loop has no descriptor
 * events.  A preprocessor conditional cannot appear inside the ivar macro, so
 * it is a macro of its own.
 */
#if	defined(_WIN32)
/* Maps a registered WSAEVENT back to its socket, since the run loop only
 * hands the event handle back to -receivedEvent:type:extra:forMode:.
 */
#define	GS_NSURLSession_PLATFORM_IVARS	NSMapTable * _socketForEvent;
#else
#define	GS_NSURLSession_PLATFORM_IVARS
#endif

#define	GS_NSURLSession_IVARS \
  NSOperationQueue          *_delegateQueue; \
  id<NSURLSessionDelegate>   _delegate; \
  NSURLSessionConfiguration *_configuration; \
 \
  NSString *_sessionDescription; \
 \
  /* The libcurl multi handle associated with this session. \
   * We use the curl_multi_socket_action API as we utilise our \
   * own event-handling system integrated with the work thread run loop. \
   * \
   * Event creation and deletion is driven by the various callbacks \
   * registered during initialisation of the multi handle. \
   */ \
  CURLM * _multiHandle; \
  /* Drives a dedicated thread running an NSRunLoop.  All libcurl multi \
   * handle activity (adding handles, socket events and the timer) happens on \
   * that thread, which serialises access in place of a dispatch queue and \
   * keeps GNUstep free of a libdispatch dependency.  The helper holds the \
   * session unretained so that it does not keep the session alive. \
   */ \
  GSURLSessionWorkThread * _workHelper; \
 \
  GS_NSURLSession_PLATFORM_IVARS \
 \
  /* This timer is driven by libcurl and used by \
   * libcurl's multi API. \
   * \
   * The handler notifies libcurl using curl_multi_socket_action \
   * and checks for completed requests by calling \
   * _checkForCompletion. \
   * \
   * See https://curl.se/libcurl/c/CURLMOPT_TIMERFUNCTION.html \
   * and https://curl.se/libcurl/c/curl_multi_socket_action.html \
   * respectively.  It is scheduled on the work thread run loop. \
   */ \
  NSTimer * _timer; \
 \
  /* Only set when session originates from +[NSURLSession sharedSession] */ \
  BOOL _isSharedSession; \
  BOOL _invalidated; \
 \
  /* \
   * Number of currently running handles. \
   * This number is updated by curl_multi_socket_action \
   * in the socket source handlers. \
   */ \
  int _stillRunning; \
 \
  /* List of active tasks. Access is synchronised via the work thread. \
   */ \
  GS_GENERIC_CLASS(NSMutableArray, NSURLSessionTask *) * _tasks; \
 \
  /* PEM encoded blob of one or more certificates. \
   * \
   * See GSCACertificateFilePath in NSUserDefaults.h \
   */ \
  NSData * _certificateBlob; \
  /* Path to PEM encoded CA certificate file. */ \
  NSString * _certificatePath; \
 \
  /* The task identifier for the next task.  Read and incremented under \
   * _taskLock, so it needs no atomic type of its own. \
   */ \
  NSInteger _taskIdentifier; \
  /* Lock for _taskIdentifier and _tasks \
   */ \
  gs_mutex_t _taskLock;

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
#import "Foundation/NSInvocation.h"
#import "Foundation/NSInvocationOperation.h"
#import "Foundation/NSMethodSignature.h"

#import "GNUstepBase/NSDebug+GNUstepBase.h"  /* For NSDebugMLLog */
#import "GNUstepBase/NSObject+GNUstepBase.h" /* For -notImplemented */
#import "GSPThread.h"                        /* For nextSessionIdentifier() */

#define	GSInternal	NSURLSessionInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLSession)

NSString * GS_NSURLSESSION_DEBUG_KEY = @"NSURLSession";

NSInvocation *
GSURLSessionInvocation(id target, SEL aSelector)
{
  NSInvocation	*inv;

  inv = [NSInvocation invocationWithMethodSignature:
    [target methodSignatureForSelector: aSelector]];
  [inv setTarget: target];
  [inv setSelector: aSelector];
  return inv;
}

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
               long timeout_ms,    /* timeout in number of ms */
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
                void * socketp)        /* private socket pointer */
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

      GS_CREATE_INTERNAL(NSURLSession);

      sessionIdentifier = nextSessionIdentifier();
      queueLabel = [[NSString alloc]
                    initWithFormat: @"org.gnustep.NSURLSession.WorkQueue%ld",
                    sessionIdentifier];
      ASSIGN(internal->_delegate, delegate);
      ASSIGNCOPY(internal->_configuration, configuration);

      internal->_tasks = [[NSMutableArray alloc] init];
      GS_MUTEX_INIT(internal->_taskLock);

      internal->_timer = nil;
#if	defined(_WIN32)
      internal->_socketForEvent = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
        NSIntegerMapValueCallBacks, 0);
#endif
      /* A port keeps the work thread run loop from exiting when it has no
       * other input sources. */
      internal->_workHelper = [[GSURLSessionWorkThread alloc] init];
      internal->_workHelper->port = [[NSPort port] retain];
      internal->_workHelper->thread = [[NSThread alloc] initWithTarget: internal->_workHelper
                                                    selector: @selector(run)
                                                      object: nil];
      [internal->_workHelper->thread setName: queueLabel];
      [queueLabel release];
      [internal->_workHelper->thread start];

      /* Use the provided delegateQueue if available.  It is retained, since
       * -dealloc releases it and the caller may share one queue between
       * several sessions. */
      if (queue)
        {
          ASSIGN(internal->_delegateQueue, queue);
        }
      else
        {
          /* This (serial) NSOperationQueue is only used for dispatching
           * delegate callbacks and is orthogonal to the workQueue.
           */
          internal->_delegateQueue = [[NSOperationQueue alloc] init];
          [internal->_delegateQueue setMaxConcurrentOperationCount: 1];
        }

      /* libcurl Configuration */
      curl_global_init(CURL_GLOBAL_SSL);

      internal->_multiHandle = curl_multi_init();

      // Set up CURL multi callbacks
      curl_multi_setopt(internal->_multiHandle, CURLMOPT_SOCKETFUNCTION, socket_callback);
      curl_multi_setopt(internal->_multiHandle, CURLMOPT_SOCKETDATA, self);
      curl_multi_setopt(internal->_multiHandle, CURLMOPT_TIMERFUNCTION, timer_callback);
      curl_multi_setopt(internal->_multiHandle, CURLMOPT_TIMERDATA, self);

      // Configure Multi Handle
      curl_multi_setopt(
        internal->_multiHandle,
        CURLMOPT_MAX_HOST_CONNECTIONS,
        [internal->_configuration HTTPMaximumConnectionsPerHost]);

      /* Check if GSCACertificateFilePath is set */

      caPath = [[NSUserDefaults standardUserDefaults]
                objectForKey: GSCACertificateFilePath];
      if (caPath)
        {
          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Found a GSCACertificateFilePath entry in UserDefaults");

          internal->_certificateBlob = [[NSData alloc] initWithContentsOfFile: caPath];
          if (!internal->_certificateBlob)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Could not open file at GSCACertificateFilePath=%@",
                caPath);
            }
          else
            {
              ASSIGN(internal->_certificatePath, caPath);
            }
        }
    }

  return self;
} /* initWithConfiguration */

#pragma mark - Private Methods

- (NSData *) _certificateBlob
{
  return internal->_certificateBlob;
}

- (NSString *) _certificatePath
{
  return internal->_certificatePath;
}

- (void) _setSharedSession: (BOOL)flag
{
  internal->_isSharedSession = flag;
}

- (NSInteger) _nextTaskIdentifier
{
  NSInteger identifier;

  GS_MUTEX_LOCK(internal->_taskLock);
  identifier = internal->_taskIdentifier;
  internal->_taskIdentifier += 1;
  GS_MUTEX_UNLOCK(internal->_taskLock);

  return identifier;
}

- (void) _resumeTask: (NSURLSessionTask *)task
{
  [self _performSelectorOnWorkThread: @selector(_workResumeTask:)
			      target: self
			  withObject: task];
}

- (void) _workResumeTask: (NSURLSessionTask *)task
{
  CURLMcode	code;
  CURLM		*multiHandle = internal->_multiHandle;

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
    &internal->_stillRunning);
  [self _checkForCompletion];
}

- (void) _addHandle: (CURL *)easy
{
  curl_multi_add_handle(internal->_multiHandle, easy);

  /* Kick the added transfer off now rather than waiting for libcurl to fire
   * the timer callback.  Relying on the timer alone races with the run loop,
   * which shows up most on a handle that is re-added after a redirect: the
   * transfer can stall until an unrelated event drives the multi handle.
   * See https://curl.se/libcurl/c/curl_multi_socket_action.html . */
  curl_multi_socket_action(internal->_multiHandle, CURL_SOCKET_TIMEOUT, 0,
    &internal->_stillRunning);
  [self _checkForCompletion];
}
- (void) _removeHandle: (CURL *)easy
{
  curl_multi_remove_handle(internal->_multiHandle, easy);
}

/* The single point at which a task's transfer is finished.  Every completion
 * path (normal completion in -_checkForCompletion, a delegate cancellation, or
 * a held completion delivered once a disposition is known) funnels through
 * here so the easy handle removal, the -_transferFinishedWithCode: delivery
 * and the didBecomeInvalidWithError bookkeeping happen exactly once and
 * identically regardless of which path finished the task.  A no-op if the task
 * has already been finished by another path. */
- (void) _finishTask: (NSURLSessionTask *)task withCode: (CURLcode)code
{
  if (![internal->_tasks containsObject: task])
    {
      return;
    }
  curl_multi_remove_handle(internal->_multiHandle, [task _easyHandle]);

  /* -_transferFinishedWithCode: may release the last reference to the
   * session, so keep both alive across the call. */
  RETAIN(self);
  RETAIN(task);
  [internal->_tasks removeObject: task];
  [task _transferFinishedWithCode: code];
  RELEASE(task);

  /* Send URLSession:didBecomeInvalidWithError: to the delegate once the last
   * task of an invalidated session has finished. */
  if (internal->_invalidated && [internal->_tasks count] == 0 &&
      [internal->_delegate respondsToSelector: @selector(URLSession:
                                               didBecomeInvalidWithError:)])
    {
      /* We only support explicit invalidation for now, so error is nil. */
      NSInvocation	*inv;
      NSURLSession	*session = self;
      NSError		*error = nil;

      inv = GSURLSessionInvocation(internal->_delegate,
	@selector(URLSession:didBecomeInvalidWithError:));
      [inv setArgument: &session atIndex: 2];
      [inv setArgument: &error atIndex: 3];
      [self _enqueueDelegateInvocation: inv];
    }
  RELEASE(self);
}

/* Called on the work thread when the delegate cancels a task from a callback
 * (refusing a redirect, or returning NSURLSessionResponseCancel from
 * URLSession:dataTask:didReceiveResponse:completionHandler:).  The response is
 * already buffered in libcurl, so relying on the progress or write callback to
 * abort races with the transfer completing normally; finish it as cancelled. */
- (void) _cancelTaskFromDelegate: (NSURLSessionTask *)task
{
  [self _finishTask: task withCode: CURLE_ABORTED_BY_CALLBACK];
}

/* Called on the work thread after the delegate allows a response.  If libcurl
 * completed the transfer while the delegate was answering didReceiveResponse
 * its completion was held back in -_checkForCompletion; deliver it now.  If
 * nothing was held, the transfer is still running and completes normally. */
- (void) _deliverHeldCompletionForTask: (NSURLSessionTask *)task
{
  if ([task _heldCompletionCode] < 0)
    {
      return;
    }
  [self _finishTask: task withCode: (CURLcode)[task _heldCompletionCode]];
}

/* Called on the work thread from libcurl's timer_callback.  Schedules a
 * one-shot timer on the work thread run loop; libcurl re-arms it as needed.
 */
- (void) _setTimer: (NSInteger)timeoutMs
{
  [internal->_timer invalidate];
  internal->_timer = [NSTimer scheduledTimerWithTimeInterval: (double)timeoutMs / 1000.0
                                            target: self
                                          selector: @selector(_timerFired:)
                                          userInfo: nil
                                           repeats: NO];
}

- (void) _suspendTimer
{
  [internal->_timer invalidate];
  internal->_timer = nil;
}

- (void) _timerFired: (NSTimer *)timer
{
  /* The run loop releases the fired non-repeating timer. */
  internal->_timer = nil;

  curl_multi_socket_action(
    internal->_multiHandle,
    CURL_SOCKET_TIMEOUT,
    0,
    &internal->_stillRunning);
  [self _checkForCompletion];
}

#pragma mark - Work thread

- (void) _runWorkInvocation: (NSInvocation *)anInvocation
{
  [anInvocation invoke];
}

- (void) _performSelectorOnWorkThread: (SEL)aSelector
			       target: (id)target
			   withObject: (id)anObject
{
  [self _performSelectorOnWorkThread: aSelector
			      target: target
			  withObject: anObject
		       waitUntilDone: NO];
}

- (void) _performSelectorOnWorkThread: (SEL)aSelector
			       target: (id)target
			   withObject: (id)anObject
			waitUntilDone: (BOOL)shouldWait
{
  /* Run immediately if we are already on the work thread (e.g. called from
   * a libcurl callback), otherwise schedule on its run loop. */
  if ([NSThread currentThread] == internal->_workHelper->thread)
    {
      [target performSelector: aSelector withObject: anObject];
    }
  else
    {
      [target performSelector: aSelector
		     onThread: internal->_workHelper->thread
		   withObject: anObject
		waitUntilDone: shouldWait];
    }
}

- (void) _performInvocationOnWorkThread: (NSInvocation *)anInvocation
{
  if ([NSThread currentThread] == internal->_workHelper->thread)
    {
      [anInvocation invoke];
    }
  else
    {
      [anInvocation retainArguments];
      [self performSelector: @selector(_runWorkInvocation:)
		   onThread: internal->_workHelper->thread
		 withObject: anInvocation
	      waitUntilDone: NO];
    }
}

- (void) _enqueueDelegateInvocation: (NSInvocation *)anInvocation
{
  NSInvocationOperation	*op;

  if (nil == internal->_delegateQueue)
    {
      return;
    }
  [anInvocation retainArguments];
  op = [[NSInvocationOperation alloc] initWithInvocation: anInvocation];
  [internal->_delegateQueue addOperation: op];
  RELEASE(op);
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
      NSMapRemove(internal->_socketForEvent, (void*)sources->event);
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
  curl_multi_assign(internal->_multiHandle, socket, info);
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
            NSMapInsert(internal->_socketForEvent, (void*)sources->event,
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

#if GS_HAVE_NSURLSESSION_WEBSOCKETS
  for (NSURLSessionTask *task in _tasks)
    {
      if ([task isKindOfClass: [NSURLSessionWebSocketTask class]])
        {
          [(NSURLSessionWebSocketTask *)task
            _resumeSendIfWaitingForReadableSocket];
        }
    }
#endif

#if	defined(_WIN32)
  WSANETWORKEVENTS occurred;

  socket = (curl_socket_t)(intptr_t)NSMapGet(internal->_socketForEvent, data);
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

  curl_multi_socket_action(internal->_multiHandle, socket, action, &internal->_stillRunning);
  [self _checkForCompletion];

  /* When internal->_stillRunning reaches zero, all transfers are complete/done */
  if (internal->_stillRunning <= 0)
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
  while ((msg = curl_multi_info_read(internal->_multiHandle, &msgs_left)))
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

          /* With CURLOPT_FOLLOWLOCATION disabled libcurl reports an
           * intercepted 3xx response as a completed transfer.  When the task
           * is being redirected the easy handle is about to be re-added for
           * the new location (or cancelled by the delegate), so hold back the
           * completion instead of delivering it for the intermediate leg. */
          if ([task _redirectInProgress])
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Holding back completion for redirecting task %@",
                task);
              continue;
            }

          /* Similarly, libcurl may report the buffered response as complete
           * before the delegate answers didReceiveResponse.  Remember the
           * result and hold the completion back; the disposition handler
           * delivers it (or a cancellation) once the delegate replies. */
          if ([task _awaitingResponseDisposition])
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Holding back completion (code %d) for task %@ awaiting a "
                @"didReceiveResponse disposition",
                (int)res, task);
              [task _setHeldCompletionCode: (int)res];
              continue;
            }

          [self _finishTask: task withCode: res];
        }
    }
} /* _checkForCompletion */

/* Adds task to internal->_tasks and updates the delegate */
- (void) _didCreateTask: (NSURLSessionTask *)task
{
  [self _performSelectorOnWorkThread: @selector(_workAddTask:)
			      target: self
			  withObject: task];

  if ([internal->_delegate respondsToSelector: @selector(URLSession:didCreateTask:)])
    {
      NSInvocation	*inv;
      NSURLSession	*session = self;

      inv = GSURLSessionInvocation(internal->_delegate,
	@selector(URLSession:didCreateTask:));
      [inv setArgument: &session atIndex: 2];
      [inv setArgument: &task atIndex: 3];
      [self _enqueueDelegateInvocation: inv];
    }
}

- (void) _workAddTask: (NSURLSessionTask *)task
{
  [internal->_tasks addObject: task];
}

#pragma mark - Public API

- (void) finishTasksAndInvalidate
{
  if (internal->_isSharedSession)
    {
      return;
    }

  [self _performSelectorOnWorkThread: @selector(_workInvalidate)
			      target: self
			  withObject: nil];
}

- (void) _workInvalidate
{
  internal->_invalidated = YES;
}

- (void) invalidateAndCancel
{
  if (internal->_isSharedSession)
    {
      return;
    }

  [self _performSelectorOnWorkThread: @selector(_workInvalidateAndCancel)
			      target: self
			  withObject: nil];
}

- (void) _workInvalidateAndCancel
{
  internal->_invalidated = YES;

  /* Cancel all tasks */
  for (NSURLSessionTask * task in internal->_tasks)
    {
      [task cancel];
    }
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];

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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
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

#if GS_HAVE_NSURLSESSION_WEBSOCKETS
- (NSURLSessionWebSocketTask *) webSocketTaskWithURL: (NSURL *)url
{
  NSURLRequest * request;

  request = [NSURLRequest requestWithURL: url];
  return [self webSocketTaskWithRequest: request];
}

- (NSURLSessionWebSocketTask *) webSocketTaskWithURL: (NSURL *)url
                                          protocols:
  (GS_GENERIC_CLASS(NSArray, NSString *) *)protocols
{
  NSURLRequest * request;

  (void)protocols;
  request = [NSURLRequest requestWithURL: url];
  return [self webSocketTaskWithRequest: request];
}

- (NSURLSessionWebSocketTask *) webSocketTaskWithRequest: (NSURLRequest *)request
{
  NSURLSessionWebSocketTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionWebSocketTask alloc] initWebSocketTask: self
                                                       request: request
                                                taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
  [task _setProperties: GSURLSessionUpdatesDelegate];
  [self _didCreateTask: task];
  return AUTORELEASE(task);
}
#endif

- (GS_GENERIC_CLASS(NSArray, NSURLSessionTask *) *) allTasks
{
  NSMutableArray	*collected = [NSMutableArray array];

  [self _performSelectorOnWorkThread: @selector(_workCollectTasksInto:)
			      target: self
			  withObject: collected
		       waitUntilDone: YES];
  return collected;
}

- (void) _workCollectTasksInto: (NSMutableArray *)collected
{
  [collected addObjectsFromArray: internal->_tasks];
}

- (GS_GENERIC_CLASS(NSArray, NSURLSessionTask *) *) tasksOfKind: (Class)aClass
{
  NSMutableArray	*matched = [NSMutableArray array];
  NSEnumerator		*e = [[self allTasks] objectEnumerator];
  NSURLSessionTask	*task;

  while ((task = [e nextObject]) != nil)
    {
      if ([task isKindOfClass: aClass])
	{
	  [matched addObject: task];
	}
    }
  return matched;
}

- (void) getTasksWithCompletionHandler:
  (GSNSURLSessionTasksCompletionHandler)completionHandler
{
  NSArray	*all = [self allTasks];
  NSMutableArray *dataTasks = [NSMutableArray array];
  NSMutableArray *uploadTasks = [NSMutableArray array];
  NSMutableArray *downloadTasks = [NSMutableArray array];
  Class		dataTaskClass = [NSURLSessionDataTask class];
  Class		uploadTaskClass = [NSURLSessionUploadTask class];
  Class		downloadTaskClass = [NSURLSessionDownloadTask class];
  NSEnumerator	*e = [all objectEnumerator];
  NSURLSessionTask *task;

  while ((task = [e nextObject]) != nil)
    {
      /* An upload task is a kind of data task, so test for it first. */
      if ([task isKindOfClass: uploadTaskClass])
	{
	  [uploadTasks addObject: task];
	}
      else if ([task isKindOfClass: dataTaskClass])
	{
	  [dataTasks addObject: task];
	}
      else if ([task isKindOfClass: downloadTaskClass])
	{
	  [downloadTasks addObject: task];
	}
    }

  CALL_BLOCK(completionHandler, dataTasks, uploadTasks, downloadTasks);
} /* getTasksWithCompletionHandler */

- (void) getAllTasksWithCompletionHandler:
  (GSNSURLSessionAllTasksCompletionHandler)completionHandler
{
  CALL_BLOCK(completionHandler, [self allTasks]);
}

#pragma mark - Getter and Setter

- (NSOperationQueue *) delegateQueue
{
  return internal->_delegateQueue;
}

- (id<NSURLSessionDelegate>) delegate
{
  return internal->_delegate;
}

- (NSURLSessionConfiguration *) configuration
{
  return AUTORELEASE([internal->_configuration copy]);
}

- (NSString *) sessionDescription
{
  return internal->_sessionDescription;
}

- (void) setSessionDescription: (NSString *)sessionDescription
{
  ASSIGNCOPY(internal->_sessionDescription, sessionDescription);
}

- (void) dealloc
{
  /* Stop the work thread and wait for it to finish before releasing state
   * it might touch.  We target the helper (not self) so this does not
   * transiently resurrect a session already at zero retain count.  A
   * pending timer would retain self and defer dealloc, so none is pending
   * here.
   */
  if (internal->_workHelper != nil)
    {
      [internal->_workHelper performSelector: @selector(stop)
                          onThread: internal->_workHelper->thread
                        withObject: nil
                     waitUntilDone: YES];
      while (![internal->_workHelper->thread isFinished])
        {
          [NSThread sleepForTimeInterval: 0.001];
        }
      RELEASE(internal->_workHelper->thread);
      RELEASE(internal->_workHelper->port);
      RELEASE(internal->_workHelper);
    }

  RELEASE(internal->_delegateQueue);
  RELEASE(internal->_delegate);
  RELEASE(internal->_configuration);
  RELEASE(internal->_tasks);
  RELEASE(internal->_certificateBlob);
  RELEASE(internal->_certificatePath);

  curl_multi_cleanup(internal->_multiHandle);

#if	defined(_WIN32)
  if (internal->_socketForEvent != NULL)
    {
      NSFreeMapTable(internal->_socketForEvent);
    }
#endif

  GS_DESTROY_INTERNAL(NSURLSession);
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];
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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];

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
  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];

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

  [task setDelegate: (id<NSURLSessionTaskDelegate>)internal->_delegate];

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
