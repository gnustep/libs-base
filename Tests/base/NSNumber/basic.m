#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSValue.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSNumber *testObj;

  test_alloc_only(@"NSNumber");
  testObj = [NSNumber numberWithInt: 5];
  test_NSObject(@"NSNumber", [NSArray arrayWithObject:testObj]);
  test_NSCoding([NSArray arrayWithObject:testObj]);
  test_NSCopying(@"NSNumber", @"NSNumber", 
  		 [NSArray arrayWithObject:testObj],YES,NO);
  [arp release]; arp = nil;
  return 0;
}
