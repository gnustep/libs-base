#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSTimer.h>

/* -performPendingSelectorsForMode: performs the performers
 * -acceptInputForMode:beforeDate: would perform before polling, and
 * nothing else: no timers, no input.
 */

static NSString *OtherMode = @"PerformPendingOtherMode";

@interface	Queuer : NSObject
{
@public
  NSMutableString	*target;
  volatile BOOL		queued;
}
- (void) queueFromThread: (id)arg;
@end

@implementation	Queuer
- (void) queueFromThread: (id)arg
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];

  [target performSelectorOnMainThread: @selector(appendString:)
			   withObject: @"thread"
			waitUntilDone: NO
				modes: [NSArray arrayWithObject:
				  NSDefaultRunLoopMode]];
  queued = YES;
  [pool drain];
}
@end

@interface	Counter : NSObject
{
@public
  int	fired;
  int	read;
}
- (void) tick: (NSTimer*)t;
- (void) didRead: (NSNotification*)n;
@end

@implementation	Counter
- (void) tick: (NSTimer*)t
{
  fired++;
}
- (void) didRead: (NSNotification*)n
{
  read++;
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSRunLoop		*run = [NSRunLoop currentRunLoop];
  NSMutableString	*str;
  Queuer		*queuer;
  Counter		*counter;
  NSTimer		*timer;
  NSDate		*limit;
  BOOL			done;

  START_SET("performPendingSelectorsForMode: performs this mode's performers")
  str = [NSMutableString string];
  [run performSelector: @selector(appendString:)
		target: str
	      argument: @"foo"
		 order: 0
		 modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
  PASS([run performPendingSelectorsForMode: NSDefaultRunLoopMode] == YES,
    "it reports a performer performed")
  PASS([str isEqual: @"foo"], "the performer ran")
  PASS([run performPendingSelectorsForMode: NSDefaultRunLoopMode] == NO,
    "nothing is left to perform the second time")
  PASS([str isEqual: @"foo"], "a performer runs only once")
  END_SET("performPendingSelectorsForMode: performs this mode's performers")

  START_SET("performPendingSelectorsForMode: leaves other modes' performers")
  str = [NSMutableString string];
  [run performSelector: @selector(appendString:)
		target: str
	      argument: @"other"
		 order: 0
		 modes: [NSArray arrayWithObject: OtherMode]];
  [run performPendingSelectorsForMode: nil];
  PASS([str isEqual: @""],
    "a performer for another mode doesn't run in the default mode (nil)")
  PASS([run performPendingSelectorsForMode: OtherMode] == YES
    && [str isEqual: @"other"], "it runs in its own mode")
  END_SET("performPendingSelectorsForMode: leaves other modes' performers")

  START_SET("performPendingSelectorsForMode: performs work from other threads")
  str = [NSMutableString string];
  queuer = [[Queuer new] autorelease];
  queuer->target = str;
  queuer->queued = NO;
  [NSThread detachNewThreadSelector: @selector(queueFromThread:)
			   toTarget: queuer
			 withObject: nil];
  limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];
  while (NO == queuer->queued && [limit timeIntervalSinceNow] > 0)
    {
      [NSThread sleepForTimeInterval: 0.01];
    }
  PASS(queuer->queued, "another thread queued a -performSelectorOnMainThread:")
  PASS([str isEqual: @""], "nothing ran before it was asked to")
  PASS([run performPendingSelectorsForMode: NSDefaultRunLoopMode] == YES
    && [str isEqual: @"thread"],
    "the work queued from the other thread runs")
  END_SET("performPendingSelectorsForMode: performs work from other threads")

  START_SET("performPendingSelectorsForMode: fires no timers")
  counter = [[Counter new] autorelease];
  timer = [NSTimer timerWithTimeInterval: 0.0
				  target: counter
				selector: @selector(tick:)
				userInfo: nil
				 repeats: NO];
  [run addTimer: timer forMode: NSDefaultRunLoopMode];
  [NSThread sleepForTimeInterval: 0.05];
  [run performPendingSelectorsForMode: NSDefaultRunLoopMode];
  PASS(counter->fired == 0, "a due timer doesn't fire")
  [run limitDateForMode: NSDefaultRunLoopMode];
  PASS(counter->fired == 1, "it fires when the loop fires timers")
  END_SET("performPendingSelectorsForMode: fires no timers")

  START_SET("performPendingSelectorsForMode: polls no input")
  {
    NSPipe		*pipe = [NSPipe pipe];
    NSFileHandle	*reader = [pipe fileHandleForReading];

    counter = [[Counter new] autorelease];
    [[NSNotificationCenter defaultCenter]
      addObserver: counter
	 selector: @selector(didRead:)
	     name: NSFileHandleReadCompletionNotification
	   object: reader];
    [reader readInBackgroundAndNotify];
    [[pipe fileHandleForWriting] writeData:
      [@"input" dataUsingEncoding: NSASCIIStringEncoding]];
    [NSThread sleepForTimeInterval: 0.05];
    [run performPendingSelectorsForMode: NSDefaultRunLoopMode];
    PASS(counter->read == 0, "data waiting on a pipe isn't read")
    limit = [NSDate dateWithTimeIntervalSinceNow: 2.0];
    done = NO;
    while (NO == done && [limit timeIntervalSinceNow] > 0)
      {
	[run runMode: NSDefaultRunLoopMode
	  beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	done = (counter->read > 0);
      }
    if (NO == done)
      {
	SKIP("the run loop doesn't read the pipe here either")
      }
    PASS(counter->read == 1, "the loop reads it when it polls")
    [[NSNotificationCenter defaultCenter] removeObserver: counter];
  }
  END_SET("performPendingSelectorsForMode: polls no input")

  [arp drain];
  return 0;
}
