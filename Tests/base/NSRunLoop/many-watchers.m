/*
 * The poll() based run loop keeps, for each descriptor, its position in
 * the array passed to poll(), so that a descriptor watched for several
 * events gets one entry.  Check that this works with more than 32767
 * descriptors (the positions were stored in a short), and that a watcher
 * for a negative descriptor is ignored without disturbing the others.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <unistd.h>

#define	MANY	32800

@interface Watcher : NSObject <RunLoopEvents>
{
@public
  int	reads;
  int	writes;
  int	others;
}
@end

@implementation Watcher
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  if (type == ET_RDESC)
    {
      char	c;

      if (read((int)(intptr_t)data, &c, 1) == 1)
	{
	  reads++;
	}
      else
	{
	  others++;
	}
    }
  else if (type == ET_WDESC)
    {
      writes++;
    }
  else
    {
      others++;
    }
}
@end

static void
runUntil(NSRunLoop *rl, Watcher *w)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 2.0];

  while ((w->reads == 0 || w->writes == 0) && [limit timeIntervalSinceNow] > 0)
    {
      [rl runMode: NSDefaultRunLoopMode
       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
}

int main()
{
  ENTER_POOL
  NSRunLoop		*rl = [NSRunLoop currentRunLoop];
  Watcher		*w;
  Watcher		*ignored;
  int			sv[2];

  START_SET("negative descriptor")

  w = AUTORELEASE([Watcher new]);
  ignored = AUTORELEASE([Watcher new]);
  socketpair(AF_UNIX, SOCK_STREAM, 0, sv);
  [rl addEvent: (void*)(intptr_t)-1 type: ET_RDESC watcher: ignored
       forMode: NSDefaultRunLoopMode];
  [rl addEvent: (void*)(intptr_t)sv[0] type: ET_RDESC watcher: w
       forMode: NSDefaultRunLoopMode];
  [rl addEvent: (void*)(intptr_t)sv[0] type: ET_WDESC watcher: w
       forMode: NSDefaultRunLoopMode];
  write(sv[1], "x", 1);
  runUntil(rl, w);
  PASS(w->reads == 1 && w->writes > 0,
    "watchers of a real descriptor fire next to one for -1")
  PASS(ignored->reads == 0 && ignored->writes == 0 && ignored->others == 0,
    "the watcher for -1 is not called")
  [rl removeEvent: (void*)(intptr_t)-1 type: ET_RDESC
	  forMode: NSDefaultRunLoopMode all: YES];
  [rl removeEvent: (void*)(intptr_t)sv[0] type: ET_RDESC
	  forMode: NSDefaultRunLoopMode all: YES];
  [rl removeEvent: (void*)(intptr_t)sv[0] type: ET_WDESC
	  forMode: NSDefaultRunLoopMode all: YES];
  close(sv[0]);
  close(sv[1]);

  END_SET("negative descriptor")

  START_SET("more than 32767 descriptors")
  {
    struct rlimit	lim;
    int			*fds;
    int			n;
    int			i;
    Watcher		*idle = AUTORELEASE([Watcher new]);

    /* Each idle watcher needs a pipe (two descriptors).
     */
    if (getrlimit(RLIMIT_NOFILE, &lim) < 0
      || (lim.rlim_max != RLIM_INFINITY && lim.rlim_max < 2 * MANY + 100))
      {
	SKIP("the descriptor limit is too low for this test")
      }
    if (lim.rlim_cur != RLIM_INFINITY && lim.rlim_cur < 2 * MANY + 100)
      {
	lim.rlim_cur = 2 * MANY + 100;
	if (setrlimit(RLIMIT_NOFILE, &lim) < 0)
	  {
	    SKIP("cannot raise the descriptor limit for this test")
	  }
      }

    w = AUTORELEASE([Watcher new]);
    socketpair(AF_UNIX, SOCK_STREAM, 0, sv);
    /* The watchers are looked at from the last added to the first, so
     * the two for sv[0] come after all the others, and the descriptor
     * gets a position above 32767 when its first watcher is seen.
     */
    [rl addEvent: (void*)(intptr_t)sv[0] type: ET_RDESC watcher: w
	 forMode: NSDefaultRunLoopMode];
    [rl addEvent: (void*)(intptr_t)sv[0] type: ET_WDESC watcher: w
	 forMode: NSDefaultRunLoopMode];
    fds = malloc(2 * MANY * sizeof(int));
    for (n = 0; n < MANY; n++)
      {
	if (pipe(&fds[2 * n]) < 0)
	  {
	    break;
	  }
	[rl addEvent: (void*)(intptr_t)fds[2 * n] type: ET_RDESC watcher: idle
	     forMode: NSDefaultRunLoopMode];
      }
    PASS(n == MANY, "%d idle descriptors are watched", n)
    write(sv[1], "x", 1);
    runUntil(rl, w);
    PASS(w->reads == 1,
      "a read watcher fires for a descriptor also watched for writing")
    PASS(w->writes > 0, "the write watcher fires too")
    PASS(idle->reads == 0 && idle->others == 0,
      "the idle watchers are not called")

    for (i = 0; i < n; i++)
      {
	[rl removeEvent: (void*)(intptr_t)fds[2 * i] type: ET_RDESC
		forMode: NSDefaultRunLoopMode all: YES];
	close(fds[2 * i]);
	close(fds[2 * i + 1]);
      }
    free(fds);
    [rl removeEvent: (void*)(intptr_t)sv[0] type: ET_RDESC
	    forMode: NSDefaultRunLoopMode all: YES];
    [rl removeEvent: (void*)(intptr_t)sv[0] type: ET_WDESC
	    forMode: NSDefaultRunLoopMode all: YES];
    close(sv[0]);
    close(sv[1]);
  }
  END_SET("more than 32767 descriptors")

  LEAVE_POOL
  return 0;
}
