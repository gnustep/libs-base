#import "ObjectTesting.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <pthread.h>
#endif

/* Several threads send their first message to NSMutableArray at the same
 * moment, before anything else in the process has used the array classes.
 * Each must get a concrete mutable array from +alloc.  Nothing in
 * Foundation is used before the threads have finished.
 */

#define	THREADS	32

static volatile int	waiting = 0;
static int		results[THREADS];	/* 0 ok, 1 nil, 2 abstract */

#if defined(_WIN32)
unsigned int __stdcall
#else
void *
#endif
firstUse(void *arg)
{
  int			index = (int)(intptr_t)arg;
  NSAutoreleasePool	*arp;
  id			a;

  __sync_fetch_and_add(&waiting, 1);
  while (waiting < THREADS)
    {
      /* Start together. */
    }
  arp = [NSAutoreleasePool new];
  a = [NSMutableArray alloc];
  if (a == nil)
    {
      results[index] = 1;
    }
  else if ([a class] == [NSMutableArray class])
    {
      results[index] = 2;
    }
  else
    {
      a = [a init];
      [a addObject: @"x"];
      [a release];
    }
  [arp release];
  return 0;
}

int main()
{
  NSAutoreleasePool	*arp;
  int			nilCount = 0;
  int			abstractCount = 0;
  int			i;
#if defined(_WIN32)
  HANDLE		thr[THREADS];

  for (i = 0; i < THREADS; i++)
    {
      thr[i] = (HANDLE)_beginthreadex(NULL, 0, firstUse,
	(void*)(intptr_t)i, 0, NULL);
    }
  for (i = 0; i < THREADS; i++)
    {
      WaitForSingleObject(thr[i], INFINITE);
      CloseHandle(thr[i]);
    }
#else
  pthread_t		thr[THREADS];

  for (i = 0; i < THREADS; i++)
    {
      pthread_create(&thr[i], NULL, firstUse, (void*)(intptr_t)i);
    }
  for (i = 0; i < THREADS; i++)
    {
      pthread_join(thr[i], NULL);
    }
#endif

  arp = [NSAutoreleasePool new];
  for (i = 0; i < THREADS; i++)
    {
      if (results[i] == 1)
	{
	  nilCount++;
	}
      else if (results[i] == 2)
	{
	  abstractCount++;
	}
    }
  PASS(nilCount == 0,
    "+[NSMutableArray alloc] does not return nil on concurrent first use")
  PASS(abstractCount == 0,
    "+[NSMutableArray alloc] does not return an abstract NSMutableArray"
    " on concurrent first use")
  [arp release];
  return 0;
}
