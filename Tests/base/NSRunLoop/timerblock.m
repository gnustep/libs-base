#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>

/* Statics rather than __block variables, as those would be stored in
 * the block itself.
 */
static BOOL	fired = NO;
static BOOL	captureDeallocated = NO;
static BOOL	captureAliveAfterInvalidate = NO;

@interface TimerBlockCapture : NSObject
@end

@implementation TimerBlockCapture
- (void) dealloc
{
  captureDeallocated = YES;
  [super dealloc];
}
@end

int main()
{
  START_SET("NSTimer blocks")
# ifndef __has_feature
# define __has_feature(x) 0
# endif
# if __has_feature(blocks)
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  TimerBlockCapture	*capture = [TimerBlockCapture new];
  NSTimer		*timer;
  NSDate		*limit;

  /* The block is the only owner of the captured object, so it's
   * deallocated as soon as the block is.
   */
  timer = [NSTimer timerWithTimeInterval: 0.01
                                 repeats: YES
                                   block: ^(NSTimer *t) {
    [t invalidate];
    captureAliveAfterInvalidate = !captureDeallocated && capture != nil;
    fired = YES;
  }];
  [loop addTimer: timer forMode: NSDefaultRunLoopMode];
  RELEASE(capture);

  limit = [NSDate dateWithTimeIntervalSinceNow: 1.0];
  while (NO == fired && [limit timeIntervalSinceNow] > 0.0)
    {
      [loop runMode: NSDefaultRunLoopMode
         beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }

  PASS(fired, "Timer with block fires")
  PASS(captureAliveAfterInvalidate,
       "A timer's block stays alive while it runs after invalidating the timer")
  PASS(captureDeallocated,
       "A timer's block is released after it ran and invalidated the timer")

  [arp release]; arp = nil;
# else
  SKIP("No Blocks support in the compiler.")
# endif
  END_SET("NSTimer blocks")
  return 0;
}
