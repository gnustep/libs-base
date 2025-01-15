#import <Foundation/Foundation.h>
#import <GNUstepBase/NSOperationQueue+GNUstepBase.h>
#import "ObjectTesting.h"

@interface MyClass : NSObject
{
  unsigned	counter;
}
- (void) count: (NSMapTable*)map;
- (unsigned) counter;
- (void) increment;
- (void) reset;
@end

@implementation	MyClass
- (void) count: (NSDictionary*)map
{
  unsigned	c = [map count];

//  NSLog(@"Count %u for %@", c, map);
  counter += c;
}
- (unsigned) counter
{
  return counter;
}
- (void) increment
{
  counter = counter + 1;
}
- (void) reset
{
  counter = 0;
}
@end

int main()
{
  ENTER_POOL
  NSOperationQueue	*q;
  NSUInteger		i;
  NSUInteger		ran;
  NSUInteger		want;
  NSTimeInterval	s;
  NSTimeInterval	f;
  MyClass		*o = AUTORELEASE([[MyClass alloc] init]);

  q = AUTORELEASE([[NSOperationQueue alloc] init]);
  [q setMaxConcurrentOperationCount: 1];

  ran = 0;
  want = 200;
  s = [NSDate timeIntervalSinceReferenceDate];
  for (i = 0; i < want; i++)
    {
      [q addOperationWithTarget: o
		performSelector: @selector(increment)];
    }
  [q waitUntilAllOperationsAreFinished];
  f = [NSDate timeIntervalSinceReferenceDate];
  PASS([o counter] == want, "expected number of operations")
  NSLog(@"Duration for %d sequential operations %g seconds.", want, (f - s));


  [o reset];
  [q addOperationWithTarget: o
	    performSelector: @selector(count:)
	   	    withMap:
    @"Key1", @"Val1",
    @"Key2", @"Val2",
    @"Key3", @"Val3",
    nil];
  [q waitUntilAllOperationsAreFinished];
  PASS([o counter] == 3, "map had three keys")

  LEAVE_POOL
  return 0;
}
