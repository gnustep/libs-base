/**
 * NSURLSessionPrivate.h
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

#import "common.h"

#import "Foundation/NSURLSession.h"
#import "Foundation/NSDictionary.h"
#import <curl/curl.h>

#if	defined(_WIN32)
#import <winsock2.h>
#endif

@class NSInvocation;

extern NSString * GS_NSURLSESSION_DEBUG_KEY;

/* Return an invocation for aSelector on target, with the target and the
 * selector already set.  Arguments start at index 2.
 */
extern NSInvocation *
GSURLSessionInvocation(id target, SEL aSelector);

/* libcurl asks us to monitor a socket for reading, writing or both
 * (CURL_POLL_INOUT).  We integrate this with the NSRunLoop of the session
 * work thread rather than libdispatch, so this structure records what we
 * currently have registered for a socket.
 *
 * On unix the run loop watches the descriptor directly (ET_RDESC/ET_WDESC).
 * On Windows the run loop has no descriptor events, so we associate a
 * WSAEVENT with the socket using WSAEventSelect and watch that (ET_HANDLE).
 */
struct SourceInfo
{
  curl_socket_t	socket;
  BOOL		readReady;	/* An ET_RDESC watcher is installed.	*/
  BOOL		writeReady;	/* An ET_WDESC watcher is installed.	*/
#if	defined(_WIN32)
  WSAEVENT	event;		/* Registered with the loop as ET_HANDLE. */
  long		networkEvents;	/* Currently selected FD_* mask.		*/
#endif
};

typedef NS_ENUM(NSInteger, GSURLSessionProperties)
{
  GSURLSessionStoresDataInMemory = (1 << 0),
  GSURLSessionWritesDataToFile = (1 << 1),
  GSURLSessionUpdatesDelegate = (1 << 2),
  GSURLSessionHasCompletionHandler = (1 << 3),
  GSURLSessionHasInputStream = (1 << 4)
};

@interface
  NSURLSession(Private)

/* Send aSelector to target on the session work thread's run loop.  If the
 * caller is already on the work thread the message is sent immediately.
 */
- (void)_performSelectorOnWorkThread: (SEL)aSelector
			      target: (id)target
			  withObject: (id)anObject;

- (void)_performSelectorOnWorkThread: (SEL)aSelector
			      target: (id)target
			  withObject: (id)anObject
		       waitUntilDone: (BOOL)shouldWait;

/* As above, for a message taking more than a single object argument.  The
 * arguments are retained if the invocation has to be scheduled.
 */
- (void)_performInvocationOnWorkThread: (NSInvocation *)anInvocation;

/* Add anInvocation to the delegate queue, retaining its arguments.  A no-op
 * if the session has no delegate queue.
 */
- (void)_enqueueDelegateInvocation: (NSInvocation *)anInvocation;

-(NSData *)_certificateBlob;
-(NSString *)_certificatePath;

/* Adds the internal easy handle to the multi handle.
 * Modifications are performed on the workQueue.
 */
-(void)_resumeTask: (NSURLSessionTask *)task;

/* The following methods must only be called from within callbacks dispatched on
 * the workQueue.*/
-(void)_setTimer: (NSInteger)timeout;
-(void)_suspendTimer;

/* Required for manual redirects.
 */
-(void)_addHandle: (CURL *)easy;
-(void)_removeHandle: (CURL *)easy;

/* Remove a task the delegate cancelled from a callback (redirect refusal or a
 * NSURLSessionResponseCancel disposition) and deliver a cancellation
 * completion for it.
 */
/* The single completion point for a task: removes the easy handle, delivers
 * -_transferFinishedWithCode:, and performs the didBecomeInvalidWithError
 * bookkeeping.  A no-op if the task was already finished. */
-(void)_finishTask: (NSURLSessionTask *)task withCode: (CURLcode)code;

-(void)_cancelTaskFromDelegate: (NSURLSessionTask *)task;

/* Deliver a completion that was held back while the task awaited a
 * didReceiveResponse disposition (see -[NSURLSessionTask _heldCompletionCode]).
 * A no-op if no completion was held. */
-(void)_deliverHeldCompletionForTask: (NSURLSessionTask *)task;

-(void)_removeSocket: (struct SourceInfo *)sources;
-(int)_addSocket: (curl_socket_t)socket easyHandle: (CURL *)easy what: (int)what;
-(int)_setSocket: (curl_socket_t)socket
 sources: (struct SourceInfo *)sources
 what: (int)what;

@end
