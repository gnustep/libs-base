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
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#import "common.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyedArchiver.h"
#import <Foundation/NSUbiquitousKeyValueStore.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSUserDefaults.h>

static NSUbiquitousKeyValueStore *_sharedUbiquitousKeyValueStore = nil;

@implementation NSUbiquitousKeyValueStore : NSObject

// Getting the Shared Instance
- (id) init
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSUbiquitousKeyValueStore *) defaultStore
{
  if(_sharedUbiquitousKeyValueStore == nil)
    {
      NSString *storeClassName = [[NSUserDefaults standardUserDefaults]
				   stringForKey: @"GSUbiquitousKeyValueStoreClass"];
      Class klass = NSClassFromString(storeClassName);
      _sharedUbiquitousKeyValueStore = [[klass alloc] init];
      if(_sharedUbiquitousKeyValueStore == nil)
	{
	  NSLog(@"Cannot instantiate class named %@ for shared key store",storeClassName);
	}
    }
  return _sharedUbiquitousKeyValueStore;
}
  
// Getting Values
// Returns the array associated with the specified key.
- (NSArray *) arrayForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}
  
// Returns the Boolean value associated with the specified key.
- (BOOL) boolForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return NO;
}

// Returns the data object associated with the specified key.
- (NSData*) dataForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Returns the dictionary object associated with the specified key.
- (NSDictionary *) dictionaryForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Returns the double value associated with the specified key.
- (double) doubleForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return 0.0;
}

// Returns the long long value associated with the specified key.
- (long long) longLongForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return 0.0;
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
  [self subclassResponsibility: _cmd];
  return nil;
}

// Setting Values
// Sets an array object for the specified key in the key-value store.
- (void) setArray: (NSArray *)array forKey: (NSString *)key
{
}

// Sets a Boolean value for the specified key in the key-value store.
- (void) setBool: (BOOL)flag forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a data object for the specified key in the key-value store.
- (void) setData: (NSData *)data forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a dictionary object for the specified key in the key-value store.
- (void) setDictionary: (NSDictionary *)dict forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a double value for the specified key in the key-value store.
- (void) setDouble: (double)val forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a long long value for the specified key in the key-value store.
- (void) setLongLong: (long long)val forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets an object for the specified key in the key-value store.
- (void) setObject: (id) obj forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
}

// Sets a string object for the specified key in the key-value store.
- (void) setString: (NSString *)string forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
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

// Notifications & constants
GS_EXPORT NSString* const NSUbiquitousKeyValueStoreDidChangeExternallyNotification;
GS_EXPORT NSString* const NSUbiquitousKeyValueStoreChangeReasonKey;

@end

@interface GSSimpleUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
  NSMutableDictionary *_dict;
}
@end

@implementation GSSimpleUbiquitousKeyValueStore 

- (id) init
{
  self = [super init];
  if(self != nil)
    {
      _dict = [[NSMutableDictionary alloc] initWithCapacity: 10];
    }
  return self;
}

// Getting Values
// Returns the array associated with the specified key.
- (NSArray *) arrayForKey: (NSString *)key
{
  return (NSArray *)[_dict objectForKey: key];
}
  
// Returns the Boolean value associated with the specified key.
- (BOOL) boolForKey: (NSString *)key
{
  return (BOOL)([[_dict objectForKey: key] boolValue] == 1);
}

// Returns the data object associated with the specified key.
- (NSData*) dataForKey: (NSString *)key
{
  return (NSData *)[_dict objectForKey: key];
}

// Returns the dictionary object associated with the specified key.
- (NSDictionary *) dictionaryForKey: (NSString *)key
{
  return (NSDictionary *)[_dict objectForKey: key];
}

// Returns the double value associated with the specified key.
- (double) doubleForKey: (NSString *)key
{
  return (double)[[_dict objectForKey: key] doubleValue];
}

// Returns the long long value associated with the specified key.
- (long long) longLongForKey: (NSString *)key
{
  return (long long)[[_dict objectForKey: key] longValue];
}

// Returns the object associated with the specified key.
- (id) objectForKey: (NSString *)key
{
  return [_dict objectForKey: key];
}

//  Returns the string associated with the specified key.
- (NSString *) stringForKey: (NSString *)key
{
  return (NSString *)[_dict objectForKey: key];
}

// Setting Values
// Sets an array object for the specified key in the key-value store.
- (void) setArray: (NSArray *)array forKey: (NSString *)key
{
  [_dict setObject: array forKey: key];
}

// Sets a Boolean value for the specified key in the key-value store.
- (void) setBool: (BOOL)flag forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithBool: flag];
  [_dict setObject: num forKey: key];
}

// Sets a data object for the specified key in the key-value store.
- (void) setData: (NSData *)data forKey: (NSString *)key
{
  [_dict setObject: data forKey: key];
}

// Sets a dictionary object for the specified key in the key-value store.
- (void) setDictionary: (NSDictionary *)dict forKey: (NSString *)key
{
  [_dict setObject: dict forKey: key];
}

// Sets a double value for the specified key in the key-value store.
- (void) setDouble: (double)val forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithDouble: val];
  [_dict setObject: num forKey: key];
}

// Sets a long long value for the specified key in the key-value store.
- (void) setLongLong: (long long)val forKey: (NSString *)key
{
  NSNumber *num = [NSNumber numberWithLong: val];
  [_dict setObject: num forKey: key];
}

// Sets an object for the specified key in the key-value store.
- (void) setObject: (id) obj forKey: (NSString *)key
{
  [_dict setObject: obj forKey: key];
}

// Sets a string object for the specified key in the key-value store.
- (void) setString: (NSString *)string forKey: (NSString *)key
{
  [_dict setObject: string forKey: key];
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
  [_dict removeObjectForKey: key];
}

// Retrieving the Current Keys and Values
// A dictionary containing all of the key-value pairs in the key-value store.
- (NSDictionary *) dictionaryRepresentation
{
  return _dict;
}

@end

@interface GSAWSUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
}
@end

@implementation GSAWSUbiquitousKeyValueStore
@end
