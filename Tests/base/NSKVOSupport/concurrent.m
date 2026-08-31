#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Concurrent setters on one observed key.  The accessors are atomic, so the
 * only state shared between the threads is the one the observation keeps.
 */

#define	THREADS	4
#define	WRITES	250

@interface      Holder : NSObject
{
  NSString	*_token;
}
@property (copy) NSString *token;
@end

@implementation Holder
@synthesize token = _token;
- (void) dealloc
{
  [_token release];
  [super dealloc];
}
@end

@interface      Counter : NSObject
{
@public
  volatile int	count;
}
@end

@implementation Counter
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  __sync_fetch_and_add(&count, 1);
}
@end

static Holder		*holder = nil;
static NSCondition	*finished = nil;
static int		 running = 0;

@interface      Writer : NSObject
+ (void) write: (id)arg;
@end

@implementation Writer
+ (void) write: (id)arg
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  int			 i;

  for (i = 0; i < WRITES; i++)
    {
      [holder setToken: @"v"];
    }
  [pool release];

  [finished lock];
  running--;
  [finished signal];
  [finished unlock];
}
@end

int
main(int argc, char **argv)
{
  Counter	*counter;
  int		 i;

  [NSAutoreleasePool new];
  counter = [Counter new];
  finished = [NSCondition new];

  holder = [Holder new];
  [holder setToken: @"start"];
  [holder addObserver: counter
           forKeyPath: @"token"
              options: 0
              context: 0];

  running = THREADS;
  for (i = 0; i < THREADS; i++)
    {
      [NSThread detachNewThreadSelector: @selector(write:)
                               toTarget: [Writer class]
                             withObject: nil];
    }
  [finished lock];
  while (running > 0)
    {
      [finished wait];
    }
  [finished unlock];

  PASS(counter->count == THREADS * WRITES,
    "every concurrent set of an observed key is reported once (%d of %d)",
    counter->count, THREADS * WRITES);

  [holder removeObserver: counter forKeyPath: @"token" context: 0];
  [holder release];
  [counter release];
  [finished release];
  return 0;
}
