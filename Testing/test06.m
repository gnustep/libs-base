
#include <objects/objects.h>

#define N 20

int main()
{
  int i;

  Array* array = [[Array alloc] init];

  for (i = 0; i < N; i++)
    {
      [array addObject:[[Object alloc] init]];
    }

  [array makeObjectsPerform:@selector(name)];

  [[array objectAtIndex:0] hash];
  [[array releaseObjects] release];
  printf("no errors\n");
  exit(0);
}
