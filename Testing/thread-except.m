/* Test whether each thread has their own exception handlers. */

#define _REENTRANT

#include <stdio.h>
#include <stdlib.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>

#define N 10 /* Number of threads */
#define MAX_ITER 10000.0 /* Max number of iterations. */

FILE *file;

@interface SingleThread : NSObject
{
  int ident; // Identifier
}

- initWithInt: (int)n;
- (void)runWith: (id)thing;

@end

@implementation SingleThread

- initWithInt: (int)n
{
  ident = n;
  return self;
}

- (void)runWith: (id)thing
{
  int i, n;
  
  NS_DURING
    n = 1+(int)((MAX_ITER*rand())/(RAND_MAX+1.0));
    for (i = 0; i < n; i++)
      {
	fprintf(file, "%d ", i);
	fflush(file);
      }
    [NSException raise: @"Some exception" format: @"thread %d", ident];
  NS_HANDLER
    printf("%s: %s for thread %d\n", [[localException name] cString],
	   [[localException reason] cString], ident);
  NS_ENDHANDLER
  [NSThread exit];
}

@end

int main()
{
  int i;
  SingleThread *threads[N];

  printf("We run %d threads.\n", N);
  printf("Some of them might not raise exceptions,\n");
  printf("but the exception associated with each thread must match.\n");
  file = fopen("/dev/null", "w");
  srand(10);
  for (i = 0; i < N; i++)
    threads[i] = [[SingleThread alloc] initWithInt: i];
  NS_DURING
    for (i = 0; i < N; i++)
      [NSThread detachNewThreadSelector: @selector(runWith:)
		toTarget: threads[i] withObject: nil];
  
    // Hopefully this will end after all the other threads end.
    for (i = 0; i < N*MAX_ITER; i++)
      {
	fprintf(file, "%d", i);
	fflush(file);
      }
  NS_HANDLER
    printf("There's a runaway exception!  Something is wrong!\n");
  NS_ENDHANDLER
  fclose(file);
  return 0;
}
