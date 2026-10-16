/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSPortNameServer.h>
#import <Foundation/NSString.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSThread.h>

#if	!defined(_WIN32)
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* One client of gdnc that stops reading its socket (a hung or stopped
 * application) must not stop gdnc from serving everybody else.
 *
 * The test runs its own gdnc in a private temporary directory, which is
 * where NSMessagePort keeps its names, so neither an unfixed gdnc that
 * hangs nor the stopped client can disturb the gdnc of the user running
 * the test.  Set GDNC to the gdnc binary under test (default: gdnc in
 * PATH).
 */

static NSString	*flood = @"GSStuckClientTestFlood";
static NSString	*marker = @"GSStuckClientTestMarker";
/* Enough to fill the stopped client's socket several times over (about
 * 50 posts did it on Linux), without being so many that an unfixed gdnc
 * crashes rather than hangs: one nested wait per post was the crash.
 */
static unsigned	posts = 200;
/* Generous against gdnc's own client timeout, far below "never". */
static int	bound = 30;

@interface	StuckClientObserver : NSObject
{
@public
  unsigned	received;
  BOOL		sawMarker;
}
- (void) received: (NSNotification*)n;
@end

@implementation	StuckClientObserver
- (void) received: (NSNotification*)n
{
  if ([[n name] isEqual: marker])
    {
      sawMarker = YES;
    }
  else
    {
      received++;
    }
}
@end

static BOOL
waitFor(BOOL *flag, NSTimeInterval seconds)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: seconds];

  while (*flag == NO && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  return *flag;
}

static pid_t	children[3];

static BOOL
waitForCount(StuckClientObserver *o, unsigned count, NSTimeInterval seconds)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: seconds];

  while (o->received < count && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  return o->received >= count;
}

static void
hung(int sig)
{
  _exit(3);
}

/* An unfixed gdnc can block this process too; fail instead of hanging the
 * test run, and take the stopped client and the private gdnc along.
 */
static void
killChildren(void)
{
  int	i;

  for (i = 0; i < 3; i++)
    {
      if (children[i] > 0)
	{
	  kill(children[i], SIGKILL);
	}
    }
}

static void
parentHung(int sig)
{
  static const char	msg[] = "Failed test: the test timed out\n";

  (void)write(2, msg, sizeof(msg) - 1);
  killChildren();
  _exit(1);
}

/* Blocks until the parent writes a byte, so a child touches gdnc only
 * when the test is ready for it and never shares the parent's connection.
 */
static void
awaitGo(int fd)
{
  char	c;

  if (read(fd, &c, 1) != 1)
    {
      _exit(4);
    }
  close(fd);
}

static void
sendByte(int fd)
{
  char	c = 1;

  (void)write(fd, &c, 1);
}

/* A client that registers an observer, says so, and then keeps servicing
 * its run loop until the parent stops it with SIGSTOP.
 */
static pid_t
startStuckClient(int *go, int *ack)
{
  int	g[2];
  int	a[2];
  pid_t	pid;

  if (pipe(g) != 0 || pipe(a) != 0)
    {
      return -1;
    }
  pid = fork();
  if (pid == 0)
    {
      StuckClientObserver	*o;

      close(g[1]);
      close(a[0]);
      awaitGo(g[0]);
      o = [StuckClientObserver new];
      [[NSDistributedNotificationCenter defaultCenter]
	addObserver: o
	   selector: @selector(received:)
	       name: flood
	     object: nil];
      sendByte(a[1]);
      [[NSRunLoop currentRunLoop] run];
      _exit(0);
    }
  close(g[0]);
  close(a[1]);
  *go = g[1];
  *ack = a[0];
  return pid;
}

/* A client that connects only once the stuck client has blocked gdnc:
 * it must register an observer and get a notification back.  It exits 0
 * on success, so the parent only has to time it.
 */
static pid_t
startLateClient(int *go)
{
  int	g[2];
  pid_t	pid;

  if (pipe(g) != 0)
    {
      return -1;
    }
  pid = fork();
  if (pid == 0)
    {
      NSDistributedNotificationCenter	*dnc;
      StuckClientObserver		*o;

      close(g[1]);
      awaitGo(g[0]);
      signal(SIGALRM, hung);
      alarm(bound * 2);
      o = [StuckClientObserver new];
      dnc = [NSDistributedNotificationCenter defaultCenter];
      /* Observe what the stopped client observes, so delivery to it
       * stands between this client and its notification. */
      [dnc addObserver: o selector: @selector(received:)
		  name: flood object: nil];
      [dnc postNotificationName: flood object: nil userInfo: nil
	     deliverImmediately: YES];
      _exit(waitForCount(o, 1, bound * 2) ? 0 : 1);
    }
  close(g[0]);
  *go = g[1];
  return pid;
}

static pid_t
startServer(void)
{
  pid_t	pid = fork();

  if (pid == 0)
    {
      const char	*gdnc = getenv("GDNC");

      if (gdnc == NULL)
	{
	  gdnc = "gdnc";
	}
      execlp(gdnc, gdnc, "--no-fork", (char*)NULL);
      _exit(127);
    }
  return pid;
}

/* Waits for a child for up to `seconds`; returns its exit status, or -1
 * if it did not finish in time, and the time it took in *took.
 */
static int
reap(pid_t pid, int seconds, double *took)
{
  struct timespec	start;
  struct timespec	now;
  int			status;

  clock_gettime(CLOCK_MONOTONIC, &start);
  for (;;)
    {
      clock_gettime(CLOCK_MONOTONIC, &now);
      *took = (now.tv_sec - start.tv_sec)
	+ (now.tv_nsec - start.tv_nsec) / 1e9;
      if (waitpid(pid, &status, WNOHANG) == pid)
	{
	  return WIFEXITED(status) ? WEXITSTATUS(status) : 128;
	}
      if (*took > seconds)
	{
	  return -1;
	}
      /* Keep reading our own notifications, or gdnc would rightly
       * treat this process as a client that stopped reading too. */
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
}

/* NSMessagePort reads TEMP/TMP once at start-up, so a private directory
 * has to be in place before the process starts: re-execute with one.
 */
static void
usePrivateTemporaryDirectory(char **argv)
{
  char	dir[] = "/tmp/stuckClient.XXXXXX";

  if (getenv("STUCK_CLIENT_TMP") != NULL)
    {
      return;
    }
  if (mkdtemp(dir) == NULL)
    {
      fprintf(stderr, "mkdtemp: %s\n", strerror(errno));
      exit(1);
    }
  setenv("STUCK_CLIENT_TMP", dir, 1);
  setenv("TEMP", dir, 1);
  setenv("TMP", dir, 1);
  execv(argv[0], argv);
  fprintf(stderr, "execv %s: %s\n", argv[0], strerror(errno));
  exit(1);
}
#endif

int main(int argc, char **argv)
{
#if	!defined(_WIN32)
  usePrivateTemporaryDirectory(argv);
#endif
  START_SET("gdnc with a client that stopped reading")
#if	defined(_WIN32)
    SKIP("fork() is not available")
#else
    NSDistributedNotificationCenter	*dnc;
    StuckClientObserver			*o = [StuckClientObserver new];
    NSDictionary			*info;
    NSDate				*limit;
    pid_t				server;
    pid_t				stuck;
    pid_t				late;
    int					stuckGo;
    int					stuckAck;
    int					lateGo;
    int					status;
    unsigned				i;
    double				took;
    char				c;
    char				cmd[256];

    /* Never run against the gdnc of the user running the test. */
    if ([NSTemporaryDirectory() isEqual: [NSString stringWithUTF8String:
      getenv("STUCK_CLIENT_TMP")]] == NO)
      {
	fprintf(stderr, "private temporary directory not in use: %s\n",
	  [NSTemporaryDirectory() UTF8String]);
	exit(1);
      }

    /* Fork every client before this process uses DO itself. */
    stuck = startStuckClient(&stuckGo, &stuckAck);
    late = startLateClient(&lateGo);
    server = startServer();
    children[0] = stuck;
    children[1] = late;
    children[2] = server;
    signal(SIGALRM, parentHung);
    alarm(bound * 4);

    limit = [NSDate dateWithTimeIntervalSinceNow: 10.0];
    while ([[NSMessagePortNameServer sharedInstance]
      portForName: @"GDNCServer"] == nil && [limit timeIntervalSinceNow] > 0)
      {
	[NSThread sleepForTimeInterval: 0.1];
      }
    PASS(waitpid(server, &status, WNOHANG) == 0
      && [[NSMessagePortNameServer sharedInstance]
	portForName: @"GDNCServer"] != nil,
      "a private gdnc is running");

    sendByte(stuckGo);
    PASS(read(stuckAck, &c, 1) == 1 && kill(stuck, SIGSTOP) == 0,
      "a client registered an observer and then stopped reading");

    dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc addObserver: o selector: @selector(received:)
		name: flood object: nil];
    [dnc addObserver: o selector: @selector(received:)
		name: marker object: nil];

    /* Large enough to fill the stopped client's socket many times over,
     * and to nest gdnc's waits until it crashes if every post that
     * arrives during a wait starts another one.
     */
    info = [NSDictionary dictionaryWithObject:
      [NSMutableData dataWithLength: 4096] forKey: @"payload"];
    NS_DURING
      {
	for (i = 0; i < posts; i++)
	  {
	    [dnc postNotificationName: flood object: nil userInfo: info
		   deliverImmediately: YES];
	  }
	[dnc postNotificationName: marker object: nil userInfo: nil
	       deliverImmediately: YES];
      }
    NS_HANDLER
      {
	NSLog(@"posting raised %@", localException);
      }
    NS_ENDHANDLER

    sendByte(lateGo);
    status = reap(late, bound, &took);
    PASS(status == 0, "a client that connects while one is stopped"
      " registers and gets a notification (status %d after %.1f s)",
      status, took);

    PASS(waitFor(&o->sawMarker, bound), "the poster gets its marker");
    /* The late client's post counts too. */
    PASS(waitForCount(o, posts + 1, bound),
      "every post reached the poster (%u of %u)", o->received, posts + 1);
    PASS(waitpid(server, &status, WNOHANG) == 0, "gdnc is still running");
    alarm(0);

    killChildren();
    waitpid(late, NULL, 0);
    waitpid(stuck, NULL, 0);
    waitpid(server, NULL, 0);
    snprintf(cmd, sizeof(cmd), "rm -rf '%s'", getenv("STUCK_CLIENT_TMP"));
    (void)system(cmd);
#endif
  END_SET("gdnc with a client that stopped reading")
  return 0;
}
