#include <Foundation/Foundation.h>

NSLock	*lock = nil;

@interface XX : NSObject
- (void) fire;
- (void) setup;
@end

@implementation	XX
- (void) fire
{
  NSLog(@"Got here");
}
- (void) setup
{
  CREATE_AUTORELEASE_POOL(arp);

  NSLog(@"Attempting to obtain lock to proceed");
  if ([lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 5.0]] == YES)
    {
      NSLog(@"Setup1");
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
      NSLog(@"Setup2");
      [self performSelectorOnMainThread: @selector(fire)
			     withObject: nil
			  waitUntilDone: NO];
      NSLog(@"Done perform no wait.");
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
      NSLog(@"Setup3");
      [self performSelectorOnMainThread: @selector(fire)
			     withObject: nil
			  waitUntilDone: YES];
      NSLog(@"Done perform with wait.");
    }
  else
    {
      NSLog(@"Failed to obtain lock");
    }
  RELEASE(arp);
  [NSThread exit];
}
@end

int main(int argc, char **argv, char **env)
{
  CREATE_AUTORELEASE_POOL(arp);
  
  NSLog(@"Start in main");
  lock = [NSLock new];
  [lock lock];

  [NSThread detachNewThreadSelector: @selector(setup)
			   toTarget: [XX new]
			 withObject: nil];
  NSLog(@"Waiting to give thread time to start");
  [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
  NSLog(@"Releasing lock so thread may proceed");
  [lock unlock];	// Allow other thread to proceed.

  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 10.0]];
  
  NSLog(@"Done main thread");

  DESTROY(arp);
  return 0;
}

