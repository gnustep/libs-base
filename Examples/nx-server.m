#include <remote/NXConnection.h>
#include <objc/List.h>

int main(int argc, char *argv[])
{
  id s = [[List alloc] init];
  id c;

  [s addObject:[Object new]];

  c = [NXConnection registerRoot:s withName:"nxserver"];
  [c run];

  exit(0);
}
