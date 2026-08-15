#import "ObjectTesting.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSUserDefaults.h>

@interface Counter : NSObject
{
  NSInteger	count;
}
- (NSInteger) count;
- (void) notified: (NSNotification*)n;
- (void) reset;
@end

@implementation Counter
- (NSInteger) count
{
  return count;
}
- (void) notified: (NSNotification*)n
{
  count++;
}
- (void) reset
{
  count = 0;
}
@end

int main()
{
  START_SET("NSUserDefaults change notification")
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  Counter		*obs = AUTORELEASE([Counter new]);
  NSDictionary		*dict;
  NSArray		*list;

  dict = [NSDictionary dictionaryWithObject: @"value" forKey: @"NotifyKey"];
  list = [defs searchList];

  [[NSNotificationCenter defaultCenter] addObserver: obs
					   selector: @selector(notified:)
					       name: NSUserDefaultsDidChangeNotification
					     object: nil];

  [obs reset];
  [defs registerDefaults: dict];
  PASS([obs count] == 1,
    "-registerDefaults: posts a change notification")
  PASS_EQUAL([defs stringForKey: @"NotifyKey"], @"value",
    "-registerDefaults: makes the value visible")

  [obs reset];
  [defs setVolatileDomain: dict forName: @"NotifyVolatile"];
  PASS([obs count] == 1,
    "-setVolatileDomain:forName: posts a change notification")

  [obs reset];
  [defs removeVolatileDomainForName: @"NotifyVolatile"];
  PASS([obs count] == 1,
    "-removeVolatileDomainForName: posts a change notification")

  [obs reset];
  [defs addSuiteNamed: @"NotifySuite"];
  PASS([obs count] == 1,
    "-addSuiteNamed: posts a change notification")

  [obs reset];
  [defs removeSuiteNamed: @"NotifySuite"];
  PASS([obs count] == 1,
    "-removeSuiteNamed: posts a change notification")

  [obs reset];
  [defs setSearchList: [list arrayByAddingObject: @"NotifyListed"]];
  PASS([obs count] == 1,
    "-setSearchList: posts a change notification")

  [obs reset];
  [defs setSearchList: [defs searchList]];
  PASS([obs count] == 0,
    "-setSearchList: with an equal list posts nothing")

  [defs setSearchList: list];
  [[NSNotificationCenter defaultCenter] removeObserver: obs];

  END_SET("NSUserDefaults change notification")
  return 0;
}
