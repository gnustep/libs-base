#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSAutoreleasePool.h>

#import "ObjectTesting.h" 

@interface      TaskHandler : NSObject
{
  NSString     *path;
}
@end

@implementation TaskHandler

static BOOL taskTerminationNotificationReceived; 

- (void) setLaunchPath: (NSString*)s
{
  ASSIGNCOPY(path, s);
}

- (void) taskDidTerminate: (NSNotification *)notification 
{ 
  NSLog(@"Received NSTaskDidTerminateNotification %@", notification); 
  taskTerminationNotificationReceived = YES; 
} 

- (void) testNSTaskNotifications 
{ 
  NSDate        *deadline; 
  BOOL          earlyTermination = NO; 

  for (;;)
    { 
      NSTask *task = [NSTask new]; 

      [task setLaunchPath: path];
      [task setArguments: [NSArray arrayWithObjects:
        @"-c", @"echo Child starting; sleep 10; echo Child exiting", nil]]; 
      taskTerminationNotificationReceived = NO; 
      [[NSNotificationCenter defaultCenter]
        addObserver: self 
        selector: @selector(taskDidTerminate:) 
        name: NSTaskDidTerminateNotification 
        object: task]; 
      [task launch]; 
      NSLog(@"Launched pid %d", [task processIdentifier]); 
      if (earlyTermination)
        { 
          NSLog(@"Running run loop for 5 seconds"); 
          deadline = [NSDate dateWithTimeIntervalSinceNow:5.0]; 
          while ([deadline timeIntervalSinceNow] > 0.0) 
            {
              [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]]; 
              NSLog(@"Run loop finished, will now call -[NSTask terminate]"); 
              [task terminate]; 
              NSLog(@"Terminate returned, waiting for termination"); 
              [task waitUntilExit]; 
            }
        }
      else
        { 
          NSLog(@"Running run loop for 15 seconds"); 
          deadline = [NSDate dateWithTimeIntervalSinceNow: 15.0]; 
          while ([deadline timeIntervalSinceNow] > 0.0
            && !taskTerminationNotificationReceived) 
            {
              [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]]; 
            }
        } 
      [task release]; 
      NSAssert(taskTerminationNotificationReceived,
        @"termination notification not received"); 
      [[NSNotificationCenter defaultCenter]
        removeObserver: self name: NSTaskDidTerminateNotification object: nil]; 
      if (earlyTermination) 
        break; 
      earlyTermination = YES; 
    } 
} 

@end

int main()
{
  TaskHandler   *h;
  NSFileManager *mgr;
  NSString      *helpers;
  NSString      *lp;

  START_SET("notify");
  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  lp = [helpers stringByAppendingPathComponent: @"testecho"];

  h = [TaskHandler new];
  [h setLaunchPath: lp];
  [h testNSTaskNotifications];
  [h release];

  END_SET("notify");
  return 0;
}
