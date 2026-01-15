#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSError.h>
#import "ObjectTesting.h"

/* Test setCurrentDirectoryPath with posix_spawn_file_actions_addchdir_np
 * This is a critical test because it uses a GNU extension (glibc 2.29+)
 * and is one of the main reasons we require modern glibc for posix_spawn
 */
int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testpwd;
  NSString *testsimple;
  NSTask *task;
  NSPipe *outPipe;
  NSFileHandle *outHandle;
  NSData *data;
  NSString *output;
  NSString *trimmed;
  NSString *currentDir;
  NSString *parentDir;
  NSString *tmpDir;
  NSError *error;

#if defined(_WIN32)
  testpwd = @"testpwd.exe";
  testsimple = @"testsimple.exe";
#else
  testpwd = @"testpwd";
  testsimple = @"testsimple";
#endif

  mgr = [NSFileManager defaultManager];
  currentDir = [mgr currentDirectoryPath];
  helpers = [currentDir stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  
  parentDir = [currentDir stringByDeletingLastPathComponent];
  tmpDir = NSTemporaryDirectory();

  /* Test 1: Task inherits current directory by default */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testpwd]];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  trimmed = [[output stringByTrimmingCharactersInSet: 
    [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
  DESTROY(output);
  
  PASS([trimmed isEqualToString: currentDir],
       "task inherits current directory (expected '%@', got '%@')",
       currentDir, trimmed);
  DESTROY(trimmed);
  DESTROY(task);

  /* Test 2: setCurrentDirectoryPath to parent directory */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testpwd]];
  [task setCurrentDirectoryPath: parentDir];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  trimmed = [[output stringByTrimmingCharactersInSet:
    [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
  DESTROY(output);
  
  PASS([trimmed isEqualToString: parentDir],
       "task runs in parent directory (expected '%@', got '%@')",
       parentDir, trimmed);
  DESTROY(trimmed);
  DESTROY(task);

  /* Test 3: setCurrentDirectoryPath to /tmp */
  task = [[NSTask alloc] init];
  outPipe = [NSPipe pipe];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testpwd]];
  [task setCurrentDirectoryPath: tmpDir];
  [task setStandardOutput: outPipe];
  outHandle = [outPipe fileHandleForReading];
  
  [task launch];
  data = [outHandle readDataToEndOfFile];
  [task waitUntilExit];
  
  output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  trimmed = [[output stringByTrimmingCharactersInSet:
    [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
  DESTROY(output);
  
  PASS([trimmed isEqualToString: tmpDir] || 
       [tmpDir hasPrefix: trimmed], // Some systems may resolve symlinks differently
       "task runs in temp directory (expected '%@', got '%@')",
       tmpDir, trimmed);
  DESTROY(trimmed);
  DESTROY(task);

  /* Test 4: Invalid directory path should fail gracefully */
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setCurrentDirectoryPath: @"/nonexistent/directory/path"];
  
  error = nil;
  BOOL launched = [task launchAndReturnError: &error];
  
  PASS(launched == NO, "task fails to launch with invalid directory");
  PASS(error != nil, "error is set for invalid directory");
  DESTROY(task);

  /* Test 5: Multiple tasks with different directories */
  NSArray *testDirs = [NSArray arrayWithObjects: 
    currentDir, parentDir, tmpDir, nil];
  int i;
  
  for (i = 0; i < [testDirs count]; i++)
    {
      NSString *testDir = [testDirs objectAtIndex: i];
      
      task = [[NSTask alloc] init];
      outPipe = [NSPipe pipe];
      [task setLaunchPath: [helpers stringByAppendingPathComponent: testpwd]];
      [task setCurrentDirectoryPath: testDir];
      [task setStandardOutput: outPipe];
      outHandle = [outPipe fileHandleForReading];
      
      [task launch];
      data = [outHandle readDataToEndOfFile];
      [task waitUntilExit];
      
      output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      trimmed = [[output stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
      DESTROY(output);
      
      PASS([trimmed isEqualToString: testDir] || [testDir hasPrefix: trimmed],
           "sequential task %d runs in correct directory", i);
      DESTROY(trimmed);
      DESTROY(task);
    }

  /* Test 6: Verify directory change doesn't affect parent process */
  NSString *dirBeforeTest = [mgr currentDirectoryPath];
  
  task = [[NSTask alloc] init];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: testsimple]];
  [task setCurrentDirectoryPath: tmpDir];
  [task launch];
  [task waitUntilExit];
  DESTROY(task);
  
  NSString *dirAfterTest = [mgr currentDirectoryPath];
  
  PASS([dirBeforeTest isEqualToString: dirAfterTest],
       "parent process directory unchanged after child task runs");

  [arp release];
  return 0;
}
