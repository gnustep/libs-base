#if	defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "GNUstepBase/GNUstep.h"
#import "Testing.h"

#if	defined(__unix__) || defined(__APPLE__)
#include <pthread.h>
#include <string.h>
#include <stdlib.h>

static volatile int	decoded = 0;

static void *
worker(void *arg)
{
  ENTER_POOL
  GSMimeParser	*p = [GSMimeParser mimeParser];
  NSMutableData	*m = [NSMutableData data];
  const char	*pre = "Subject: =?utf-8?B?";
  const char	*post = "?=\r\n\r\n";
  NSUInteger	n = 400000;
  char		*a = malloc(n);

  (void)arg;
  memset(a, 'A', n);
  [m appendBytes: pre length: strlen(pre)];
  [m appendBytes: a length: n];
  [m appendBytes: post length: strlen(post)];
  free(a);

  [p parse: m];
  [p parse: nil];
  if ([p mimeDocument] != nil)
    {
      decoded = 1;
    }
  LEAVE_POOL
  return NULL;
}
#endif

int main()
{
  START_SET("GSMime encoded-word stack safety")
#if	defined(__unix__) || defined(__APPLE__)
  pthread_attr_t	attr;
  pthread_t		t;

  /* A long RFC2047 encoded word used to be decoded into a stack VLA sized
   * from the (untrusted) word length, overflowing the stack.  Decode it on
   * a small stack so the regression crashes rather than merely runs. */
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, 256 * 1024);
  pthread_create(&t, &attr, worker, NULL);
  pthread_join(t, NULL);
  PASS(decoded == 1,
    "a long encoded word is decoded without overflowing the stack")
#else
  SKIP("test needs pthreads with a configurable stack size")
#endif
  END_SET("GSMime encoded-word stack safety")
  return 0;
}
#else
int main(void)
{
  return 0;
}
#endif
