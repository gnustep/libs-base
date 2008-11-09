#import <Foundation/Foundation.h>

static NSArray *array;

@interface SyncTest : NSObject
- (void) sayHello;
@end

@implementation SyncTest
- (void) sayHello
{
  NSLog(@"Before the sync block %@",[NSThread currentThread]);
  @synchronized(array) {
    NSLog(@"In the sync block %@:%d",[NSThread currentThread],[NSThread isMainThread]);
    NSLog(@"Waiting five seconds...");
    [NSThread sleepForTimeInterval: 5.0];
    NSLog(@"Done waiting");
  }
  NSLog(@"After the sync block %@",[NSThread currentThread]);
}
@end

int main (int argc, const char * argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  SyncTest *st = [[SyncTest alloc] init];
  array = [NSArray arrayWithObjects: @"Hello World",nil];	
  
  [NSThread detachNewThreadSelector: @selector(sayHello)
	    toTarget: st
	    withObject: nil];	
  [st sayHello];
  
  [pool drain];
  return 0;
}
