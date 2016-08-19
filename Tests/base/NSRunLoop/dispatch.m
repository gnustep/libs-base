#import "ObjectTesting.h"

#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSRunLoop.h"
#import "GNUstepBase/GSConfig.h"

const NSTimeInterval kDelay = 0.01;

#if HAVE_LIBDISPATCH_RUNLOOP && __has_feature(blocks)
#  define DISPATCH_RL_INTEGRATION 1
#  ifdef HAVE_DISPATCH_H
#    include <dispatch.h>
#  else
#    ifdef HAVE_DISPATCH_DISPATCH_H
#      include <dispatch/dispatch.h>
#    endif
#  endif
#endif

/**
 * This is a simple counter object that gets incremented from a different
 * thread, but by using dispatch_async() to put the actual increment operation
 * onto the main queue.
 */
@interface Counter : NSObject
{
  NSUInteger counter;
}
- (void)increment;
- (NSUInteger)counter;
@end

/**
 * This is the object running in the other thread. It's purpose is to dispatch
 * five increments to the main queue and then exit.
 */
@interface Queuer : NSObject
- (void)worker: (Counter*)counter;
- (void)run;
- (void)timeout: (NSTimer*)t;
@end

@implementation Counter
- (void)increment
{
  counter++;
}

- (NSUInteger)counter
{
  return counter;
}
@end

@implementation Queuer

- (void)worker: (Counter*)counter
{
  NSUInteger i = 0;
  NSAutoreleasePool     *pool = [NSAutoreleasePool new];
  for (i  = 0; i < 5; i++)
  {
#   ifdef DISPATCH_RL_INTEGRATION
      dispatch_async(dispatch_get_main_queue(), ^ {
        [counter increment];
      });
#   endif
    NSDate *d  = [NSDate dateWithTimeIntervalSinceNow: kDelay];
    while ([d timeIntervalSinceNow] > 0)
      {
        [[NSRunLoop currentRunLoop] runUntilDate: d];
      }
  }
  [pool release];
}


- (void)timeout: (NSTimer*)t
{
  PASS(NO, "Timeout while trying to run blocks on main thread");
}

- (void) run
{
  NSDate *until = [NSDate dateWithTimeIntervalSinceNow: 1.0];
  Counter *c = [Counter new];
  [NSTimer scheduledTimerWithTimeInterval: 1.0
                                   target: self
                                 selector: @selector(timeout:)
                                 userInfo: nil
                                  repeats: YES];

  [NSThread detachNewThreadSelector: @selector(worker:)
                           toTarget: self
                         withObject: c];

  while ([until timeIntervalSinceNow] > 0)
    {
      NSDate  *tick = [NSDate dateWithTimeIntervalSinceNow: kDelay * 2];
      [[NSRunLoop currentRunLoop] runUntilDate: tick];
      if ([c counter] == 5)
        {
          break;
        }
    }
  PASS([c counter] == 5, "Dispatch blocks execute on main queue");
}

@end

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  START_SET("NSRunLoop libdispatch integration")
# ifndef DISPATCH_RL_INTEGRATION
  SKIP("No libdispatch, no blocks support or no runloop integration hooks in libdispatch")
# else
  [[[Queuer new] autorelease] run];
# endif
  END_SET("NSRunLoop libdispatch integration")
  [pool release];
  return 0;
}
