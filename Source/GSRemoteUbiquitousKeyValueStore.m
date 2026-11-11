/** Shared remote key-value store synchronization
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
#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSPropertyList.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

#import "GSRemoteUbiquitousKeyValueStore.h"

#if defined(HAVE_GNUTLS)

NSData *
GSRemoteUTF8(NSString *string)
{
  return [string dataUsingEncoding: NSUTF8StringEncoding];
}

NSString *
GSRemotePath(NSString *key)
{
  NSData *data = GSRemoteUTF8(key);
  const unsigned char *bytes = [data bytes];
  NSMutableString *path = [NSMutableString stringWithString: @"/"];
  NSUInteger i;

  for (i = 0; i < [data length]; i++)
    {
      unsigned char c = bytes[i];
      if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9') || c == '-' || c == '_'
        || c == '.' || c == '~' || c == '/')
        {
          [path appendFormat: @"%c", c];
        }
      else
        {
          [path appendFormat: @"%%%02X", c];
        }
    }
  return path;
}

/* Bound nesting also rejects cyclic containers before serialization. */
static BOOL
GSRemoteValidValue(id value, NSUInteger depth)
{
  NSEnumerator *enumerator;
  id item;

  if (depth > 128)
    {
      return NO;
    }
  if ([value isKindOfClass: [NSDictionary class]])
    {
      enumerator = [value keyEnumerator];
      while ((item = [enumerator nextObject]) != nil)
        {
          if (![item isKindOfClass: [NSString class]]
            || !GSRemoteValidValue([value objectForKey: item], depth + 1))
            {
              return NO;
            }
        }
      return YES;
    }
  if ([value isKindOfClass: [NSArray class]])
    {
      enumerator = [value objectEnumerator];
      while ((item = [enumerator nextObject]) != nil)
        {
          if (!GSRemoteValidValue(item, depth + 1))
            {
              return NO;
            }
        }
      return YES;
    }
  return [value isKindOfClass: [NSString class]]
    || [value isKindOfClass: [NSData class]]
    || [value isKindOfClass: [NSNumber class]]
    || [value isKindOfClass: [NSDate class]];
}

static id
GSRemoteImmutableCopy(id value)
{
  NSData *data;

  if (!GSRemoteValidValue(value, 0))
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Remote key-value store requires property-list values"];
    }
  data = [NSPropertyListSerialization dataWithPropertyList: value
    format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL];

  if (data == nil)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Remote key-value store requires property-list values"];
    }
  return [NSPropertyListSerialization propertyListWithData: data
    options: NSPropertyListImmutable format: NULL error: NULL];
}

NSDictionary *
GSRemoteDictionary(NSData *data)
{
  id value;

  if (data == nil || [data length] > 1048576)
    {
      [NSException raise: NSGenericException
        format: @"Remote key-value store object is missing or exceeds 1 MiB"];
    }
  value = [NSPropertyListSerialization propertyListWithData: data
    options: NSPropertyListImmutable format: NULL error: NULL];
  if (![value isKindOfClass: [NSDictionary class]] || !GSRemoteValidValue(value, 0))
    {
      [NSException raise: NSGenericException
        format: @"Remote key-value store object is not a property-list dictionary"];
    }
  return value;
}

#endif

@implementation GSRemoteUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if (self != nil)
    {
#if defined(HAVE_GNUTLS)
      _values = [[NSMutableDictionary alloc] init];
      _pending = [[NSMutableDictionary alloc] init];
      _removed = [[NSMutableSet alloc] init];
      _lock = [[NSRecursiveLock alloc] init];
#else
      RELEASE(self);
      [NSException raise: NSInternalInconsistencyException
                  format: @"Remote key-value stores require a GnuTLS build"];
      return nil;
#endif
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_values);
  RELEASE(_pending);
  RELEASE(_removed);
  RELEASE(_lock);
  DEALLOC
}

- (NSDictionary *) remoteDictionaryWithVersion: (NSString **)version
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) writeRemoteData: (NSData *)data version: (NSString *)version
{
  [self subclassResponsibility: _cmd];
  return NO;
}

#if defined(HAVE_GNUTLS)

- (id) objectForKey: (NSString *)key
{
  id result;

  [_lock lock];
  @try
    {
      result = AUTORELEASE(RETAIN([_values objectForKey: key]));
    }
  @finally
    {
      [_lock unlock];
    }
  return result;
}

- (void) setObject: (id)object forKey: (NSString *)key
{
  if (![key isKindOfClass: [NSString class]] || object == nil)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Remote key-value store requires a string key and a value"];
    }
  object = GSRemoteImmutableCopy(object);
  [_lock lock];
  @try
    {
      [_values setObject: object forKey: key];
      [_pending setObject: object forKey: key];
      [_removed removeObject: key];
      _revision++;
    }
  @finally
    {
      [_lock unlock];
    }
}

- (void) removeObjectForKey: (NSString *)key
{
  if (![key isKindOfClass: [NSString class]])
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Remote key-value store requires a string key"];
    }
  [_lock lock];
  @try
    {
      [_values removeObjectForKey: key];
      [_pending removeObjectForKey: key];
      [_removed addObject: key];
      _revision++;
    }
  @finally
    {
      [_lock unlock];
    }
}

- (NSDictionary *) dictionaryRepresentation
{
  NSDictionary *result;

  [_lock lock];
  @try
    {
      result = AUTORELEASE([_values copy]);
    }
  @finally
    {
      [_lock unlock];
    }
  return result;
}

- (void) synchronize
{
  BOOL notify = NO;
  BOOL initial;
  NSUInteger attempt;

  [_lock lock];
  if (_synchronizing)
    {
      [_lock unlock];
      return;
    }
  _synchronizing = YES;
  initial = !_loaded;
  @try
    {
      for (attempt = 0; attempt < 3; attempt++)
        {
          NSUInteger revision = _revision;
          NSString *version = nil;
          NSDictionary *remote = [self remoteDictionaryWithVersion: &version];
          NSMutableDictionary *merged;
          NSData *data;

          if (remote == nil)
            {
              continue;
            }
          merged = [NSMutableDictionary dictionaryWithDictionary: remote];
          [merged addEntriesFromDictionary: _pending];
          [merged removeObjectsForKeys: [_removed allObjects]];
          if ([_pending count] > 0 || [_removed count] > 0)
            {
              data = [NSPropertyListSerialization dataWithPropertyList: merged
                format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL];
              if (data == nil || [data length] > 1048576)
                {
                  [NSException raise: NSGenericException
                    format: @"Remote key-value store exceeds the 1 MiB serialized limit"];
                }
              if (![self writeRemoteData: data version: version])
                {
                  continue;
                }
            }
          if (revision == _revision)
            {
              [_pending removeAllObjects];
              [_removed removeAllObjects];
            }
          else
            {
              /* Run-loop callbacks may edit the store during a transfer.
               * Keep those edits pending for the next synchronization. */
              [merged addEntriesFromDictionary: _pending];
              [merged removeObjectsForKeys: [_removed allObjects]];
            }
          notify = ![_values isEqual: merged];
          [_values setDictionary: merged];
          _loaded = YES;
          break;
        }
      if (attempt == 3)
        {
          [NSException raise: NSGenericException
            format: @"Remote key-value store synchronization conflicted three times"];
        }
    }
  @finally
    {
      _synchronizing = NO;
      [_lock unlock];
    }
  if (notify)
    {
      [[NSNotificationCenter defaultCenter]
        postNotificationName: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
        object: self userInfo: [NSDictionary dictionaryWithObject:
          [NSNumber numberWithInt: initial ? 1 : 0]
          forKey: NSUbiquitousKeyValueStoreChangeReasonKey]];
    }
}

#endif

@end
