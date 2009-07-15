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

   AutogsdocSource: NSOperation.m
   AutogsdocSource: NSOperationQueue.m
   */ 

#import <Foundation/NSObject.h>

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
  // Priority...
  NSOperationQueuePriority priority;

  // Status...
  BOOL cancelled;
  BOOL concurrent;
  BOOL executing;
  BOOL finished;
  BOOL ready;

  // Dependencies
  NSMutableArray *dependencies;
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
  NSMutableArray *operations;
  BOOL suspended;
  NSInteger count;
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
