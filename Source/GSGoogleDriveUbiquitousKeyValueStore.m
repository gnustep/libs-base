/** Google Drive ubiquitous key-value store backend
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
#import "Foundation/NSException.h"
#import "Foundation/NSJSONSerialization.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSString.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLRequest.h"
#import "Foundation/NSURLProtocol.h"
#import "Foundation/NSURLResponse.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSUUID.h"
#import "Foundation/NSValue.h"

#import "GNUstepBase/GSTLS.h"
#import "GSRemoteUbiquitousKeyValueStore.h"
#import "GSKeyValueStoreTransfer.h"

/* Drive uses v2's explicit file ETag for conditional content updates. */
@interface GSGoogleDriveUbiquitousKeyValueStore : GSRemoteUbiquitousKeyValueStore
{
  NSString *_name;
  NSString *_fileID;
  NSString *_createID;
  BOOL _fixedID;
  NSString *_accessToken;
  NSDate *_tokenExpiry;
  NSDictionary *_credentials;
}

@end

#if defined(HAVE_GNUTLS)

static NSString *
GSDriveEncode(NSString *string)
{
  /* The shared encoder handles UTF-8; query/form values must also escape /. */
  return [[GSRemotePath(string) substringFromIndex: 1]
    stringByReplacingOccurrencesOfString: @"/" withString: @"%2F"];
}

static NSDictionary *
GSDriveJSON(NSData *data)
{
  id value = data ? [NSJSONSerialization JSONObjectWithData: data
    options: 0 error: NULL] : nil;

  if (![value isKindOfClass: [NSDictionary class]])
    {
      [NSException raise: NSGenericException
        format: @"Google Drive returned an invalid JSON object"];
    }
  return value;
}

static BOOL
GSDriveString(id value)
{
  return [value isKindOfClass: [NSString class]] && [value length] > 0;
}

static NSString *
GSDriveIdentifier(id value)
{
  NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
    @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];

  if (!GSDriveString(value)
    || [value rangeOfCharacterFromSet: [allowed invertedSet]].length != 0)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive returned an invalid file identifier"];
    }
  return value;
}

static NSMutableURLRequest *
GSDriveRequest(NSString *url, NSString *method, NSData *data, NSString *type)
{
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
    [NSURL URLWithString: url] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
    timeoutInterval: 30.0];
  NSString *host = [[request URL] host];

  /* Only these two fixed API origins may receive credentials. */
  if (![[[request URL] scheme] isEqual: @"https"]
    || !([host isEqual: @"www.googleapis.com"] || [host isEqual: @"oauth2.googleapis.com"]))
    {
      [NSException raise: NSInvalidArgumentException
        format: @"Invalid Google Drive API origin"];
    }
  [NSURLProtocol setProperty: @"YES" forKey: GSTLSVerify inRequest: request];
  [NSURLProtocol setProperty: host forKey: GSTLSRemoteHosts inRequest: request];
  [NSURLProtocol setProperty: host forKey: GSTLSServerName inRequest: request];
  [request setHTTPShouldHandleCookies: NO];
  [request setHTTPMethod: method];
  if (data != nil)
    {
      [request setHTTPBody: data];
      [request setValue: type forHTTPHeaderField: @"Content-Type"];
    }
  return request;
}

#endif

@implementation GSGoogleDriveUbiquitousKeyValueStore

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSString *name = [defaults stringForKey: @"GSGoogleDriveKeyValueStoreName"];
      NSString *fileID = [defaults stringForKey: @"GSGoogleDriveKeyValueStoreFileID"];

      if ([name length] == 0 && [fileID length] == 0)
        {
          RELEASE(self);
          [NSException raise: NSInvalidArgumentException
            format: @"Configure GSGoogleDriveKeyValueStoreName or GSGoogleDriveKeyValueStoreFileID"];
          return nil;
        }
      _name = [name copy];
      _fileID = [fileID copy];
      _fixedID = [fileID length] > 0;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_name);
  RELEASE(_fileID);
  RELEASE(_createID);
  RELEASE(_accessToken);
  RELEASE(_tokenExpiry);
  RELEASE(_credentials);
  DEALLOC
}

#if defined(HAVE_GNUTLS)

- (NSData *) sendDriveRequest: (NSURLRequest *)request
                    response: (NSHTTPURLResponse **)response
{
  GSKeyValueStoreTransfer *transfer = [[GSKeyValueStoreTransfer alloc] init];
  NSData *result;

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

- (void) refreshAccessToken
{
  NSString *client = [_credentials objectForKey: @"GOOGLE_DRIVE_CLIENT_ID"];
  NSString *secret = [_credentials objectForKey: @"GOOGLE_DRIVE_CLIENT_SECRET"];
  NSString *refresh = [_credentials objectForKey: @"GOOGLE_DRIVE_REFRESH_TOKEN"];
  NSMutableString *form;
  NSMutableURLRequest *request;
  NSHTTPURLResponse *response = nil;
  NSDictionary *json;
  NSData *data;
  id expires;

  if (!GSDriveString(client) || !GSDriveString(refresh))
    {
      [NSException raise: NSInvalidArgumentException
        format: @"Google Drive needs an access token or a client ID and refresh token"];
    }
  form = [NSMutableString stringWithFormat:
    @"grant_type=refresh_token&client_id=%@&refresh_token=%@",
    GSDriveEncode(client), GSDriveEncode(refresh)];
  if ([secret length] > 0)
    {
      [form appendFormat: @"&client_secret=%@", GSDriveEncode(secret)];
    }
  request = GSDriveRequest(@"https://oauth2.googleapis.com/token", @"POST",
    GSRemoteUTF8(form), @"application/x-www-form-urlencoded");
  data = [self sendDriveRequest: request response: &response];
  if ([response statusCode] != 200)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive token refresh failed (HTTP %ld)",
        (long)[response statusCode]];
    }
  json = GSDriveJSON(data);
  expires = [json objectForKey: @"expires_in"];
  if (!GSDriveString([json objectForKey: @"access_token"])
    || ![[json objectForKey: @"token_type"] isKindOfClass: [NSString class]]
    || [[json objectForKey: @"token_type"] caseInsensitiveCompare: @"Bearer"] != NSOrderedSame
    || ![expires isKindOfClass: [NSNumber class]] || [expires doubleValue] <= 0)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive token response is incomplete"];
    }
  ASSIGNCOPY(_accessToken, [json objectForKey: @"access_token"]);
  ASSIGN(_tokenExpiry, [NSDate dateWithTimeIntervalSinceNow:
    MAX(1.0, [expires doubleValue] - 30.0)]);
}

- (NSData *) authorizedRequest: (NSMutableURLRequest *)request
                      response: (NSHTTPURLResponse **)response
{
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  NSMutableDictionary *credentials = [NSMutableDictionary dictionary];
  NSArray *keys = [NSArray arrayWithObjects: @"GOOGLE_DRIVE_ACCESS_TOKEN",
    @"GOOGLE_DRIVE_CLIENT_ID", @"GOOGLE_DRIVE_CLIENT_SECRET",
    @"GOOGLE_DRIVE_REFRESH_TOKEN", nil];
  NSUInteger i;
  NSData *data;

  for (i = 0; i < [keys count]; i++)
    {
      NSString *key = [keys objectAtIndex: i];
      NSString *value = [environment objectForKey: key];
      if ([value length] > 0)
        {
          [credentials setObject: value forKey: key];
        }
    }
  if (![_credentials isEqual: credentials])
    {
      ASSIGNCOPY(_credentials, credentials);
      ASSIGNCOPY(_accessToken, [credentials objectForKey: @"GOOGLE_DRIVE_ACCESS_TOKEN"]);
      DESTROY(_tokenExpiry);
    }
  if ([_accessToken length] == 0
    || (_tokenExpiry != nil && [_tokenExpiry timeIntervalSinceNow] <= 0))
    {
      [self refreshAccessToken];
    }
  [request setValue: [@"Bearer " stringByAppendingString: _accessToken]
    forHTTPHeaderField: @"Authorization"];
  data = [self sendDriveRequest: request response: response];
  if ([*response statusCode] == 401
    && [[_credentials objectForKey: @"GOOGLE_DRIVE_REFRESH_TOKEN"] length] > 0)
    {
      [self refreshAccessToken];
      [request setValue: [@"Bearer " stringByAppendingString: _accessToken]
        forHTTPHeaderField: @"Authorization"];
      data = [self sendDriveRequest: request response: response];
    }
  return data;
}

- (NSDictionary *) driveJSONAtURL: (NSString *)url allowMissing: (BOOL)missing
{
  NSHTTPURLResponse *response = nil;
  NSData *data = [self authorizedRequest: GSDriveRequest(url, @"GET", nil, nil)
    response: &response];

  if (missing && [response statusCode] == 404)
    {
      return nil;
    }
  if ([response statusCode] != 200)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive metadata request failed (HTTP %ld)",
        (long)[response statusCode]];
    }
  return GSDriveJSON(data);
}

- (NSString *) metadataURLForID: (NSString *)fileID
{
  return [NSString stringWithFormat:
    @"https://www.googleapis.com/drive/v2/files/%@?fields=id,etag,spaces,title,labels(trashed)",
    GSDriveIdentifier(fileID)];
}

- (NSString *) findFileID
{
  NSString *escaped = [_name stringByReplacingOccurrencesOfString: @"\\"
    withString: @"\\\\"];
  NSString *query;
  NSString *page = nil;
  NSString *found = nil;
  NSMutableSet *pages = [NSMutableSet set];

  escaped = [escaped stringByReplacingOccurrencesOfString: @"'" withString: @"\\'"];
  query = GSDriveEncode([NSString stringWithFormat: @"trashed = false and title = '%@'", escaped]);
  do
    {
      NSString *url = [NSString stringWithFormat:
        @"https://www.googleapis.com/drive/v2/files?spaces=appDataFolder&q=%@&maxResults=1000&fields=items(id),nextPageToken%@",
        query, page ? [@"&pageToken=" stringByAppendingString: GSDriveEncode(page)] : @""];
      NSDictionary *json = [self driveJSONAtURL: url allowMissing: NO];
      NSArray *items = [json objectForKey: @"items"];
      NSUInteger i;

      if (![items isKindOfClass: [NSArray class]])
        {
          [NSException raise: NSGenericException format: @"Invalid Google Drive file listing"];
        }
      for (i = 0; i < [items count]; i++)
        {
          id item = [items objectAtIndex: i];
          NSString *identifier;
          if (![item isKindOfClass: [NSDictionary class]])
            {
              [NSException raise: NSGenericException format: @"Invalid Google Drive file entry"];
            }
          identifier = GSDriveIdentifier([item objectForKey: @"id"]);
          if (found != nil && ![found isEqual: identifier])
            {
              [NSException raise: NSGenericException
                format: @"Multiple Google Drive stores have this name; select a FileID explicitly"];
            }
          found = identifier;
        }
      page = [json objectForKey: @"nextPageToken"];
      if (page != nil && (!GSDriveString(page) || [pages containsObject: page]
        || [pages count] >= 100))
        {
          [NSException raise: NSGenericException format: @"Invalid Google Drive pagination"];
        }
      if (page != nil)
        {
          [pages addObject: page];
        }
    }
  while (page != nil);
  return found;
}

- (NSDictionary *) remoteDictionaryWithVersion: (NSString **)version
{
  NSDictionary *metadata;
  NSDictionary *after;
  NSString *url;
  NSString *identifier;
  NSString *etag;
  NSHTTPURLResponse *response = nil;
  NSData *data;

  *version = nil;
  identifier = _fixedID ? _fileID : [self findFileID];
  if (identifier == nil)
    {
      if (_fileID != nil)
        {
          [NSException raise: NSGenericException
            format: @"The Google Drive store disappeared; local changes are retained"];
        }
      if (_createID == nil)
        {
          return [NSDictionary dictionary];
        }
      /* A prior create may have succeeded despite a lost response. Check its
       * pre-generated ID before attempting the same idempotent insertion. */
      metadata = [self driveJSONAtURL: [self metadataURLForID: _createID]
        allowMissing: YES];
      if (metadata == nil)
        {
          return [NSDictionary dictionary];
        }
      identifier = _createID;
    }
  else
    {
      metadata = [self driveJSONAtURL: [self metadataURLForID: identifier]
        allowMissing: NO];
    }
  etag = [metadata objectForKey: @"etag"];
  if (!GSDriveString(etag)
    || ![[metadata objectForKey: @"id"] isEqual: identifier]
    || ![[metadata objectForKey: @"spaces"] isKindOfClass: [NSArray class]]
    || ![[metadata objectForKey: @"spaces"] containsObject: @"appDataFolder"]
    || (![metadata objectForKey: @"labels"] ? NO :
      ![[metadata objectForKey: @"labels"] isKindOfClass: [NSDictionary class]])
    || [[[metadata objectForKey: @"labels"] objectForKey: @"trashed"] boolValue]
    || (!_fixedID && ![[metadata objectForKey: @"title"] isEqual: _name]))
    {
      [NSException raise: NSGenericException
        format: @"Google Drive store metadata is invalid or outside appDataFolder"];
    }
  ASSIGNCOPY(_fileID, identifier);
  url = [NSString stringWithFormat: @"https://www.googleapis.com/drive/v2/files/%@?alt=media",
    GSDriveIdentifier(_fileID)];
  data = [self authorizedRequest: GSDriveRequest(url, @"GET", nil, nil) response: &response];
  if ([response statusCode] != 200)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive download failed (HTTP %ld)", (long)[response statusCode]];
    }
  /* Metadata and media are separate requests. Never associate stale metadata
   * with bytes read after another writer changed the file. */
  after = [self driveJSONAtURL: [self metadataURLForID: _fileID] allowMissing: NO];
  if (![etag isEqual: [after objectForKey: @"etag"]])
    {
      return nil;
    }
  *version = etag;
  return GSRemoteDictionary(data);
}

- (BOOL) writeRemoteData: (NSData *)data version: (NSString *)version
{
  NSMutableURLRequest *request;
  NSHTTPURLResponse *response = nil;
  NSData *result;
  NSInteger status;

  if (version != nil)
    {
      NSString *url = [NSString stringWithFormat:
        @"https://www.googleapis.com/upload/drive/v2/files/%@?uploadType=media&fields=id",
        GSDriveIdentifier(_fileID)];
      request = GSDriveRequest(url, @"PUT", data, @"application/xml");
      [request setValue: version forHTTPHeaderField: @"If-Match"];
    }
  else
    {
      NSDictionary *metadata;
      NSData *json;
      NSMutableData *body = [NSMutableData data];
      NSString *boundary = [[NSUUID UUID] UUIDString];

      if (_createID == nil)
        {
          NSDictionary *generated = [self driveJSONAtURL:
            @"https://www.googleapis.com/drive/v2/files/generateIds?maxResults=1&space=appDataFolder"
            allowMissing: NO];
          NSArray *ids = [generated objectForKey: @"ids"];
          if (![ids isKindOfClass: [NSArray class]] || [ids count] != 1)
            {
              [NSException raise: NSGenericException format: @"Invalid generated Drive IDs"];
            }
          ASSIGNCOPY(_createID, GSDriveIdentifier([ids objectAtIndex: 0]));
        }
      metadata = [NSDictionary dictionaryWithObjectsAndKeys:
        _createID, @"id", _name, @"title", @"application/xml", @"mimeType",
        [NSArray arrayWithObject: [NSDictionary dictionaryWithObject:
          @"appDataFolder" forKey: @"id"]], @"parents", nil];
      json = [NSJSONSerialization dataWithJSONObject: metadata options: 0 error: NULL];
      [body appendData: GSRemoteUTF8([NSString stringWithFormat:
        @"--%@\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n", boundary])];
      [body appendData: json];
      [body appendData: GSRemoteUTF8([NSString stringWithFormat:
        @"\r\n--%@\r\nContent-Type: application/xml\r\n\r\n", boundary])];
      [body appendData: data];
      [body appendData: GSRemoteUTF8([NSString stringWithFormat: @"\r\n--%@--\r\n", boundary])];
      request = GSDriveRequest(
        @"https://www.googleapis.com/upload/drive/v2/files?uploadType=multipart&fields=id",
        @"POST", body, [NSString stringWithFormat: @"multipart/related; boundary=%@", boundary]);
    }
  result = [self authorizedRequest: request response: &response];
  status = [response statusCode];
  if (status == 412 || (status == 409 && version == nil))
    {
      return NO;
    }
  if (status != 200 && status != 201)
    {
      [NSException raise: NSGenericException
        format: @"Google Drive upload failed (HTTP %ld)", (long)status];
    }
  if (![[GSDriveJSON(result) objectForKey: @"id"] isEqual:
    version ? _fileID : _createID])
    {
      [NSException raise: NSGenericException format: @"Google Drive upload returned the wrong file ID"];
    }
  if (version == nil)
    {
      ASSIGNCOPY(_fileID, _createID);
    }
  return YES;
}

#endif

@end
