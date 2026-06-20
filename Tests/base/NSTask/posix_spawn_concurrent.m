#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import "ObjectTesting.h"

/* Test multiple concurrent NSTask instances
 * This verifies that posix_spawn can handle multiple tasks running
 * simultaneously without resource conflicts or race conditions
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testsimple;
  NSString *testecho;
  NSMutableArray *tasks;
  NSMutableArray *pipes;
  int i;
  int j;
  int numTasks;

#if defined(_WIN32)
  testsimple = @"testsimple.exe";
  testecho = @"testecho.exe";
#else
  testsimple = @"testsimple";
  testecho = @"testecho";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  /* Test 1: Launch multiple tasks concurrently and wait for all */
  numTasks = 10;
  tasks = [NSMutableArray arrayWithCapacity: numTasks];
  pipes = [NSMutableArray arrayWithCapacity: numTasks];
  
  // Launch all tasks
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [[NSTask alloc] init];
      NSPipe *outPipe = [NSPipe pipe];
      
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testecho]];
      [task setArguments: [NSArray arrayWithObjects:
        [NSString stringWithFormat: @"Task%d", i], nil]];
      [task setStandardOutput: outPipe];
      
      [task launch];
      
      [tasks addObject: task];
      [pipes addObject: outPipe];
      [task release];
    }
  
  PASS([tasks count] == numTasks, "launched %d concurrent tasks", numTasks);
  
  // Wait for all tasks and verify output
  int successCount = 0;
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [tasks objectAtIndex: i];
      NSPipe *pipe = [pipes objectAtIndex: i];
      NSFileHandle *handle = [pipe fileHandleForReading];
      
      NSData *data = [handle readDataToEndOfFile];
      [task waitUntilExit];
      
      if ([task terminationStatus] == 0)
        {
          NSString *output = [[NSString alloc] initWithData: data
                                                   encoding: NSUTF8StringEncoding];
          if ([output rangeOfString: [NSString stringWithFormat: @"Task%d", i]].location
              != NSNotFound)
            {
              successCount++;
            }
          [output release];
        }
    }
  
  PASS(successCount == numTasks,
       "all %d concurrent tasks completed successfully (got %d)",
       numTasks, successCount);

  /* Test 2: Launch tasks, collect them, then wait in different order */
  [tasks removeAllObjects];
  [pipes removeAllObjects];
  numTasks = 5;
  
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [[NSTask alloc] init];
      NSPipe *outPipe = [NSPipe pipe];
      
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
      [task setArguments: [NSArray arrayWithObjects: @"0", nil]];
      [task setStandardOutput: outPipe];
      
      [task launch];
      
      [tasks addObject: task];
      [pipes addObject: outPipe];
      [task release];
    }
  
  // Wait in reverse order
  successCount = 0;
  for (i = numTasks - 1; i >= 0; i--)
    {
      NSTask *task = [tasks objectAtIndex: i];
      [task waitUntilExit];
      
      if ([task terminationStatus] == 0)
        {
          successCount++;
        }
    }
  
  PASS(successCount == numTasks,
       "waiting in reverse order works (%d/%d)", successCount, numTasks);

  /* Test 3: Mix of quick and tasks with different arguments */
  [tasks removeAllObjects];
  [pipes removeAllObjects];
  numTasks = 8;
  
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [[NSTask alloc] init];
      NSPipe *outPipe = [NSPipe pipe];
      
      if (i % 2 == 0)
        {
          [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
          [task setArguments: [NSArray arrayWithObjects:
            [NSString stringWithFormat: @"%d", i], nil]];
        }
      else
        {
          [task setLaunchPath: [helpers stringByAppendingPathComponent: testecho]];
          [task setArguments: [NSArray arrayWithObjects:
            [NSString stringWithFormat: @"Arg%d", i],
            @"ExtraArg", nil]];
        }
      
      [task setStandardOutput: outPipe];
      [task launch];
      
      [tasks addObject: task];
      [pipes addObject: outPipe];
      [task release];
    }
  
  successCount = 0;
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [tasks objectAtIndex: i];
      NSPipe *pipe = [pipes objectAtIndex: i];
      NSFileHandle *handle = [pipe fileHandleForReading];

      // Drain the pipe to prevent child process from blocking
      (void)[handle readDataToEndOfFile];
      [task waitUntilExit];

      if ([task terminationStatus] == 0 || [task terminationStatus] == i)
        {
          successCount++;
        }
    }
  
  PASS(successCount == numTasks,
       "mixed task types run concurrently (%d/%d)", successCount, numTasks);

  /* Test 4: Rapid launch and wait cycles */
  successCount = 0;
  for (i = 0; i < 20; i++)
    {
      NSTask *task = [[NSTask alloc] init];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
      [task setArguments: [NSArray array]];
      
      [task launch];
      [task waitUntilExit];
      
      if ([task terminationStatus] == 0)
        {
          successCount++;
        }
      
      [task release];
    }
  
  PASS(successCount == 20,
       "rapid launch/wait cycles work (%d/20)", successCount);

  /* Test 5: Verify process IDs are unique for concurrent tasks */
  [tasks removeAllObjects];
  numTasks = 5;
  NSMutableArray *pids = [NSMutableArray arrayWithCapacity: numTasks];
  
  for (i = 0; i < numTasks; i++)
    {
      NSTask *task = [[NSTask alloc] init];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
      [task launch];
      
      [tasks addObject: task];
      [pids addObject: [NSNumber numberWithInt: [task processIdentifier]]];
      [task release];
    }
  
  // Check all PIDs are different
  BOOL allUnique = YES;
  for (i = 0; i < [pids count]; i++)
    {
      for (j = i + 1; j < [pids count]; j++)
        {
          if ([[pids objectAtIndex: i] isEqual: [pids objectAtIndex: j]])
            {
              allUnique = NO;
              break;
            }
        }
    }
  
  for (i = 0; i < numTasks; i++)
    {
      [[tasks objectAtIndex: i] waitUntilExit];
    }
  
  PASS(allUnique, "all concurrent tasks have unique process IDs");

  [arp release];
  return 0;
}
