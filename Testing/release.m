#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#ifndef _WIN32
#include "malloc.h"
#endif

@interface ReleaseTester : NSObject
{
  int label;
}
@end

@implementation ReleaseTester

- initWithLabel: (int)l
{
  label = l;
  return self;
}

- (oneway void) release
{
  // printf ("release'ing %d\n", label);
  [super release];
}

- (void) dealloc
{
  // printf ("dealloc'ing %d\n", label);
  [super dealloc];
}

@end

void
autorelease_test (int depth)
{
  int n = 2;
  id os[n];
  id a = [NSArray new];
  int i;
  id arp;

  if (depth < 0)
    return;

  arp = [[NSAutoreleasePool alloc] init];

  for (i = 0; i < n; i++)
    {
      id r = [[[ReleaseTester alloc] initWithLabel: i+depth*n] autorelease];
      os[i] = r;
      [a addObject: r];
    }

#if 0
  fprintf (stderr, "totalAutoreleasedObjects %d\n", 
	   [NSAutoreleasePool totalAutoreleasedObjects]);
#endif
  autorelease_test (depth-1);

  [a release];

  [arp release];

  fflush (stdin);
}

void
release_test (int depth)
{
  int n = 1000;
  id os[n];
  int i;

  if (depth < 0)
    return;

  for (i = 0; i < n; i++)
    os[i] = [[ReleaseTester alloc] initWithLabel: i];
  for (i = 0; i < n; i++)
    [os[i] retain];
  for (i = 0; i < n; i++)
    [os[i] release];
  for (i = 0; i < n; i++)
    [os[i] release];

  release_test (depth-1);
}


#if GNU_LIBC
static void *(*old_malloc_hook) (size_t);
static void (*old_free_hook) (void *ptr);

static void *
my_malloc_hook (size_t size)
{
  void *result;
  __malloc_hook = old_malloc_hook;
  result = malloc (size);
  /* `printf' might call `malloc', so protect it too. */
  printf ("malloc (%u) returns %p\n", (unsigned int) size, result);
  __malloc_hook = my_malloc_hook;
  return result;
}

void 
my_free_hook (void *ptr)
{
  __free_hook = old_free_hook;
  free (ptr);
  __free_hook = my_free_hook;
}
#endif /* GNU_LIBC */

int
main ()
{
  int i;

#if GNU_LIBC
  old_malloc_hook = __malloc_hook;
  old_free_hook = __free_hook;
  __malloc_hook = my_malloc_hook;
  __free_hook = my_free_hook;
#endif /* GNU_LIBC */

#if 1
  for (i = 0; i < 10000; i++)
    autorelease_test (3);
#else
  /* Checking for memory leak in objc_mutex_lock() */
  _objc_mutex_t gate;
  gate = objc_mutex_allocate ();
  for (i = 0; i < 1000000; i++)
    {
      objc_mutex_lock (gate);
      objc_mutex_unlock (gate);
    }
#endif

  exit (0);
}
