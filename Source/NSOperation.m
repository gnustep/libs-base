/**Implementation for NSOperation for GNUStep
   Copyright (C) 2008-2023 Free Software Foundation, Inc.

   Written by:  Gregory Casamento <greg.casamento@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   <title>NSOperation class reference</title>
   Created: 2008-06-08 11:38:33 +0100 (Sun, 08 Jun 2008)
   */
#import "common.h"
#if GS_USE_LIBDISPATCH == 1
#include "dispatch/dispatch.h"
#endif

#import "Foundation/NSLock.h"

#define	GS_NSOperation_IVARS \
  NSRecursiveLock *lock; \
  NSConditionLock *cond; \
  NSOperationQueuePriority priority; \
  double threadPriority; \
  BOOL cancelled; \
  BOOL concurrent; \
  BOOL executing; \
  BOOL finished; \
  BOOL blocked; \
  BOOL ready; \
  NSMutableArray *dependencies; \
  id completionBlock;

#define	GS_NSOperationQueue_IVARS \
  NSRecursiveLock	*lock; \
  NSMutableArray	*operations; \
  NSMutableArray	*waiting; \
  NSString		*name; \
  BOOL			suspended; \
  NSInteger		executing; \
  NSInteger		maxThreads; \
  id			queueImpl;

#import "Foundation/NSOperation.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/NSArray+GNUstepBase.h"
#import "GSPrivate.h"
#import "GSDispatch.h"

#define	GSInternal	NSOperationInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSOperation)

static void     *isFinishedCtxt = (void*)"isFinished";
static void     *isReadyCtxt = (void*)"isReady";
static void     *queuePriorityCtxt = (void*)"queuePriority";

@interface	NSOperation (Private)
- (void) _finish;
- (void) _updateReadyState;
@end


static const NSInteger GSOperationInitialCondition = 0;
static const NSInteger GSOperationFinishedCondition = 1;

@implementation NSOperation

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
  /* Handle all KVO manually
   */
  return NO;
}

- (void) addDependency: (NSOperation *)op
{
  if (NO == [op isKindOfClass: [NSOperation class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] dependency is not an NSOperation",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (op == self)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] attempt to add dependency on self",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  [internal->lock lock];
  if (internal->dependencies == nil)
    {
      internal->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
  NS_DURING
    {
      if (NSNotFound == [internal->dependencies indexOfObjectIdenticalTo: op])
	{
	  [self willChangeValueForKey: @"dependencies"];
          [internal->dependencies addObject: op];
	  /* We only need to watch for changes if it's possible for them to
	   * happen and make a difference.
	   */
	  if (NO == [op isFinished]
	    && NO == [self isCancelled]
	    && NO == [self isExecuting]
	    && NO == [self isFinished])
	    {
	      /* Can change readiness if we are neither cancelled nor
	       * executing nor finished.  So we need to observe for the
	       * finish of the dependency.
	       */
	      [op addObserver: self
		   forKeyPath: @"isFinished"
		      options: NSKeyValueObservingOptionNew
		      context: isFinishedCtxt];
	      if (internal->ready == YES)
		{
		  /* The new dependency stops us being ready ...
		   * change state.
		   */
		  [self willChangeValueForKey: @"isReady"];
		  internal->ready = NO;
		  [self didChangeValueForKey: @"isReady"];
		}
	    }
	  [self didChangeValueForKey: @"dependencies"];
	}
    }
  NS_HANDLER
    {
      [internal->lock unlock];
      NSLog(@"Problem adding dependency: %@", localException);
      return;
    }
  NS_ENDHANDLER
  [internal->lock unlock];
}

- (void) cancel
{
  if (NO == internal->cancelled && NO == [self isFinished])
    {
      [internal->lock lock];
      if (NO == internal->cancelled && NO == [self isFinished])
	{
	  NS_DURING
	    {
	      [self willChangeValueForKey: @"isCancelled"];
	      internal->cancelled = YES;
	      if (NO == internal->ready)
		{
	          [self willChangeValueForKey: @"isReady"];
		  internal->ready = YES;
	          [self didChangeValueForKey: @"isReady"];
		}
	      [self didChangeValueForKey: @"isCancelled"];
	    }
	  NS_HANDLER
	    {
	      [internal->lock unlock];
	      NSLog(@"Problem cancelling operation: %@", localException);
	      return;
	    }
	  NS_ENDHANDLER
	}
      [internal->lock unlock];
    }
}

- (GSOperationCompletionBlock) completionBlock
{
  return (GSOperationCompletionBlock)internal->completionBlock;
}

- (void) dealloc
{
  /* Only clean up if ivars have been initialised
   */
  if (GS_EXISTS_INTERNAL && internal->lock != nil)
    {
      NSOperation	*op;

      if (!internal->finished)
        {
          [self removeObserver: self forKeyPath: @"isFinished"];
        }
      while ((op = [internal->dependencies lastObject]) != nil)
	{
	  [self removeDependency: op];
	}
      RELEASE(internal->dependencies);
      RELEASE(internal->cond);
      RELEASE(internal->lock);
      RELEASE(internal->completionBlock);
      GS_DESTROY_INTERNAL(NSOperation);
    }
  DEALLOC
}

- (NSArray *) dependencies
{
  NSArray	*a;

  if (internal->dependencies == nil)
    {
      a = [NSArray array];	// OSX return an empty array
    }
  else
    {
      [internal->lock lock];
      a = [NSArray arrayWithArray: internal->dependencies];
      [internal->lock unlock];
    }
  return a;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GS_CREATE_INTERNAL(NSOperation);
      internal->priority = NSOperationQueuePriorityNormal;
      internal->threadPriority = 0.5;
      internal->ready = YES;
      internal->lock = [NSRecursiveLock new];
      [internal->lock setName:
        [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
      internal->cond
	= [[NSConditionLock alloc] initWithCondition: GSOperationInitialCondition];
      [internal->cond setName:
        [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
      [self addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
    }
  return self;
}

- (BOOL) isCancelled
{
  return internal->cancelled;
}

- (BOOL) isExecuting
{
  return internal->executing;
}

- (BOOL) isFinished
{
  return internal->finished;
}

- (BOOL) isConcurrent
{
  return internal->concurrent;
}

- (BOOL) isReady
{
  return internal->ready;
}

- (void) main
{
  return;	// OSX default implementation does nothing
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  NSOperation *op = object;
  if (NO == [op isFinished])
    {
      return;
    }

  if (object == self)
    {
      [internal->lock lock];

      /* We only observe isFinished changes, and we can remove self as an
       * observer once we know the operation has finished since it can never
       * become unfinished.
       */
      [object removeObserver: self forKeyPath: @"isFinished"];

      /* Concurrent operations: Call completion block and set internal finished
       * state so we don't try removing the observer again in -dealloc. */
      if (YES == [self isConcurrent])
        {
          internal->finished = YES;
          CALL_BLOCK_NO_ARGS(
            ((GSOperationCompletionBlock)internal->completionBlock));
        }

      /* We have finished and need to unlock the condition lock so that
       * any waiting thread can continue.
       */
      [internal->cond lock];
      [internal->cond unlockWithCondition: GSOperationFinishedCondition];

      [internal->lock unlock];
    }
  else
    {
      /* Some dependency has finished ...
       */
      [self _updateReadyState];
    }
}

- (NSOperationQueuePriority) queuePriority
{
  return internal->priority;
}

- (void) removeDependency: (NSOperation *)op
{
  [internal->lock lock];
  NS_DURING
    {
      if (NSNotFound != [internal->dependencies indexOfObjectIdenticalTo: op])
	{
	  [op removeObserver: self forKeyPath: @"isFinished"];
	  [self willChangeValueForKey: @"dependencies"];
	  [internal->dependencies removeObject: op];
	  if (NO == internal->ready)
	    {
	      /* The dependency may cause us to become ready ...
	       */
	      [self _updateReadyState];
	    }
	  [self didChangeValueForKey: @"dependencies"];
	}
    }
  NS_HANDLER
    {
      [internal->lock unlock];
      NSLog(@"Problem removing dependency: %@", localException);
      return;
    }
  NS_ENDHANDLER
  [internal->lock unlock];
}

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
{
  ASSIGNCOPY(internal->completionBlock, (id)aBlock);
}

- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
  if (pri <= NSOperationQueuePriorityVeryLow)
    pri = NSOperationQueuePriorityVeryLow;
  else if (pri <= NSOperationQueuePriorityLow)
    pri = NSOperationQueuePriorityLow;
  else if (pri < NSOperationQueuePriorityHigh)
    pri = NSOperationQueuePriorityNormal;
  else if (pri < NSOperationQueuePriorityVeryHigh)
    pri = NSOperationQueuePriorityHigh;
  else
    pri = NSOperationQueuePriorityVeryHigh;

  if (pri != internal->priority)
    {
      [internal->lock lock];
      if (pri != internal->priority)
	{
	  NS_DURING
	    {
	      [self willChangeValueForKey: @"queuePriority"];
	      internal->priority = pri;
	      [self didChangeValueForKey: @"queuePriority"];
	    }
	  NS_HANDLER
	    {
	      [internal->lock unlock];
	      NSLog(@"Problem setting priority: %@", localException);
	      return;
	    }
	  NS_ENDHANDLER
	}
      [internal->lock unlock];
    }
}

- (void) setThreadPriority: (double)pri
{
  if (pri > 1) pri = 1;
  else if (pri < 0) pri = 0;
  internal->threadPriority = pri;
}

- (void) start
{
  ENTER_POOL

  double	prio = [NSThread  threadPriority];

  AUTORELEASE(RETAIN(self));	// Make sure we exist while running.
  [internal->lock lock];
  NS_DURING
    {
      if (YES == [self isExecuting])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] called on executing operation",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
      if (YES == [self isFinished])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] called on finished operation",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
      if (NO == [self isReady])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] called on operation which is not ready",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
      if (NO == internal->executing)
	{
	  [self willChangeValueForKey: @"isExecuting"];
	  internal->executing = YES;
	  [self didChangeValueForKey: @"isExecuting"];
	}
    }
  NS_HANDLER
    {
      [internal->lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [internal->lock unlock];

  NS_DURING
    {
      if (NO == [self isCancelled])
	{
	  [NSThread setThreadPriority: internal->threadPriority];
	  [self main];
	}
    }
  NS_HANDLER
    {
      [NSThread setThreadPriority:  prio];
      [localException raise];
    }
  NS_ENDHANDLER;

  [self _finish];
  LEAVE_POOL
}

- (double) threadPriority
{
  return internal->threadPriority;
}

- (void) waitUntilFinished
{
  // Wait for finish
  [internal->cond lockWhenCondition: GSOperationFinishedCondition]; 
  
  // Signal any other watchers
  [internal->cond unlockWithCondition: GSOperationFinishedCondition];
}
@end

@implementation	NSOperation (Private)
/* NB code calling this method must ensure that the receiver is retained
 * until after the method returns.
 */
- (void) _finish
{
  [internal->lock lock];
  if (NO == internal->finished)
    {
      if (YES == internal->executing)
        {
	  [self willChangeValueForKey: @"isExecuting"];
	  [self willChangeValueForKey: @"isFinished"];
	  internal->executing = NO;
	  internal->finished = YES;
	  [self didChangeValueForKey: @"isFinished"];
	  [self didChangeValueForKey: @"isExecuting"];
	}
      else
	{
	  [self willChangeValueForKey: @"isFinished"];
	  internal->finished = YES;
	  [self didChangeValueForKey: @"isFinished"];
	}
      CALL_BLOCK_NO_ARGS(
	((GSOperationCompletionBlock)internal->completionBlock));
    }
  [internal->lock unlock];
}

- (void) _updateReadyState
{
  [internal->lock lock];
  if (NO == internal->ready)
    {
      NSEnumerator	*en;
      NSOperation	*op;

      /* After a dependency has finished or was removed we need to check
       * to see if we are now ready.
       * This is protected by locks so that an update due to an observed
       * change in one thread won't interrupt anything in another thread.
       */
      en = [internal->dependencies objectEnumerator];
      while ((op = [en nextObject]) != nil)
        {
          if (NO == [op isFinished])
            break;
        }
      if (op == nil)
        {
          [self willChangeValueForKey: @"isReady"];
          internal->ready = YES;
          [self didChangeValueForKey: @"isReady"];
        }
    }
  [internal->lock unlock];
}

@end


@implementation NSBlockOperation

+ (instancetype) blockOperationWithBlock: (GSBlockOperationBlock)block
{
  NSBlockOperation *op = [[self alloc] init];

  [op addExecutionBlock: block];
  return AUTORELEASE(op);
}

- (void) addExecutionBlock: (GSBlockOperationBlock)block
{
  id	blockCopy = (id)Block_copy(block);

  [_executionBlocks addObject: blockCopy];
  RELEASE(blockCopy);
}

- (void) dealloc
{
  RELEASE(_executionBlocks);
  DEALLOC
}

- (NSArray *) executionBlocks
{
  return _executionBlocks;
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _executionBlocks = [[NSMutableArray alloc] initWithCapacity: 1];
    }
  return self;
}

- (void) main
{
  NSEnumerator 		*en = [_executionBlocks objectEnumerator];
  GSBlockOperationBlock theBlock;

  while ((theBlock = (GSBlockOperationBlock)[en nextObject]) != NULL)
    {
      CALL_NON_NULL_BLOCK_NO_ARGS(theBlock);
    }

  [_executionBlocks removeAllObjects];
}
@end


#undef	GSInternal
#define	GSInternal	NSOperationQueueInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSOperationQueue)


@interface	NSOperationQueue (Private)
- (void) _execute;
- (void) _main: (NSOperation *)op;

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
@end

@interface GSOperationQueueImpl : NSObject
{
@protected
  NSOperationQueue *_queue;
}
- (id) initWithQueue: (NSOperationQueue *)queue;
- (void) execute;
- (void) setInternalQueueName: (NSString *)name;
- (void) initAsMainQueue;
@end

@interface GSThreadOperationQueueImpl : GSOperationQueueImpl
{
  NSConditionLock *_cond;
  NSMutableArray *_starting;
  NSString *_threadName;
  NSInteger _threadCount;
}
@end

#if GS_USE_LIBDISPATCH == 1
@interface GSDispatchOperationQueueImpl : GSOperationQueueImpl
{
  dispatch_queue_t _underlyingQueue;
  BOOL _ownsUnderlyingQueue;
}
- (dispatch_queue_t) underlyingQueue;
@end
#endif

static NSInteger	maxConcurrent = 8;	// Thread pool size

static NSComparisonResult
compareByQueuePriority(id op1, id op2, void *ctxt)
{
  NSOperationQueuePriority p1 = [op1 queuePriority];
  NSOperationQueuePriority p2 = [op2 queuePriority];

  if (p1 < p2) return NSOrderedDescending;
  if (p1 > p2) return NSOrderedAscending;
  return NSOrderedSame;
}

static NSString	*threadKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation GSOperationQueueImpl

- (void) dealloc
{
  _queue = nil;
  [super dealloc];
}

- (id) initWithQueue: (NSOperationQueue *)queue
{
  if ((self = [super init]) != nil)
    {
      _queue = queue;
    }
  return self;
}

- (void) execute
{
}

- (void) setInternalQueueName: (NSString *)name
{
}

- (void) initAsMainQueue
{
}

@end

#if GS_USE_LIBDISPATCH == 1
/* Function passed to dispatch_async_f to execute a NSOperation */
static void dispatchQueueExecuteOperation(void *context);

@implementation GSDispatchOperationQueueImpl

- (void) dealloc
{
  if (YES == _ownsUnderlyingQueue)
    {
      dispatch_release(_underlyingQueue);
    }
  [super dealloc];
}

- (id) initWithQueue: (NSOperationQueue *)queue
{
  if ((self = [super initWithQueue: queue]) != nil)
    {
      _underlyingQueue = dispatch_queue_create(
	[[queue name] UTF8String], DISPATCH_QUEUE_CONCURRENT);
      _ownsUnderlyingQueue = YES;
    }
  return self;
}

- (void) execute
{
  NSInteger	max;
  NSMutableArray *operationsToStart = nil;
  NSOperationQueue *queue = _queue;

  [GSIVar(queue, lock) lock];

  max = [queue maxConcurrentOperationCount];
  if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
      max = maxConcurrent;
    }

  NS_DURING
  while (NO == [queue isSuspended]
    && max > GSIVar(queue, executing)
    && [GSIVar(queue, waiting) count] > 0)
    {
      NSOperation	*op;

      op = [GSIVar(queue, waiting) objectAtIndex: 0];
      [GSIVar(queue, waiting) removeObjectAtIndex: 0];
      [op removeObserver: queue forKeyPath: @"queuePriority"];
      [op addObserver: queue
	   forKeyPath: @"isFinished"
	      options: NSKeyValueObservingOptionNew
	      context: isFinishedCtxt];
      GSIVar(queue, executing)++;
      if (nil == operationsToStart)
	{
	  operationsToStart = [NSMutableArray new];
	}
      [operationsToStart addObject: op];
    }
  NS_HANDLER
    {
      [GSIVar(queue, lock) unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [GSIVar(queue, lock) unlock];

  if (nil != operationsToStart)
    {
      GS_FOR_IN(NSOperation *, op, operationsToStart)
	{
	  NSArray *context = [[NSArray alloc] initWithObjects: queue, op, nil];
	  dispatch_async_f(_underlyingQueue, context,
	    dispatchQueueExecuteOperation);
	}
      GS_END_FOR(operationsToStart)
      RELEASE(operationsToStart);
    }
}

- (dispatch_queue_t) underlyingQueue
{
  return _underlyingQueue;
}

- (void) setUnderlyingQueue: (dispatch_queue_t) dispatchQueue
{
  [GSIVar(_queue, lock) lock];
  NS_DURING
    {
      if ([GSIVar(_queue, operations) count] > 0)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Cannot set underlyingQueue while operations are enqueued."];
        }
      if (dispatchQueue == dispatch_get_main_queue())
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"underlyingQueue must not be dispatch_get_main_queue()."];
        }
      if (dispatchQueue == NULL)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"underlyingQueue must not be NULL."];
        }

      dispatch_retain(dispatchQueue);
      if (YES == _ownsUnderlyingQueue && _underlyingQueue != NULL)
        {
          dispatch_release(_underlyingQueue);
        }
      _underlyingQueue = dispatchQueue;
      _ownsUnderlyingQueue = YES;
    }
  NS_HANDLER
    {
      [GSIVar(_queue, lock) unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [GSIVar(_queue, lock) unlock];
}

- (void) initAsMainQueue
{
  if (YES == _ownsUnderlyingQueue && _underlyingQueue != NULL)
    {
      dispatch_release(_underlyingQueue);
    }
  _underlyingQueue = dispatch_get_main_queue();
  _ownsUnderlyingQueue = NO;
}

@end

/* Function passed to dispatch_async_f to execute a NSOperation */
static void
dispatchQueueExecuteOperation(void *context)
{
  NSArray *a = (NSArray *)context;
  NSOperationQueue *queue = (NSOperationQueue *)[a objectAtIndex: 0];
  NSOperation *op = (NSOperation *)[a objectAtIndex: 1];

  [queue _main: op];
  RELEASE(a);
}
#endif

@implementation NSOperationQueue

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
      mainQueue = [[self alloc] _initMainQueue];
      [mainQueue setMaxConcurrentOperationCount: 1];
    }
}

+ (id) mainQueue
{
  return mainQueue;
}

#if GS_USE_LIBDISPATCH == 1 && OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
- (dispatch_queue_t) underlyingQueue
{
  return [(GSDispatchOperationQueueImpl *)internal->queueImpl underlyingQueue];
}

- (void) setUnderlyingQueue: (dispatch_queue_t)dispatchQueue
{
  [(GSDispatchOperationQueueImpl *)internal->queueImpl
    setUnderlyingQueue: dispatchQueue];
}
#endif

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

- (void) addOperationWithBlock: (GSBlockOperationBlock)block
{
  NSBlockOperation *bop = [NSBlockOperation blockOperationWithBlock: block];
  [self addOperation: bop];
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
  if (GS_EXISTS_INTERNAL && internal->lock != nil)
    {
      [self cancelAllOperations];
      DESTROY(internal->operations);
      DESTROY(internal->waiting);
      DESTROY(internal->name);
      DESTROY(internal->queueImpl);
      DESTROY(internal->lock);
      GS_DESTROY_INTERNAL(NSOperationQueue);
    }
  DEALLOC
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GS_CREATE_INTERNAL(NSOperationQueue);
      internal->suspended = NO;
      internal->maxThreads = NSOperationQueueDefaultMaxConcurrentOperationCount;
      internal->operations = [NSMutableArray new];
      internal->waiting = [NSMutableArray new];
      internal->lock = [NSRecursiveLock new];
      [internal->lock setName:
        [NSString stringWithFormat: @"lock-for-op-%p", self]];
      internal->name
	= [[NSString alloc] initWithFormat: @"NSOperationQueue %p", self];
#if GS_USE_LIBDISPATCH == 1
      internal->queueImpl
	= [[GSDispatchOperationQueueImpl alloc] initWithQueue: self];
#else
      internal->queueImpl
	= [[GSThreadOperationQueueImpl alloc] initWithQueue: self];
#endif
      [internal->queueImpl setInternalQueueName: internal->name];
    }
  return self;
}

- (id) _initMainQueue
{
  if ((self = [self init]) != nil)
    {
      [internal->lock lock];
      internal->maxThreads = 1;
      [internal->queueImpl initAsMainQueue];
      [internal->lock unlock];
    }
  return self;
}

- (BOOL) isSuspended
{
  return internal->suspended;
}

- (NSInteger) maxConcurrentOperationCount
{
  return internal->maxThreads;
}

- (NSString*) name
{
  NSString	*s;

  [internal->lock lock];
  s = [internal->name copy];
  [internal->lock unlock];

  return AUTORELEASE(s);
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
  if (self == mainQueue)
    {
      cnt = 1;
    }
  if (cnt < 0
    && cnt != NSOperationQueueDefaultMaxConcurrentOperationCount)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] cannot set negative (%"PRIdPTR") count",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd), cnt];
    }
  [internal->lock lock];
  if (cnt != internal->maxThreads)
    {
      [self willChangeValueForKey: @"maxConcurrentOperationCount"];
      internal->maxThreads = cnt;
      [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
  [internal->lock unlock];
  [self _execute];
}

- (void) setName: (NSString*)s
{
  if (s == nil) return;

  [internal->lock lock];
  if (NO == [internal->name isEqual: s])
    {
      [self willChangeValueForKey: @"name"];
      RELEASE(internal->name);
      internal->name = [s copy];
      [internal->queueImpl setInternalQueueName: internal->name];
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
      RETAIN(op);
      [internal->lock unlock];
      [op waitUntilFinished];
      RELEASE(op);
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
      NSOperation *op = object;
      if (YES == [op isFinished])
        {
          [internal->lock lock];
          internal->executing--;
          [object removeObserver: self forKeyPath: @"isFinished"];
          [internal->lock unlock];
          [self willChangeValueForKey: @"operations"];
          [self willChangeValueForKey: @"operationCount"];
          [internal->lock lock];
          [internal->operations removeObjectIdenticalTo: object];
          [internal->lock unlock];
          [self didChangeValueForKey: @"operationCount"];
          [self didChangeValueForKey: @"operations"];
        }
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
                                   usingFunction: compareByQueuePriority
                                         context: 0];
      [internal->waiting insertObject: object atIndex: pos];
      [internal->lock unlock];
    }
  [self _execute];
}

- (void) _main: (NSOperation *)op
{
  BOOL	concurrent;
#if GS_USE_LIBDISPATCH == 1
  NSMutableDictionary *threadDictionary;
#endif

  concurrent = [op isConcurrent];
#if GS_USE_LIBDISPATCH == 1
  threadDictionary = [[NSThread currentThread] threadDictionary];
  [threadDictionary setObject: self forKey: threadKey];
#endif
  NS_DURING
    {
      ENTER_POOL
      [op start];
      LEAVE_POOL
    }
  NS_HANDLER
    {
      NSLog(@"Problem running operation %@ ... %@",
	op, localException);
    }
  NS_ENDHANDLER
  if (NO == concurrent)
    {
      [op _finish];
    }
}

/* Check for operations which can be executed and start them.
 */
- (void) _execute
{
  [internal->queueImpl execute];
}

- (void) _thread: (NSNumber *) threadNumber
{
  [internal->queueImpl _thread: threadNumber];
}

@end

static const NSInteger GSThreadQueueIdleCondition = 0;
static const NSInteger GSThreadQueueHasWorkCondition = 1;

@implementation GSThreadOperationQueueImpl

- (void) dealloc
{
  DESTROY(_starting);
  DESTROY(_cond);
  [super dealloc];
}

- (id) initWithQueue: (NSOperationQueue *)queue
{
  if ((self = [super initWithQueue: queue]) != nil)
    {
      _starting = [NSMutableArray new];
      _cond = [[NSConditionLock alloc] initWithCondition:
	GSThreadQueueIdleCondition];
      [_cond setName:
	[NSString stringWithFormat: @"cond-for-op-%p", queue]];

       /* Ensure that default thread name can be displayed on systems with a
        * limited thread name length.
        *
        * This value is set to internal->name, when altered with -setName:
        * Worker threads are not renamed during their lifetime.
        */
      _threadName = @"NSOperationQ";
      _threadCount = 0;
    }
  return self;
}

- (void) _thread: (NSNumber *) threadNumber
{
  NSString *tName;
  NSThread *current;
  NSOperationQueue *queue = _queue;

  CREATE_AUTORELEASE_POOL(arp);

  current = [NSThread currentThread];

  [GSIVar(queue, lock) lock];
  tName = [_threadName stringByAppendingFormat: @"_%@", threadNumber];
  [GSIVar(queue, lock) unlock];

  [[current threadDictionary] setObject: queue forKey: threadKey];
  [current setName: tName];

  for (;;)
    {
      NSOperation	*op;
      NSDate		*when;
      BOOL		found;
      RECREATE_AUTORELEASE_POOL(arp);

      /* Wait up to five seconds for work to be added to `_starting`. */
      when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
      found = [_cond lockWhenCondition: GSThreadQueueHasWorkCondition
			     beforeDate: when];
      RELEASE(when);
      if (NO == found)
	{
	  [_cond lock];
	  if ([_starting count] == 0)
	    {
	      /* Still no work after timeout: remove queue mapping and exit. */
	      [_cond unlock];
	      [[[NSThread currentThread] threadDictionary]
		removeObjectForKey: threadKey];
	      [GSIVar(queue, lock) lock];
	      _threadCount--;
	      [GSIVar(queue, lock) unlock];
	      break;
	    }
	}

      if ([_starting count] > 0)
	{
          op = RETAIN([_starting objectAtIndex: 0]);
	  [_starting removeObjectAtIndex: 0];
	}
      else
	{
	  op = nil;
	}

      if ([_starting count] > 0)
	{
          [_cond unlockWithCondition: GSThreadQueueHasWorkCondition];
	}
      else
	{
          [_cond unlockWithCondition: GSThreadQueueIdleCondition];
	}

      if (nil != op)
	{
          NS_DURING
	    {
	      ENTER_POOL
              /* Execute on this worker thread using the operation's
               * configured thread priority.
               */
              [NSThread setThreadPriority: [op threadPriority]];
              [op start];
	      LEAVE_POOL
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

  DESTROY(arp);
  [NSThread exit];
}

- (void) execute
{
  NSInteger	max;
  NSMutableArray *mainQueueOperations = nil;
  NSOperationQueue *queue = _queue;

  [GSIVar(queue, lock) lock];

  max = [queue maxConcurrentOperationCount];
  if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
      max = maxConcurrent;
    }

  NS_DURING
  while (NO == [queue isSuspended]
    && max > GSIVar(queue, executing)
    && [GSIVar(queue, waiting) count] > 0)
    {
      NSOperation	*op;

      op = [GSIVar(queue, waiting) objectAtIndex: 0];
      [GSIVar(queue, waiting) removeObjectAtIndex: 0];
      [op removeObserver: queue forKeyPath: @"queuePriority"];
      [op addObserver: queue
	   forKeyPath: @"isFinished"
	      options: NSKeyValueObservingOptionNew
	      context: isFinishedCtxt];
      GSIVar(queue, executing)++;
      if (queue == mainQueue)
	{
	  if (nil == mainQueueOperations)
	    {
	      mainQueueOperations = [NSMutableArray new];
	    }
	  [mainQueueOperations addObject: op];
	}
      else if (YES == [op isConcurrent])
	{
	  [op start];
	}
      else
	{
	  [_cond lock];
	  [_starting addObject: op];

	  if (_threadCount < max)
	    {
	      NSInteger	count = _threadCount++;
	      NSNumber 	*threadNumber = [NSNumber numberWithInteger: count];

	      NS_DURING
		{
		  [NSThread detachNewThreadSelector: @selector(_thread:)
					   toTarget: queue
					 withObject: threadNumber];
		}
	      NS_HANDLER
		{
		  NSLog(@"Failed to create thread %@ for %@: %@",
		    threadNumber, queue, localException);
		  --_threadCount;
		}
	      NS_ENDHANDLER
	    }
	  [_cond unlockWithCondition: GSThreadQueueHasWorkCondition];
	}
    }
  NS_HANDLER
    {
      [GSIVar(queue, lock) unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [GSIVar(queue, lock) unlock];

  if (nil != mainQueueOperations)
    {
      GS_FOR_IN(NSOperation *, op, mainQueueOperations)
	{
	  [queue performSelectorOnMainThread: @selector(_main:)
				  withObject: op
			       waitUntilDone: NO];
	}
      GS_END_FOR(mainQueueOperations)
      RELEASE(mainQueueOperations);
    }
}

- (void) setInternalQueueName: (NSString *)name
{
  _threadName = name;
}

@end
