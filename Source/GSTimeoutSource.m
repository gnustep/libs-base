#import "GSTimeoutSource.h"

@implementation GSTimeoutSource

- (instancetype) initWithQueue: (dispatch_queue_t)queue
                       handler: (dispatch_block_t)handler 
{
  if (nil != (self = [super init])) 
    {
      dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
      dispatch_source_set_event_handler(timer, handler);
      dispatch_source_set_cancel_handler(timer, ^{
        dispatch_release(timer);
      });

      _timer = timer;
      _timeoutMs = -1;
      _isSuspended = YES;
    }
  return self;
}

- (void) dealloc 
{
  [self cancel];
  [super dealloc];
}

- (NSInteger) timeout
{
  return _timeoutMs;
}

- (void) setTimeout: (NSInteger)timeoutMs
{
  if (timeoutMs >= 0)
    {
      _timeoutMs = timeoutMs;

      dispatch_source_set_timer(_timer,
        dispatch_time(DISPATCH_TIME_NOW, timeoutMs * NSEC_PER_MSEC),
        DISPATCH_TIME_FOREVER,  // don't repeat
        timeoutMs * 0.05);      // 5% leeway

      if (_isSuspended)
        {
          _isSuspended = NO;
          dispatch_resume(_timer);
        }
    }
  else
  {
    [self suspend];
  }
}

- (void)suspend
{
  if (!_isSuspended)
    {
      _isSuspended = YES;
      _timeoutMs = -1;
      dispatch_suspend(_timer);
    }
}

- (void) cancel
{
  if (_timer)
    {
      dispatch_source_cancel(_timer);
      _timer = NULL; // released in cancel handler
    }
}

@end