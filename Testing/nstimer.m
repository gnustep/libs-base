#include <Foundation/NSRunLoop.h>
#include <base/Invocation.h>
#include <Foundation/NSTimer.h>
#include    <Foundation/NSAutoreleasePool.h>

@interface TestDouble : NSObject
+ (double) testDouble;
- (double) testDoubleInstance;
@end
@implementation TestDouble
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

void say_count ()
{
  static int count = 0;
  printf ("Timer fired %d times\n", ++count);
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  volatile double foo, bar;
  id inv = [[VoidFunctionInvocation alloc] initWithVoidFunction: say_count];
  id o;
  id d;
  
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
  [NSRunLoop run];
  [arp release];
  exit (0);
}
