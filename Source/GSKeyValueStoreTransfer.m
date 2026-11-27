/** Remote key-value store transport
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
#import "Foundation/NSData.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSURLError.h"
#import "Foundation/NSURLConnection.h"
#import "Foundation/NSURLRequest.h"
#import "Foundation/NSURLResponse.h"

#import "GSKeyValueStoreTransfer.h"

@implementation GSKeyValueStoreTransfer

- (void) dealloc
{
  RELEASE(_data);
  RELEASE(_response);
  RELEASE(_error);
  DEALLOC
}

- (NSURLRequest *) connection: (NSURLConnection *)connection
             willSendRequest: (NSURLRequest *)request
            redirectResponse: (NSURLResponse *)response
{
  if (response != nil)
    {
      ASSIGN(_response, (NSHTTPURLResponse *)response);
      _done = YES;
      return nil;
    }
  return request;
}

- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse *)response
{
  ASSIGN(_response, (NSHTTPURLResponse *)response);
  [_data setLength: 0];
}

- (void) connection: (NSURLConnection *)connection
    didReceiveData: (NSData *)data
{
  if ([_data length] + [data length] > 1048576)
    {
      ASSIGN(_error, [NSError errorWithDomain: NSURLErrorDomain
        code: NSURLErrorDataLengthExceedsMaximum userInfo: nil]);
      [connection cancel];
      _done = YES;
    }
  else
    {
      [_data appendData: data];
    }
}

- (void) connection: (NSURLConnection *)connection
  didFailWithError: (NSError *)error
{
  ASSIGN(_error, error);
  _done = YES;
}

- (NSCachedURLResponse *) connection: (NSURLConnection *)connection
                  willCacheResponse: (NSCachedURLResponse *)response
{
  return nil;
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
  _done = YES;
}

- (NSData *) sendRequest: (NSURLRequest *)request
               response: (NSHTTPURLResponse **)response
{
  NSURLConnection *connection;
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 30.0];

  _data = [[NSMutableData alloc] init];
  connection = [[NSURLConnection alloc] initWithRequest: request delegate: self];
  @try
    {
      while (connection != nil && !_done && [deadline timeIntervalSinceNow] > 0)
        {
          [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                  beforeDate: deadline];
        }
      if (!_done || _error != nil)
        {
          [NSException raise: NSGenericException
                      format: @"Remote key-value store transport failed (%ld)",
                      (long)(_error ? [_error code] : NSURLErrorTimedOut)];
        }
      *response = AUTORELEASE(RETAIN(_response));
      return AUTORELEASE([_data copy]);
    }
  @finally
    {
      [connection cancel];
      RELEASE(connection);
    }
}

@end
