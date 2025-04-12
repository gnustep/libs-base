#import <Foundation/Foundation.h>
#import "ObjectTesting.h"
int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  test_alloc(@"NSArchiver");
  test_NSObject(@"NSArchiver",
    [NSArray arrayWithObject: AUTORELEASE([[NSArchiver alloc] init])]);
  test_alloc(@"NSUnarchiver");  
  test_NSObject(@"NSUnarchiver",
    [NSArray arrayWithObject: AUTORELEASE([[NSUnarchiver alloc] init])]);
  
  [arp release]; arp = nil;
  return 0;
}
