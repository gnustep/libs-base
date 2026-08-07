#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

@interface TestObserver : NSObject
{
  BOOL notificationReceived;
  NSDictionary *receivedUserInfo;
}
@property (nonatomic) BOOL notificationReceived;
@property (nonatomic, retain) NSDictionary *receivedUserInfo;
- (void) ubiquitousStoreDidChange: (NSNotification *)notification;
@end

@implementation TestObserver
@synthesize notificationReceived;
@synthesize receivedUserInfo;

- (void) ubiquitousStoreDidChange: (NSNotification *)notification
{
  self.notificationReceived = YES;
  self.receivedUserInfo = [notification userInfo];
}

- (void) dealloc
{
  [receivedUserInfo release];
  [super dealloc];
}
@end

int main()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  START_SET("NSUbiquitousKeyValueStore base");

  NSUbiquitousKeyValueStore *kvStore = [NSUbiquitousKeyValueStore defaultStore];
  PASS(kvStore != nil, "defaultStore returns non-nil instance");

  // Test basic string storage
  [kvStore setObject:@"Hello" forKey:@"World"];
  id obj = [kvStore objectForKey:@"World"];
  PASS([obj isEqualToString:@"Hello"], "Returned proper string value");

  [kvStore setString:@"Hello" forKey:@"World2"];
  obj = [kvStore objectForKey:@"World2"];
  PASS([obj isEqualToString:@"Hello"], "Returned proper string value via setString");

  // Test array storage
  [kvStore setArray: [NSArray arrayWithObject:@"Hello"] forKey:@"World3"];
  obj = [kvStore arrayForKey:@"World3"];
  PASS([obj isEqual:[NSArray arrayWithObject:@"Hello"] ], "Returned proper array value");

  // Test dictionary storage
  [kvStore setDictionary:[NSDictionary dictionaryWithObject:@"Hello" forKey:@"World4"] forKey:@"World5"];
  obj = [kvStore dictionaryForKey:@"World5"];
  PASS([obj isEqual:[NSDictionary dictionaryWithObject:@"Hello" forKey:@"World4"]], "Returned proper dictionary value");

  // Test data storage
  [kvStore setData:[NSData dataWithBytes:"hello" length:5] forKey:@"World6"];
  obj = [kvStore dataForKey:@"World6"];
  PASS([obj isEqual:[NSData dataWithBytes:"hello" length:5]], "Returned proper data value");

  // Test number storage
  [kvStore setBool:YES forKey:@"BoolKey"];
  PASS([kvStore boolForKey:@"BoolKey"] == YES, "Boolean value storage works");

  [kvStore setDouble:3.14159 forKey:@"DoubleKey"];
  PASS(fabs([kvStore doubleForKey:@"DoubleKey"] - 3.14159) < 0.00001, "Double value storage works");

  [kvStore setLongLong:123456789LL forKey:@"LongLongKey"];
  PASS([kvStore longLongForKey:@"LongLongKey"] == 123456789LL, "Long long value storage works");

  // Test removal
  [kvStore setString:@"ToBeRemoved" forKey:@"RemovalTest"];
  PASS([kvStore stringForKey:@"RemovalTest"] != nil, "Value exists before removal");
  [kvStore removeObjectForKey:@"RemovalTest"];
  PASS([kvStore stringForKey:@"RemovalTest"] == nil, "Value removed successfully");

  // Test dictionary representation
  NSDictionary *dictRep = [kvStore dictionaryRepresentation];
  PASS(dictRep != nil, "dictionaryRepresentation returns non-nil");
  PASS([dictRep count] > 0, "dictionaryRepresentation contains data");

  // Test synchronization (should not crash)
  [kvStore synchronize];
  PASS(YES, "synchronize method works without crashing");

  // Test that we can get same instance
  NSUbiquitousKeyValueStore *kvStore2 = [NSUbiquitousKeyValueStore defaultStore];
  PASS(kvStore == kvStore2, "defaultStore returns same instance");

  // Test nil key handling
  BOOL exceptionThrown = NO;
  @try
    {
      [kvStore setString:@"test" forKey:nil];
    }
  @catch (NSException *e)
    {
      exceptionThrown = YES;
    }
  PASS(exceptionThrown, "Setting nil key throws exception");

  // Test notification system
  TestObserver *observer = [[TestObserver alloc] init];
  [[NSNotificationCenter defaultCenter]
    addObserver:observer
       selector:@selector(ubiquitousStoreDidChange:)
           name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
         object:kvStore];

  // Simulate external change notification
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSUbiquitousKeyValueStoreServerChange
                                                       forKey:NSUbiquitousKeyValueStoreChangeReasonKey];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                  object:kvStore
                userInfo:userInfo];

  // Give notification time to be processed
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

  PASS(observer.notificationReceived, "External change notification received");
  PASS([observer.receivedUserInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey] != nil,
       "Notification contains change reason");

  [[NSNotificationCenter defaultCenter] removeObserver:observer];
  [observer release];

  END_SET("NSUbiquitousKeyValueStore base");

  [pool drain];
  return 0;
}
