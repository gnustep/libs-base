/** Simple ubiquitous key-value store backend
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
#import "Foundation/NSUbiquitousKeyValueStore.h"
#import "Foundation/NSDictionary.h"

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

// Returns the object associated with the specified key.
- (id) objectForKey: (NSString *)key
{
  return [_dict objectForKey: key];
}

// Sets an object for the specified key in the key-value store.
- (void) setObject: (id) obj forKey: (NSString *)key
{
  [_dict setObject: obj forKey: key];
}

// Explicitly Synchronizing In-Memory Key-Value Data to Disk
// Explicitly synchronizes in-memory keys and values with those stored on disk.
- (void) synchronize
{
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
