#include <Foundation/Foundation.h>
#include <stdio.h>


#if 0
int main ()
{
  id o = [NSObject new];
  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);
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
