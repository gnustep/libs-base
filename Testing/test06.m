
#include <gnustep/base/all.h>

#define N 20

int main()
{
  int i;

  Array* array = [[Array alloc] init];

  for (i = 0; i < N; i++)
    {
      [array addObject:[[[NSObject alloc] init] autorelease]];
    }

  [array makeObjectsPerform:@selector(name)];

  [[array objectAtIndex:0] hash];
  [array release];
  printf("no errors\n");
  exit(0);
}
