#include <Foundation/Foundation.h>


@interface TaskObs : NSObject
- (void) terminated: (NSNotification*)aNotification;
@end
@implementation TaskObs
- (void) terminated: (NSNotification*)aNotification
{
  NSLog(@"Task (%@) terminated", [aNotification object]);
}
@end

int
main()
{
  NSAutoreleasePool *pool;
  NSDictionary	*env;
  NSTask	*task;
  NSTask	*t0, *t1;
  NSData	*d;
  TaskObs	*obs = [TaskObs new];

  pool = [NSAutoreleasePool new];
  [[NSNotificationCenter defaultCenter]
    addObserver: obs
       selector: @selector(terminated:)
	   name: NSTaskDidTerminateNotification
	 object: nil];

#ifdef __MINGW__
  task = [NSTask launchedTaskWithLaunchPath: @"C:\\windows\\system32\\mem.exe"
				  arguments: nil];
#else
  task = [NSTask launchedTaskWithLaunchPath: @"/bin/ls"
				  arguments: nil];
#endif
  [task waitUntilExit];
  printf("Exit status - %d\n", [task terminationStatus]); fflush(stdout);

  RELEASE(pool);
  pool = [NSAutoreleasePool new];

  task = [NSTask new];
  env = [[[[NSProcessInfo processInfo] environment] mutableCopy] autorelease];
  [task setEnvironment: env];
  [task setLaunchPath: @"/bin/sh"];
  [task setArguments: [NSArray arrayWithObjects: @"-c", @"echo $PATH", nil]];
  if ([task usePseudoTerminal] == NO)
    printf("Argh - unable to use pseudo terminal\n");
  [task launch];
  d = [[task standardOutput] availableData];
  NSLog(@"Got PATH of '%*s'", [d length], [d bytes]);

  [task waitUntilExit];
  RELEASE(task);

  NSLog(@"Testing two tasks at the same time");
  t0 = [NSTask launchedTaskWithLaunchPath: @"/bin/sh"
				arguments:
    [NSArray arrayWithObjects: @"-c", @"echo task0", nil]];
  NSLog(@"Launched task0 - %@", t0);

  t1 = [NSTask launchedTaskWithLaunchPath: @"/bin/sh"
				arguments:
    [NSArray arrayWithObjects: @"-c", @"echo task1", nil]];
  NSLog(@"Launched task1 - %@", t1);

  while ([t0 isRunning] == YES || [t1 isRunning] == YES)
    {
      NSAutoreleasePool	*arp = [NSAutoreleasePool new];

      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:
	[NSDate dateWithTimeIntervalSinceNow: 1]];
      RELEASE(arp);
    }
  RELEASE(pool);

  exit(0);
}

