
#include <objects/Connection.h>
#include "first-server.h"

int main(int argc, char *argv[])
{
  id s;

  if (argc > 2)
    {
      printf("Looking for connection named `firstserver' on host `%s'...\n",
	     argv[2]);
      s = [Connection rootProxyAtName:"firstserver" onHost:argv[2]];
    }
  else
    {
      printf("Looking for connection named `firstserver' on localhost...\n");
      s = [Connection rootProxyAtName:"firstserver"];
    }

  printf("Found connection named `firstserver'\n");

  printf("Saying hello to the server\n");
  if (argc > 1)
    [s sayHiTo:argv[1]];
  else
    [s sayHiTo:"out there"];


  printf("Shutting down my connection to the server\n");
  [s free];

  exit(0);
}
