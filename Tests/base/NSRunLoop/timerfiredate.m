#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>

@interface FireDateTarget : NSObject
{
@public
  unsigned	count;
  NSDate	*rescheduleTo;
}
- (void) fired: (NSTimer*)timer;
@end

@implementation FireDateTarget
- (void) fired: (NSTimer*)timer
{
  count++;
  if (rescheduleTo != nil)
    {
      [timer setFireDate: rescheduleTo];
      rescheduleTo = nil;
    }
}
@end

static void
runUntilFired(NSRunLoop *loop, NSString *mode, FireDateTarget *target,
  unsigned count, NSTimeInterval timeout)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: timeout];

  while (target->count < count && [limit timeIntervalSinceNow] > 0.0)
    {
      [loop runMode: mode beforeDate: limit];
    }
}

static NSTimer *
timerAt(NSTimeInterval ti, FireDateTarget *target, BOOL repeats)
{
  NSDate	*d = [NSDate dateWithTimeIntervalSinceNow: ti];

  return AUTORELEASE([[NSTimer alloc] initWithFireDate: d
					      interval: repeats ? 0.01 : 0.0
						target: target
					      selector: @selector(fired:)
					      userInfo: nil
					       repeats: repeats]);
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  NSString		*other = @"TimerFireDateTestMode";
  FireDateTarget	*early = AUTORELEASE([FireDateTarget new]);
  FireDateTarget	*late = AUTORELEASE([FireDateTarget new]);
  NSTimer		*a;
  NSTimer		*b;

  START_SET("NSTimer -setFireDate: on scheduled timers")

  /* 'a' is at the top of the heap.  Moving 'b' before it and 'a' far
   * into the future must let 'b' fire.
   */
  a = timerAt(30.0, late, NO);
  b = timerAt(60.0, early, NO);
  [loop addTimer: a forMode: NSDefaultRunLoopMode];
  [loop addTimer: b forMode: NSDefaultRunLoopMode];
  [a setFireDate: [NSDate dateWithTimeIntervalSinceNow: 3600.0]];
  [b setFireDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
  runUntilFired(loop, NSDefaultRunLoopMode, early, 1, 2.0);
  PASS(early->count == 1, "timer moved earlier fires at its new date")
  PASS(late->count == 0, "timer moved later does not fire early")
  [a invalidate];
  [b invalidate];

  /* Same in a mode other than the default, and in two modes at once.
   */
  early->count = late->count = 0;
  a = timerAt(30.0, late, NO);
  b = timerAt(60.0, early, NO);
  [loop addTimer: a forMode: NSDefaultRunLoopMode];
  [loop addTimer: a forMode: other];
  [loop addTimer: b forMode: NSDefaultRunLoopMode];
  [loop addTimer: b forMode: other];
  [a setFireDate: [NSDate dateWithTimeIntervalSinceNow: 3600.0]];
  [b setFireDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
  runUntilFired(loop, other, early, 1, 2.0);
  PASS(early->count == 1, "rescheduled timer fires in a non-default mode")
  [a invalidate];
  [b invalidate];

  /* Same for timers in the common modes.
   */
  early->count = late->count = 0;
  a = timerAt(30.0, late, NO);
  b = timerAt(60.0, early, NO);
  [loop addTimer: a forMode: NSRunLoopCommonModes];
  [loop addTimer: b forMode: NSRunLoopCommonModes];
  [a setFireDate: [NSDate dateWithTimeIntervalSinceNow: 3600.0]];
  [b setFireDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
  runUntilFired(loop, NSDefaultRunLoopMode, early, 1, 2.0);
  PASS(early->count == 1, "rescheduled timer fires in the common modes")
  [a invalidate];
  [b invalidate];

  /* A repeating timer which sets its own fire date while firing keeps
   * that date rather than its interval.
   */
  early->count = late->count = 0;
  a = timerAt(30.0, late, NO);
  b = timerAt(0.01, early, YES);
  early->rescheduleTo = [NSDate dateWithTimeIntervalSinceNow: 3600.0];
  [loop addTimer: a forMode: NSDefaultRunLoopMode];
  [loop addTimer: b forMode: NSDefaultRunLoopMode];
  runUntilFired(loop, NSDefaultRunLoopMode, early, 2, 0.5);
  PASS(early->count == 1, "timer rescheduled while firing keeps its new date")
  PASS([[b fireDate] timeIntervalSinceNow] > 3000.0,
    "timer rescheduled while firing reports its new date")
  [a invalidate];
  [b invalidate];

  END_SET("NSTimer -setFireDate: on scheduled timers")

  [arp release];
  return 0;
}
