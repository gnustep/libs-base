/**Implementation for NSOperation for GNUStep
   Copyright (C) 2009,2010 Free Software Foundation, Inc.

   Written by:  Gregory Casamento <greg.casamento@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2009,2010

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

   <title>NSOperation class reference</title>
   $Date: 2008-06-08 11:38:33 +0100 (Sun, 08 Jun 2008) $ $Revision: 26606 $
   */

#import "common.h"

#import "GNUstepBase/GSOperation.h"

@implementation GSOperation

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
  /* Handle all KVO manually
   */
  return NO;
}

+ (void) initialize
{
  empty = [NSArray new];
  [[NSObject leakAt: &empty] release];
}

- (void) dealloc
{
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
    }
  return self;
}
@end

#undef	GSInternal
#define	GSInternal	NSOperationQueueInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSOperationQueue)

@interface	NSOperationQueue (Private)
- (void) _execute;
- (void) _thread;
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
@end

static NSInteger	maxConcurrent = 200;	// Thread pool size

static NSComparisonResult
sortFunc(id o1, id o2, void *ctxt)
{
  NSOperationQueuePriority p1 = [o1 queuePriority];
  NSOperationQueuePriority p2 = [o2 queuePriority];

  if (p1 < p2) return NSOrderedDescending;
  if (p1 > p2) return NSOrderedAscending;
  return NSOrderedSame;
}

static NSString	*threadKey = @"GSDispatchOperationQueue";
static GSOperationQueue *mainQueue = nil;

@implementation GSDispatchOperationQueue

+ (id) currentQueue
{
  if ([NSThread isMainThread])
    {
      return mainQueue;
    }
  return [[[NSThread currentThread] threadDictionary] objectForKey: threadKey];
}

+ (void) initialize
{
  if (nil == mainQueue)
    {
      mainQueue = [self new];
    }
}

+ (id) mainQueue
{
  return mainQueue;
}

- (void) addOperation: (NSOperation *)op
{
  if (op == nil || NO == [op isKindOfClass: [NSOperation class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] object is not an NSOperation",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  [internal->lock lock];
  if (NSNotFound == [internal->operations indexOfObjectIdenticalTo: op]
    && NO == [op isFinished])
    {
      [op addObserver: self
	   forKeyPath: @"isReady"
	      options: NSKeyValueObservingOptionNew
	      context: isReadyCtxt];
      [self willChangeValueForKey: @"operations"];
      [self willChangeValueForKey: @"operationCount"];
      [internal->operations addObject: op];
      [self didChangeValueForKey: @"operationCount"];
      [self didChangeValueForKey: @"operations"];
      if (YES == [op isReady])
	{
	  [self observeValueForKeyPath: @"isReady"
			      ofObject: op
				change: nil
			       context: isReadyCtxt];
	}
    }
  [internal->lock unlock];
}

- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait
{
  NSUInteger	total;
  NSUInteger	index;

  if (ops == nil || NO == [ops isKindOfClass: [NSArray class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] object is not an NSArray",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  total = [ops count];
  if (total > 0)
    {
      BOOL		invalidArg = NO;
      NSUInteger	toAdd = total;
      GS_BEGINITEMBUF(buf, total, id)

      [ops getObjects: buf];
      for (index = 0; index < total; index++)
	{
	  NSOperation	*op = buf[index];

	  if (NO == [op isKindOfClass: [NSOperation class]])
	    {
	      invalidArg = YES;
	      toAdd = 0;
	      break;
	    }
	  if (YES == [op isFinished])
	    {
	      buf[index] = nil;
	      toAdd--;
	    }
	}
      if (toAdd > 0)
	{
          [internal->lock lock];
	  [self willChangeValueForKey: @"operationCount"];
	  [self willChangeValueForKey: @"operations"];
	  for (index = 0; index < total; index++)
	    {
	      NSOperation	*op = buf[index];

	      if (op == nil)
		{
		  continue;		// Not added
		}
	      if (NSNotFound
		!= [internal->operations indexOfObjectIdenticalTo: op])
		{
		  buf[index] = nil;	// Not added
		  toAdd--;
		  continue;
		}
	      [op addObserver: self
		   forKeyPath: @"isReady"
		      options: NSKeyValueObservingOptionNew
		      context: isReadyCtxt];
	      [internal->operations addObject: op];
	      if (NO == [op isReady])
		{
		  buf[index] = nil;	// Not yet ready
		}
	    }
	  [self didChangeValueForKey: @"operationCount"];
	  [self didChangeValueForKey: @"operations"];
	  for (index = 0; index < total; index++)
	    {
	      NSOperation	*op = buf[index];

	      if (op != nil)
		{
		  [self observeValueForKeyPath: @"isReady"
				      ofObject: op
					change: nil
				       context: isReadyCtxt];
		}
	    }
          [internal->lock unlock];
	}
      GS_ENDITEMBUF()
      if (YES == invalidArg)
	{
	  [NSException raise: NSInvalidArgumentException
	    format: @"[%@-%@] object at index %"PRIuPTR" is not an NSOperation",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd),
	    index];
	}
    }
  if (YES == shouldWait)
    {
      [self waitUntilAllOperationsAreFinished];
    }
}

- (void) cancelAllOperations
{
  [[self operations] makeObjectsPerformSelector: @selector(cancel)];
}

- (void) dealloc
{
  [self cancelAllOperations];
  DESTROY(internal->operations);
  DESTROY(internal->starting);
  DESTROY(internal->waiting);
  DESTROY(internal->name);
  DESTROY(internal->cond);
  DESTROY(internal->lock);
  GS_DESTROY_INTERNAL(NSOperationQueue);
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GS_CREATE_INTERNAL(NSOperationQueue);
      internal->suspended = NO;
      internal->count = NSOperationQueueDefaultMaxConcurrentOperationCount;
      internal->operations = [NSMutableArray new];
      internal->starting = [NSMutableArray new];
      internal->waiting = [NSMutableArray new];
      internal->lock = [NSRecursiveLock new];
      [internal->lock setName:
        [NSString stringWithFormat: @"lock-for-op-%p", self]];
      internal->cond = [[NSConditionLock alloc] initWithCondition: 0];
      [internal->cond setName:
        [NSString stringWithFormat: @"cond-for-op-%p", self]];
    }
  return self;
}

- (BOOL) isSuspended
{
  return internal->suspended;
}

- (NSInteger) maxConcurrentOperationCount
{
  return internal->count;
}

- (NSString*) name
{
  NSString	*s;

  [internal->lock lock];
  if (internal->name == nil)
    {
      internal->name
	= [[NSString alloc] initWithFormat: @"NSOperation %p", self];
    }
  s = [internal->name retain];
  [internal->lock unlock];
  return [s autorelease];
}

- (NSUInteger) operationCount
{
  NSUInteger	c;

  [internal->lock lock];
  c = [internal->operations count];
  [internal->lock unlock];
  return c;
}

- (NSArray *) operations
{
  NSArray	*a;

  [internal->lock lock];
  a = [NSArray arrayWithArray: internal->operations];
  [internal->lock unlock];
  return a;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
  if (cnt < 0
    && cnt != NSOperationQueueDefaultMaxConcurrentOperationCount)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] cannot set negative (%"PRIdPTR") count",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd), cnt];
    }
  [internal->lock lock];
  if (cnt != internal->count)
    {
      [self willChangeValueForKey: @"maxConcurrentOperationCount"];
      internal->count = cnt;
      [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
  [internal->lock unlock];
  [self _execute];
}

- (void) setName: (NSString*)s
{
  if (s == nil) s = @"";
  [internal->lock lock];
  if (NO == [internal->name isEqual: s])
    {
      [self willChangeValueForKey: @"name"];
      [internal->name release];
      internal->name = [s copy];
      [self didChangeValueForKey: @"name"];
    }
  [internal->lock unlock];
}

- (void) setSuspended: (BOOL)flag
{
  [internal->lock lock];
  if (flag != internal->suspended)
    {
      [self willChangeValueForKey: @"suspended"];
      internal->suspended = flag;
      [self didChangeValueForKey: @"suspended"];
    }
  [internal->lock unlock];
  [self _execute];
}

- (void) waitUntilAllOperationsAreFinished
{
  NSOperation	*op;

  [internal->lock lock];
  while ((op = [internal->operations lastObject]) != nil)
    {
      [op retain];
      [internal->lock unlock];
      [op waitUntilFinished];
      [op release];
      [internal->lock lock];
    }
  [internal->lock unlock];
}
@end

@implementation	NSOperationQueue (Private)

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  /* We observe three properties in sequence ...
   * isReady (while we wait for an operation to be ready)
   * queuePriority (when priority of a ready operation may change)
   * isFinished (to see if an executing operation is over).
   */
  if (context == isFinishedCtxt)
    {
      [internal->lock lock];
      internal->executing--;
      [object removeObserver: self
		  forKeyPath: @"isFinished"];
      [internal->lock unlock];
      [self willChangeValueForKey: @"operations"];
      [self willChangeValueForKey: @"operationCount"];
      [internal->lock lock];
      [internal->operations removeObjectIdenticalTo: object];
      [internal->lock unlock];
      [self didChangeValueForKey: @"operationCount"];
      [self didChangeValueForKey: @"operations"];
    }
  else if (context == queuePriorityCtxt || context == isReadyCtxt)
    {
      NSInteger pos;

      [internal->lock lock];
      if (context == queuePriorityCtxt)
        {
          [internal->waiting removeObjectIdenticalTo: object];
        }
      if (context == isReadyCtxt)
        {
          [object removeObserver: self forKeyPath: @"isReady"];
          [object addObserver: self
                   forKeyPath: @"queuePriority"
                      options: NSKeyValueObservingOptionNew
                      context: queuePriorityCtxt];
        }
      pos = [internal->waiting insertionPosition: object
                                   usingFunction: sortFunc
                                         context: 0];
      [internal->waiting insertObject: object atIndex: pos];
      [internal->lock unlock];
    }
  [self _execute];
}

- (void) _thread
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];

  [[[NSThread currentThread] threadDictionary] setObject: self
                                                  forKey: threadKey];
  for (;;)
    {
      NSOperation	*op;
      NSDate		*when;
      BOOL		found;

      when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
      found = [internal->cond lockWhenCondition: 1 beforeDate: when];
      RELEASE(when);
      if (NO == found)
	{
	  break;	// Idle for 5 seconds ... exit thread.
	}

      if ([internal->starting count] > 0)
	{
          op = RETAIN([internal->starting objectAtIndex: 0]);
	  [internal->starting removeObjectAtIndex: 0];
	}
      else
	{
	  op = nil;
	}

      if ([internal->starting count] > 0)
	{
	  // Signal any other idle threads,
          [internal->cond unlockWithCondition: 1];
	}
      else
	{
	  // There are no more operations starting.
          [internal->cond unlockWithCondition: 0];
	}

      if (nil != op)
	{
          NS_DURING
	    {
	      NSAutoreleasePool	*opPool = [NSAutoreleasePool new];

	      if (NO == [op isCancelled])
		{
		  [NSThread setThreadPriority: [op threadPriority]];
		  [op main];
		}
	      RELEASE(opPool);
	    }
          NS_HANDLER
	    {
	      NSLog(@"Problem running operation %@ ... %@",
		op, localException);
	    }
          NS_ENDHANDLER
	  [op _finish];
          RELEASE(op);
	}
    }

  [[[NSThread currentThread] threadDictionary] removeObjectForKey: threadKey];
  [internal->lock lock];
  internal->threadCount--;
  [internal->lock unlock];
  RELEASE(pool);
  [NSThread exit];
}

/* Check for operations which can be executed and start them.
 */
- (void) _execute
{
  NSInteger	max;

  [internal->lock lock];

  max = [self maxConcurrentOperationCount];
  if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
      max = maxConcurrent;
    }

  while (NO == [self isSuspended]
    && max > internal->executing
    && [internal->waiting count] > 0)
    {
      NSOperation	*op;

      /* Take the first operation from the queue and start it executing.
       * We set ourselves up as an observer for the operating finishing
       * and we keep track of the count of operations we have started,
       * but the actual startup is left to the NSOperation -start method.
       */
      op = [internal->waiting objectAtIndex: 0];
      [internal->waiting removeObjectAtIndex: 0];
      [op removeObserver: self forKeyPath: @"queuePriority"];
      [op addObserver: self
	   forKeyPath: @"isFinished"
	      options: NSKeyValueObservingOptionNew
	      context: isFinishedCtxt];
      internal->executing++;
      if (YES == [op isConcurrent])
	{
          [op start];
	}
      else
	{
	  NSUInteger	pending;

	  [internal->cond lock];
	  pending = [internal->starting count];
	  [internal->starting addObject: op];

	  /* Create a new thread if all existing threads are busy and
	   * we haven't reached the pool limit.
	   */
	  if (0 == internal->threadCount
	    || (pending > 0 && internal->threadCount < POOL))
	    {
	      internal->threadCount++;
	      [NSThread detachNewThreadSelector: @selector(_thread)
				       toTarget: self
				     withObject: nil];
	    }
	  /* Tell the thread pool that there is an operation to start.
	   */
	  [internal->cond unlockWithCondition: 1];
	}
    }
  [internal->lock unlock];
}

@end

