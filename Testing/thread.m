#import <Foundation/Foundation.h>

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
  RELEASE(arp);
  [NSThread exit];
}
@end

int main(int argc, char **argv, char **env)
{
  id arp = [NSAutoreleasePool new];
  
  NSLog(@"Start in main");
  [NSThread detachNewThreadSelector: @selector(setup)
			   toTarget: [XX new]
			 withObject: nil];
  
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 10.0]];
  
  NSLog(@"Done main thread");
  return 0;
}

