#include <Foundation/Foundation.h>
#include <stdio.h>


#if 1
int main ()
{
  id	pool = [NSAutoreleasePool new];
  id o = [NSObject new];
  NSLock *lock = [NSLock new];
  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);
  [lock tryLock];
  exit (0);
}
#else
int main (int argc, char **argv)
{
  NSString *string;
  id	pool = [NSAutoreleasePool new];
  NSProcessInfo	*info = [NSProcessInfo processInfo];
  NSUserDefaults	*defaults;
  
  [info setProcessName: @"TestProcess"];
  defaults = [NSUserDefaults standardUserDefaults];
  NSLog(@"%@", [defaults  dictionaryRepresentation]);
  return 0;
}
#endif
