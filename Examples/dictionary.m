/* A simple demonstration of the GNU Dictionary object.
   In this example the Dictionary holds int's which are keyed by strings. */

#include <gnustep/base/stdall.h>
#include <gnustep/base/Dictionary.h>

int main()
{
  id d;

  /* Create a Dictionary object that will store int's with string keys */
  d = [[Dictionary alloc] 
       initWithType:@encode(int)
       keyType:@encode(char*)];

  /* Load the dictionary with some items */
  [d putElement:1 atKey:"one"];
  [d putElement:2 atKey:"two"];
  [d putElement:3 atKey:"three"];
  [d putElement:4 atKey:"four"];
  [d putElement:5 atKey:"five"];
  [d putElement:6 atKey:"six"];
  
  printf("There are %u elements stored in the dictionary\n",
	 [d count]);

  printf("Element %d is stored at \"%s\"\n", 
	 [d elementAtKey:"three"].int_u, "three");

  printf("Removing element stored at \"three\"\n");
  [d removeElementAtKey:"three"];

  printf("Removing element 2\n");
  [d removeElement:2];

  printf("Now there are %u elements stored in the dictionary\n",
	 [d count]);

  exit(0);
}
