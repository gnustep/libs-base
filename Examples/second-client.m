#include "second-client.h"
#include <objects/String.h>

int main(int argc, char *argv[])
{
  id server;
  id a1;
  id remote_array;
  char namebuf[16];

  printf("Looking up server object on localhost with name `secondserver'\n");
  server = [Connection rootProxyAtName:@"secondserver"];
  printf("Found server.\n");

  /* Create an AppellationObject */
  a1 = [[AppellationObject alloc] init];
  sprintf(namebuf, "%d", (int)getpid());
  [a1 setAppellation:namebuf];
  printf("This client has appellation %s\n", [a1 appellation]);

  /* Let the server know about object a1. */
  [server addRemoteObject:a1];

  /* Get the server's array of all other AppellationObject's */
  remote_array = [server array];

  /* Print all the appellations */
  {
    int i, count;
    const char *s;
    id a2;			/* appellation object from server's list */
    
    count = [remote_array count];
    for (i = 0; i < count; i++)
      {
	a2 = [remote_array objectAtIndex:i];
	s = [a2 appellation];
	printf("Server knows about client with appellation %s\n", s);
	if ([a2 isProxy])
	  (*objc_free)((void*)s);
      }
  }

  /* Run, exiting as soon as there are 15 seconds with no requests */
  [[server connectionForProxy] runConnectionWithTimeout:15000];
  
  /* Clean up, to let the server know we're going away */
  [[server connectionForProxy] free];

  exit(0);
}
