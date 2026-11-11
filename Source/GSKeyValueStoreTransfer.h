/** Private remote key-value store transport
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
#ifndef GS_KEY_VALUE_STORE_TRANSFER_H
#define GS_KEY_VALUE_STORE_TRANSFER_H

#import "Foundation/NSObject.h"

@class NSMutableData, NSHTTPURLResponse, NSError, NSURLRequest, NSData;

/* Never forward signing credentials or OAuth tokens through redirects. */
@interface GSKeyValueStoreTransfer : NSObject
{
  NSMutableData *_data;
  NSHTTPURLResponse *_response;
  NSError *_error;
  BOOL _done;
}

- (NSData *) sendRequest: (NSURLRequest *)request
               response: (NSHTTPURLResponse **)response;

@end

#endif
