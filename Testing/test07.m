#include <gnustep/base/objects.h>

int main()
{
  id a = [[Array alloc] initWithType:@encode(int)];
  int i;
  void plus2 (elt e) {printf("%d ", e.int_u+2);}

  for (i = 0; i < 10; i++)
    [a addElement:i];

  [a withElementsCall:plus2];

  printf("\n");
  exit(0);
}
