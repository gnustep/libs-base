#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

/* Observers of NSUserDefaults must be called without the defaults lock held,
 * or an observer that waits for another thread using the defaults deadlocks.
 */

static NSString	*key = @"KVOLockKey";

@interface Observer : NSObject
{
@public
  NSUserDefaults	*defs;
  volatile BOOL		readerDone;
  BOOL			called;
  BOOL			readerFinishedInCallback;
}
@end

@implementation Observer

- (void) read
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  [defs objectForKey: key];
  readerDone = YES;
  [arp release];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];

  called = YES;
  readerDone = NO;
  [NSThread detachNewThreadSelector: @selector(read)
			   toTarget: self
			 withObject: nil];
  while (NO == readerDone && [limit timeIntervalSinceNow] > 0)
    {
      [NSThread sleepForTimeInterval: 0.01];
    }
  readerFinishedInCallback = readerDone;
}

/* A reader blocked by the lock finishes once the change has returned. */
- (void) waitForReader
{
  while (NO == readerDone)
    {
      [NSThread sleepForTimeInterval: 0.01];
    }
}

@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  Observer		*obs = [[Observer new] autorelease];

  START_SET("NSUserDefaults KVO without the lock held")

  obs->defs = defs;
  [defs removeObjectForKey: key];
  [defs addObserver: obs forKeyPath: key options: 0 context: NULL];

  [defs setObject: @"value" forKey: key];
  [obs waitForReader];
  PASS(obs->called, "-setObject:forKey: notifies observers")
  PASS(obs->readerFinishedInCallback,
    "another thread can read the defaults during -setObject:forKey: KVO")

  obs->called = NO;
  obs->readerFinishedInCallback = NO;
  [defs removeObjectForKey: key];
  [obs waitForReader];
  PASS(obs->called, "-removeObjectForKey: notifies observers")
  PASS(obs->readerFinishedInCallback,
    "another thread can read the defaults during -removeObjectForKey: KVO")

  [defs removeObserver: obs forKeyPath: key];

  END_SET("NSUserDefaults KVO without the lock held")

  [arp release];
  return 0;
}
