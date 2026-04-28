#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>
#if GS_USE_LIBDISPATCH == 1
#import <dispatch/dispatch.h>
#endif
#import "ObjectTesting.h"

/* Ensure this TU contributes an Objective-C constant string section.
 * Some toolchain/runtime combinations expect it at link time.
 */
static NSString *forceConstantStringSection = @"queue_dispatch";

@interface Counter : NSObject
{
  NSLock *_lock;
  NSUInteger _value;
}
- (void) increment;
- (NSUInteger) value;
@end

@implementation Counter
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _lock = [NSLock new];
      _value = 0;
    }
  return self;
}

- (void) dealloc
{
  [_lock release];
  [super dealloc];
}

- (void) increment
{
  [_lock lock];
  _value++;
  [_lock unlock];
}

- (NSUInteger) value
{
  NSUInteger v;

  [_lock lock];
  v = _value;
  [_lock unlock];
  return v;
}
@end

@interface DelayIncrementOperation : NSOperation
{
  Counter *_counter;
  NSTimeInterval _delay;
}
- (id) initWithCounter: (Counter *)counter delay: (NSTimeInterval)delay;
@end

@implementation DelayIncrementOperation
- (id) initWithCounter: (Counter *)counter delay: (NSTimeInterval)delay
{
  self = [super init];
  if (self != nil)
    {
      _counter = [counter retain];
      _delay = delay;
    }
  return self;
}

- (void) dealloc
{
  [_counter release];
  [super dealloc];
}

- (void) main
{
  if (_delay > 0.0)
    {
      [NSThread sleepForTimeInterval: _delay];
    }
  [_counter increment];
}
@end

/* Keep tests buildable against environments where Foundation headers are older
 * than the checked-out source tree.
 */
@interface NSOperationQueue (QueueDispatchTest)
- (void *) underlyingQueue;
- (void) setUnderlyingQueue: (void *)queue;
@end

int main()
{
  NSOperationQueue *queue;
  START_SET("NSOperationQueue dispatch-backed behavior")

#if GS_USE_LIBDISPATCH == 1
  {
    void *oldUnderlying;
    void *customUnderlying;

    queue = [NSOperationQueue new];
    oldUnderlying = [queue underlyingQueue];
    PASS(([queue underlyingQueue] != NULL),
      "custom operation queue exposes a non-null underlying queue");
    PASS(([[NSOperationQueue mainQueue] underlyingQueue] != NULL),
      "main queue exposes a non-null underlying queue");
    PASS(([queue underlyingQueue] != [[NSOperationQueue mainQueue] underlyingQueue]),
      "custom queue and main queue use different underlying queues");

    // Assigning a custom libdispatch queue succeeds and updates the value.
    customUnderlying = dispatch_queue_create("queue-dispatch-test", NULL);
    [queue setUnderlyingQueue: customUnderlying];
    PASS(([queue underlyingQueue] == customUnderlying),
      "setUnderlyingQueue accepts a non-main dispatch queue");
    PASS(([queue underlyingQueue] != oldUnderlying),
      "setUnderlyingQueue replaces the previous underlying queue");

    // Assigning the main queue must fail.
    PASS_EXCEPTION(
      [queue setUnderlyingQueue: dispatch_get_main_queue()],
      NSInvalidArgumentException,
      "setUnderlyingQueue rejects dispatch_get_main_queue");

    // Assigning while operations are enqueued must fail.
    {
      Counter *busyCounter;
      DelayIncrementOperation *op;

      busyCounter = [Counter new];
      op = [[DelayIncrementOperation alloc] initWithCounter: busyCounter
                                                      delay: 0.20];
      [queue addOperation: op];
      [op release];
      PASS_EXCEPTION(
        [queue setUnderlyingQueue: customUnderlying],
        NSInvalidArgumentException,
        "setUnderlyingQueue rejects changes while operations are enqueued");
      [queue waitUntilAllOperationsAreFinished];
      [busyCounter release];
    }

    dispatch_release((dispatch_queue_t)customUnderlying);
    [queue release];
  }
#else
  PASS(YES, "underlyingQueue checks are disabled when libdispatch is unavailable");
#endif

  END_SET("NSOperationQueue dispatch-backed behavior");
  return 0;
}
