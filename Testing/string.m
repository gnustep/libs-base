#include "objects/String.h"

int main()
{
  id s = @"This is a test string";
  id s2;

  printf("The string [%s], length %d\n", [s cString], [s length]);
  exit(0);
}
