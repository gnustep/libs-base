#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

int
main()
{
  id a, b;			/* dictionaries */
  id enumerator;
  id objects, keys;
  id key;

  behavior_set_debug(0);

  objects = [NSArray arrayWithObjects:
		     @"vache", @"poisson", @"cheval", @"poulet", nil];
  keys = [NSArray arrayWithObjects:
		  @"cow", @"fish", @"horse", @"chicken", nil];
  a = [NSDictionary dictionaryWithObjects:objects forKeys:keys];

  printf("NSDictionary has count %d\n", [a count]);
  key = @"fish";
  printf("Object at key %s is %s\n", 
	 [key cString],
	 [[a objectForKey:key] cString]);

  assert([a count] == [[a allValues] count]);
  
  enumerator = [a objectEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b cString]);
  printf("\n");

  enumerator = [a keyEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b cString]);
  printf("\n");

  b = [a mutableCopy];
  assert([b count]);
  [b setObject:@"formi" forKey:@"ant"];
  [b removeObjectForKey:@"horse"];

  exit(0);
}
