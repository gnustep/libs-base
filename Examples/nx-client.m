#include <remote/NXConnection.h>
#include <remote/NXProxy.h>
#include <objc/List.h>

int main(int argc, char *argv[])
{
  id s;

  s = [NXConnection connectToName:"nxserver"];

  printf("Server has class name `%s'\n", 
	 [s name]);
  printf("First object in server has class name `%s'\n", 
	 [[s objectAt:0] name]);

  /* Be nice and shut down the connection */
  [[s connectionForProxy] free];

  exit(0);
}
