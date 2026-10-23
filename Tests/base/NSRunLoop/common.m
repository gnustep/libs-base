#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSStream.h>
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


@interface CommonModesStreamDelegate : NSObject
{
  unsigned bytesAvailable;
}
- (void) stream: (NSStream *)stream
   handleEvent: (NSStreamEvent)event;
- (unsigned) bytesAvailable;
@end

@implementation CommonModesStreamDelegate
- (void) stream: (NSStream *)stream
   handleEvent: (NSStreamEvent)event
{
  if (event == NSStreamEventHasBytesAvailable)
    {
      bytesAvailable++;
    }
}

- (unsigned) bytesAvailable
{
  return bytesAvailable;
}
@end

/*
 * Run the current run loop until a bytes-available event arrives
 * or the deadline expires.
 */
static void
runUntilBytesAvailable(
  NSRunLoop *loop,
  NSString *mode,
  CommonModesStreamDelegate *delegate,
  NSTimeInterval timeout)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: timeout];

  while ([delegate bytesAvailable] == 0
    && [deadline timeIntervalSinceNow] > 0)
    {
      [loop runMode: mode beforeDate: deadline];
    }
}

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
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

  PASS([target count] == 0,
       "Common-mode timer does not fire in an unrelated private mode");

  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

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
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  [loop runMode: NSDefaultRunLoopMode
     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

  PASS([target count] > 1,
       "Repeating common-mode timer fires more than once");

  [timer invalidate];
  RELEASE(target);

  END_SET("common mode timers")

  START_SET("common mode streams")

  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  NSInputStream		*stream;
  CommonModesStreamDelegate *delegate;
  NSData 		*data;

  data = [NSData dataWithBytes: "test" length: 4];

  /*
   * A stream scheduled in common modes receives events in default mode.
   */
  stream = [[NSInputStream alloc] initWithData: data];
  delegate = [CommonModesStreamDelegate new];

  [stream setDelegate: delegate];
  [stream scheduleInRunLoop: loop forMode: NSRunLoopCommonModes];
  [stream open];

  runUntilBytesAvailable(loop, NSDefaultRunLoopMode, delegate, 0.2);

  PASS([delegate bytesAvailable] > 0,
    "Common-mode input stream receives bytes-available event in default mode")

  [stream close];
  [stream setDelegate: nil];
  [stream removeFromRunLoop: loop forMode: NSRunLoopCommonModes];
  RELEASE(stream);
  RELEASE(delegate);

  /*
   * A stream scheduled in a private mode is not serviced in default mode.
   */
  stream = [[NSInputStream alloc] initWithData: data];
  delegate = [CommonModesStreamDelegate new];

  [stream setDelegate: delegate];
  [stream scheduleInRunLoop: loop forMode: @"TestPrivateRunLoopMode"];
  [stream open];

  runUntilBytesAvailable(loop, NSDefaultRunLoopMode, delegate, 0.05);

  PASS([delegate bytesAvailable] == 0, "Mode-specific input stream"
    " does not receive bytes-available event in default mode")

  runUntilBytesAvailable(loop, @"TestPrivateRunLoopMode", delegate, 0.2);

  PASS([delegate bytesAvailable] > 0, "Mode-specific input stream"
    " receives bytes-available event in its registered mode")

  [stream close];
  [stream setDelegate: nil];
  [stream removeFromRunLoop: loop forMode: @"TestPrivateRunLoopMode"];
  RELEASE(stream);
  RELEASE(delegate);

  END_SET("common mode streams")

  return 0;
}

