#import <Foundation/Foundation.h>

static NSArray *array;

@interface SyncTest : NSObject
- (void) sayHello;
@end

@implementation SyncTest
- (void) sayHello
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  NSLog(@"Before the sync block %s\n",[[[NSThread currentThread] description] cString]);
  @synchronized(array) {
    NSLog(@"In the sync block %s:%d\n",[[[NSThread currentThread] description] cString], [NSThread isMainThread]);
    NSLog(@"Waiting five seconds...\n");
    [NSThread sleepForTimeInterval: 5.0];
    NSLog(@"Done waiting\n");
  }
  NSLog(@"After the sync block %s\n",[[[NSThread currentThread] description] cString]);
  [pool release];
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
