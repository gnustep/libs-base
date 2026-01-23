#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLock.h>
#import "ObjectTesting.h"

/* Test NSTask in a multithreaded environment
 * This is critical because posix_spawn() is thread-safe unlike fork()
 * which can cause deadlocks in multithreaded applications
 */

static NSLock *lock = nil;
static int successCount = 0;
static int failureCount = 0;

@interface TaskRunner : NSObject
{
  NSString *helperPath;
  int threadId;
}
- (id) initWithHelperPath: (NSString *)path threadId: (int)tid;
- (void) runTask: (id)arg;
@end

@implementation TaskRunner

- (id) initWithHelperPath: (NSString *)path threadId: (int)tid
{
  self = [super init];
  if (self)
    {
      helperPath = [path retain];
      threadId = tid;
    }
  return self;
}

- (void) dealloc
{
  [helperPath release];
  [super dealloc];
}

- (void) runTask: (id)arg
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSTask *task;
  int i;
  
  /* Each thread launches multiple tasks */
  for (i = 0; i < 3; i++)
    {
      task = [[NSTask alloc] init];
      [task setLaunchPath: helperPath];
      [task setArguments: [NSArray arrayWithObjects: @"0", nil]];

      [task launch];
      [task waitUntilExit];

      if ([task terminationStatus] == 0)
        {
          [lock lock];
          successCount++;
          [lock unlock];
        }
      else
        {
          [lock lock];
          failureCount++;
          [lock unlock];
        }

      [task release];
    }
  
  [pool release];
}

@end

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *mgr;
  NSString *helpers;
  NSString *testsimple;
  NSMutableArray *threads;
  int i;
  int numThreads = 5;

#if defined(_WIN32)
  testsimple = @"testsimple.exe";
#else
  testsimple = @"testsimple";
#endif

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  helpers = [helpers stringByAppendingPathComponent: testsimple];

  lock = [[NSLock alloc] init];
  threads = [NSMutableArray arrayWithCapacity: numThreads];

  /* Test 1: Launch tasks from multiple threads concurrently */
  for (i = 0; i < numThreads; i++)
    {
      TaskRunner *runner = [[TaskRunner alloc] initWithHelperPath: helpers
                                                          threadId: i];
      NSThread *thread = [[NSThread alloc] initWithTarget: runner
                                                 selector: @selector(runTask:)
                                                   object: nil];
      [threads addObject: thread];
      [thread start];
      [runner release];
    }

  /* Wait for all threads to complete */
  for (i = 0; i < [threads count]; i++)
    {
      NSThread *thread = [threads objectAtIndex: i];
      while ([thread isExecuting])
        {
          [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                   beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        }
    }

  /* Verify results */
  int expectedSuccess = numThreads * 3; // Each thread runs 3 tasks
  
  PASS(failureCount == 0, 
    "no failures in multithreaded task execution (failures: %d)", failureCount);
  PASS(successCount == expectedSuccess,
    "all %d tasks succeeded in multithreaded execution (got %d)", 
    expectedSuccess, successCount);

  /* Test 2: Verify we can still launch tasks from main thread after 
   * multithreaded execution */
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: helpers];
  [task setArguments: [NSArray array]];
  [task launch];
  [task waitUntilExit];
  PASS([task terminationStatus] == 0,
    "can launch task from main thread after multithreaded execution");
  DESTROY(task);

  [lock release];
  [arp release];
  return 0;
}
