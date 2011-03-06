/* Test whether Objective-C runtime +initialize support is thread-safe
 */

#include "objc-common.g"
#include <pthread.h>
#include <stdio.h>

#if defined(_WIN32)
#define	mySleep(X)	usleep(1000*(X))
#else
#define	mySleep(X)	sleep(X)
#endif

static unsigned	initialize_entered = 0;
static unsigned	initialize_exited = 0;
static unsigned	class_entered = 0;
static BOOL	may_proceed = NO;

@interface	MyClass : NSObject
@end

@implementation	MyClass

+ (void) initialize
{
  initialize_entered++;
  while (NO == may_proceed)
    mySleep(1);
  initialize_exited++;
}

+ (Class) class
{
  class_entered++;
  return self;
}

@end

static void test(void *arg)
{
  [MyClass class];
}

int
main()
{
  pthread_t t1;
  pthread_t t2;
  unsigned  counter = 0;

  if (0 == pthread_create(&t1, 0, test, 0))
    {
      while (0 == initialize_entered && counter++ < 3)
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
	      mySleep(1);

	      if (class_entered > 0)
	        {
	          fprintf(stderr, "class entered prematurely\n");
	          return 1;
	        }

	      may_proceed = YES;

          // sleep longer than t1 may need to complete initialize
          // plus time for t1 and t2 to complete "test"
	      mySleep(2);

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

