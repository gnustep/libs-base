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

/* gdnc drops a client that stops reading for longer than its client
 * timeout.  Once that client runs again it must reconnect by itself and
 * register its observers again, or it stays deaf for the rest of its life.
 *
 * The test runs its own gdnc, with a one second client timeout, in a
 * private temporary directory, which is where NSMessagePort keeps its
 * names, so it never touches the gdnc of the user running it.  Set GDNC to
 * the gdnc binary to use (default: gdnc in PATH).
 */

static NSString	*flood = @"GSDroppedClientTestFlood";
static NSString	*marker = @"GSDroppedClientTestMarker";
static int	bound = 15;

@interface	DroppedClientObserver : NSObject
- (void) received: (NSNotification*)n;
@end

@implementation	DroppedClientObserver
- (void) received: (NSNotification*)n
{
  if ([[n name] isEqual: marker])
    {
      _exit(0);
    }
}
@end

static pid_t	children[2];

static void
killChildren(void)
{
  int	i;

  for (i = 0; i < 2; i++)
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

/* A client that registers its observers, says so, and then services its
 * run loop.  It exits 0 as soon as it receives the marker, which the
 * parent posts only after the client was dropped and resumed.
 */
static pid_t
startClient(int *go, int *ack)
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
      NSDistributedNotificationCenter	*dnc;
      DroppedClientObserver		*o;
      char				c = 1;

      close(g[1]);
      close(a[0]);
      if (read(g[0], &c, 1) != 1)
	{
	  _exit(4);
	}
      o = [DroppedClientObserver new];
      dnc = [NSDistributedNotificationCenter defaultCenter];
      [dnc addObserver: o selector: @selector(received:)
		  name: flood object: nil];
      [dnc addObserver: o selector: @selector(received:)
		  name: marker object: nil];
      (void)write(a[1], &c, 1);
      [[NSRunLoop currentRunLoop] runUntilDate:
	[NSDate dateWithTimeIntervalSinceNow: bound * 4]];
      _exit(1);
    }
  close(g[0]);
  close(a[1]);
  *go = g[1];
  *ack = a[0];
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
      execlp(gdnc, gdnc, "--no-fork", "-GDNCClientTimeout", "1",
	(char*)NULL);
      _exit(127);
    }
  return pid;
}

static void
runFor(NSTimeInterval seconds)
{
  [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			   beforeDate: [NSDate dateWithTimeIntervalSinceNow: seconds]];
}

/* NSMessagePort reads TEMP/TMP once at start-up, so a private directory
 * has to be in place before the process starts: re-execute with one.
 */
static void
usePrivateTemporaryDirectory(char **argv)
{
  char	dir[] = "/tmp/droppedClient.XXXXXX";

  if (getenv("DROPPED_CLIENT_TMP") != NULL)
    {
      return;
    }
  if (mkdtemp(dir) == NULL)
    {
      fprintf(stderr, "mkdtemp: %s\n", strerror(errno));
      exit(1);
    }
  setenv("DROPPED_CLIENT_TMP", dir, 1);
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
  START_SET("a client dropped by gdnc receives again")
#if	defined(_WIN32)
    SKIP("fork() is not available")
#else
    NSDistributedNotificationCenter	*dnc;
    NSDictionary			*info;
    NSDate				*limit;
    pid_t				server;
    pid_t				client;
    int					go;
    int					ack;
    int					status = -1;
    unsigned				i;
    BOOL				exited = NO;
    char				c;
    char				cmd[256];

    /* Never run against the gdnc of the user running the test. */
    if ([NSTemporaryDirectory() isEqual: [NSString stringWithUTF8String:
      getenv("DROPPED_CLIENT_TMP")]] == NO)
      {
	fprintf(stderr, "private temporary directory not in use: %s\n",
	  [NSTemporaryDirectory() UTF8String]);
	exit(1);
      }

    client = startClient(&go, &ack);
    server = startServer();
    children[0] = client;
    children[1] = server;
    signal(SIGALRM, parentHung);
    alarm(bound * 4);

    limit = [NSDate dateWithTimeIntervalSinceNow: bound];
    while ([[NSMessagePortNameServer sharedInstance]
      portForName: @"GDNCServer"] == nil && [limit timeIntervalSinceNow] > 0)
      {
	[NSThread sleepForTimeInterval: 0.05];
      }
    PASS(waitpid(server, &status, WNOHANG) == 0
      && [[NSMessagePortNameServer sharedInstance]
	portForName: @"GDNCServer"] != nil,
      "a private gdnc is running");

    c = 1;
    (void)write(go, &c, 1);
    PASS(read(ack, &c, 1) == 1 && kill(client, SIGSTOP) == 0,
      "a client registered its observers and then stopped reading");

    /* Fill the stopped client's socket so that gdnc times out on it. */
    dnc = [NSDistributedNotificationCenter defaultCenter];
    info = [NSDictionary dictionaryWithObject:
      [NSMutableData dataWithLength: 4096] forKey: @"payload"];
    for (i = 0; i < 200; i++)
      {
	[dnc postNotificationName: flood object: nil userInfo: info
	       deliverImmediately: YES];
      }
    /* Long enough for gdnc's one second timeout to expire. */
    runFor(3.0);
    kill(client, SIGCONT);

    /* Post the marker until the resumed client has it. */
    limit = [NSDate dateWithTimeIntervalSinceNow: bound];
    while (exited == NO && [limit timeIntervalSinceNow] > 0)
      {
	NSAutoreleasePool	*pool = [NSAutoreleasePool new];

	[dnc postNotificationName: marker object: nil userInfo: nil
	       deliverImmediately: YES];
	runFor(0.25);
	if (waitpid(client, &status, WNOHANG) == client)
	  {
	    exited = YES;
	  }
	[pool drain];
      }
    PASS(exited && WIFEXITED(status) && WEXITSTATUS(status) == 0,
      "the dropped client gets a notification after it resumes");
    PASS(waitpid(server, &status, WNOHANG) == 0, "gdnc is still running");
    alarm(0);

    if (exited)
      {
	children[0] = 0;
      }
    killChildren();
    waitpid(client, NULL, WNOHANG);
    waitpid(server, NULL, 0);
    snprintf(cmd, sizeof(cmd), "rm -rf '%s'", getenv("DROPPED_CLIENT_TMP"));
    (void)system(cmd);
#endif
  END_SET("a client dropped by gdnc receives again")
  return 0;
}
