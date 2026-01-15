#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import "ObjectTesting.h"

/* Test stdin/stdout/stderr redirection with posix_spawn
 * Ensures that posix_spawn_file_actions_adddup2 works correctly
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *teststdio;
  NSString *testecho;
  NSTask *task;
  NSPipe *inPipe, *outPipe, *errPipe;
  NSFileHandle *inHandle, *outHandle, *errHandle;
  NSData *data;
  NSString *output;
  NSString *testInput = @"Hello from stdin\n";

#if defined(_WIN32)
  teststdio = @"teststdio.exe";
  testecho = @"testecho.exe";
#else
  teststdio = @"teststdio";
  testecho = @"testecho";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  /* Test 1: Basic stdout capture */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testecho]];
  [task setArguments: [NSArray arrayWithObjects: @"Test", @"Output", nil]];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([data length] > 0, "captured stdout from task");
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  PASS([output rangeOfString: @"Test"].location != NSNotFound &&
       [output rangeOfString: @"Output"].location != NSNotFound,
       "stdout contains expected arguments");
  DESTROY(output);
  DESTROY(task);

  /* Test 2: stdin -> stdout redirection */
  task = [[NSTask alloc] init];
  inPipe = [NSPipe pipe];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: teststdio]];
  [task setStandardInput: inPipe];
  [task setStandardOutput: outPipe];
  
  inHandle = [inPipe fileHandleForWriting];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  
  // Write to stdin
  [inHandle writeData: [testInput dataUsingEncoding: NSUTF8StringEncoding]];
  [inHandle closeFile];
  
  // Read from stdout
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([data length] > 0, "captured output after writing to stdin");
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  PASS([output rangeOfString: @"Hello from stdin"].location != NSNotFound,
       "stdout echoed stdin input correctly");
  DESTROY(output);
  DESTROY(task);

  /* Test 3: Separate stdout and stderr capture */
  task = [[NSTask alloc] init];
  inPipe = [NSPipe pipe];
  outPipe = [NSPipe pipe];
  errPipe = [NSPipe pipe];
  
  [task setLaunchPath: [helpers stringByAppendingPathComponent: teststdio]];
  [task setStandardInput: inPipe];
  [task setStandardOutput: outPipe];
  [task setStandardError: errPipe];
  
  inHandle = [inPipe fileHandleForWriting];
  outHandle = [outPipe fileHandleForReading];
  errHandle = [errPipe fileHandleForReading];
  
  [task launch];
  
  // Write to stdin
  NSString *testMsg = @"Test stderr\n";
  [inHandle writeData: [testMsg dataUsingEncoding: NSUTF8StringEncoding]];
  [inHandle closeFile];
  
  // Read from both stdout and stderr
  NSData *outData = [outHandle readDataToEndOfFile];
  NSData *errData = [errHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([outData length] > 0, "captured stdout with separate stderr");
  PASS([errData length] > 0, "captured stderr separately from stdout");
  
  NSString *outStr = [[NSString alloc] initWithData: outData 
                                            encoding: NSUTF8StringEncoding];
  NSString *errStr = [[NSString alloc] initWithData: errData 
                                            encoding: NSUTF8StringEncoding];
  
  PASS([outStr rangeOfString: @"STDOUT"].location != NSNotFound,
       "stdout contains STDOUT marker");
  PASS([errStr rangeOfString: @"STDERR"].location != NSNotFound,
       "stderr contains STDERR marker");
  PASS([errStr rangeOfString: @"Test stderr"].location != NSNotFound,
       "stderr contains expected input text");
  
  DESTROY(outStr);
  DESTROY(errStr);
  DESTROY(task);

  /* Test 4: Multiple tasks with different stdio configurations */
  int i;
  for (i = 0; i < 3; i++)
    {
      task = [[NSTask alloc] init];
      outPipe = [NSPipe pipe];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testecho]];
      [task setArguments: [NSArray arrayWithObjects: 
        [NSString stringWithFormat: @"Task%d", i], nil]];
      [task setStandardOutput: outPipe];
      outHandle = [outPipe fileHandleForReading];
      
      [task launch];
      data = [outHandle readDataToEndOfFile];
      [task waitUntilExit];
      
      output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      NSRange range = [output rangeOfString: [NSString stringWithFormat: @"Task%d", i]];
      PASS(range.location != NSNotFound,
           "task %d stdio redirection works correctly", i);
      DESTROY(output);
      DESTROY(task);
    }

  [arp release];
  return 0;
}
