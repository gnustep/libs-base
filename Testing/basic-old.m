#include <objc/objc-api.h>
#include <objc/Object.h>
#include <stdio.h>

int main ()
{
  id o = [Object new];
  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);
  exit (0);
}
