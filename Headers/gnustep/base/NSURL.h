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

GS_EXPORT NSString* NSURLFileScheme; //file

//============================================================================
@interface NSURL: NSObject <NSCoding, NSCopying, NSURLHandleClient>
{
  NSString	*_urlString;
  NSURL		*_baseURL;
}
        
+ (id) fileURLWithPath: (NSString*)aPath;
+ (id) URLWithString: (NSString*)aUrlString;
+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl;

- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 path: (NSString*)aPath;

//Non Standard Function
- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 port: (NSNumber*)aPort
		 path: (NSString*)aPath;

//Do a initWithScheme: NSFileScheme host: nil path: path
- (id) initFileURLWithPath: (NSString*)aPath;

// urlString is escaped
- (id) initWithString: (NSString*)aUrlString;

//URLString!=nil !
// urlString is escaped
- (id) initWithString: (NSString*)aUrlString
	relativeToURL: (NSURL*)aBaseUrl;

- (NSString*) description;
- (NSString*) absoluteString;
- (NSString*) relativeString;

- (NSURL*) baseURL;
- (NSURL*) absoluteURL;

- (NSString*) scheme;
- (NSString*) resourceSpecifier;

- (NSString*) host;
- (NSNumber*) port;
- (NSString*) user;
- (NSString*) password;
- (NSString*) path;
- (NSString*) fragment;
- (NSString*) parameterString;
- (NSString*) query;
- (NSString*) relativePath;

- (BOOL) isFileURL;

- (NSURL*) standardizedURL;

//FIXME: delete these fn when NSURL will be validated
+ (void) test;
+ (void) testPrint: (NSURL*)url;

@end

//=============================================================================
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

//=============================================================================
@interface NSObject (NSURLClient)
- (void) URL: (NSURL*)sender
  resourceDataDidBecomeAvailable: (NSData*)newBytes;

- (void) URLResourceDidFinishLoading: (NSURL*)sender;
- (void) URLResourceDidCancelLoading: (NSURL*)sender;

- (void) URL: (NSURL*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason;
@end

#endif //_NSUrl_h__
