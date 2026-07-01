#if	defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "GNUstepBase/GNUstep.h"
#import "Testing.h"

#if	defined(__unix__) || defined(__APPLE__)
#include <pthread.h>

static volatile int	scanned = 0;

static void *
worker(void *arg)
{
  ENTER_POOL
  GSMimeParser	*p = [GSMimeParser mimeParser];
  NSUInteger	n = 400000;
  NSString	*big = [@"" stringByPaddingToLength: n
				 withString: @"A" startingAtIndex: 0];
  NSString	*quoted = [NSString stringWithFormat: @"\"%@\"", big];
  NSScanner	*sc = [NSScanner scannerWithString: quoted];
  NSString	*token;

  (void)arg;
  token = [p scanToken: sc];
  if ([token length] == n)
    {
      scanned = 1;
    }
  LEAVE_POOL
  return NULL;
}
#endif

int main()
{
  START_SET("GSMime quoted-token stack safety")
#if	defined(__unix__) || defined(__APPLE__)
  pthread_attr_t	attr;
  pthread_t		t;

  /* A long quoted header value used to be copied into a stack VLA sized from
   * the (untrusted) value length, overflowing the stack.  Scan it on a small
   * stack so the regression crashes rather than merely runs. */
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, 256 * 1024);
  pthread_create(&t, &attr, worker, NULL);
  pthread_join(t, NULL);
  PASS(scanned == 1,
    "a long quoted token is scanned without overflowing the stack")
#else
  SKIP("test needs pthreads with a configurable stack size")
#endif
  END_SET("GSMime quoted-token stack safety")
  return 0;
}
#else
int main(void)
{
  return 0;
}
#endif
