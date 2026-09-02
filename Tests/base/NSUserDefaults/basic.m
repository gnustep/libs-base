#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSUserDefaults.h>

int main()
{
  START_SET("NSUserDefaults basic")
  NSUserDefaults	*defs = AUTORELEASE([NSUserDefaults new]);
  NSArray		*a;

  test_NSObject(@"NSUserDefaults", [NSArray arrayWithObject: defs]); 

  defs = [NSUserDefaults standardUserDefaults];
  [defs setDouble: (double)42.42 forKey: @"aDouble"];
  PASS(EQ((double)42.42, [defs doubleForKey: @"aDouble"]),
    "can store double");

  a = [defs arrayForKey: @"NSLanguages"];
  PASS(a != nil, "NSLanguages array exists")
NSLog(@"NSLanguages: %@", a);

  END_SET("NSUserDefaults basic")
  return 0;
}
