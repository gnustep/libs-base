/*
 * When an event handler runs the run loop again (in another mode, as a
 * modal loop does) and that nested run handles an event which the outer
 * poll also saw, the outer poll must not call the watcher for it again
 * afterwards: the nested run tells the outer contexts with
 * -endEvent:for:.  The descriptors are non-blocking, so a second call
 * finds nothing to read instead of blocking.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <fcntl.h>
#include <unistd.h>

static NSString	*nested = @"GSTestNestedMode";

@interface Handler : NSObject <RunLoopEvents>
{
@public
  int	shared[2];	// Watched in both modes
  int	trigger[2];	// Watched in the default mode: runs the nested loop
  int	sharedReads;	// Bytes read from shared
  int	emptyCalls;	// Calls with nothing to read
  int	nestedRuns;
}
@end

@implementation Handler
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  int	fd = (int)(intptr_t)data;
  char	c;

  if (read(fd, &c, 1) != 1)
    {
      emptyCalls++;
      return;
    }
  if (fd == shared[0])
    {
      sharedReads++;
    }
  else if (fd == trigger[0] && [mode isEqual: NSDefaultRunLoopMode])
    {
      NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 0.3];

      nestedRuns++;
      while (sharedReads == 0 && [limit timeIntervalSinceNow] > 0)
	{
	  [[NSRunLoop currentRunLoop] runMode: nested
	    beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
	}
    }
}
@end

static void
nonBlocking(int fd)
{
  fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
}

int main()
{
  ENTER_POOL
  NSRunLoop		*rl = [NSRunLoop currentRunLoop];
  Handler		*h = AUTORELEASE([Handler new]);
  int			round;
  int			once = 0;
  int			empty = 0;
  int			runs = 0;

  pipe(h->shared);
  pipe(h->trigger);
  nonBlocking(h->shared[0]);
  nonBlocking(h->trigger[0]);
  [rl addEvent: (void*)(intptr_t)h->shared[0] type: ET_RDESC watcher: h
       forMode: NSDefaultRunLoopMode];
  [rl addEvent: (void*)(intptr_t)h->trigger[0] type: ET_RDESC watcher: h
       forMode: NSDefaultRunLoopMode];
  [rl addEvent: (void*)(intptr_t)h->shared[0] type: ET_RDESC watcher: h
       forMode: nested];

  START_SET("an event handled by a nested run")

  /* Both descriptors are readable when the outer poll is made, so it
   * sees both; depending on which it handles first, the shared one is
   * handled by the outer run or by the nested one, but only once.
   */
  for (round = 0; round < 20; round++)
    {
      NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 1.0];

      h->sharedReads = 0;
      h->emptyCalls = 0;
      h->nestedRuns = 0;
      write(h->shared[1], "x", 1);
      write(h->trigger[1], "x", 1);
      while ((h->sharedReads == 0 || h->nestedRuns == 0)
	&& [limit timeIntervalSinceNow] > 0)
	{
	  [rl runMode: NSDefaultRunLoopMode
	   beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
	}
      /* Let the outer loop finish anything it still had to handle.  */
      [rl runMode: NSDefaultRunLoopMode
       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
      if (h->sharedReads == 1)
	{
	  once++;
	}
      empty += h->emptyCalls;
      runs += h->nestedRuns;
    }
  PASS(runs == 20, "the nested loop ran each time")
  PASS(once == 20, "the shared descriptor was read each time")
  PASS(empty == 0,
    "no watcher was called again for an event already handled (%d calls)",
    empty)

  END_SET("an event handled by a nested run")

  [rl removeEvent: (void*)(intptr_t)h->shared[0] type: ET_RDESC
	  forMode: NSDefaultRunLoopMode all: YES];
  [rl removeEvent: (void*)(intptr_t)h->trigger[0] type: ET_RDESC
	  forMode: NSDefaultRunLoopMode all: YES];
  [rl removeEvent: (void*)(intptr_t)h->shared[0] type: ET_RDESC
	  forMode: nested all: YES];
  LEAVE_POOL
  return 0;
}
