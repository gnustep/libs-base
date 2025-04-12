#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  id testObj = AUTORELEASE([NSDate new]);
  
  test_NSObject(@"NSDate", [NSArray arrayWithObject: [NSDate date]]);
  test_NSCoding([NSArray arrayWithObject: testObj]);
  test_keyed_NSCoding([NSArray arrayWithObject: testObj]);
  test_NSCopying(@"NSDate", @"NSDate",
    [NSArray arrayWithObject: testObj], NO, NO);
   
  [arp release]; arp = nil;
  return 0;
}
