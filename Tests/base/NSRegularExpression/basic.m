#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSRegularExpression.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  id testObj = [[NSRegularExpression alloc] initWithPattern: @"^a"
                                                    options: 0
                                                      error: NULL];

  test_NSObject(@"NSRegularExpression",
                [NSArray arrayWithObject: 
                  [[NSRegularExpression alloc] initWithPattern: @"^a"
                                                       options: 0
                                                         error: NULL]]);
  test_NSCopying(@"NSRegularExpression",@"NSRegularExpression",
                 [NSArray arrayWithObject:testObj],NO,NO);
   
  [arp release]; arp = nil;
  return 0;
}
