/* Test whether Objective-C runtime +initialize support is thread-safe
 */

#include "objc-common.g"
#include <pthread.h>
#include <stdio.h>

#if defined(_WIN32)
# define	mySleep(X)	usleep(1000*(X))
#else
# define	mySleep(X)	sleep(X)
#endif

/* Use volatile variables so compiler optimisation won't prevent one thread
 * from seeing changes made by another.
 */
static volatile unsigned	initialize_entered = 0;
static volatile unsigned	initialize_exited = 0;
static volatile unsigned	class_entered = 0;
static volatile BOOL		may_proceed = NO;

@interface	MyClass : NSObject
@end

@implementation	MyClass

+ (void) initialize
{
  initialize_entered++;
  while (NO == may_proceed)
    ;
  initialize_exited++;
}

+ (Class) class
{
  class_entered++;
  return self;
}

@end

static void *
test(void *arg)
{
  [MyClass class];
  return 0;
}

int
main()
{
  pthread_t t1;
  pthread_t t2;
  unsigned  counter;

  if (0 == pthread_create(&t1, 0, test, 0))
    {
      for (counter = 0; 0 == initialize_entered && counter < 5; counter++)
	{
	  mySleep(1);
	}

      if (0 == initialize_entered)
	{
	  fprintf(stderr, "Failed to initialize\n");
	  return 1;
	}

      if (0 == pthread_create(&t2, 0, test, 0))
        {
          /* Wait long enough for t2 to  try calling +class
	   */
	  mySleep(1);

	  if (class_entered > 0)
	    {
	      fprintf(stderr, "class entered prematurely\n");
	      return 1;
	    }

	  /* Let t1 proceed and wait long enough for it to complete
	   * +initialize and for both threads to call +class
	   */
	  may_proceed = YES;
          for (counter = 0; 2 > class_entered && counter < 5; counter++)
	    {
	      mySleep(1);
	    }

	  if (2 == class_entered)
	    {
	      return 0; // OK
	    }
	  fprintf(stderr, "problem with initialize\n");
          return 1;
	}
      else
	{
	  fprintf(stderr, "failed to create t2\n");
	  return 1;
	}
    }
  else
    {
      fprintf(stderr, "failed to create t1\n");
      return 1;
    }
}

