#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSProcessInfo.h>
#import "ObjectTesting.h"

/* Test environment variable handling with posix_spawn
 * Ensures that environment variables are correctly passed to spawned processes
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testenvvar;
  NSTask *task;
  NSPipe *outPipe;
  NSFileHandle *outHandle;
  NSData *data;
  NSString *output;
  NSDictionary *env;
  NSMutableDictionary *customEnv;

#if defined(_WIN32)
  testenvvar = @"testenvvar.exe";
#else
  testenvvar = @"testenvvar";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  env = [[NSProcessInfo processInfo] environment];

  /* Test 1: Task inherits parent environment by default */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: @"PATH", nil]];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([task terminationStatus] == 0, "task finds inherited PATH variable");
  
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  PASS([output rangeOfString: @"PATH="].location != NSNotFound,
       "output contains PATH variable");
  DESTROY(output);
  DESTROY(task);

  /* Test 2: Custom environment variable */
  customEnv = [NSMutableDictionary dictionaryWithDictionary: env];
  [customEnv setObject: @"TestValue123" forKey: @"CUSTOM_TEST_VAR"];
  
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: 
    @"CUSTOM_TEST_VAR", @"TestValue123", nil]];
  [task setEnvironment: customEnv];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  PASS([task terminationStatus] == 0, 
       "custom environment variable passed correctly");
  DESTROY(task);

  /* Test 3: Multiple custom environment variables */
  customEnv = [NSMutableDictionary dictionaryWithDictionary: env];
  [customEnv setObject: @"Value1" forKey: @"TEST_VAR_1"];
  [customEnv setObject: @"Value2" forKey: @"TEST_VAR_2"];
  [customEnv setObject: @"Value3" forKey: @"TEST_VAR_3"];
  
  int i;
  for (i = 1; i <= 3; i++)
    {
      task = [[NSTask alloc] init];
      outPipe = [NSPipe pipe];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
      [task setArguments: [NSArray arrayWithObjects:
        [NSString stringWithFormat: @"TEST_VAR_%d", i],
        [NSString stringWithFormat: @"Value%d", i],
        nil]];
      [task setEnvironment: customEnv];
      [task setStandardOutput: outPipe];
      outHandle = [outPipe fileHandleForReading];
      
      [task launch];
      data = [outHandle readDataToEndOfFile];
      [task waitUntilExit];
      
      PASS([task terminationStatus] == 0,
           "environment variable TEST_VAR_%d set correctly", i);
      DESTROY(task);
    }

  /* Test 4: Minimal environment (with only required variables for dynamic linking) */
  customEnv = [NSMutableDictionary dictionary];
  [customEnv setObject: @"OnlyThis" forKey: @"ONLY_VAR"];
#if defined(_WIN32)
  /* On Windows, PATH is needed for finding DLLs */
  if ([env objectForKey: @"PATH"] != nil)
    {
      [customEnv setObject: [env objectForKey: @"PATH"] forKey: @"PATH"];
    }
#else
  /* On Unix-like systems, LD_LIBRARY_PATH is needed for dynamic linking */
  if ([env objectForKey: @"LD_LIBRARY_PATH"] != nil)
    {
      [customEnv setObject: [env objectForKey: @"LD_LIBRARY_PATH"]
                    forKey: @"LD_LIBRARY_PATH"];
    }
#endif
  
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: @"ONLY_VAR", @"OnlyThis", nil]];
  [task setEnvironment: customEnv];
  
  [task launch];
  [task waitUntilExit];
  
  PASS([task terminationStatus] == 0,
       "task with minimal environment works");
  DESTROY(task);

#if !defined(_WIN32)
  /* Test 5: Verify PATH is not inherited when not in custom env
   * Note: This test is Unix-only because on Windows, PATH is required
   * for DLL loading, making it impossible to test PATH exclusion.
   */
  customEnv = [NSMutableDictionary dictionary];
  [customEnv setObject: @"test" forKey: @"MYVAR"];
  /* Need LD_LIBRARY_PATH for dynamic linking, but not PATH */
  if ([env objectForKey: @"LD_LIBRARY_PATH"] != nil)
    {
      [customEnv setObject: [env objectForKey: @"LD_LIBRARY_PATH"]
                    forKey: @"LD_LIBRARY_PATH"];
    }
  
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: @"PATH", nil]];
  [task setEnvironment: customEnv];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  // Should fail because PATH is not in the custom environment
  PASS([task terminationStatus] != 0,
       "task doesn't inherit PATH when custom env is set without it");
  
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  PASS([output rangeOfString: @"not found"].location != NSNotFound,
       "output indicates PATH not found");
  DESTROY(output);
  DESTROY(task);
#endif

  /* Test 6: Environment with special characters */
  customEnv = [NSMutableDictionary dictionaryWithDictionary: env];
  [customEnv setObject: @"Value with spaces and = signs" 
                forKey: @"SPECIAL_VAR"];
  
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: @"SPECIAL_VAR", nil]];
  [task setEnvironment: customEnv];
  
  [task launch];
  [task waitUntilExit];
  
  PASS([task terminationStatus] == 0,
       "environment variable with special characters works");
  DESTROY(task);

  /* Test 7: Large environment */
  customEnv = [NSMutableDictionary dictionaryWithDictionary: env];
  for (i = 0; i < 50; i++)
    {
      [customEnv setObject: [NSString stringWithFormat: @"LargeValue%d", i]
                    forKey: [NSString stringWithFormat: @"LARGE_VAR_%d", i]];
    }
  
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testenvvar]];
  [task setArguments: [NSArray arrayWithObjects: @"LARGE_VAR_25", nil]];
  [task setEnvironment: customEnv];
  
  [task launch];
  [task waitUntilExit];
  
  PASS([task terminationStatus] == 0,
       "task with large environment works");
  DESTROY(task);

  [arp release];
  return 0;
}
