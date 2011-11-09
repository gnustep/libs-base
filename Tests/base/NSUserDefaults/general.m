#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSUserDefaults.h>
#import "ObjectTesting.h"

@interface      Observer : NSObject
{
  unsigned count;
}
- (NSString*) count;
- (void) notified: (NSNotification*)n;
@end

@implementation Observer
- (NSString*) count
{
  return [NSString stringWithFormat: @"%u", count];
}
- (void) notified: (NSNotification*)n
{
  count++;
}
@end

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  Observer *obs = [[Observer new] autorelease];
  NSUserDefaults *defs;

  defs = [NSUserDefaults standardUserDefaults];
  PASS(defs != nil && [defs isKindOfClass: [NSUserDefaults class]],
       "NSUserDefaults understands +standardUserDefaults");

  [[NSNotificationCenter defaultCenter] addObserver: obs
    selector: @selector(notified:)
    name: NSUserDefaultsDidChangeNotification
    object: nil];

  [defs setBool: YES forKey: @"Test Suite Bool"];
  PASS([defs boolForKey: @"Test Suite Bool"],
       "NSUserDefaults can set/get a BOOL");

  PASS_EQUAL([obs count], @"1", "setting a boolean causes notification");

  [defs setInteger: 34 forKey: @"Test Suite Int"];
  PASS([defs integerForKey: @"Test Suite Int"] == 34,
       "NSUserDefaults can set/get an int");

  PASS_EQUAL([obs count], @"2", "setting an integer causes notification");

  [defs setObject: @"SetString" forKey: @"Test Suite Str"];
  PASS([[defs stringForKey: @"Test Suite Str"] isEqual: @"SetString"],
       "NSUserDefaults can set/get a string");
  
  [defs removeObjectForKey: @"Test Suite Bool"];
  PASS(nil == [defs objectForKey: @"Test Suite Bool"],
       "NSUserDefaults can use -removeObjectForKey: to remove a bool");

  [defs setObject: nil forKey: @"Test Suite Int"];
  PASS(nil == [defs objectForKey: @"Test Suite Int"],
       "NSUserDefaults can use -setObject:forKey: to remove an int");

  [arp release]; arp = nil;
  return 0;
}
