#include <Foundation/NSSet.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>

int
main ()
{
  id a, s1, s2;
  id enumerator;

  a = [NSArray arrayWithObjects:
	       @"vache", @"poisson", @"cheval", @"poulet", nil];

  s1 = [NSSet setWithArray:a];

  assert ([s1 member:@"vache"]);
  assert ([s1 containsObject:@"cheval"]);
  assert ([s1 count] == 4);

  enumerator = [s1 objectEnumerator];
  while ([[enumerator nextObject] description]);

  s2 = [s1 mutableCopy];
  assert ([s1 isEqual:s2]);

  printf("Test passed\n");
  exit (0);
}
