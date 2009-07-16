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

@interface	NSOperationInternal : NSObject
{
@public
  NSOperationQueuePriority priority;
  BOOL cancelled;
  BOOL concurrent;
  BOOL executing;
  BOOL finished;
  BOOL ready;
  NSMutableArray *dependencies;
}
@end

@implementation	NSOperationInternal
/* As long as this class does nothing but act as a container for ivars,
 * we can easily remove it at a later date using a global substitution
 * to replace all the code of the form 'internal->ivar' with 'ivar'.
 */
@end


@implementation NSOperation : NSObject

#define	internal	((NSOperationInternal*)_internal)

- (void) dealloc
{
  if (_internal != nil)
    {
      RELEASE(internal->dependencies);
      [_internal release];
    }
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _internal = [NSOperationInternal new];
      internal->priority = NSOperationQueuePriorityNormal;
      internal->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
  return self;
}


// Executing the operation
- (void) start
{
  internal->executing = YES;
  internal->finished = NO;

  if ([self isConcurrent])
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

  internal->executing = NO;
  internal->finished = YES;
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
  [internal->dependencies addObject: op];
}

- (void) removeDependency: (NSOperation *)op
{
  [internal->dependencies removeObject: op];
}

- (NSArray *)dependencies
{
  return [NSArray arrayWithArray: internal->dependencies];
}

// Prioritization 
- (NSOperationQueuePriority) queuePriority
{
  return internal->priority;
}

- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
  internal->priority = pri;
}
@end


@interface NSOperationQueueInternal : NSObject
{
  @public
  NSMutableArray	*operations;
  BOOL			suspended;
  NSInteger		count;
}
@end

@implementation NSOperationQueueInternal : NSObject
/* As long as this class does nothing but act as a container for ivars,
 * we can easily remove it at a later date using a global substitution
 * to replace all the code of the form 'internal->ivar' with 'ivar'.
 */
@end

@implementation NSOperationQueue

#undef	internal
#define	internal	((NSOperationQueueInternal*)_internal)

- (void) dealloc
{
  if (_internal != nil)
    {
      [internal->operations release];
      [_internal release];
    }
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _internal = [NSOperationQueueInternal new];
      internal->suspended = NO;
      internal->count = NSOperationQueueDefaultMaxConcurrentOperationCount;
      internal->operations = [NSMutableArray new];
    }
  return self;
}

// status
- (BOOL) isSuspended
{
  return internal->suspended;
}

- (void) setSuspended: (BOOL)flag
{
  internal->suspended = flag;
}

- (NSInteger) maxConcurrentOperationCount
{
  return internal->count;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
  internal->count = cnt;
}

// operations
- (void) addOperation: (NSOperation *) op
{
  [internal->operations addObject: op];
}

- (NSArray *) operations
{
  return [NSArray arrayWithArray: internal->operations];
}

- (void) cancelAllOperations
{
  NSEnumerator *en = [internal->operations objectEnumerator];
  id o = nil;

  while ((o = [en nextObject]) != nil )
    {
      [o cancel];
    }
}

- (void) waitUntilAllOperationsAreFinished
{
  // not yet implemented...
}
@end
