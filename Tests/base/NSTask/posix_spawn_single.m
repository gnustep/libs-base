#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import "ObjectTesting.h"

/* Test basic NSTask functionality in a single-threaded context
 * This ensures posix_spawn() works correctly for simple cases
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testsimple;
  NSTask *task;
  NSPipe *outPipe;
  NSFileHandle *outHandle;
  NSData *data;
  NSString *output;

#if defined(_WIN32)
  testsimple = @"testsimple.exe";
#else
  testsimple = @"testsimple";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  /* Test 1: Launch a simple task that exits with code 0 */
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setArguments: [NSArray arrayWithObjects: @"0", nil]];
  [task launch];
  [task waitUntilExit];
  PASS([task terminationStatus] == 0, 
    "simple task exits with code 0");
  PASS([task terminationReason] == NSTaskTerminationReasonExit,
    "simple task has correct termination reason");
  DESTROY(task);

  /* Test 2: Launch a simple task that exits with code 42 */
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setArguments: [NSArray arrayWithObjects: @"42", nil]];
  [task launch];
  [task waitUntilExit];
  PASS([task terminationStatus] == 42,
    "simple task exits with custom code 42");
  DESTROY(task);

  /* Test 3: Launch task and capture output */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setArguments: [NSArray arrayWithObjects: @"0", nil]];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([data length] > 0, "captured output from simple task");
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  PASS([output rangeOfString: @"Exiting with code 0"].location != NSNotFound,
    "output contains expected text");
  DESTROY(output);
  DESTROY(task);

  /* Test 4: Verify task state changes correctly */
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setArguments: [NSArray array]];
  
  PASS([task isRunning] == NO, "task not running before launch");
  
  [task launch];
  // Note: Task might finish very quickly, so we can't reliably test isRunning == YES
  [task waitUntilExit];
  
  PASS([task isRunning] == NO, "task not running after waitUntilExit");
  PASS([task processIdentifier] > 0, "task has valid process identifier");
  DESTROY(task);

  /* Test 5: Verify we can launch multiple tasks sequentially */
  int i;
  for (i = 0; i < 5; i++)
    {
      task = [[NSTask alloc] init];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
      [task setArguments: [NSArray array]];
      [task launch];
      [task waitUntilExit];
      PASS([task terminationStatus] == 0,
        "sequential task %d completed successfully", i);
      DESTROY(task);
    }

  [arp release];
  return 0;
}
