#include <Foundation/NSObject.h>
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

     string = [NSString stringWithCString:argv[1]];

     return 0;
}
#endif
