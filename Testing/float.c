#include <math.h>

#define FACTOR (1 << 30)
/* #define FACTOR 1e8 */

int main()
{
  int i1, i2, i3;
  unsigned u2, u3 = 0;
  volatile double d = 0.123456789;
  volatile double di;

#if 0
  printf ("%f %d\n", d, i);
  d = frexp (d, &i);
  printf ("%f %d\n", d, i);

  d = ldexp (d, i);
  printf("%f\n", d);

#elif 1

  i1 = i2 = i3 = 0;
  d = -0.123456789;
  printf ("encoded value = %.15g\n", d);
  d = frexp (d, &i1);
  printf ("%g %d %d %d\n", d, i1, i2, i3);
  d *= FACTOR;
  i2 = d;
  d -= i2;
  printf ("%g %d %d %d\n", d, i1, i2, i3);
  d *= FACTOR;
  i3 = d;
  d -= i3;
  printf ("%g %d %d %d\n", d, i1, i2, i3);

  d = 0;
  d = i3;
  d /= FACTOR;
  d += i2;
  d /= FACTOR;
  d = ldexp (d, i1);
  printf ("decoded value = %.15g\n", d);

#else

  d = 0.123456789;
  printf ("original value = %g\n", d);

  d = frexp (d, &i1);
  d *= FACTOR;
  d = modf (d, &di);
  u2 = di;
  if (d != 0)
    {
      d *= FACTOR;
      d = modf (d, &di);
      u3 = di;
    }
  printf ("%d %u %u\n", i1, u2, u3);
  
  d = 0;
  d = u3;
  d /= FACTOR;
  d += u2;
  d /= FACTOR;
  d = ldexp (d, i1);
  printf ("decoded value = %g\n", d);

#endif

  exit (0);
}
