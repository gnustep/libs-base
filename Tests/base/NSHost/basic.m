#import "ObjectTesting.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHost.h>
#import <Foundation/NSString.h>

int main()
{
  ENTER_POOL
  NSHost        *h = [NSHost currentHost];

  test_NSObject(@"NSHost", [NSArray arrayWithObject: h]);
  NSLog(@"%@", h);
  LEAVE_POOL
  return 0;
}
