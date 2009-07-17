/**Interface for NSOperation for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Gregory Casamento <greg.casamento@gmail.com>
   Date: 2009
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */ 

#ifndef __NSOperation_h_GNUSTEP_BASE_INCLUDE
#define __NSOperation_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

#if OS_API_VERSION(100500, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSMutableArray;

enum {
  NSOperationQueuePriorityVeryLow = -8,
  NSOperationQueuePriorityLow = -4,
  NSOperationQueuePriorityNormal = 0,
  NSOperationQueuePriorityHigh = 4,
  NSOperationQueuePriorityVeryHigh = 8
};

typedef NSInteger NSOperationQueuePriority;

@interface NSOperation : NSObject
{
@private
  id	_internal;
}

// Initialization
- (id) init;

// Executing the operation
- (void) start;
- (void) main;

// Cancelling the operation
- (void) cancel;

// Getting the operation status
- (BOOL) isCancelled;
- (BOOL) isExecuting;
- (BOOL) isFinished;
- (BOOL) isConcurrent;
- (BOOL) isReady;

// Managing dependencies
- (void) addDependency: (NSOperation *)op;
- (void) removeDependency: (NSOperation *)op;
- (NSArray *)dependencies;

// Prioritization 
- (NSOperationQueuePriority) queuePriority;
- (void) setQueuePriority: (NSOperationQueuePriority)priority;
@end


/**
 * NSOperationQueue
 */

// Enumerated type for default operation count.
enum {
   NSOperationQueueDefaultMaxConcurrentOperationCount = -1
};

// NSOperationQueue
@interface NSOperationQueue : NSObject
{
@private
  id	_internal;
}

// status
- (BOOL) isSuspended;
- (void) setSuspended: (BOOL)flag;
- (NSInteger) maxConcurrentOperationCount;
- (void) setMaxConcurrentOperationCount: (NSInteger)cnt;

// operations
- (void) addOperation: (NSOperation *) op;
- (NSArray *) operations;
- (void) cancelAllOperations;
- (void) waitUntilAllOperationsAreFinished;
@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif /* __NSOperation_h_GNUSTEP_BASE_INCLUDE */
