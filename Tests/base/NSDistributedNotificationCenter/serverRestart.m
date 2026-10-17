/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDistributedNotificationCenter.h>
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
#include <unistd.h>

/* A process that only observes distributed notifications must keep
 * receiving them after gdnc was restarted: the center has to reconnect
 * by itself and register its observers with the new gdnc again.
 *
 * The test runs its own gdnc in a private temporary directory, which is
 * where NSMessagePort keeps its names, so it never touches the gdnc of
 * the user running it.  Set GDNC to the gdnc binary to use (default: gdnc
 * in PATH).
 */

static NSString	*name = @"GSServerRestartTestNotification";
static int	bound = 10;

@interface	RestartObserver : NSObject
{
@public
  unsigned	received;
}
- (void) received: (NSNotification*)n;
@end

@implementation	RestartObserver
- (void) received: (NSNotification*)n
{
  received++;
}
@end

static pid_t	children[3];

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

static BOOL
waitForCount(RestartObserver *o, unsigned count, NSTimeInterval seconds)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: seconds];

  while (o->received < count && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  return o->received >= count;
}

/* A poster that waits for the parent's go and then posts every 250 ms
 * until it is killed, so the parent does not have to know when exactly
 * its center has reconnected.  It is forked before the parent uses DO.
 */
static pid_t
startPoster(int *go)
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
      char				c;
      int				i;

      close(g[1]);
      if (read(g[0], &c, 1) != 1)
	{
	  _exit(4);
	}
      dnc = [NSDistributedNotificationCenter defaultCenter];
      for (i = 0; i < bound * 4 * 2; i++)
	{
	  NSAutoreleasePool	*pool = [NSAutoreleasePool new];

	  [dnc postNotificationName: name object: nil userInfo: nil
		 deliverImmediately: YES];
	  [pool drain];
	  [NSThread sleepForTimeInterval: 0.25];
	}
      _exit(0);
    }
  close(g[0]);
  *go = g[1];
  return pid;
}

static void
sendByte(int fd)
{
  char	c = 1;

  (void)write(fd, &c, 1);
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

static BOOL
serverUp(pid_t server)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: bound];
  int		status;

  while ([[NSMessagePortNameServer sharedInstance]
    portForName: @"GDNCServer"] == nil && [limit timeIntervalSinceNow] > 0)
    {
      [NSThread sleepForTimeInterval: 0.05];
    }
  return waitpid(server, &status, WNOHANG) == 0
    && [[NSMessagePortNameServer sharedInstance]
      portForName: @"GDNCServer"] != nil;
}

/* NSMessagePort reads TEMP/TMP once at start-up, so a private directory
 * has to be in place before the process starts: re-execute with one.
 */
static void
usePrivateTemporaryDirectory(char **argv)
{
  char	dir[] = "/tmp/serverRestart.XXXXXX";

  if (getenv("SERVER_RESTART_TMP") != NULL)
    {
      return;
    }
  if (mkdtemp(dir) == NULL)
    {
      fprintf(stderr, "mkdtemp: %s\n", strerror(errno));
      exit(1);
    }
  setenv("SERVER_RESTART_TMP", dir, 1);
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
  START_SET("observers survive a gdnc restart")
#if	defined(_WIN32)
    SKIP("fork() is not available")
#else
    NSDistributedNotificationCenter	*dnc;
    RestartObserver			*kept = [RestartObserver new];
    RestartObserver			*removed = [RestartObserver new];
    pid_t				server;
    pid_t				before;
    pid_t				after;
    int					beforeGo;
    int					afterGo;
    char				cmd[256];

    /* Never run against the gdnc of the user running the test. */
    if ([NSTemporaryDirectory() isEqual: [NSString stringWithUTF8String:
      getenv("SERVER_RESTART_TMP")]] == NO)
      {
	fprintf(stderr, "private temporary directory not in use: %s\n",
	  [NSTemporaryDirectory() UTF8String]);
	exit(1);
      }

    before = startPoster(&beforeGo);
    after = startPoster(&afterGo);
    server = startServer();
    children[0] = before;
    children[1] = after;
    children[2] = server;
    signal(SIGALRM, parentHung);
    alarm(bound * 6);

    PASS(serverUp(server), "a private gdnc is running");

    dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc addObserver: kept selector: @selector(received:)
		name: name object: nil];
    [dnc addObserver: removed selector: @selector(received:)
		name: name object: nil];
    sendByte(beforeGo);
    PASS(waitForCount(kept, 1, bound) && waitForCount(removed, 1, bound),
      "the observers get a notification from another process");
    kill(before, SIGKILL);
    waitpid(before, NULL, 0);
    children[0] = 0;
    [dnc removeObserver: removed name: name object: nil];
    removed->received = 0;

    kill(server, SIGKILL);
    waitpid(server, NULL, 0);
    server = startServer();
    children[2] = server;
    PASS(serverUp(server), "gdnc was killed and a new one started");

    kept->received = 0;
    sendByte(afterGo);
    PASS(waitForCount(kept, 1, bound),
      "the observer gets a notification posted after the restart"
      " (%u within %d s)", kept->received, bound);
    PASS(removed->received == 0,
      "an observer removed before the restart is not registered again");
    alarm(0);

    killChildren();
    waitpid(after, NULL, 0);
    waitpid(server, NULL, 0);
    snprintf(cmd, sizeof(cmd), "rm -rf '%s'", getenv("SERVER_RESTART_TMP"));
    (void)system(cmd);
#endif
  END_SET("observers survive a gdnc restart")
  return 0;
}
