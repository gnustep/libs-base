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

#import "config.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSThread.h"

#define	GSInternal	NSOperationInternal
#include	"GSInternal.h"
GS_BEGIN_INTERNAL(NSOperation)
  NSRecursiveLock *lock;
  NSConditionLock *cond;
  NSOperationQueuePriority priority;
  double threadPriority;
  BOOL cancelled;
  BOOL concurrent;
  BOOL executing;
  BOOL finished;
  BOOL ready;
  NSMutableArray *dependencies;
GS_END_INTERNAL(NSOperation)

static NSArray	*empty = nil;

@implementation NSOperation : NSObject

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
  /* Handle all KVO manually
   */
  return NO;
}

+ (void) initialize
{
  empty = [NSArray new];
}

- (void) addDependency: (NSOperation *)op
{
  if (NO == [op isKindOfClass: [self class]])
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
		      context: NULL];
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

- (void) dealloc
{
  if (internal != nil)
    {
      NSOperation	*op;

      while ((op = [internal->dependencies lastObject]) != nil)
	{
	  [self removeDependency: op];
	}
      RELEASE(internal->dependencies);
      RELEASE(internal->cond);
      RELEASE(internal->lock);
      GS_DESTROY_INTERNAL(NSOperation);
    }
  [super dealloc];
}

- (NSArray *) dependencies
{
  NSArray	*a;

  if (internal->dependencies == nil)
    {
      a = empty;	// OSX return an empty array
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
      internal->cond = [[NSConditionLock alloc] initWithCondition: 0];
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

- (void) main;
{
  return;	// OSX default implementation does nothing
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  /* Some dependency has finished (or been removed) ...
   * so we need to check to see if we are now ready unless we know we are.
   * This is protected by locks so that an update due to an observed
   * change in one thread won't interrupt anything in another thread.
   */
  [internal->lock lock];
  if (NO == internal->ready)
    {
      NSEnumerator	*en;
      NSOperation	*op;

      en = [internal->dependencies objectEnumerator];
      while ((op = [en nextObject]) != nil)
        {
          if (NO == [op isReady])
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
	  [op removeObserver: self
	          forKeyPath: @"isFinished"];
	  [self willChangeValueForKey: @"dependencies"];
	  [internal->dependencies removeObject: op];
	  if (NO == internal->ready)
	    {
	      /* The dependency may cause us to become ready ...
	       * fake an observation so we can deal with that.
	       */
	      [self observeValueForKeyPath: @"isFinished"
				  ofObject: op
				    change: nil
				   context: nil];
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

- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
  if (pri < NSOperationQueuePriorityVeryLow)
    pri = NSOperationQueuePriorityVeryLow;
  else if (pri < NSOperationQueuePriorityLow)
    pri = NSOperationQueuePriorityLow;
  else if (pri < NSOperationQueuePriorityNormal)
    pri = NSOperationQueuePriorityNormal;
  else if (pri > NSOperationQueuePriorityVeryHigh)
    pri = NSOperationQueuePriorityVeryHigh;
  else if (pri > NSOperationQueuePriorityHigh)
    pri = NSOperationQueuePriorityHigh;
  else if (pri > NSOperationQueuePriorityNormal)
    pri = NSOperationQueuePriorityNormal;

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
  CREATE_AUTORELEASE_POOL(pool);
  double	prio = [NSThread  threadPriority];

  [internal->lock lock];
  NS_DURING
    {
      if (YES == [self isConcurrent])
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"[%@-%@] called on concurrent operation",
	    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
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

      [self willChangeValueForKey: @"isExecuting"];
      internal->executing = YES;
      [self didChangeValueForKey: @"isExecuting"];
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

  [internal->lock lock];
  NS_DURING
    {
      /* Notify KVO system of changes to isExecuting and isFinished
       */
      [self willChangeValueForKey: @"isExecuting"];
      [self willChangeValueForKey: @"isFinished"];
      internal->executing = NO;
      internal->finished = YES;
      [self didChangeValueForKey: @"isFinished"];
      [self didChangeValueForKey: @"isExecuting"];
      [internal->cond lock];
      [internal->cond unlockWithCondition: 1];
    }
  NS_HANDLER
    {
      [internal->lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [internal->lock unlock];
  RELEASE(pool);
}

- (double) threadPriority
{
  return internal->threadPriority;
}

- (void) waitUntilFinished
{
  [internal->cond lockWhenCondition: 1];	// Wait for finish
  [internal->cond unlockWithCondition: 1];	// Signal any other watchers
}
@end


#undef	GSInternal
#define	GSInternal	NSOperationQueueInternal
#include	"GSInternal.h"
GS_BEGIN_INTERNAL(NSOperationQueue)
  NSRecursiveLock	*lock;
  NSConditionLock	*cond;
  NSMutableArray	*operations;
  NSMutableArray	*waiting;
  NSString		*name;
  BOOL			suspended;
  NSInteger		threads;	// number of threads allocated
  NSInteger		idle;		// threads waiting for an op to do
  NSInteger		count;		// max executing operations
GS_END_INTERNAL(NSOperationQueue)


@interface	NSOperationQueue (Private)
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
- (void) _thread;
- (void) _update;
@end

static NSInteger	maxThreads = 200;	// FIXME ... how many really?

static NSComparisonResult
sortFunc(id o1, id o2, void *ctxt)
{
  NSOperationQueuePriority p1 = [o1 queuePriority];
  NSOperationQueuePriority p2 = [o2 queuePriority];
  
  if (p1 < p2) return NSOrderedDescending;
  if (p1 > p2) return NSOrderedAscending;
  return NSOrderedSame;
}

@implementation NSOperationQueue

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
    && NO == [op isCancelled]
    && NO == [op isExecuting]
    && NO == [op isFinished])
    {
      [op addObserver: self
	   forKeyPath: @"isReady"
	      options: NSKeyValueObservingOptionNew
	      context: NULL];
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
			       context: nil];
	}
    }
  [internal->lock unlock];
}

- (void) cancelAllOperations
{
  NSUInteger	index;
  NSOperation	*o;

  [internal->cond lock];
  while ((o = [internal->waiting lastObject]) != nil)
    {
      [o removeObserver: self
	     forKeyPath: @"isReady"];
      [o cancel];
      [internal->waiting removeLastObject];
    }
  [internal->cond unlockWithCondition: 0];	// Nothing waiting to execute

  [internal->lock lock];
  index = [internal->operations count];
  while (index-- > 0)
    {
      NSOperation	*o;

      o = [internal->operations objectAtIndex: index];
      if (NO == [o isCancelled])
	{
          [o removeObserver: self
	         forKeyPath: @"isReady"];
          [o cancel];
	}
    }
  [internal->lock unlock];
}

- (void) dealloc
{
  if (_internal != nil)
    {
      [internal->operations release];
      [internal->waiting release];
      [internal->name release];
      [internal->cond release];
      [internal->lock release];
      GS_DESTROY_INTERNAL(NSOperationQueue);
    }
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
      internal->waiting = [NSMutableArray new];
      internal->cond = [[NSConditionLock alloc] initWithCondition: 0];
      internal->lock = [NSRecursiveLock new];
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
		  format: @"[%@-%@] cannot set negative (%d) count",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd), cnt];
    }
  [internal->lock lock];
  if (cnt != internal->count)
    {
      [self willChangeValueForKey: @"maxConcurrentOperationCount"];
      internal->count = cnt;
      [self didChangeValueForKey: @"maxConcurrentOperationCount"];
      [self _update];
    }
  [internal->lock unlock];
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
      [self _update];
    }
  [internal->lock unlock];
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
  [internal->cond lock];
  if (YES == [object isReady])
    {
      if ([internal->waiting indexOfObjectIdenticalTo: object] == NSNotFound)
	{
          [internal->waiting addObject: object];
 	}
    }
  else
    {
      NSUInteger	index;

      index = [internal->waiting indexOfObjectIdenticalTo: object];
      if (index != NSNotFound)
	{
          [internal->waiting removeObjectAtIndex: index];
	}
    }
  if ([internal->waiting count] > 0)
    {
      [internal->cond unlockWithCondition: 1];
      [internal->lock lock];
      [self _update];
      [internal->lock unlock];
    }
  else
    {
      [internal->cond unlockWithCondition: 0];
    }
}

- (void) _thread
{
  [internal->lock lock];
  while ([internal->operations count] > 0)
    {
      NSOperation	*op;
      NSUInteger	index;

      /* Unlock the queue while we are waiting for another operation
       * to perform.
       */
      [internal->lock unlock];

      /* Wait for an operation to become available.
       */
      [internal->cond lockWhenCondition: 1];
      [internal->waiting sortUsingFunction: sortFunc context: 0];
      op = [[internal->waiting lastObject] retain];
      [internal->waiting removeLastObject];
      if ([internal->waiting count] == 0)
	{
          [internal->cond unlockWithCondition: 0];
	}
      else
	{
          [internal->cond unlockWithCondition: 1];
	}

      /* Restore the queue lock so we can track the idle count.
       */
      [internal->lock lock];
      if (YES == [op isReady])
	{
	  if (NO == [op isCancelled])
	    {
	      internal->idle--;

	      /* Unlock the queue while the operation is executing.
	       */
	      [internal->lock unlock];
	      [op start];
	      [op waitUntilFinished];

	      /* Lock the queue again to perform cleanup etc.
	       */
	      [internal->lock lock];
	      internal->idle++;
	    }
	  [self willChangeValueForKey: @"operations"];
	  [self willChangeValueForKey: @"operationCount"];
	  [internal->operations removeObjectIdenticalTo: op];
	  [self didChangeValueForKey: @"operationCount"];
	  [self didChangeValueForKey: @"operations"];
	}
      [op release];

      /* And now make sure we clean up any finished operations.
       */
      index = [internal->operations count];
      while (index-- > 0)
	{
	  op = [internal->operations objectAtIndex: index];
	  if (YES == [op isFinished])
	    {
	      [self willChangeValueForKey: @"operations"];
	      [self willChangeValueForKey: @"operationCount"];
	      [internal->operations removeObjectAtIndex: index];
	      [self didChangeValueForKey: @"operationCount"];
	      [self didChangeValueForKey: @"operations"];
	    }
	}
    }
  internal->idle--;
  internal->threads--;
  [internal->lock unlock];
}

/* NB.  This must only be called from a locked section of code!
 * It's just to check to see if a new thread needs to be started.
 */
- (void) _update
{
  if (0 == internal->idle
    && NO == [self isSuspended]
    && [self maxConcurrentOperationCount] != 0
    && [internal->waiting count] > 0)
    {
      NSInteger	count = internal->count;

      if (count == NSOperationQueueDefaultMaxConcurrentOperationCount)
	{
	  count = maxThreads;	// Limit number of allowed threads
	}
      if (internal->threads < count)
	{
	  /* All threads are in use, but we don't have the maximum
	   * number of threads, so we can create a new one for the
	   * waiting operation.
	   */
	  internal->threads++;
	  internal->idle++;
	  [NSThread detachNewThreadSelector: @selector(_thread)
				   toTarget: self
				 withObject: nil];
	}
    }
}

@end

