#include <Foundation/Foundation.h>
#include <stdio.h>

#define	_(X)	\
[[NSBundle mainBundle] localizedStringForKey: @#X value: nil table: nil]
#define	$(X)	\
[[NSBundle mainBundle] localizedStringForKey: X value: nil table: nil]


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
  NSURL	*url = [NSURL fileURLWithPath: @"/tmp/a"];
  NSData *data = [url resourceDataUsingCache: YES];

  NSLog(@"%@", data);
  url = [NSURL fileURLWithPath: @"/tmp/z"];
  [url setResourceData: data];

  NSLog(@"%@", _(Testing));
  NSLog(@"%@", $(@"Testing"));

  string = [NSString stringWithCString:argv[1]];

  return 0;
}
#endif
