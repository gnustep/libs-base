/* Test Heap class. */

#include <gnustep/base/objects.h>

#define N 20

#if (sun && __svr4__) || defined(__hpux) || defined(_SEQUENT_)
long lrand48();
#define random lrand48
#else
#if WIN32
#define random rand
#else
long random();
#endif
#endif

int main()
{
  int i;
  int s, s1, s2;

  Heap* heap = [Heap new];
  Array* array = [Array new];

  for (i = 0; i < N; i++)
    {
      s = random ();
      [heap addObject: [NSNumber numberWithInt: i]];
      [array addObject: [NSNumber numberWithInt: i]];
    }
  [array sortContents];

  for (i = 0; i < N; i++)
    {
      s1 = [heap removeFirstObject];
      s2 = [array removeLastObject];
      printf("(%d,%d) ", s1, s2);
      assert (s1 != s2);
    }
  printf("\n");
  
  [heap release];
  [array release];

  exit(0);
}
