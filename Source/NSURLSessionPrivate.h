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

extern NSString * GS_NSURLSESSION_DEBUG_KEY;

/* A block executed on the session work thread. */
typedef void (^GSURLSessionWorkBlock)(void);

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

/* Schedule a block to run on the session work thread's run loop.  If the
 * caller is already on the work thread the block runs immediately.
 */
- (void)_performOnWorkThread: (GSURLSessionWorkBlock)block;

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

-(void)_removeSocket: (struct SourceInfo *)sources;
-(int)_addSocket: (curl_socket_t)socket easyHandle: (CURL *)easy what: (int)what;
-(int)_setSocket: (curl_socket_t)socket
 sources: (struct SourceInfo *)sources
 what: (int)what;

@end
