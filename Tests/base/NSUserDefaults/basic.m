#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSUserDefaults.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSArray *testObj = [NSUserDefaults new];

  test_NSObject(@"NSUserDefaults", [NSArray arrayWithObject:testObj]); 

  [arp release]; arp = nil;
  return 0;
}
