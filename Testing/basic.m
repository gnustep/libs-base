#include <Foundation/NSObject.h>
#include <stdio.h>

int main ()
{
  id o = [NSObject new];
  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);
  exit (0);
}
