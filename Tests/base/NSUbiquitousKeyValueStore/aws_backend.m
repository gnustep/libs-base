#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

@interface AWSTestObserver : NSObject
{
  NSMutableArray *notifications;
}
@property (nonatomic, retain) NSMutableArray *notifications;
- (void) ubiquitousStoreDidChange: (NSNotification *)notification;
@end

@implementation AWSTestObserver
@synthesize notifications;

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      notifications = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [notifications release];
  [super dealloc];
}

- (void) ubiquitousStoreDidChange: (NSNotification *)notification
{
  [notifications addObject: notification];
}
@end

int main()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  START_SET("NSUbiquitousKeyValueStore AWS Backend");

  // Test configuration without AWS credentials (should fall back to local mode)
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // Clear any existing configuration
  [defaults removeObjectForKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults removeObjectForKey: @"GSAWSAccessKeyId"];
  [defaults removeObjectForKey: @"GSAWSSecretAccessKey"];
  [defaults removeObjectForKey: @"GSAWSRegion"];
  [defaults removeObjectForKey: @"GSAWSDynamoTableName"];
  [defaults synchronize];

  // Test 1: Default behavior (should use GSSimpleUbiquitousKeyValueStore)
  NSUbiquitousKeyValueStore *defaultStore = [NSUbiquitousKeyValueStore defaultStore];
  PASS(defaultStore != nil, "Default store creation works");

  NSString *defaultClassName = NSStringFromClass([defaultStore class]);
  PASS([defaultClassName isEqualToString: @"GSSimpleUbiquitousKeyValueStore"],
       "Default implementation is GSSimpleUbiquitousKeyValueStore");

  // Test 2: Configure AWS backend (without credentials - should handle gracefully)
  [defaults setObject: @"GSAWSUbiquitousKeyValueStore" forKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults synchronize];

  // Reset singleton to test new configuration
  // Note: In a real implementation, you'd need a way to reset the singleton
  // For testing, we'll create a new instance directly

  // Test AWS configuration loading
  [defaults setObject: @"us-west-2" forKey: @"GSAWSRegion"];
  [defaults setObject: @"TestTableName" forKey: @"GSAWSDynamoTableName"];
  [defaults synchronize];

  // Test 3: AWS store basic functionality (offline mode)
  Class awsClass = NSClassFromString(@"GSAWSUbiquitousKeyValueStore");
  PASS(awsClass != nil, "GSAWSUbiquitousKeyValueStore class exists");

  if (awsClass != nil)
    {
      NSUbiquitousKeyValueStore *awsStore = [[awsClass alloc] init];
      PASS(awsStore != nil, "AWS store instance created");

      if (awsStore != nil)
        {
          // Test basic operations (should work in offline mode)
          [awsStore setString: @"AWS Test Value" forKey: @"test_key"];
          NSString *retrievedValue = [awsStore stringForKey: @"test_key"];
          PASS([retrievedValue isEqualToString: @"AWS Test Value"],
               "AWS store basic set/get works in offline mode");

          // Test different data types
          [awsStore setBool: YES forKey: @"bool_key"];
          PASS([awsStore boolForKey: @"bool_key"] == YES,
               "AWS store boolean storage works");

          [awsStore setDouble: 2.71828 forKey: @"double_key"];
          PASS(fabs([awsStore doubleForKey: @"double_key"] - 2.71828) < 0.00001,
               "AWS store double storage works");

          [awsStore setLongLong: 987654321LL forKey: @"longlong_key"];
          PASS([awsStore longLongForKey: @"longlong_key"] == 987654321LL,
               "AWS store long long storage works");

          // Test array and dictionary
          NSArray *testArray = [NSArray arrayWithObjects: @"item1", @"item2", nil];
          [awsStore setArray: testArray forKey: @"array_key"];
          NSArray *retrievedArray = [awsStore arrayForKey: @"array_key"];
          PASS([retrievedArray isEqual: testArray],
               "AWS store array storage works");

          NSDictionary *testDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"value1", @"key1", @"value2", @"key2", nil];
          [awsStore setDictionary: testDict forKey: @"dict_key"];
          NSDictionary *retrievedDict = [awsStore dictionaryForKey: @"dict_key"];
          PASS([retrievedDict isEqual: testDict],
               "AWS store dictionary storage works");

          // Test data storage
          NSData *testData = [@"Hello Data" dataUsingEncoding: NSUTF8StringEncoding];
          [awsStore setData: testData forKey: @"data_key"];
          NSData *retrievedData = [awsStore dataForKey: @"data_key"];
          PASS([retrievedData isEqual: testData],
               "AWS store data storage works");

          // Test removal
          [awsStore setString: @"To be removed" forKey: @"removal_test"];
          PASS([awsStore stringForKey: @"removal_test"] != nil,
               "Value exists before removal");
          [awsStore removeObjectForKey: @"removal_test"];
          PASS([awsStore stringForKey: @"removal_test"] == nil,
               "Value removed successfully");

          // Test dictionary representation
          NSDictionary *dictRep = [awsStore dictionaryRepresentation];
          PASS(dictRep != nil, "AWS store dictionaryRepresentation works");
          PASS([dictRep count] > 0, "Dictionary representation contains data");

          // Test synchronization (should not crash in offline mode)
          [awsStore synchronize];
          PASS(YES, "AWS store synchronize works without crashing");

          // Test notification system
          AWSTestObserver *observer = [[AWSTestObserver alloc] init];
          [[NSNotificationCenter defaultCenter]
            addObserver: observer
               selector: @selector(ubiquitousStoreDidChange:)
                   name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                 object: awsStore];

          // Simulate external change by posting notification directly
          NSDictionary *userInfo = [NSDictionary dictionaryWithObject: NSUbiquitousKeyValueStoreServerChange
                                                               forKey: NSUbiquitousKeyValueStoreChangeReasonKey];
          [[NSNotificationCenter defaultCenter]
            postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                          object: awsStore
                        userInfo: userInfo];

          // Give notification time to be processed
          [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

          PASS([observer.notifications count] > 0, "AWS store external change notification received");

          [[NSNotificationCenter defaultCenter] removeObserver: observer];
          [observer release];

          [awsStore release];
        }
    }

  // Test 4: Configuration validation
  PASS([defaults stringForKey: @"GSAWSRegion"] != nil, "AWS region configuration persists");
  PASS([defaults stringForKey: @"GSAWSDynamoTableName"] != nil, "DynamoDB table name configuration persists");

  // Test 5: User identifier generation
  [defaults removeObjectForKey: @"GSAWSUserIdentifier"];
  [defaults synchronize];

  // Create another AWS store instance to test user ID generation
  if (awsClass != nil)
    {
      NSUbiquitousKeyValueStore *awsStore2 = [[awsClass alloc] init];

      // Check if user identifier was generated
      NSString *userId = [defaults stringForKey: @"GSAWSUserIdentifier"];
      PASS(userId != nil && [userId length] > 0, "User identifier auto-generated");

      [awsStore2 release];
    }

  // Test 6: Error handling
  if (awsClass != nil)
    {
      NSUbiquitousKeyValueStore *awsStore3 = [[awsClass alloc] init];

      BOOL exceptionThrown = NO;
      @try
        {
          [awsStore3 setString: @"test" forKey: nil];
        }
      @catch (NSException *e)
        {
          exceptionThrown = YES;
        }
      PASS(exceptionThrown, "AWS store throws exception for nil key");

      [awsStore3 release];
    }

  // Clean up configuration
  [defaults removeObjectForKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults removeObjectForKey: @"GSAWSRegion"];
  [defaults removeObjectForKey: @"GSAWSDynamoTableName"];
  [defaults removeObjectForKey: @"GSAWSUserIdentifier"];
  [defaults synchronize];

  END_SET("NSUbiquitousKeyValueStore AWS Backend");

  [pool drain];
  return 0;
}
