/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSRunLoop.h>

#if	!defined(_WIN32)
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>

@interface NSMessagePort (ListenerTest) <RunLoopEvents>
- (void) getFds: (NSInteger*)fds count: (NSInteger*)count;
@end

static void
hung(int sig)
{
  /* Reaching this handler means accept() blocked; report it instead of
   * leaving the test runner waiting forever. */
  static const char msg[] = "Failed test: accept() on the listener blocked\n";
  write(2, msg, sizeof(msg) - 1);
  _exit(1);
}
#endif

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

#if	defined(_WIN32)
  testHopeful = YES;
#else
  NSMessagePort		*port = (NSMessagePort*)[NSMessagePort port];
  NSInteger		fds[8];
  NSInteger		count = 8;
  int			listener;

  [port getFds: fds count: &count];
  PASS(count >= 1, "a message port has a listening descriptor");
  listener = (int)fds[0];

  PASS((fcntl(listener, F_GETFL, 0) & O_NONBLOCK) != 0,
    "the listening descriptor does not block");

  /* The run loop can deliver a readable event for the listener when the
   * connection it saw has already been accepted, e.g. by a nested run
   * loop.  Handling that must return, not wait for the next client. */
  signal(SIGALRM, hung);
  alarm(5);
  [port receivedEvent: 0
		 type: ET_RDESC
		extra: (void*)(intptr_t)listener
	      forMode: nil];
  alarm(0);
  PASS(YES, "a readable event without a pending connection returns");
#endif

  [arp release];
  return 0;
}
