#include <foundation/NSArray.h>

int
main()
{
  id a, b;			/* arrays */
  id enumerator;

  set_behavior_debug(0);
  a = [NSArray arrayWithObjects: 
	       [NSObject class],
	       [NSArray class],
	       [NSMutableArray class],
	       nil];

  printf("NSArray has count %d\n", [a count]);
  printf("Classname at index 1 is %s\n", [[a objectAtIndex:1] name]);

  assert([a containsObject:[NSObject class]]);
  assert([a lastObject]);
  [a makeObjectsPerform:@selector(self)];
  
  enumerator = [a objectEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b name]);
  printf("\n");

  enumerator = [a reverseObjectEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b name]);
  printf("\n");

  b = [a mutableCopy];
  assert([b count]);
  [b addObject:[NSObject class]];
  [b removeObject:[NSArray class]];
  [b removeLastObject];

  assert([b firstObjectCommonWithArray:a]);

  exit(0);
}
