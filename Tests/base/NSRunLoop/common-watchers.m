/*
 * When a run loop runs in a common mode it watches the inputs of that
 * mode and those of NSRunLoopCommonModes together.  Check that both
 * sets of watchers are handled when both are present, in any number,
 * and that removing a common mode watcher works.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#if	defined(_WIN32)
int main()
{
  return 0;
}
#else

#include <unistd.h>

@interface Reader : NSObject <RunLoopEvents>
{
@public
  int	fd;
  int	writeFd;
  int	fired;
}
@end

@implementation Reader
- (id) init
{
  int	p[2];

  if (nil != (self = [super init]))
    {
      if (pipe(p) < 0)
	{
	  DESTROY(self);
	  return nil;
	}
      fd = p[0];
      writeFd = p[1];
    }
  return self;
}
- (void) dealloc
{
  close(fd);
  close(writeFd);
  [super dealloc];
}
- (void) makeReadable
{
  write(writeFd, "x", 1);
}
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  char	c;

  if (read(fd, &c, 1) == 1)
    {
      fired++;
    }
}
@end

static NSMutableArray *
watch(NSRunLoop *rl, NSString *mode, int count)
{
  NSMutableArray	*a = [NSMutableArray array];

  while (count-- > 0)
    {
      Reader	*r = AUTORELEASE([Reader new]);

      [rl addEvent: (void*)(intptr_t)r->fd
	      type: ET_RDESC
	   watcher: r
	   forMode: mode];
      [r makeReadable];
      [a addObject: r];
    }
  return a;
}

static void
unwatch(NSRunLoop *rl, NSArray *a, NSString *mode)
{
  NSEnumerator	*e = [a objectEnumerator];
  Reader	*r;

  while ((r = [e nextObject]) != nil)
    {
      [rl removeEvent: (void*)(intptr_t)r->fd
		 type: ET_RDESC
	      forMode: mode
		  all: YES];
    }
}

/* Run the loop until every reader in the arrays has fired or a second
 * has passed.
 */
static BOOL
allFire(NSRunLoop *rl, NSString *mode, NSArray *a, NSArray *b)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: 1.0];
  NSArray	*all = [a arrayByAddingObjectsFromArray: b];

  while ([limit timeIntervalSinceNow] > 0)
    {
      NSEnumerator	*e = [all objectEnumerator];
      Reader		*r;
      BOOL		done = YES;

      [rl runMode: mode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
      while ((r = [e nextObject]) != nil)
	{
	  if (r->fired == 0)
	    {
	      done = NO;
	    }
	}
      if (done)
	{
	  return YES;
	}
    }
  return NO;
}

static void
both(NSRunLoop *rl, int inMode, int inCommon)
{
  NSMutableArray	*m = watch(rl, NSDefaultRunLoopMode, inMode);
  NSMutableArray	*c = watch(rl, NSRunLoopCommonModes, inCommon);

  PASS(allFire(rl, NSDefaultRunLoopMode, m, c),
    "%d default mode and %d common mode watchers all fire",
    inMode, inCommon)
  unwatch(rl, m, NSDefaultRunLoopMode);
  unwatch(rl, c, NSRunLoopCommonModes);
}

int main()
{
  ENTER_POOL
  NSRunLoop		*rl = [NSRunLoop currentRunLoop];
  NSMutableArray	*m;
  NSMutableArray	*c;
  Reader		*gone;

  START_SET("watchers in a mode and in the common modes")

  both(rl, 0, 1);
  both(rl, 1, 0);
  both(rl, 1, 1);
  both(rl, 1, 3);
  both(rl, 3, 1);
  both(rl, 4, 4);

  END_SET("watchers in a mode and in the common modes")

  START_SET("removing common mode watchers")

  m = watch(rl, NSDefaultRunLoopMode, 2);
  c = watch(rl, NSRunLoopCommonModes, 3);
  gone = [c objectAtIndex: 1];
  [rl removeEvent: (void*)(intptr_t)gone->fd
	     type: ET_RDESC
	  forMode: NSRunLoopCommonModes
	      all: YES];
  [c removeObjectAtIndex: 1];
  PASS(allFire(rl, NSDefaultRunLoopMode, m, c),
    "the other watchers fire after one is removed")
  PASS(gone->fired == 0, "the removed watcher is not called")
  unwatch(rl, m, NSDefaultRunLoopMode);
  unwatch(rl, c, NSRunLoopCommonModes);

  END_SET("removing common mode watchers")

  START_SET("a mode which is not common")

  m = watch(rl, @"GSTestPrivateMode", 2);
  c = watch(rl, NSRunLoopCommonModes, 2);
  PASS(allFire(rl, @"GSTestPrivateMode", m, nil),
    "the watchers of a private mode fire")
  PASS(((Reader*)[c objectAtIndex: 0])->fired == 0
    && ((Reader*)[c objectAtIndex: 1])->fired == 0,
    "common mode watchers do not fire in it")
  PASS(allFire(rl, NSDefaultRunLoopMode, nil, c),
    "they fire in the default mode")
  unwatch(rl, m, @"GSTestPrivateMode");
  unwatch(rl, c, NSRunLoopCommonModes);

  END_SET("a mode which is not common")

  LEAVE_POOL
  return 0;
}
#endif
