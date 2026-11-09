#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

/* Test that threads creating the shared standard handles at the same time
 * all get the same handles, and that none of them is over-released.
 */

#define	THREADS	16

static volatile int	started = 0;
static volatile int	done = 0;
static id		handles[THREADS][3];

@interface Getter : NSObject
@end

@implementation Getter

- (void) getHandles: (NSNumber *)index
{
  ENTER_POOL
  int	i = [index intValue];

  /* Start all threads at the same time, so that they overlap */
  __sync_add_and_fetch(&started, 1);
  while (started < THREADS)
    {
      [NSThread sleepForTimeInterval: 0];
    }
  handles[i][0] = RETAIN([NSFileHandle fileHandleWithStandardInput]);
  handles[i][1] = RETAIN([NSFileHandle fileHandleWithStandardOutput]);
  handles[i][2] = RETAIN([NSFileHandle fileHandleWithStandardError]);
  LEAVE_POOL
  __sync_add_and_fetch(&done, 1);
}

@end

int main(void)
{
  ENTER_POOL
  Getter	*getter = AUTORELEASE([Getter new]);
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 30.0];
  BOOL		same = YES;
  int		i;
  int		j;

  for (i = 0; i < THREADS; i++)
    {
      [NSThread detachNewThreadSelector: @selector(getHandles:)
			       toTarget: getter
			     withObject: [NSNumber numberWithInt: i]];
    }
  while (done < THREADS && [limit timeIntervalSinceNow] > 0)
    {
      [NSThread sleepForTimeInterval: 0.01];
    }
  PASS(done == THREADS, "all threads got the standard handles")

  for (i = 0; i < THREADS; i++)
    {
      for (j = 0; j < 3; j++)
	{
	  if (handles[i][j] != handles[0][j] || handles[i][j] == nil)
	    {
	      same = NO;
	    }
	}
    }
  PASS(same, "all threads got the same standard handles")

  for (i = 0; i < THREADS; i++)
    {
      for (j = 0; j < 3; j++)
	{
	  RELEASE(handles[i][j]);
	}
    }
  PASS([NSFileHandle fileHandleWithStandardInput] == handles[0][0]
    && [NSFileHandle fileHandleWithStandardOutput] == handles[0][1]
    && [NSFileHandle fileHandleWithStandardError] == handles[0][2],
    "the standard handles are kept after the threads release theirs")
  PASS([[NSFileHandle fileHandleWithStandardOutput] fileDescriptor] == 1,
    "the standard output handle is still usable")

  LEAVE_POOL
  return 0;
}
