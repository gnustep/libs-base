/* Test Heap class. */

#include <gnustep/base/objects.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>

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
  int i, s;
  id s1, s2;
  id arp;

  Heap* heap = [Heap new];
  Array* array = [Array new];

  arp = [NSAutoreleasePool new];

  for (i = 0; i < N; i++)
    {
      s = random () % 100;
      [heap addObject: [NSNumber numberWithInt: s]];
      [array addObject: [NSNumber numberWithInt: s]];
    }
  [array sortContents];

  [heap printForDebugger];
  [array printForDebugger];

  for (i = 0; i < N; i++)
    {
      s1 = [heap firstObject];
      s2 = [array firstObject];
      [heap removeFirstObject];
      [array removeFirstObject];
      printf("(%d,%d) ", [s1 intValue], [s2 intValue]);
      assert ([s1 intValue] == [s2 intValue]);
    }
  printf("\n");
  
  [heap release];
  [array release];

  [arp release];

  exit(0);
}
