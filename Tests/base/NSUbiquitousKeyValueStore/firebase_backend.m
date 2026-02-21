#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

@interface FirebaseTestObserver : NSObject
{
  NSMutableArray *notifications;
}
@property (nonatomic, retain) NSMutableArray *notifications;
- (void) ubiquitousStoreDidChange: (NSNotification *)notification;
@end

@implementation FirebaseTestObserver
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

  START_SET("NSUbiquitousKeyValueStore Firebase Free Backend");

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // Clear any existing configuration to test auto-configuration
  [defaults removeObjectForKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults removeObjectForKey: @"GSAutoFirebaseURL"];
  [defaults removeObjectForKey: @"GSAutoFirebaseBinName"];
  [defaults removeObjectForKey: @"GSFirebaseUserIdentifier"];
  [defaults synchronize];

  // Test 1: Default behavior (should still work)
  NSUbiquitousKeyValueStore *defaultStore = [NSUbiquitousKeyValueStore defaultStore];
  PASS(defaultStore != nil, "Default store creation works");

  // Test 2: Configure Firebase backend
  [defaults setObject: @"GSFirebaseUbiquitousKeyValueStore" forKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults synchronize];

  // Test Firebase backend class exists
  Class firebaseClass = NSClassFromString(@"GSFirebaseUbiquitousKeyValueStore");
  PASS(firebaseClass != nil, "GSFirebaseUbiquitousKeyValueStore class exists");

  if (firebaseClass != nil)
    {
      // Create Firebase store instance to test auto-configuration
      NSUbiquitousKeyValueStore *firebaseStore = [[firebaseClass alloc] init];
      PASS(firebaseStore != nil, "Firebase store instance created");

      if (firebaseStore != nil)
        {
          // Give auto-configuration time to complete
          [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];

          // Test auto-configuration results
          NSString *autoURL = [defaults stringForKey: @"GSAutoFirebaseURL"];
          NSString *binName = [defaults stringForKey: @"GSAutoFirebaseBinName"];
          NSString *userId = [defaults stringForKey: @"GSFirebaseUserIdentifier"];

          PASS(autoURL != nil, "Auto-configuration created URL");
          PASS(binName != nil, "Auto-configuration created bin name");
          PASS(userId != nil && [userId length] > 0, "User identifier generated");

          if (autoURL != nil)
            {
              PASS([autoURL hasPrefix: @"https://"], "Auto-configured URL uses HTTPS");
              PASS([autoURL containsString: @"jsonbin.io"], "Using JSONBin.io service");
            }

          if (binName != nil)
            {
              PASS([binName hasPrefix: @"gnustep_"], "Bin name has proper prefix");
              PASS([binName length] > 10, "Bin name is sufficiently unique");
            }

          // Test basic operations
          [firebaseStore setString: @"Firebase Test Value" forKey: @"test_key"];
          NSString *retrievedValue = [firebaseStore stringForKey: @"test_key"];
          PASS([retrievedValue isEqualToString: @"Firebase Test Value"],
               "Firebase store basic set/get works");

          // Test different data types
          [firebaseStore setBool: YES forKey: @"bool_key"];
          PASS([firebaseStore boolForKey: @"bool_key"] == YES,
               "Firebase store boolean storage works");

          [firebaseStore setDouble: 2.71828 forKey: @"double_key"];
          PASS(fabs([firebaseStore doubleForKey: @"double_key"] - 2.71828) < 0.00001,
               "Firebase store double storage works");

          [firebaseStore setLongLong: 987654321LL forKey: @"longlong_key"];
          PASS([firebaseStore longLongForKey: @"longlong_key"] == 987654321LL,
               "Firebase store long long storage works");

          // Test complex types
          NSArray *testArray = [NSArray arrayWithObjects: @"free", @"cloud", @"storage", nil];
          [firebaseStore setArray: testArray forKey: @"array_key"];
          NSArray *retrievedArray = [firebaseStore arrayForKey: @"array_key"];
          PASS([retrievedArray isEqual: testArray],
               "Firebase store array storage works");

          NSDictionary *testDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"JSONBin.io", @"service", @"free", @"cost", nil];
          [firebaseStore setDictionary: testDict forKey: @"dict_key"];
          NSDictionary *retrievedDict = [firebaseStore dictionaryForKey: @"dict_key"];
          PASS([retrievedDict isEqual: testDict],
               "Firebase store dictionary storage works");

          // Test data storage
          NSData *testData = [@"Firebase Data Test" dataUsingEncoding: NSUTF8StringEncoding];
          [firebaseStore setData: testData forKey: @"data_key"];
          NSData *retrievedData = [firebaseStore dataForKey: @"data_key"];
          PASS([retrievedData isEqual: testData],
               "Firebase store data storage works");

          // Test removal
          [firebaseStore setString: @"To be removed" forKey: @"removal_test"];
          PASS([firebaseStore stringForKey: @"removal_test"] != nil,
               "Value exists before removal");
          [firebaseStore removeObjectForKey: @"removal_test"];
          PASS([firebaseStore stringForKey: @"removal_test"] == nil,
               "Value removed successfully");

          // Test dictionary representation
          NSDictionary *dictRep = [firebaseStore dictionaryRepresentation];
          PASS(dictRep != nil, "Firebase store dictionaryRepresentation works");
          PASS([dictRep count] > 0, "Dictionary representation contains data");

          // Test synchronization (should not crash)
          [firebaseStore synchronize];
          PASS(YES, "Firebase store synchronize works without crashing");

          // Test notification system
          FirebaseTestObserver *observer = [[FirebaseTestObserver alloc] init];
          [[NSNotificationCenter defaultCenter]
            addObserver: observer
               selector: @selector(ubiquitousStoreDidChange:)
                   name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                 object: firebaseStore];

          // Simulate external change
          NSDictionary *userInfo = [NSDictionary dictionaryWithObject: NSUbiquitousKeyValueStoreServerChange
                                                               forKey: NSUbiquitousKeyValueStoreChangeReasonKey];
          [[NSNotificationCenter defaultCenter]
            postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                          object: firebaseStore
                        userInfo: userInfo];

          [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

          PASS([observer.notifications count] > 0, "Firebase store external change notification received");

          [[NSNotificationCenter defaultCenter] removeObserver: observer];
          [observer release];

          [firebaseStore release];
        }
    }

  // Test 3: Configuration persistence and reuse
  // Create another instance to test that configuration is reused
  if (firebaseClass != nil)
    {
      NSUbiquitousKeyValueStore *firebaseStore2 = [[firebaseClass alloc] init];

      // Should reuse existing configuration
      NSString *autoURL2 = [defaults stringForKey: @"GSAutoFirebaseURL"];
      NSString *binName2 = [defaults stringForKey: @"GSAutoFirebaseBinName"];

      PASS([autoURL2 length] > 0, "Configuration reused on second instance");
      PASS([binName2 length] > 0, "Bin name reused on second instance");

      [firebaseStore2 release];
    }

  // Test 4: Error handling
  if (firebaseClass != nil)
    {
      NSUbiquitousKeyValueStore *firebaseStore3 = [[firebaseClass alloc] init];

      BOOL exceptionThrown = NO;
      @try
        {
          [firebaseStore3 setString: @"test" forKey: nil];
        }
      @catch (NSException *e)
        {
          exceptionThrown = YES;
        }
      PASS(exceptionThrown, "Firebase store throws exception for nil key");

      [firebaseStore3 release];
    }

  // Test 5: Key sanitization
  if (firebaseClass != nil)
    {
      NSUbiquitousKeyValueStore *firebaseStore4 = [[firebaseClass alloc] init];

      // Test keys with special characters that need sanitization
      [firebaseStore4 setString: @"test value" forKey: @"key.with.dots"];
      [firebaseStore4 setString: @"test value2" forKey: @"key/with/slashes"];
      [firebaseStore4 setString: @"test value3" forKey: @"key[with]brackets"];

      NSString *val1 = [firebaseStore4 stringForKey: @"key.with.dots"];
      NSString *val2 = [firebaseStore4 stringForKey: @"key/with/slashes"];
      NSString *val3 = [firebaseStore4 stringForKey: @"key[with]brackets"];

      PASS([val1 isEqualToString: @"test value"], "Key with dots sanitized and stored");
      PASS([val2 isEqualToString: @"test value2"], "Key with slashes sanitized and stored");
      PASS([val3 isEqualToString: @"test value3"], "Key with brackets sanitized and stored");

      [firebaseStore4 release];
    }

  // Test 6: Bundle ID handling
  NSString *currentBundleId = [[NSBundle mainBundle] bundleIdentifier];
  if (currentBundleId == nil)
    {
      // Should fall back to default
      NSString *binName = [defaults stringForKey: @"GSAutoFirebaseBinName"];
      PASS([binName containsString: @"GNUstepApp"], "Falls back to default bundle ID");
    }

  // Clean up configuration (optional - leave for real usage)
  printf("Note: Leaving auto-configuration in place for actual usage.\n");
  printf("Auto-configured endpoint: %s\n", [[defaults stringForKey: @"GSAutoFirebaseURL"] UTF8String]);
  printf("Storage bin: %s\n", [[defaults stringForKey: @"GSAutoFirebaseBinName"] UTF8String]);

  END_SET("NSUbiquitousKeyValueStore Firebase Free Backend");

  [pool drain];
  return 0;
}
