
#include <objects/objects.h>

#define N 20

#if (sun && __svr4__) || defined(__hpux) || defined(_SEQUENT_)
long lrand48();
#define random lrand48
#else
long random();
#endif

int main()
{
  int i;
  short s, s1, s2;

  Heap* heap = [[Heap alloc] initWithType:"s"];
  Array* array = [[Array alloc] initWithType:"s"];

  for (i = 0; i < N; i++)
    {
      s = (short)random();
      [heap addElement:s];
      [array addElement:s];
    }
  [array sortContents];

  for (i = 0; i < N; i++)
    {
      s1 = [heap removeFirstElement].short_int_u;
      s2 = [array removeLastElement].short_int_u;
      printf("(%d,%d) ", s1, s2);
      if (s1 != s2)
	exit(1);
    }
  printf("\n");
  
  /* cause an error */
  /*  s = [heap elementAtIndex:999].short_int_u; */

  [heap release];
  exit(0);
}
