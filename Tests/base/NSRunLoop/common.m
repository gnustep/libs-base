#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>

@interface CommonModesTimerTarget : NSObject
{
  unsigned count;
}
- (void) fired: (NSTimer *)timer;
- (unsigned) count;
@end

@implementation CommonModesTimerTarget
- (void) fired: (NSTimer *)timer
{
  count++;
}
- (unsigned) count
{
  return count;
}
@end


int main()
{
  START_SET("common mode timers")

  NSRunLoop			*loop = [NSRunLoop currentRunLoop];
  CommonModesTimerTarget	*target;
  NSTimer 			*timer;

  /* A common-mode timer fires in the default mode. */
  target = [CommonModesTimerTarget new];
  timer = [NSTimer timerWithTimeInterval: 0.01
                                  target: target
                                selector: @selector(fired:)
                                userInfo: nil
                                 repeats: NO];
  [loop addTimer: timer forMode: NSRunLoopCommonModes];

  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];

  PASS([target count] == 1,
       "Common-mode timer fires in default mode");

  [timer invalidate];
  RELEASE(target);

  /* A timer added to a specific mode is not implicitly added
     to every mode. */
  target = [CommonModesTimerTarget new];
  timer = [NSTimer timerWithTimeInterval: 0.01
                                  target: target
                                selector: @selector(fired:)
                                userInfo: nil
                                 repeats: NO];

  [loop addTimer: timer forMode: @"TestPrivateRunLoopMode"];

  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];

  PASS([target count] == 0,
       "Mode-specific timer does not fire in default mode");

  [loop runMode: @"TestPrivateRunLoopMode"
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];

  PASS([target count] == 1,
       "Mode-specific timer fires in its registered mode");

  RELEASE(target);

  /* A common-mode timer should not fire in an unrelated private mode. */
  target = [CommonModesTimerTarget new];
  timer = [NSTimer timerWithTimeInterval: 0.01
				  target: target
				selector: @selector(fired:)
				userInfo: nil
				 repeats: NO];

  [loop addTimer: timer forMode: NSRunLoopCommonModes];

  [loop runMode: @"TestUnrelatedRunLoopMode"
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];

  PASS([target count] == 0,
       "Common-mode timer does not fire in an unrelated private mode");

  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];

  PASS([target count] == 1,
       "Common-mode timer subsequently fires in default mode");

  [timer invalidate];
  RELEASE(target);

  /* A repeating common-mode timer fires over multiple run-loop iterations. */
  target = [CommonModesTimerTarget new];
  timer = [NSTimer timerWithTimeInterval: 0.01
				  target: target
				selector: @selector(fired:)
				userInfo: nil
				 repeats: YES];

  [loop addTimer: timer forMode: NSRunLoopCommonModes];

  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];

  PASS([target count] > 1,
       "Repeating common-mode timer fires more than once");

  [timer invalidate];
  RELEASE(target);

  END_SET("common mode timers")

  return 0;
}

