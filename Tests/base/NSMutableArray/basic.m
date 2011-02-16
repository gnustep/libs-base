#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSArray *testObj = [NSMutableArray arrayWithCapacity:1];
  test_alloc(@"NSMutableArray");
  test_NSObject(@"NSMutableArray", [NSArray arrayWithObject:testObj]); 
  test_NSCoding([NSArray arrayWithObject:testObj]); 
  test_NSCopying(@"NSArray",@"NSMutableArray", 
                 [NSArray arrayWithObject:testObj], NO, NO); 
  test_NSMutableCopying(@"NSArray",@"NSMutableArray", 
                 [NSArray arrayWithObject:testObj]); 
  [arp release]; arp = nil;
  return 0;
}
