#include <math.h>

int main()
{
  int i = 0;
  double d = 0.123456789;

  printf ("%f %d\n", d, i);
  d = frexp (d, &i);

  d = ldexp (d, i);
  printf("%f\n", d);

  printf ("%f %d\n", d, i);
  d = frexp (d, &i);

  printf ("%f %d\n", d, i);
  d = frexp (d, &i);

  printf ("%f %d\n", d, i);
  d = frexp (d, &i);

  exit (0);
}
