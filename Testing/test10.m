#include <gnustep/base/objects.h>
#include <assert.h>

int main()
{
#if ELT_INCLUDES_DOUBLE

  id a = [[Array alloc] initWithType:@encode(double)];
  elt e;
  double dbl;

  printf("testing elt doubles\n");

  [a addElement:(double)3.14];
  [a addElement:(double)1.41];
  [a addElement:(double)4.15];
  [a addElement:(double)1.59];
  [a addElement:(double)5.92];
  [a addElement:(double)9.26];

  e = [a elementAtIndex:1];
  dbl = [a elementAtIndex:2].double_u;
  printf("dbl = %f\n", dbl);

  [a addElementIfAbsent:(double)9.26];
  assert([a count] == 6);

  [a removeElement:(double)3.14];
  assert([a count] == 5);

#endif /* ELT_INCLUDES_DOUBLE */

  printf("no errors\n");
  exit(0);
}
