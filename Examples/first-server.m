
#include <objects/Connection.h>
#include "first-server.h"
#include <objects/String.h>

@implementation FirstServer
- sayHiTo: (char *)name
{
  printf("Hello, %s.\n", name);
  return self;
}
@end

int main()
{
  id s, c;

  /* Create our server object */
  s = [[FirstServer alloc] init];

  /* Register a connection that provides the server object to the network */
  printf("Registering a connection for the server using name `firstserver'\n");
  c = [Connection newRegisteringAtName:@"firstserver"
		  withRootObject:s];
  
  /* Run the connection */
  printf("Running the connection... (until you interrupt with control-C)\n");
  [c runConnection];			/* This runs until interrupt. */

  exit(0);
}
