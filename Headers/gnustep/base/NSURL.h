/* NSURL.h - Class NSURL
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 		Jan 1999
   
   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _NSURL_h__
#define _NSURL_h__

#include <Foundation/NSURLHandle.h>

@class NSNumber;

GS_EXPORT NSString* NSURLFileScheme;

@interface NSURL: NSObject <NSCoding, NSCopying, NSURLHandleClient>
{
  NSString	*_urlString;
  NSURL		*_baseURL;
  void		*_clients;
  void		*_data;
}
        
+ (id) fileURLWithPath: (NSString*)aPath;
+ (id) URLWithString: (NSString*)aUrlString;
+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl;

- (id) initFileURLWithPath: (NSString*)aPath;
- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 path: (NSString*)aPath;
- (id) initWithString: (NSString*)aUrlString;
- (id) initWithString: (NSString*)aUrlString
	relativeToURL: (NSURL*)aBaseUrl;

- (NSString*) absoluteString;
- (NSURL*) absoluteURL;
- (NSURL*) baseURL;
- (NSString*) fragment;
- (NSString*) host;
- (BOOL) isFileURL;
- (NSString*) parameterString;
- (NSString*) password;
- (NSString*) path;
- (NSNumber*) port;
- (NSString*) query;
- (NSString*) relativePath;
- (NSString*) relativeString;
- (NSString*) resourceSpecifier;
- (NSString*) scheme;
- (NSURL*) standardizedURL;
- (NSString*) user;

@end

@interface NSURL (NSURLLoading)
- (NSData*) resourceDataUsingCache: (BOOL)shouldUseCache;

- (void) loadResourceDataNotifyingClient: (id)client
			      usingCache: (BOOL)shouldUseCache;

- (NSURLHandle*)URLHandleUsingCache: (BOOL)shouldUseCache;

- (BOOL) setResourceData: (NSData*)data;

- (id) propertyForKey: (NSString*)propertyKey;
- (BOOL) setProperty: (id)property
	      forKey: (NSString*)propertyKey;

@end

@interface NSObject (NSURLClient)
- (void) URL: (NSURL*)sender
  resourceDataDidBecomeAvailable: (NSData*)newBytes;

- (void) URLResourceDidFinishLoading: (NSURL*)sender;
- (void) URLResourceDidCancelLoading: (NSURL*)sender;

- (void) URL: (NSURL*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason;
@end

#endif //_NSUrl_h__
