
#include <gnustep/base/Connection.h>
#include <gnustep/base/Proxy.h>
#include "first-server.h"
#include <Foundation/NSString.h>

int main(int argc, char *argv[])
{
  id s;

  if (argc > 2)
    {
      printf("Looking for connection named `firstserver' on host `%s'...\n",
	     argv[2]);
      s = [Connection rootProxyAtName:@"firstserver" 
		      onHost:[NSString stringWithCString:argv[2]]];
    }
  else
    {
      printf("Looking for connection named `firstserver' on localhost...\n");
      s = [Connection rootProxyAtName:@"firstserver"];
    }

  printf("Found connection named `firstserver'\n");

  printf("Saying hello to the server\n");
  if (argc > 1)
    [s sayHiTo:argv[1]];
  else
    [s sayHiTo:"out there"];


  printf("Shutting down my connection to the server\n");
  [[s connectionForProxy] invalidate];
  /* Although this isn't strictly necessary.  The server will recognize
     that we are gone, and handle it, if we just exit (or if we crash). */

  exit(0);
}
