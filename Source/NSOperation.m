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
   */ 

#import <Foundation/NSOperation.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>

@implementation NSOperation : NSObject
// Initialization
- (id) init
{
  if((self = [super init]) != nil)
    {
      priority = NSOperationQueuePriorityNormal;
      
      cancelled = NO;
      concurrent = NO;
      executing = NO;
      finished = NO;
      ready = NO;
      
      dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(dependencies);
  [super dealloc];
}

// Executing the operation
- (void) start
{
  executing = YES;
  finished = NO;

  if([self isConcurrent])
    {
      [self main];
    }
  else
    {
      NS_DURING
	{
	  [self main];
	}
      NS_HANDLER
	{
	  NSLog(@"%@",[localException reason]);
	}
      NS_ENDHANDLER;
    }

  executing = NO;
  finished = YES;
}

- (void) main;
{
  // subclass responsibility...
  [self subclassResponsibility: _cmd];
}

// Cancelling the operation
- (void) cancel
{
  [self subclassResponsibility: _cmd];
}

// Getting the operation status
- (BOOL) isCancelled
{
  return NO;
}

- (BOOL) isExecuting
{
  return NO;
}

- (BOOL) isFinished
{
  return NO;
}

- (BOOL) isConcurrent
{
  return NO;
}

- (BOOL) isReady
{
  return NO;
}

// Managing dependencies
- (void) addDependency: (NSOperation *)op
{
  [dependencies addObject: op];
}

- (void) removeDependency: (NSOperation *)op
{
  [dependencies removeObject: op];
}

- (NSArray *)dependencies
{
  return [[NSArray alloc] initWithArray: dependencies];
}

// Prioritization 
- (NSOperationQueuePriority) queuePriority
{
  return priority;
}

- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
  priority = pri;
}
@end

@implementation NSOperationQueue

- (id) init
{
  if((self = [super init]) != nil)
    {
      suspended = NO;
      count = NSOperationQueueDefaultMaxConcurrentOperationCount;
    }
  return self;
}

// status
- (BOOL) isSuspended
{
  return suspended;
}

- (void) setSuspended: (BOOL)flag
{
  suspended = flag;
}

- (NSInteger) maxConcurrentOperationCount
{
  return count;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
  count = cnt;
}

// operations
- (void) addOperation: (NSOperation *) op
{
  [operations addObject: op];
}

- (NSArray *) operations
{
  return [[NSArray alloc] initWithArray: operations];
}

- (void) cancelAllOperations
{
  NSEnumerator *en = [operations objectEnumerator];
  id o = nil;
  while( (o = [en nextObject]) != nil )
    {
      [o cancel];
    }
}

- (void) waitUntilAllOperationsAreFinished
{
  // not yet implemented...
}
@end
