#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSTask.h>

int
main()
{
  id pool;
  NSDictionary	*env;
  NSTask	*task;
  NSData	*d;

  pool = [[NSAutoreleasePool alloc] init];

#ifdef __MINGW__
  task = [NSTask launchedTaskWithLaunchPath: @"C:\\WINDOWS\\COMMAND\\MEM.EXE"
				  arguments: nil];
#else
  task = [NSTask launchedTaskWithLaunchPath: @"/bin/ls"
				  arguments: nil];
#endif
  [task waitUntilExit];
  printf("Exit status - %d\n", [task terminationStatus]);

  [pool release];
  pool = [[NSAutoreleasePool alloc] init];

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
  [task release];
  [pool release];

  exit(0);
}

