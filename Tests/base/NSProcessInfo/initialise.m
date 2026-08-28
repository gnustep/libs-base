#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>

#include <stdlib.h>

/* GSInitializeProcess() is what a program uses when the library cannot pick
 * the arguments up for itself, which is the case for a library loaded into a
 * host that has its own main().  An Android activity is one such host.
 */
int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*key = @"AN_UNUSUAL_ENVIRONMENT_KEY";
  NSString		*executable;
  char			*argv[2];
  NSDictionary		*env;

  /* The zero'th argument has to be somewhere the executable can be found:
   * the library works out its own location from it.
   */
  executable = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
  argv[0] = (char *)[executable UTF8String];
  argv[1] = 0;

  putenv((char *)"AN_UNUSUAL_ENVIRONMENT_KEY=hello");

  GSInitializeProcess(1, argv, 0);

  env = [[NSProcessInfo processInfo] environment];
  PASS([env count] > 0,
    "a process initialised without an environment has the one it started with")
  PASS_EQUAL([env objectForKey: key], @"hello",
    "and a variable set before initialisation is in it")

  PASS_EQUAL([[NSProcessInfo processInfo] processName], @"initialise",
    "the process name comes from the arguments supplied")

  [arp release]; arp = nil;
  return 0;
}
