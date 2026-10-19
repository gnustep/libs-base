#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSThread.h>
#import "GNUstepBase/GSConfig.h"

#ifndef __has_feature
#  define __has_feature(x) 0
#endif

#if GS_USE_LIBDISPATCH
#  include <dispatch/dispatch.h>

static long deallocated = 0;

@interface Tracked : NSObject
@end

@implementation Tracked
- (void) dealloc
{
  __atomic_fetch_add(&deallocated, 1, __ATOMIC_SEQ_CST);
  [super dealloc];
}
@end

static void
autoreleaseObject(void *done)
{
  [[Tracked new] autorelease];
  dispatch_semaphore_signal((dispatch_semaphore_t)done);
}

/* Objects autoreleased by work on libdispatch's worker threads must be
 * released when the work returns, not only when the (long-lived) worker
 * thread exits.
 */
static void
testWorkerThreadPools(BOOL useBlocks)
{
  const long		count = 100;
  dispatch_queue_t	queue;
  dispatch_semaphore_t	done = dispatch_semaphore_create(0);
  NSDate		*limit;
  long			i;

  __atomic_store_n(&deallocated, 0, __ATOMIC_SEQ_CST);
  queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  for (i = 0; i < count; i++)
    {
#if __has_feature(blocks)
      if (useBlocks)
	{
	  dispatch_async(queue, ^{
	    autoreleaseObject(done);
	  });
	  continue;
	}
#endif
      dispatch_async_f(queue, done, autoreleaseObject);
    }
  for (i = 0; i < count; i++)
    {
      dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    }

  /* The pools are popped right after the work returns.  Don't wait long,
   * as idle worker threads exit after a few seconds, emptying their pools.
   */
  limit = [NSDate dateWithTimeIntervalSinceNow: 1.0];
  while (__atomic_load_n(&deallocated, __ATOMIC_SEQ_CST) < count
    && [limit timeIntervalSinceNow] > 0)
    {
      [NSThread sleepForTimeInterval: 0.01];
    }
  PASS(__atomic_load_n(&deallocated, __ATOMIC_SEQ_CST) == count,
    "objects autoreleased by %s on libdispatch worker threads are released"
    " when it returns", useBlocks ? "a block" : "a function")

  dispatch_release(done);
}

#endif

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("NSAutoreleasePool libdispatch worker threads")
#if !GS_USE_LIBDISPATCH
  SKIP("No libdispatch")
#else
  testWorkerThreadPools(NO);
#  if __has_feature(blocks)
  testWorkerThreadPools(YES);
#  endif
#endif
  END_SET("NSAutoreleasePool libdispatch worker threads")

  [arp release];
  return 0;
}
