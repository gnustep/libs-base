/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/Foundation.h>

NSLock	*lock = nil;
unsigned	retainReleaseThreads = 0;

@interface XX : NSObject
- (void) fire;
- (void) retainRelease: (id)obj;
- (void) setup;
@end

@implementation	XX
- (void) fire
{
  NSLog(@"Got here");
}
- (void) retainRelease: (id)obj
{
  unsigned	i;

  NSLog(@"Start retain/releases in thread %@", [NSThread currentThread]);
  for (i = 0; i < 1000000; i++)
    {
      [obj retain];
      [obj release];
    }
  [lock lock];
  retainReleaseThreads++;
  [lock unlock];
  NSLog(@"Done %d retain/releases in thread %@", i, [NSThread currentThread]);
}
- (void) setup
{
  CREATE_AUTORELEASE_POOL(arp);

  NSLog(@"Attempting to obtain lock to proceed");
  if ([lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 5.0]] == YES)
    {
      NSLog(@"Setup1");
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
      NSLog(@"Setup2");
      [self performSelectorOnMainThread: @selector(fire)
			     withObject: nil
			  waitUntilDone: NO];
      NSLog(@"Done perform no wait.");
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
      NSLog(@"Setup3");
      [self performSelectorOnMainThread: @selector(fire)
			     withObject: nil
			  waitUntilDone: YES];
      NSLog(@"Done perform with wait.");
      [lock unlock];
    }
  else
    {
      NSLog(@"Failed to obtain lock");
    }
  RELEASE(arp);
  [NSThread exit];
}
@end

int main(int argc, char **argv, char **env)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSObject	*o = [NSObject new];
  XX		*x = [XX new];

  NSLog(@"Start in main");
  lock = [NSLock new];
  [lock lock];

  [NSThread detachNewThreadSelector: @selector(retainRelease:)
			   toTarget: x
			 withObject: o];
  [NSThread detachNewThreadSelector: @selector(retainRelease:)
			   toTarget: x
			 withObject: o];
  [NSThread detachNewThreadSelector: @selector(retainRelease:)
			   toTarget: x
			 withObject: o];
  [NSThread detachNewThreadSelector: @selector(retainRelease:)
			   toTarget: x
			 withObject: o];
  [NSThread detachNewThreadSelector: @selector(retainRelease:)
			   toTarget: x
			 withObject: o];

  [NSThread detachNewThreadSelector: @selector(setup)
			   toTarget: x
			 withObject: nil];
  NSLog(@"Waiting to give thread time to start");
  [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
  NSLog(@"Releasing lock so thread may proceed");
  [lock unlock];	// Allow other thread to proceed.

  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 10.0]];

  NSLog(@"Done main thread");

  while (retainReleaseThreads < 5)
    {
      NSLog(@"Waiting for all 5 retainRelease threads to complete (%d)",
        retainReleaseThreads);
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    }
  if ([o retainCount] != 1)
    {
      NSLog(@"ERROR ... retain count is %d, expected 1", [o retainCount]);
    }
  DESTROY(arp);
  return 0;
}

