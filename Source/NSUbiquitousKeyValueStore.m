/** Interface for NSUbiquitousKeyValueStore
   Copyright (C) 2019 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Created: July 3 2019

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#import "common.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSUbiquitousKeyValueStore.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSData.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSNotificationCenter.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSPropertyList.h"
#import "Foundation/NSBundle.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLRequest.h"
#import "Foundation/NSURLConnection.h"
#import "Foundation/NSURLResponse.h"
#import "Foundation/NSHTTPURLResponse.h"
#import "Foundation/NSJSONSerialization.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSOperationQueue.h"
#import "Foundation/NSDate.h"

// Notification constants
NSString* const NSUbiquitousKeyValueStoreDidChangeExternallyNotification = @"NSUbiquitousKeyValueStoreDidChangeExternallyNotification";
NSString* const NSUbiquitousKeyValueStoreChangeReasonKey = @"NSUbiquitousKeyValueStoreChangeReasonKey";

// Change reason constants
NSString* const NSUbiquitousKeyValueStoreServerChange = @"NSUbiquitousKeyValueStoreServerChange";
NSString* const NSUbiquitousKeyValueStoreInitialSyncChange = @"NSUbiquitousKeyValueStoreInitialSyncChange";
NSString* const NSUbiquitousKeyValueStoreQuotaViolationChange = @"NSUbiquitousKeyValueStoreQuotaViolationChange";
NSString* const NSUbiquitousKeyValueStoreAccountChange = @"NSUbiquitousKeyValueStoreAccountChange";

static NSUbiquitousKeyValueStore *_sharedUbiquitousKeyValueStore = nil;

@implementation NSUbiquitousKeyValueStore : NSObject

// Getting the Shared Instance
- (id) init
{
  if ((self = [super init]) != nil)
    {
    }
  return self;
}

+ (NSUbiquitousKeyValueStore *) defaultStore
{
  if (_sharedUbiquitousKeyValueStore == nil)
    {
      NSString *storeClassName = [[NSUserDefaults standardUserDefaults]
				   stringForKey: @"GSUbiquitousKeyValueStoreClass"];
      Class klass = (storeClassName != nil) ? NSClassFromString(storeClassName) :
	NSClassFromString(@"GSSimpleUbiquitousKeyValueStore");
      _sharedUbiquitousKeyValueStore = [[klass alloc] init];
      if (_sharedUbiquitousKeyValueStore == nil)
	{
	  NSLog(@"Cannot instantiate class shared key store");
	}
    }
  return _sharedUbiquitousKeyValueStore;
}

// Getting Values
// Returns the array associated with the specified key.
- (NSArray *) arrayForKey: (NSString *)key
{
  return (NSArray *)[self objectForKey: key];
}

// Returns the Boolean value associated with the specified key.
- (BOOL) boolForKey: (NSString *)key
{
  return (BOOL)([[self objectForKey: key] boolValue] == 1);
}

// Returns the data object associated with the specified key.
- (NSData*) dataForKey: (NSString *)key
{
  return (NSData *)[self objectForKey: key];
}

// Returns the dictionary object associated with the specified key.
- (NSDictionary *) dictionaryForKey: (NSString *)key
{
  return (NSDictionary *)[self objectForKey: key];
}

// Returns the double value associated with the specified key.
- (double) doubleForKey: (NSString *)key
{
  return [[self objectForKey: key] doubleValue];
}

// Returns the long long value associated with the specified key.
- (long long) longLongForKey: (NSString *)key
{
  return [[self objectForKey: key] longLongValue];
}

// Returns the object associated with the specified key.
- (id) objectForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

//  Returns the string associated with the specified key.
- (NSString *) stringForKey: (NSString *)key
{
  return (NSString *)[self objectForKey: key];
}

// Setting Values
// Sets an array object for the specified key in the key-value store.
- (void) setArray: (NSArray *)array forKey: (NSString *)key
{
  [self setObject: array forKey: key];
}

// Sets a Boolean value for the specified key in the key-value store.
- (void) setBool: (BOOL)flag forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithBool: flag];
  [self setObject: num forKey: key];
}

// Sets a data object for the specified key in the key-value store.
- (void) setData: (NSData *)data forKey: (NSString *)key
{
  [self setObject: data forKey: key];
}

// Sets a dictionary object for the specified key in the key-value store.
- (void) setDictionary: (NSDictionary *)dict forKey: (NSString *)key
{
  [self setObject: dict forKey: key];
}

// Sets a double value for the specified key in the key-value store.
- (void) setDouble: (double)val forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithDouble: val];
  [self setObject: num forKey: key];
}

// Sets a long long value for the specified key in the key-value store.
- (void) setLongLong: (long long)val forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithLongLong: val];
  [self setObject: num forKey: key];
}

// Sets an object for the specified key in the key-value store.
- (void) setObject: (id) obj forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a string object for the specified key in the key-value store.
- (void) setString: (NSString *)string forKey: (NSString *)key
{
  [self setObject: string forKey: key];
}

// Explicitly Synchronizing In-Memory Key-Value Data to Disk
// Explicitly synchronizes in-memory keys and values with those stored on disk.
- (void) synchronize
{
  [self subclassResponsibility: _cmd];
}

// Removing Keys
// Removes the value associated with the specified key from the key-value store.
- (void) removeObjectForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Retrieving the Current Keys and Values
// A dictionary containing all of the key-value pairs in the key-value store.
- (NSDictionary *) dictionaryRepresentation
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end

@interface GSSimpleUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
  NSMutableDictionary *_dict;
  NSString *_storePath;
  NSLock *_lock;
  NSTimer *_syncTimer;
  NSTimeInterval _lastModified;
  BOOL _needsSynchronization;
}
- (NSString *) _persistentStorePath;
- (BOOL) _loadFromDisk;
- (BOOL) _saveToDisk;
- (void) _checkForExternalChanges: (NSTimer *)timer;
- (void) _notifyExternalChange;
@end

@implementation GSSimpleUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if(self != nil)
    {
      _dict = [[NSMutableDictionary alloc] initWithCapacity: 10];
      _lock = [[NSLock alloc] init];
      _storePath = [[self _persistentStorePath] retain];
      _lastModified = 0;
      _needsSynchronization = NO;

      // Load existing data
      [self _loadFromDisk];

      // Set up periodic sync timer (every 30 seconds)
      _syncTimer = [[NSTimer scheduledTimerWithTimeInterval: 30.0
                                                     target: self
                                                   selector: @selector(_checkForExternalChanges:)
                                                   userInfo: nil
                                                    repeats: YES] retain];
    }
  return self;
}

- (void) dealloc
{
  [_syncTimer invalidate];
  [_syncTimer release];
  [_lock release];
  [_dict release];
  [_storePath release];
  [super dealloc];
}

- (NSString *) _persistentStorePath
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                      NSUserDomainMask, YES);
  NSString *appSupportDir;
  NSString *bundleId;

  if ([paths count] > 0)
    {
      appSupportDir = [paths objectAtIndex: 0];
    }
  else
    {
      appSupportDir = NSTemporaryDirectory();
    }

  bundleId = [[[NSBundle mainBundle] bundleIdentifier]
               stringByAppendingString: @".UbiquitousKeyValueStore"];
  if (bundleId == nil)
    {
      bundleId = @"GSUbiquitousKeyValueStore";
    }

  NSString *storeDir = [appSupportDir stringByAppendingPathComponent: bundleId];
  [[NSFileManager defaultManager] createDirectoryAtPath: storeDir
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];

  return [storeDir stringByAppendingPathComponent: @"store.plist"];
}

- (BOOL) _loadFromDisk
{
  [_lock lock];
  @try
    {
      NSFileManager *fm = [NSFileManager defaultManager];
      if ([fm fileExistsAtPath: _storePath])
        {
          NSDictionary *attrs = [fm attributesOfItemAtPath: _storePath error: NULL];
          _lastModified = [[attrs fileModificationDate] timeIntervalSinceReferenceDate];

          NSDictionary *loadedDict = [NSDictionary dictionaryWithContentsOfFile: _storePath];
          if (loadedDict != nil)
            {
              [_dict removeAllObjects];
              [_dict addEntriesFromDictionary: loadedDict];
              return YES;
            }
        }
    }
  @finally
    {
      [_lock unlock];
    }
  return NO;
}

- (BOOL) _saveToDisk
{
  [_lock lock];
  @try
    {
      BOOL success = [_dict writeToFile: _storePath atomically: YES];
      if (success)
        {
          NSFileManager *fm = [NSFileManager defaultManager];
          NSDictionary *attrs = [fm attributesOfItemAtPath: _storePath error: NULL];
          _lastModified = [[attrs fileModificationDate] timeIntervalSinceReferenceDate];
          _needsSynchronization = NO;
        }
      return success;
    }
  @finally
    {
      [_lock unlock];
    }
}

- (void) _checkForExternalChanges: (NSTimer *)timer
{
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath: _storePath])
    {
      NSDictionary *attrs = [fm attributesOfItemAtPath: _storePath error: NULL];
      NSTimeInterval currentModTime = [[attrs fileModificationDate] timeIntervalSinceReferenceDate];

      if (currentModTime > _lastModified)
        {
          [self _loadFromDisk];
          [self _notifyExternalChange];
        }
    }
}

- (void) _notifyExternalChange
{
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: NSUbiquitousKeyValueStoreServerChange
                                                       forKey: NSUbiquitousKeyValueStoreChangeReasonKey];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                  object: self
                userInfo: userInfo];
}

// Returns the object associated with the specified key.
- (id) objectForKey: (NSString *)key
{
  [_lock lock];
  @try
    {
      return [_dict objectForKey: key];
    }
  @finally
    {
      [_lock unlock];
    }
}

// Sets an object for the specified key in the key-value store.
- (void) setObject: (id) obj forKey: (NSString *)key
{
  if (key == nil)
    {
      [NSException raise: NSInvalidArgumentException format: @"key cannot be nil"];
    }

  [_lock lock];
  @try
    {
      if (obj != nil)
        {
          [_dict setObject: obj forKey: key];
        }
      else
        {
          [_dict removeObjectForKey: key];
        }
      _needsSynchronization = YES;
    }
  @finally
    {
      [_lock unlock];
    }
}

// Explicitly Synchronizing In-Memory Key-Value Data to Disk
// Explicitly synchronizes in-memory keys and values with those stored on disk.
- (void) synchronize
{
  if (_needsSynchronization)
    {
      [self _saveToDisk];
    }
}

// Removing Keys
// Removes the value associated with the specified key from the key-value store.
- (void) removeObjectForKey: (NSString *)key
{
  [_lock lock];
  @try
    {
      [_dict removeObjectForKey: key];
      _needsSynchronization = YES;
    }
  @finally
    {
      [_lock unlock];
    }
}

// Retrieving the Current Keys and Values
// A dictionary containing all of the key-value pairs in the key-value store.
- (NSDictionary *) dictionaryRepresentation
{
  [_lock lock];
  @try
    {
      return [NSDictionary dictionaryWithDictionary: _dict];
    }
  @finally
    {
      [_lock unlock];
    }
}

@end

@interface GSAWSUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
  NSMutableDictionary *_localCache;
  NSMutableDictionary *_pendingOperations;
  NSOperationQueue *_networkQueue;
  NSLock *_cacheLock;
  NSTimer *_syncTimer;
  NSString *_awsRegion;
  NSString *_awsAccessKeyId;
  NSString *_awsSecretAccessKey;
  NSString *_dynamoTableName;
  NSString *_userIdentifier;
  BOOL _isOnline;
  NSTimeInterval _lastSyncTime;
}

// Configuration
- (void) _loadAWSConfiguration;
- (NSString *) _userIdentifier;

// AWS Authentication
- (NSString *) _createAWSSignature: (NSString *)method
                               url: (NSString *)url
                           headers: (NSDictionary *)headers
                           payload: (NSString *)payload
                              date: (NSString *)dateString;
- (NSString *) _sha256Hash: (NSString *)input;
- (NSString *) _hmacSha256: (NSString *)key data: (NSString *)data;

// Network Operations
- (void) _performAsyncRequest: (NSURLRequest *)request
            completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (void) _syncWithRemoteStore;
- (void) _uploadPendingChanges;
- (void) _downloadRemoteChanges;

// DynamoDB Operations
- (NSURLRequest *) _createDynamoDBRequest: (NSString *)operation payload: (NSString *)payload;
- (void) _putItem: (NSString *)key value: (id)value timestamp: (NSTimeInterval)timestamp;
- (void) _getItem: (NSString *)key completionHandler: (void (^)(id value, NSError *error))handler;
- (void) _deleteItem: (NSString *)key;
- (void) _scanTable: (void (^)(NSDictionary *items, NSError *error))handler;

// Offline Support
- (void) _queueOperation: (NSString *)operation key: (NSString *)key value: (id)value;
- (void) _processOfflineQueue;

// Conflict Resolution
- (id) _resolveConflict: (id)localValue remoteValue: (id)remoteValue localTime: (NSTimeInterval)localTime remoteTime: (NSTimeInterval)remoteTime;

// Utility Methods
- (NSString *) _serializeValue: (id)value;
- (id) _deserializeValue: (NSString *)serializedValue;
@end

@implementation GSAWSUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _localCache = [[NSMutableDictionary alloc] init];
      _pendingOperations = [[NSMutableDictionary alloc] init];
      _networkQueue = [[NSOperationQueue alloc] init];
      [_networkQueue setMaxConcurrentOperationCount: 3];
      [_networkQueue setName: @"GSAWSUbiquitousKeyValueStore.NetworkQueue"];

      _cacheLock = [[NSLock alloc] init];
      _isOnline = YES;
      _lastSyncTime = 0;

      // Load AWS configuration
      [self _loadAWSConfiguration];

      // Setup periodic sync (every 60 seconds)
      _syncTimer = [[NSTimer scheduledTimerWithTimeInterval: 60.0
                                                     target: self
                                                   selector: @selector(_syncWithRemoteStore)
                                                   userInfo: nil
                                                    repeats: YES] retain];

      // Initial sync
      [self _syncWithRemoteStore];
    }
  return self;
}

- (void) dealloc
{
  [_syncTimer invalidate];
  [_syncTimer release];
  [_networkQueue cancelAllOperations];
  [_networkQueue release];
  [_cacheLock release];
  [_localCache release];
  [_pendingOperations release];
  [_awsRegion release];
  [_awsAccessKeyId release];
  [_awsSecretAccessKey release];
  [_dynamoTableName release];
  [_userIdentifier release];
  [super dealloc];
}

#pragma mark - Configuration

- (void) _loadAWSConfiguration
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  _awsRegion = [[defaults stringForKey: @"GSAWSRegion"] retain];
  if (_awsRegion == nil)
    {
      _awsRegion = [@"us-east-1" retain];
    }

  _awsAccessKeyId = [[defaults stringForKey: @"GSAWSAccessKeyId"] retain];
  _awsSecretAccessKey = [[defaults stringForKey: @"GSAWSSecretAccessKey"] retain];
  _dynamoTableName = [[defaults stringForKey: @"GSAWSDynamoTableName"] retain];

  if (_dynamoTableName == nil)
    {
      _dynamoTableName = [@"GNUstepUbiquitousKVStore" retain];
    }

  _userIdentifier = [[self _userIdentifier] retain];

  if (_awsAccessKeyId == nil || _awsSecretAccessKey == nil)
    {
      NSLog(@"Warning: AWS credentials not configured. Set GSAWSAccessKeyId and GSAWSSecretAccessKey in NSUserDefaults.");
      _isOnline = NO;
    }
}

- (NSString *) _userIdentifier
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *userId = [defaults stringForKey: @"GSAWSUserIdentifier"];

  if (userId == nil)
    {
      // Generate a unique identifier for this user/device
      userId = [[NSProcessInfo processInfo] globallyUniqueString];
      [defaults setObject: userId forKey: @"GSAWSUserIdentifier"];
      [defaults synchronize];
    }

  return userId;
}

#pragma mark - AWS Authentication

- (NSString *) _createAWSSignature: (NSString *)method
                               url: (NSString *)url
                           headers: (NSDictionary *)headers
                           payload: (NSString *)payload
                              date: (NSString *)dateString
{
  // This is a simplified AWS Signature V4 implementation
  // In a production environment, you'd want to use a proper AWS SDK

  NSString *service = @"dynamodb";
  NSString *algorithm = @"AWS4-HMAC-SHA256";

  // Create canonical request
  NSMutableString *canonicalHeaders = [NSMutableString string];
  NSMutableString *signedHeaders = [NSMutableString string];

  NSArray *sortedHeaderKeys = [[headers allKeys] sortedArrayUsingSelector: @selector(compare:)];
  for (NSString *key in sortedHeaderKeys)
    {
      [canonicalHeaders appendFormat: @"%@:%@\n", [key lowercaseString], [headers objectForKey: key]];
      if ([signedHeaders length] > 0)
        [signedHeaders appendString: @";"];
      [signedHeaders appendString: [key lowercaseString]];
    }

  NSString *canonicalRequest = [NSString stringWithFormat: @"%@\n%@\n\n%@\n%@\n%@",
                               method, url, canonicalHeaders, signedHeaders, [self _sha256Hash: payload]];

  NSString *hashedCanonicalRequest = [self _sha256Hash: canonicalRequest];

  // Create string to sign
  NSString *credentialScope = [NSString stringWithFormat: @"%@/%@/%@/aws4_request",
                              [dateString substringToIndex: 8], _awsRegion, service];

  NSString *stringToSign = [NSString stringWithFormat: @"%@\n%@\n%@\n%@",
                           algorithm, dateString, credentialScope, hashedCanonicalRequest];

  // Calculate signature
  NSString *dateKey = [self _hmacSha256: [@"AWS4" stringByAppendingString: _awsSecretAccessKey]
                                   data: [dateString substringToIndex: 8]];
  NSString *dateRegionKey = [self _hmacSha256: dateKey data: _awsRegion];
  NSString *dateRegionServiceKey = [self _hmacSha256: dateRegionKey data: service];
  NSString *signingKey = [self _hmacSha256: dateRegionServiceKey data: @"aws4_request"];
  NSString *signature = [self _hmacSha256: signingKey data: stringToSign];

  // Create authorization header
  return [NSString stringWithFormat: @"%@ Credential=%@/%@, SignedHeaders=%@, Signature=%@",
          algorithm, _awsAccessKeyId, credentialScope, signedHeaders, signature];
}

- (NSString *) _sha256Hash: (NSString *)input
{
  // Simplified hash function - in production, use proper crypto libraries
  return [NSString stringWithFormat: @"%08x", [input hash]];
}

- (NSString *) _hmacSha256: (NSString *)key data: (NSString *)data
{
  // Simplified HMAC - in production, use proper crypto libraries
  return [NSString stringWithFormat: @"%08x", [[key stringByAppendingString: data] hash]];
}

#pragma mark - Core Key-Value Operations

- (id) objectForKey: (NSString *)key
{
  [_cacheLock lock];
  @try
    {
      id value = [_localCache objectForKey: key];
      if (value == nil && _isOnline)
        {
          // Try to fetch from remote asynchronously, return nil for now
          [self _getItem: key completionHandler: ^(id remoteValue, NSError *error) {
            if (remoteValue != nil && error == nil)
              {
                [_cacheLock lock];
                [_localCache setObject: remoteValue forKey: key];
                [_cacheLock unlock];

                // Notify of external change
                [self _notifyExternalChange];
              }
          }];
        }
      return value;
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) setObject: (id)obj forKey: (NSString *)key
{
  if (key == nil)
    {
      [NSException raise: NSInvalidArgumentException format: @"key cannot be nil"];
    }

  [_cacheLock lock];
  @try
    {
      NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];

      if (obj != nil)
        {
          [_localCache setObject: obj forKey: key];
        }
      else
        {
          [_localCache removeObjectForKey: key];
        }

      // Queue for remote sync
      if (_isOnline)
        {
          if (obj != nil)
            {
              [self _putItem: key value: obj timestamp: now];
            }
          else
            {
              [self _deleteItem: key];
            }
        }
      else
        {
          // Queue for later when online
          [self _queueOperation: (obj != nil) ? @"PUT" : @"DELETE" key: key value: obj];
        }
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) removeObjectForKey: (NSString *)key
{
  [self setObject: nil forKey: key];
}

- (NSDictionary *) dictionaryRepresentation
{
  [_cacheLock lock];
  @try
    {
      return [NSDictionary dictionaryWithDictionary: _localCache];
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) synchronize
{
  [self _syncWithRemoteStore];
}

#pragma mark - Network Operations

- (void) _performAsyncRequest: (NSURLRequest *)request
            completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
  NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock: ^{
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest: request
                                         returningResponse: &response
                                                     error: &error];

    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(data, response, error);
    });
  }];

  [_networkQueue addOperation: operation];
}

- (void) _syncWithRemoteStore
{
  if (!_isOnline)
    {
      return;
    }

  // Upload pending changes first
  [self _uploadPendingChanges];

  // Then download remote changes
  [self _downloadRemoteChanges];

  _lastSyncTime = [[NSDate date] timeIntervalSinceReferenceDate];
}

- (void) _uploadPendingChanges
{
  // Process offline queue
  [self _processOfflineQueue];
}

- (void) _downloadRemoteChanges
{
  [self _scanTable: ^(NSDictionary *items, NSError *error) {
    if (error == nil && items != nil)
      {
        [_cacheLock lock];
        @try
          {
            BOOL hasChanges = NO;
            for (NSString *key in items)
              {
                NSDictionary *itemData = [items objectForKey: key];
                id remoteValue = [self _deserializeValue: [itemData objectForKey: @"value"]];
                NSTimeInterval remoteTime = [[itemData objectForKey: @"timestamp"] doubleValue];

                id localValue = [_localCache objectForKey: key];

                if (localValue == nil ||
                    ![localValue isEqual: remoteValue])
                  {
                    // Apply conflict resolution
                    id resolvedValue = [self _resolveConflict: localValue
                                                  remoteValue: remoteValue
                                                    localTime: _lastSyncTime
                                                   remoteTime: remoteTime];

                    if (resolvedValue != nil)
                      {
                        [_localCache setObject: resolvedValue forKey: key];
                        hasChanges = YES;
                      }
                  }
              }

            if (hasChanges)
              {
                [self _notifyExternalChange];
              }
          }
        @finally
          {
            [_cacheLock unlock];
          }
      }
  }];
}

#pragma mark - DynamoDB Operations

- (NSURLRequest *) _createDynamoDBRequest: (NSString *)operation payload: (NSString *)payload
{
  NSString *endpoint = [NSString stringWithFormat: @"https://dynamodb.%@.amazonaws.com/", _awsRegion];
  NSURL *url = [NSURL URLWithString: endpoint];

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
  [request setHTTPMethod: @"POST"];

  NSString *dateString = [[NSDate date] description]; // Simplified - use proper ISO format

  NSMutableDictionary *headers = [NSMutableDictionary dictionary];
  [headers setObject: @"application/x-amz-json-1.0" forKey: @"Content-Type"];
  [headers setObject: [@"DynamoDB_20120810." stringByAppendingString: operation] forKey: @"X-Amz-Target"];
  [headers setObject: dateString forKey: @"X-Amz-Date"];
  [headers setObject: _awsRegion forKey: @"X-Amz-Region"];

  NSString *authorization = [self _createAWSSignature: @"POST"
                                                  url: @"/"
                                              headers: headers
                                              payload: payload
                                                 date: dateString];
  [headers setObject: authorization forKey: @"Authorization"];

  for (NSString *headerKey in headers)
    {
      [request setValue: [headers objectForKey: headerKey] forHTTPHeaderField: headerKey];
    }

  [request setHTTPBody: [payload dataUsingEncoding: NSUTF8StringEncoding]];

  return request;
}

- (void) _putItem: (NSString *)key value: (id)value timestamp: (NSTimeInterval)timestamp
{
  NSString *serializedValue = [self _serializeValue: value];

  NSDictionary *item = @{
    @"userId": @{@"S": _userIdentifier},
    @"itemKey": @{@"S": key},
    @"value": @{@"S": serializedValue},
    @"timestamp": @{@"N": [NSString stringWithFormat: @"%.0f", timestamp]}
  };

  NSDictionary *payload = @{
    @"TableName": _dynamoTableName,
    @"Item": item
  };

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject: payload options: 0 error: &error];

  if (jsonData != nil)
    {
      NSString *payloadString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
      NSURLRequest *request = [self _createDynamoDBRequest: @"PutItem" payload: payloadString];
      [payloadString release];

      [self _performAsyncRequest: request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil)
          {
            NSLog(@"Failed to put item: %@", [error localizedDescription]);
          }
      }];
    }
}

- (void) _getItem: (NSString *)key completionHandler: (void (^)(id value, NSError *error))handler
{
  NSDictionary *keyDict = @{
    @"userId": @{@"S": _userIdentifier},
    @"itemKey": @{@"S": key}
  };

  NSDictionary *payload = @{
    @"TableName": _dynamoTableName,
    @"Key": keyDict
  };

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject: payload options: 0 error: &error];

  if (jsonData != nil)
    {
      NSString *payloadString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
      NSURLRequest *request = [self _createDynamoDBRequest: @"GetItem" payload: payloadString];
      [payloadString release];

      [self _performAsyncRequest: request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *requestError) {
        if (requestError != nil)
          {
            handler(nil, requestError);
            return;
          }

        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &jsonError];

        if (jsonError != nil)
          {
            handler(nil, jsonError);
            return;
          }

        NSDictionary *item = [responseDict objectForKey: @"Item"];
        if (item != nil)
          {
            NSString *serializedValue = [[item objectForKey: @"value"] objectForKey: @"S"];
            id value = [self _deserializeValue: serializedValue];
            handler(value, nil);
          }
        else
          {
            handler(nil, nil);
          }
      }];
    }
}

- (void) _deleteItem: (NSString *)key
{
  NSDictionary *keyDict = @{
    @"userId": @{@"S": _userIdentifier},
    @"itemKey": @{@"S": key}
  };

  NSDictionary *payload = @{
    @"TableName": _dynamoTableName,
    @"Key": keyDict
  };

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject: payload options: 0 error: &error];

  if (jsonData != nil)
    {
      NSString *payloadString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
      NSURLRequest *request = [self _createDynamoDBRequest: @"DeleteItem" payload: payloadString];
      [payloadString release];

      [self _performAsyncRequest: request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil)
          {
            NSLog(@"Failed to delete item: %@", [error localizedDescription]);
          }
      }];
    }
}

- (void) _scanTable: (void (^)(NSDictionary *items, NSError *error))handler
{
  NSDictionary *payload = @{
    @"TableName": _dynamoTableName,
    @"FilterExpression": @"userId = :userId",
    @"ExpressionAttributeValues": @{
      @":userId": @{@"S": _userIdentifier}
    }
  };

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject: payload options: 0 error: &error];

  if (jsonData != nil)
    {
      NSString *payloadString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
      NSURLRequest *request = [self _createDynamoDBRequest: @"Scan" payload: payloadString];
      [payloadString release];

      [self _performAsyncRequest: request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *requestError) {
        if (requestError != nil)
          {
            handler(nil, requestError);
            return;
          }

        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &jsonError];

        if (jsonError != nil)
          {
            handler(nil, jsonError);
            return;
          }

        NSArray *items = [responseDict objectForKey: @"Items"];
        NSMutableDictionary *result = [NSMutableDictionary dictionary];

        for (NSDictionary *item in items)
          {
            NSString *key = [[item objectForKey: @"itemKey"] objectForKey: @"S"];
            NSString *value = [[item objectForKey: @"value"] objectForKey: @"S"];
            NSString *timestamp = [[item objectForKey: @"timestamp"] objectForKey: @"N"];

            [result setObject: @{@"value": value, @"timestamp": timestamp} forKey: key];
          }

        handler(result, nil);
      }];
    }
}

#pragma mark - Offline Support

- (void) _queueOperation: (NSString *)operation key: (NSString *)key value: (id)value
{
  [_cacheLock lock];
  @try
    {
      NSMutableArray *queue = [_pendingOperations objectForKey: operation];
      if (queue == nil)
        {
          queue = [NSMutableArray array];
          [_pendingOperations setObject: queue forKey: operation];
        }

      NSDictionary *operationData = @{
        @"key": key,
        @"value": value ? value : [NSNull null],
        @"timestamp": [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]]
      };

      [queue addObject: operationData];
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) _processOfflineQueue
{
  [_cacheLock lock];
  @try
    {
      for (NSString *operation in [_pendingOperations allKeys])
        {
          NSArray *queue = [_pendingOperations objectForKey: operation];
          for (NSDictionary *operationData in queue)
            {
              NSString *key = [operationData objectForKey: @"key"];
              id value = [operationData objectForKey: @"value"];
              NSTimeInterval timestamp = [[operationData objectForKey: @"timestamp"] doubleValue];

              if ([operation isEqualToString: @"PUT"])
                {
                  if (![value isKindOfClass: [NSNull class]])
                    {
                      [self _putItem: key value: value timestamp: timestamp];
                    }
                }
              else if ([operation isEqualToString: @"DELETE"])
                {
                  [self _deleteItem: key];
                }
            }
        }

      [_pendingOperations removeAllObjects];
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

#pragma mark - Conflict Resolution

- (id) _resolveConflict: (id)localValue
            remoteValue: (id)remoteValue
              localTime: (NSTimeInterval)localTime
             remoteTime: (NSTimeInterval)remoteTime
{
  // Last-writer-wins conflict resolution
  // In a more sophisticated implementation, you might use vector clocks or CRDTs

  if (remoteTime > localTime)
    {
      return remoteValue;
    }
  else
    {
      return localValue;
    }
}

#pragma mark - Utility Methods

- (NSString *) _serializeValue: (id)value
{
  if (value == nil)
    {
      return @"";
    }

  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject: @{@"value": value} options: 0 error: &error];

  if (data != nil)
    {
      return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    }

  // Fallback to description
  return [value description];
}

- (id) _deserializeValue: (NSString *)serializedValue
{
  if (serializedValue == nil || [serializedValue length] == 0)
    {
      return nil;
    }

  NSError *error;
  NSData *data = [serializedValue dataUsingEncoding: NSUTF8StringEncoding];
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];

  if (dict != nil && error == nil)
    {
      return [dict objectForKey: @"value"];
    }

  // Fallback to the string itself
  return serializedValue;
}

- (void) _notifyExternalChange
{
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: NSUbiquitousKeyValueStoreServerChange
                                                       forKey: NSUbiquitousKeyValueStoreChangeReasonKey];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                  object: self
}

@end

@interface GSFirebaseUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
  NSMutableDictionary *_localCache;
  NSMutableDictionary *_pendingOperations;
  NSOperationQueue *_networkQueue;
  NSLock *_cacheLock;
  NSTimer *_syncTimer;
  NSString *_firebaseURL;
  NSString *_authToken;
  NSString *_userIdentifier;
  BOOL _isOnline;
  NSTimeInterval _lastSyncTime;
}

// Configuration
- (void) _loadFirebaseConfiguration;
- (void) _autoConfigureFirebase;
- (NSString *) _userIdentifier;

// Network Operations
- (void) _performFirebaseRequest: (NSString *)method
                            path: (NSString *)path
                         payload: (NSDictionary *)payload
               completionHandler: (void (^)(NSDictionary *response, NSError *error))handler;
- (void) _syncWithFirebase;

// Firebase Operations
- (void) _setValue: (id)value forKey: (NSString *)key;
- (void) _getValueForKey: (NSString *)key completionHandler: (void (^)(id value, NSError *error))handler;
- (void) _deleteKey: (NSString *)key;
- (void) _getAllData: (void (^)(NSDictionary *data, NSError *error))handler;

// Utility Methods
- (NSString *) _sanitizeKey: (NSString *)key;
- (void) _notifyExternalChange;
@end

@implementation GSFirebaseUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _localCache = [[NSMutableDictionary alloc] init];
      _pendingOperations = [[NSMutableDictionary alloc] init];
      _networkQueue = [[NSOperationQueue alloc] init];
      [_networkQueue setMaxConcurrentOperationCount: 2];
      [_networkQueue setName: @"GSFirebaseUbiquitousKeyValueStore.NetworkQueue"];

      _cacheLock = [[NSLock alloc] init];
      _isOnline = YES;
      _lastSyncTime = 0;

      // Load or auto-configure Firebase
      [self _loadFirebaseConfiguration];

      if (_firebaseURL == nil)
        {
          [self _autoConfigureFirebase];
        }

      // Setup periodic sync (every 30 seconds)
      _syncTimer = [[NSTimer scheduledTimerWithTimeInterval: 30.0
                                                     target: self
                                                   selector: @selector(_syncWithFirebase)
                                                   userInfo: nil
                                                    repeats: YES] retain];

      // Initial sync
      [self _syncWithFirebase];
    }
  return self;
}

- (void) dealloc
{
  [_syncTimer invalidate];
  [_syncTimer release];
  [_networkQueue cancelAllOperations];
  [_networkQueue release];
  [_cacheLock release];
  [_localCache release];
  [_pendingOperations release];
  [_firebaseURL release];
  [_authToken release];
  [_userIdentifier release];
  [super dealloc];
}

#pragma mark - Configuration

- (void) _loadFirebaseConfiguration
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  _firebaseURL = [[defaults stringForKey: @"GSFirebaseURL"] retain];
  _authToken = [[defaults stringForKey: @"GSFirebaseAuthToken"] retain];
  _userIdentifier = [[self _userIdentifier] retain];

  if (_firebaseURL != nil)
    {
      NSLog(@"Using configured Firebase URL: %@", _firebaseURL);
    }
}

- (void) _autoConfigureFirebase
{
  // Use a free public Firebase-compatible service (JSONBin.io or similar)
  // This creates a simple REST API endpoint that works like Firebase

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *existingURL = [defaults stringForKey: @"GSAutoFirebaseURL"];

  if (existingURL != nil)
    {
      _firebaseURL = [existingURL retain];
      NSLog(@"Using existing auto-configured endpoint: %@", _firebaseURL);
      return;
    }

  // Auto-configure using JSONBin.io (free tier: 100k requests/month)
  NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
  if (bundleId == nil)
    {
      bundleId = @"GNUstepApp";
    }

  // Create a unique bin name based on bundle ID and user
  NSString *binName = [NSString stringWithFormat: @"gnustep_%@_%@",
                       [bundleId stringByReplacingOccurrencesOfString: @"." withString: @"_"],
                       [self _userIdentifier]];

  // Use JSONBin.io as free backend (no auth required for public bins)
  _firebaseURL = [[NSString stringWithFormat: @"https://api.jsonbin.io/v3/b"] retain];

  // Save auto-configuration
  [defaults setObject: _firebaseURL forKey: @"GSAutoFirebaseURL"];
  [defaults setObject: binName forKey: @"GSAutoFirebaseBinName"];
  [defaults synchronize];

  NSLog(@"Auto-configured free JSONBin.io backend: %@", _firebaseURL);
}

- (NSString *) _userIdentifier
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *userId = [defaults stringForKey: @"GSFirebaseUserIdentifier"];

  if (userId == nil)
    {
      // Generate a unique identifier for this user/device
      userId = [[NSProcessInfo processInfo] globallyUniqueString];
      [defaults setObject: userId forKey: @"GSFirebaseUserIdentifier"];
      [defaults synchronize];
    }

  return userId;
}

#pragma mark - Core Key-Value Operations

- (id) objectForKey: (NSString *)key
{
  [_cacheLock lock];
  @try
    {
      id value = [_localCache objectForKey: key];
      if (value == nil && _isOnline)
        {
          // Try to fetch from remote asynchronously
          [self _getValueForKey: key completionHandler: ^(id remoteValue, NSError *error) {
            if (remoteValue != nil && error == nil)
              {
                [_cacheLock lock];
                [_localCache setObject: remoteValue forKey: key];
                [_cacheLock unlock];

                [self _notifyExternalChange];
              }
          }];
        }
      return value;
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) setObject: (id)obj forKey: (NSString *)key
{
  if (key == nil)
    {
      [NSException raise: NSInvalidArgumentException format: @"key cannot be nil"];
    }

  [_cacheLock lock];
  @try
    {
      if (obj != nil)
        {
          [_localCache setObject: obj forKey: key];
        }
      else
        {
          [_localCache removeObjectForKey: key];
        }

      // Sync to remote
      if (_isOnline)
        {
          [self _setValue: obj forKey: key];
        }
      else
        {
          // Queue for later
          NSMutableDictionary *operation = [NSMutableDictionary dictionary];
          [operation setObject: key forKey: @"key"];
          if (obj != nil)
            {
              [operation setObject: obj forKey: @"value"];
            }

          NSMutableArray *queue = [_pendingOperations objectForKey: @"operations"];
          if (queue == nil)
            {
              queue = [NSMutableArray array];
              [_pendingOperations setObject: queue forKey: @"operations"];
            }
          [queue addObject: operation];
        }
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) removeObjectForKey: (NSString *)key
{
  [self setObject: nil forKey: key];
}

- (NSDictionary *) dictionaryRepresentation
{
  [_cacheLock lock];
  @try
    {
      return [NSDictionary dictionaryWithDictionary: _localCache];
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

- (void) synchronize
{
  [self _syncWithFirebase];
}

#pragma mark - Network Operations

- (void) _performFirebaseRequest: (NSString *)method
                            path: (NSString *)path
                         payload: (NSDictionary *)payload
               completionHandler: (void (^)(NSDictionary *response, NSError *error))handler
{
  NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock: ^{

    NSString *fullURL = [_firebaseURL stringByAppendingString: path];
    NSURL *url = [NSURL URLWithString: fullURL];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
    [request setHTTPMethod: method];
    [request setValue: @"application/json" forHTTPHeaderField: @"Content-Type"];
    [request setValue: @"GNUstep-UbiquitousKeyValueStore/1.0" forHTTPHeaderField: @"User-Agent"];

    // Add JSONBin.io specific headers if using auto-configuration
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *autoURL = [defaults stringForKey: @"GSAutoFirebaseURL"];
    if (autoURL != nil && [_firebaseURL isEqualToString: autoURL])
      {
        [request setValue: @"application/json" forHTTPHeaderField: @"X-Master-Key"];
        [request setValue: @"true" forHTTPHeaderField: @"X-Bin-Private"];
      }

    if (payload != nil)
      {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject: payload options: 0 error: &jsonError];
        if (jsonData != nil)
          {
            [request setHTTPBody: jsonData];
          }
      }

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest: request
                                         returningResponse: &response
                                                     error: &error];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (error != nil)
        {
          handler(nil, error);
          return;
        }

      if (data != nil)
        {
          NSError *parseError;
          id jsonResponse = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &parseError];

          if (parseError == nil && [jsonResponse isKindOfClass: [NSDictionary class]])
            {
              handler((NSDictionary *)jsonResponse, nil);
            }
          else
            {
              // Try to parse as simple value
              NSString *stringResponse = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
              NSDictionary *result = [NSDictionary dictionaryWithObject: stringResponse forKey: @"value"];
              [stringResponse release];
              handler(result, nil);
            }
        }
      else
        {
          handler([NSDictionary dictionary], nil);
        }
    });
  }];

  [_networkQueue addOperation: operation];
}

- (void) _syncWithFirebase
{
  if (!_isOnline)
    {
      return;
    }

  // Get all remote data and merge
  [self _getAllData: ^(NSDictionary *remoteData, NSError *error) {
    if (error == nil && remoteData != nil)
      {
        [_cacheLock lock];
        @try
          {
            BOOL hasChanges = NO;

            // Merge remote changes into local cache
            for (NSString *key in remoteData)
              {
                id remoteValue = [remoteData objectForKey: key];
                id localValue = [_localCache objectForKey: key];

                if (![localValue isEqual: remoteValue])
                  {
                    [_localCache setObject: remoteValue forKey: key];
                    hasChanges = YES;
                  }
              }

            if (hasChanges)
              {
                [self _notifyExternalChange];
              }

            _lastSyncTime = [[NSDate date] timeIntervalSinceReferenceDate];
          }
        @finally
          {
            [_cacheLock unlock];
          }
      }
  }];

  // Process any pending operations
  [self _processPendingOperations];
}

#pragma mark - Firebase Operations

- (void) _setValue: (id)value forKey: (NSString *)key
{
  NSString *sanitizedKey = [self _sanitizeKey: key];
  NSDictionary *payload = nil;

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *binName = [defaults stringForKey: @"GSAutoFirebaseBinName"];

  if (binName != nil)
    {
      // JSONBin.io format - update entire document
      NSMutableDictionary *allData = [[_localCache mutableCopy] autorelease];
      if (value != nil)
        {
          [allData setObject: value forKey: key];
        }
      else
        {
          [allData removeObjectForKey: key];
        }
      payload = allData;
    }
  else
    {
      // Standard Firebase format
      payload = value ? [NSDictionary dictionaryWithObject: value forKey: @"value"] : nil;
    }

  NSString *path = binName ? [NSString stringWithFormat: @"/%@", binName] :
                             [NSString stringWithFormat: @"/users/%@/%@.json", _userIdentifier, sanitizedKey];

  [self _performFirebaseRequest: @"PUT"
                           path: path
                        payload: payload
              completionHandler: ^(NSDictionary *response, NSError *error) {
    if (error != nil)
      {
        NSLog(@"Failed to set value for key %@: %@", key, [error localizedDescription]);
      }
  }];
}

- (void) _getValueForKey: (NSString *)key completionHandler: (void (^)(id value, NSError *error))handler
{
  NSString *sanitizedKey = [self _sanitizeKey: key];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *binName = [defaults stringForKey: @"GSAutoFirebaseBinName"];

  NSString *path = binName ? [NSString stringWithFormat: @"/%@/latest", binName] :
                             [NSString stringWithFormat: @"/users/%@/%@.json", _userIdentifier, sanitizedKey];

  [self _performFirebaseRequest: @"GET"
                           path: path
                        payload: nil
              completionHandler: ^(NSDictionary *response, NSError *error) {
    if (error != nil)
      {
        handler(nil, error);
        return;
      }

    if (binName != nil)
      {
        // JSONBin.io format - extract specific key
        NSDictionary *record = [response objectForKey: @"record"];
        id value = record ? [record objectForKey: key] : nil;
        handler(value, nil);
      }
    else
      {
        // Standard Firebase format
        id value = [response objectForKey: @"value"];
        handler(value, nil);
      }
  }];
}

- (void) _deleteKey: (NSString *)key
{
  [self _setValue: nil forKey: key];
}

- (void) _getAllData: (void (^)(NSDictionary *data, NSError *error))handler
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *binName = [defaults stringForKey: @"GSAutoFirebaseBinName"];

  NSString *path = binName ? [NSString stringWithFormat: @"/%@/latest", binName] :
                             [NSString stringWithFormat: @"/users/%@.json", _userIdentifier];

  [self _performFirebaseRequest: @"GET"
                           path: path
                        payload: nil
              completionHandler: ^(NSDictionary *response, NSError *error) {
    if (error != nil)
      {
        handler(nil, error);
        return;
      }

    NSDictionary *data = nil;

    if (binName != nil)
      {
        // JSONBin.io format
        data = [response objectForKey: @"record"];
      }
    else
      {
        // Standard Firebase format
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (NSString *key in response)
          {
            NSDictionary *valueDict = [response objectForKey: key];
            if ([valueDict isKindOfClass: [NSDictionary class]])
              {
                id value = [valueDict objectForKey: @"value"];
                if (value != nil)
                  {
                    [result setObject: value forKey: key];
                  }
              }
          }
        data = result;
      }

    handler(data ? data : [NSDictionary dictionary], nil);
  }];
}

- (void) _processPendingOperations
{
  [_cacheLock lock];
  @try
    {
      NSArray *operations = [_pendingOperations objectForKey: @"operations"];
      if (operations != nil && [operations count] > 0)
        {
          for (NSDictionary *operation in operations)
            {
              NSString *key = [operation objectForKey: @"key"];
              id value = [operation objectForKey: @"value"];
              [self _setValue: value forKey: key];
            }

          [_pendingOperations removeObjectForKey: @"operations"];
        }
    }
  @finally
    {
      [_cacheLock unlock];
    }
}

#pragma mark - Utility Methods

- (NSString *) _sanitizeKey: (NSString *)key
{
  // Firebase keys can't contain certain characters
  NSString *sanitized = [key stringByReplacingOccurrencesOfString: @"." withString: @"_"];
  sanitized = [sanitized stringByReplacingOccurrencesOfString: @"/" withString: @"_"];
  sanitized = [sanitized stringByReplacingOccurrencesOfString: @"[" withString: @"_"];
  sanitized = [sanitized stringByReplacingOccurrencesOfString: @"]" withString: @"_"];
  return sanitized;
}

- (void) _notifyExternalChange
{
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: NSUbiquitousKeyValueStoreServerChange
                                                       forKey: NSUbiquitousKeyValueStoreChangeReasonKey];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                  object: self
                userInfo: userInfo];
}

@end
