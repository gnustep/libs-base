#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#if !defined(_WIN32)
#include <pthread.h>
#include <signal.h>
#include <string.h>
#endif

int main(int argc, char **argv)
{
  sigset_t	blocked;
  sigset_t	original;
  sigset_t	current;
  int		result;

#if !defined(_WIN32)
  if (argc > 1 && strcmp(argv[1], "--check-mask") == 0)
    {
      result = pthread_sigmask(SIG_BLOCK, NULL, &current);
      return result != 0 || sigismember(&current, SIGTERM) != 0
        || sigismember(&current, SIGUSR1) != 0;
    }
#endif

  START_SET("sigmask")
#if !defined(_WIN32)
  NSTask	*task;
  NSString	*path;

  /* Dispatch workers may block these signals.  Reproduce deterministically
   * without depending on the configured NSOperationQueue implementation.
   */
  sigemptyset(&blocked);
  sigaddset(&blocked, SIGTERM);
  sigaddset(&blocked, SIGUSR1);
  result = pthread_sigmask(SIG_BLOCK, &blocked, &original);
  PASS(result == 0, "block signals on the launching thread");
  if (result == 0)
    {
      @try
        {
          path = [NSString stringWithUTF8String: argv[0]];
          if (![path isAbsolutePath])
	    {
	      path = [[[NSFileManager defaultManager] currentDirectoryPath]
		stringByAppendingPathComponent: path];
	    }
          task = [NSTask new];
          [task setLaunchPath: path];
          [task setArguments: [NSArray arrayWithObject: @"--check-mask"]];
          [task launch];
          [task waitUntilExit];
          PASS([task terminationStatus] == 0,
            "child does not inherit blocked SIGTERM or SIGUSR1");
          pthread_sigmask(SIG_BLOCK, NULL, &current);
          PASS(sigismember(&current, SIGTERM) == 1
            && sigismember(&current, SIGUSR1) == 1,
            "launch preserves the parent's blocked signals");
          RELEASE(task);
        }
      @finally
        {
          pthread_sigmask(SIG_SETMASK, &original, NULL);
        }
    }
#else
  SKIP("POSIX signal masks are not available on Windows");
#endif
  END_SET("sigmask")
  return 0;
}
