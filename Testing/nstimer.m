/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSAutoreleasePool.h>

@interface TestDouble : NSObject
+ (double) testDouble;
- (double) testDoubleInstance;
@end
@implementation TestDouble
+ (void) sayCount
{
  static int count = 0;
  printf ("Timer fired %d times\n", ++count);
  if (count == 20)
    exit(0);
}
+ (double) testDouble
{
  return 12345678912345.0;
}
- (double) testDoubleInstance
{
  return 92345678912345.0;
}
@end

double test_double ()
{
  return 92345678912345.0;
}


int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  volatile double foo, bar;
  id inv;
  id o;
  id d;

  inv = [NSInvocation invocationWithMethodSignature:
    [TestDouble methodSignatureForSelector: @selector(sayCount)]];
  [inv setSelector: @selector(sayCount)];
  [inv setTarget: [TestDouble class]];

  foo = [TestDouble testDouble];
  printf ("TestDouble is %f\n", foo);
  foo = [TestDouble testDouble];
  printf ("TestDouble 2 is %f\n", foo);
  o = [[TestDouble alloc] init];
  bar = [o testDoubleInstance];
  printf ("testDouble is %f\n", bar);

  foo = test_double ();
  printf ("test_double is %f\n", foo);

  d = [NSDate date];
  printf ("time interval since now %f\n", [d timeIntervalSinceNow]);

  [NSTimer scheduledTimerWithTimeInterval: 3.0
	   invocation: inv
	   repeats: YES];
  [[NSRunLoop currentRunLoop] run];
  [arp release];
  exit (0);
}
