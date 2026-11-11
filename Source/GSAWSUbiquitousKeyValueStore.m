/** AWS ubiquitous key-value store backend
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
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLRequest.h"
#import "Foundation/NSURLProtocol.h"
#import "Foundation/NSURLResponse.h"
#import "Foundation/NSUserDefaults.h"

#import "GNUstepBase/GSTLS.h"
#import "GSRemoteUbiquitousKeyValueStore.h"
#import "GSKeyValueStoreTransfer.h"

#if defined(HAVE_GNUTLS)
#include <gnutls/crypto.h>

static NSString *
GSAWSHex(NSData *data)
{
  const unsigned char *bytes = [data bytes];
  NSMutableString *result = [NSMutableString string];
  NSUInteger i;

  for (i = 0; i < [data length]; i++)
    {
      [result appendFormat: @"%02x", bytes[i]];
    }
  return result;
}

static NSData *
GSAWSDigest(NSData *key, NSData *data)
{
  unsigned char digest[32];
  int status;

  if (key == nil)
    {
      status = gnutls_hash_fast(GNUTLS_DIG_SHA256, [data bytes],
        [data length], digest);
    }
  else
    {
      status = gnutls_hmac_fast(GNUTLS_MAC_SHA256, [key bytes],
        [key length], [data bytes], [data length], digest);
    }
  if (status < 0)
    {
      [NSException raise: NSGenericException
                  format: @"AWS key-value store signing failed"];
    }
  return [NSData dataWithBytes: digest length: sizeof(digest)];
}

#endif

@interface GSAWSUbiquitousKeyValueStore : GSRemoteUbiquitousKeyValueStore
{
  NSString *_region;
  NSString *_host;
  NSString *_path;
}

@end

@implementation GSAWSUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if (self != nil)
    {
#if defined(HAVE_GNUTLS)
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSString *bucket = [defaults stringForKey: @"GSAWSKeyValueStoreBucket"];
      NSString *region = [defaults stringForKey: @"GSAWSKeyValueStoreRegion"];
      NSString *key = [defaults stringForKey: @"GSAWSKeyValueStoreKey"];
      NSString *endpoint = [defaults stringForKey: @"GSAWSKeyValueStoreEndpoint"];
      NSURL *url = endpoint ? [NSURL URLWithString: endpoint] : nil;
      NSCharacterSet *allowed = [NSCharacterSet
        characterSetWithCharactersInString: @"abcdefghijklmnopqrstuvwxyz0123456789-"];

      /* Restrict the DNS components, and use buckets without dots so wildcard
       * TLS certificates match the virtual-hosted endpoint. */
      if ([bucket length] < 3 || [bucket length] > 63 || [region length] == 0
        || [key length] == 0
        || [bucket rangeOfCharacterFromSet: [allowed invertedSet]].length != 0
        || [region rangeOfCharacterFromSet: [allowed invertedSet]].length != 0
        || [bucket hasPrefix: @"-"] || [bucket hasSuffix: @"-"])
        {
          RELEASE(self);
          [NSException raise: NSInvalidArgumentException
            format: @"AWS key-value store requires a DNS bucket without dots, "
                    @"a region, and an object key in GSAWSKeyValueStore defaults"];
          return nil;
        }
      if (endpoint != nil && (![[url scheme] isEqual: @"https"]
        || [[url host] length] == 0 || [url user] != nil || [url password] != nil
        || [url port] != nil || [url query] != nil || [url fragment] != nil
        || ([[url path] length] > 0 && ![[url path] isEqual: @"/"])))
        {
          RELEASE(self);
          [NSException raise: NSInvalidArgumentException
            format: @"GSAWSKeyValueStoreEndpoint must be an HTTPS origin without a port"];
          return nil;
        }
      _region = [region copy];
      if (endpoint != nil)
        {
          _host = [[url host] copy];
          _path = [[NSString alloc] initWithFormat: @"/%@%@", bucket, GSRemotePath(key)];
        }
      else
        {
          _host = [[NSString alloc] initWithFormat: @"%@.s3.%@.%@", bucket,
            region, [region hasPrefix: @"cn-"] ? @"amazonaws.com.cn" : @"amazonaws.com"];
          _path = [GSRemotePath(key) copy];
        }
#else
      RELEASE(self);
      [NSException raise: NSInternalInconsistencyException
                  format: @"AWS key-value store requires a GnuTLS build"];
      return nil;
#endif
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_region);
  RELEASE(_host);
  RELEASE(_path);
  DEALLOC
}

#if defined(HAVE_GNUTLS)

/* Separate transport and clock methods permit deterministic offline tests. */
- (NSString *) awsTimestamp
{
  return [[NSDate date] descriptionWithCalendarFormat: @"%Y%m%dT%H%M%SZ"
    timeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0] locale: nil];
}

- (NSData *) sendAWSRequest: (NSURLRequest *)request
                  response: (NSHTTPURLResponse **)response
{
  GSKeyValueStoreTransfer *transfer;
  NSData *result;

  transfer = [[GSKeyValueStoreTransfer alloc] init];
  @try
    {
      result = [transfer sendRequest: request response: response];
    }
  @finally
    {
      RELEASE(transfer);
    }
  return result;
}

- (NSMutableURLRequest *) requestWithMethod: (NSString *)method
                                      data: (NSData *)data
                                      etag: (NSString *)etag
{
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  NSString *access = [environment objectForKey: @"AWS_ACCESS_KEY_ID"];
  NSString *secret = [environment objectForKey: @"AWS_SECRET_ACCESS_KEY"];
  NSString *token = [environment objectForKey: @"AWS_SESSION_TOKEN"];
  NSString *stamp = [self awsTimestamp];
  NSString *day = [stamp substringToIndex: 8];
  NSString *scope = [NSString stringWithFormat: @"%@/%@/s3/aws4_request", day, _region];
  NSString *hash = GSAWSHex(GSAWSDigest(nil, data ? data : [NSData data]));
  NSMutableDictionary *headers = [NSMutableDictionary dictionary];
  NSMutableString *canonicalHeaders = [NSMutableString string];
  NSArray *names;
  NSString *signedHeaders;
  NSString *canonical;
  NSString *toSign;
  NSData *signingKey;
  NSMutableURLRequest *request;
  NSUInteger i;

  if ([access length] == 0 || [secret length] == 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are required"];
    }
  [headers setObject: _host forKey: @"host"];
  [headers setObject: hash forKey: @"x-amz-content-sha256"];
  [headers setObject: stamp forKey: @"x-amz-date"];
  if ([token length] > 0)
    {
      [headers setObject: token forKey: @"x-amz-security-token"];
    }
  if ([method isEqual: @"PUT"])
    {
      [headers setObject: etag ? etag : @"*"
                 forKey: etag ? @"if-match" : @"if-none-match"];
      [headers setObject: @"application/xml" forKey: @"content-type"];
    }
  names = [[headers allKeys] sortedArrayUsingSelector: @selector(compare:)];
  signedHeaders = [names componentsJoinedByString: @";"];
  for (i = 0; i < [names count]; i++)
    {
      NSString *name = [names objectAtIndex: i];
      [canonicalHeaders appendFormat: @"%@:%@\n", name, [headers objectForKey: name]];
    }
  canonical = [NSString stringWithFormat: @"%@\n%@\n\n%@\n%@\n%@",
    method, _path, canonicalHeaders, signedHeaders, hash];
  toSign = [NSString stringWithFormat: @"AWS4-HMAC-SHA256\n%@\n%@\n%@",
    stamp, scope, GSAWSHex(GSAWSDigest(nil, GSRemoteUTF8(canonical)))];
  signingKey = GSAWSDigest(GSRemoteUTF8([@"AWS4" stringByAppendingString: secret]), GSRemoteUTF8(day));
  signingKey = GSAWSDigest(signingKey, GSRemoteUTF8(_region));
  signingKey = GSAWSDigest(signingKey, GSRemoteUTF8(@"s3"));
  signingKey = GSAWSDigest(signingKey, GSRemoteUTF8(@"aws4_request"));
  [headers setObject: [NSString stringWithFormat:
    @"AWS4-HMAC-SHA256 Credential=%@/%@, SignedHeaders=%@, Signature=%@",
    access, scope, signedHeaders, GSAWSHex(GSAWSDigest(signingKey, GSRemoteUTF8(toSign)))]
    forKey: @"Authorization"];
  request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:
    [NSString stringWithFormat: @"https://%@%@", _host, _path]]
    cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 30.0];
  [NSURLProtocol setProperty: @"YES" forKey: GSTLSVerify inRequest: request];
  [NSURLProtocol setProperty: _host forKey: GSTLSRemoteHosts inRequest: request];
  [NSURLProtocol setProperty: _host forKey: GSTLSServerName inRequest: request];
  [request setHTTPShouldHandleCookies: NO];
  [request setHTTPMethod: method];
  [request setAllHTTPHeaderFields: headers];
  if (data != nil)
    {
      [request setHTTPBody: data];
    }
  return request;
}

- (NSDictionary *) remoteDictionaryWithVersion: (NSString **)version
{
  NSHTTPURLResponse *response = nil;
  NSData *data = [self sendAWSRequest:
    [self requestWithMethod: @"GET" data: nil etag: nil] response: &response];
  NSInteger status = [response statusCode];
  NSEnumerator *enumerator;
  NSString *key;

  if (status == 404)
    {
      *version = nil;
      return [NSDictionary dictionary];
    }
  if (status != 200)
    {
      [NSException raise: NSGenericException
        format: @"AWS key-value store GET failed (HTTP %ld)", (long)status];
    }
  enumerator = [[response allHeaderFields] keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      if ([key caseInsensitiveCompare: @"ETag"] == NSOrderedSame)
        {
          *version = [[response allHeaderFields] objectForKey: key];
        }
    }
  if ([*version length] == 0)
    {
      [NSException raise: NSGenericException
        format: @"AWS key-value store response is missing its ETag"];
    }
  return GSRemoteDictionary(data);
}

- (BOOL) writeRemoteData: (NSData *)data version: (NSString *)version
{
  NSHTTPURLResponse *response = nil;
  NSInteger status;

  [self sendAWSRequest: [self requestWithMethod: @"PUT" data: data etag: version]
              response: &response];
  status = [response statusCode];
  if (status == 409 || status == 412)
    {
      return NO;
    }
  if (status != 200)
    {
      [NSException raise: NSGenericException
        format: @"AWS key-value store PUT failed (HTTP %ld)", (long)status];
    }
  return YES;
}

#endif

@end
