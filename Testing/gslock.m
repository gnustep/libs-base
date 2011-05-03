/** gslock - Program to test GSLazyLocks.
   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  David Ayers  <d.ayers@inode.at>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/


#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSThread.h>

#include <GNUstepBase/GSLock.h>

NSLock          *lock = nil;

NSLock              *gLock1 = nil;
GSLazyRecursiveLock *gLock2 = nil;

NSConditionLock     *cLock = nil;

volatile int counter = 0;
volatile int threadExitCounter;

void
wait_a_while ()
{
  volatile int i;
  for (i = 0; i < 5; i++)
    i = ((i + 1) + (i - 1) / 2);
}

#define NUM_ITERATIONS 10000

@interface Tester : NSObject
- (void)runTest:(NSString *)ident;
- (void)dummy:(id)none;
- (void)createNewLockAt:(id)none;
@end
@implementation Tester
- (void)dummy:(id)none
{
  NSLog(@"Multithreaded:%@",[NSThread currentThread]);
}
- (void)runTest:(NSString *)ident
{
  NSDate *start;
  NSDate *end;
  int i,j;
  NSTimeInterval time = 0;
  NSAutoreleasePool *pool;
  BOOL makeMulti;

  pool = [[NSAutoreleasePool alloc] init];

  makeMulti = ([ident isEqualToString: @"Make Multithreaded GS"]);

  for (i = 0; i < 100; i++)
    {
      start = [NSDate date];
      for (j = 0; j < NUM_ITERATIONS; j++)
	{
	  volatile int temp;

	  [lock lock];

	  temp = counter;
	  wait_a_while ();

	  if (makeMulti && i == 49 )
	    {
	      [NSThread detachNewThreadSelector: @selector(dummy:)
			toTarget: self
			withObject: nil];
	      makeMulti = NO;
	    }


	  counter =  temp + 1;
	  wait_a_while ();

	  [lock unlock];
	}
      end = [NSDate date];
      time += [end timeIntervalSinceDate: start];
    }
  NSLog(@"End (%@/%@/%@):%f ",
	[NSThread currentThread], ident, lock, time / 100 );

  threadExitCounter++;

  [pool release];
}

-(void)createNewLockAt:(id)none
{
  [cLock lock];

  GS_INITIALIZED_LOCK(gLock1,NSLock);
  GS_INITIALIZED_LOCK(gLock2,GSLazyRecursiveLock);

  NSLog(@"Created locks: %@ %@", gLock1, gLock2);

  [cLock unlockWithCondition: YES];
}
@end

void
test_lazyLocks()
{
  Tester *tester;
  int i;

  tester = [Tester new];

  [tester runTest:@"empty"];

  lock = [GSLazyLock new];
  [tester runTest:@"single GS"];

  lock = [GSLazyRecursiveLock new];
  [tester runTest:@"single (r) GS"];

  lock = [NSLock new];
  [tester runTest:@"single NS"];

  lock = [NSRecursiveLock new];
  [tester runTest:@"single (r) NS"];

  lock = [GSLazyLock new];
  [tester runTest:@"Make Multithreaded GS"];

  /* We are now multithreaded.  */
  NSCAssert1 ([lock class] == [NSLock class],
	      @"Class didn't morph:%@", lock);

  lock = [GSLazyLock new];
  NSCAssert1 ([lock class] == [NSLock class],
	      @"Returned wrong lock:%@", lock);
  /* These tests actually only test NS*Lock locking, but... */
  [tester runTest:@"multi simple GS"];

  lock = [GSLazyRecursiveLock new];
  NSCAssert1 ([lock class] == [NSRecursiveLock class],
	      @"Returned wrong lock:%@", lock);
  [tester runTest:@"multi simple (r) GS"];

  lock = [NSLock new];
  [tester runTest:@"multi simple NS"];

  lock = [NSRecursiveLock new];
  [tester runTest:@"multi simple NS"];

  /* Let's test locking anyway while we're at it. */
  for (threadExitCounter = 0, i = 0; i < 3; i++)
    {
      NSString *ident;
      ident = [NSString stringWithFormat: @"multi complex (%d)", i];
      [NSThread detachNewThreadSelector: @selector(runTest:)
		toTarget: tester
		withObject: ident];
    }

  while (threadExitCounter < 3)
    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 10.0]];

  NSCAssert1 (counter == NUM_ITERATIONS * 1300,
	      @"Locks broken! %d", counter );

}

void
test_newLockAt(void)
{
  Tester *t = [Tester new];

  cLock = [[NSConditionLock alloc] initWithCondition: NO];

  [NSThread detachNewThreadSelector: @selector(createNewLockAt:)
	    toTarget: t
	    withObject: nil];

  [cLock lockWhenCondition: YES
	 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 10.0]];
  [cLock unlock];

  NSCAssert1([gLock1 isKindOfClass: [NSLock class]],
	     @"-[NSLock newLockAt:] returned %@", gLock1);
  NSCAssert1([gLock2 isKindOfClass: [NSRecursiveLock class]],
	     @"-[GSLazyRecursiveLock newLockAt:] returned %@", gLock1);

}


int
main()
{
  NSAutoreleasePool *pool;
  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  pool = [[NSAutoreleasePool alloc] init];

  test_lazyLocks();
  test_newLockAt();

  [pool release];

  exit(0);
}
