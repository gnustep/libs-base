#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTask.h>

int
main()
{
  id pool;
  NSTask	*task;

  pool = [[NSAutoreleasePool alloc] init];

  task = [NSTask launchedTaskWithLaunchPath: @"/bin/ls"
				  arguments: nil];
  [task waitUntilExit];
  printf("Exit status - %d\n", [task terminationStatus]);

  [pool release];

  exit(0);
}

