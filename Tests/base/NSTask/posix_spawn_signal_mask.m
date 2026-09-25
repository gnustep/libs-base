#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#if !defined(_WIN32)
#include <pthread.h>
#include <signal.h>
#include <string.h>
#endif

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
#if !defined(_WIN32)
  sigset_t blocked, original, current;
  NSTask *task;
  NSString *path;
  int result;

  if (argc > 1 && strcmp(argv[1], "--check-mask") == 0)
    {
      result = pthread_sigmask(SIG_BLOCK, NULL, &current);
      [pool release];
      return result != 0 || sigismember(&current, SIGTERM) != 0
        || sigismember(&current, SIGUSR1) != 0;
    }

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
            path = [[[NSFileManager defaultManager] currentDirectoryPath]
              stringByAppendingPathComponent: path];
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
          [task release];
        }
      @finally
        {
          pthread_sigmask(SIG_SETMASK, &original, NULL);
        }
    }
#else
  SKIP("POSIX signal masks are not available on Windows");
#endif
  [pool release];
  return 0;
}
