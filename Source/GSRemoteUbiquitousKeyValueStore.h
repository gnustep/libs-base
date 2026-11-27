/** Private shared remote key-value store interface
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
#ifndef GS_REMOTE_UBIQUITOUS_KEY_VALUE_STORE_H
#define GS_REMOTE_UBIQUITOUS_KEY_VALUE_STORE_H

#import "Foundation/NSUbiquitousKeyValueStore.h"

@class NSMutableDictionary, NSMutableSet, NSRecursiveLock;

@interface GSRemoteUbiquitousKeyValueStore : NSUbiquitousKeyValueStore
{
  NSMutableDictionary *_values;
  NSMutableDictionary *_pending;
  NSMutableSet *_removed;
  NSRecursiveLock *_lock;
  BOOL _loaded;
  BOOL _synchronizing;
  NSUInteger _revision;
}

/* A nil dictionary or NO write result means the remote version changed. */
- (NSDictionary *) remoteDictionaryWithVersion: (NSString **)version;
- (BOOL) writeRemoteData: (NSData *)data version: (NSString *)version;

@end

#if defined(HAVE_GNUTLS)

/* Shared encoding and property-list validation for remote backends. */
extern NSData *GSRemoteUTF8(NSString *string);
extern NSString *GSRemotePath(NSString *key);
extern NSDictionary *GSRemoteDictionary(NSData *data);

#endif

#endif
