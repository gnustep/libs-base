/* A simple demonstration of the GNU Dictionary object.
   In this example the Dictionary holds int's which are keyed by strings. */

#include <base/Dictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>

int main()
{
  id d;

  /* Create a Dictionary object. */
  d = [[Dictionary alloc] initWithCapacity: 32];

  /* Load the dictionary with some items */
  [d putObject: [NSNumber numberWithInt: 1] atKey: @"one"];
  [d putObject: [NSNumber numberWithInt: 2] atKey: @"two"];
  [d putObject: [NSNumber numberWithInt: 3] atKey: @"three"];
  [d putObject: [NSNumber numberWithInt: 4] atKey: @"four"];
  [d putObject: [NSNumber numberWithInt: 5] atKey: @"five"];
  [d putObject: [NSNumber numberWithInt: 6] atKey: @"six"];
  
  printf("There are %u elements stored in the dictionary\n",
	 [d count]);

  printf("Element %d is stored at \"%s\"\n", 
	 [[d objectAtKey: @"three"] intValue],
	 "three");

  printf("Removing element stored at \"three\"\n");
  [d removeObjectAtKey: @"three"];

  printf("Removing element 2\n");
  [d removeObject: [NSNumber numberWithInt: 2]];

  printf("Now there are %u elements stored in the dictionary\n",
	 [d count]);

  exit(0);
}
