/* NSURLHandle.h - Class NSURLHandle
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 	Jan 1999
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef _NSURLHandle_h__
#define _NSURLHandle_h__

@class NSURLHandle;
@class NSURL;

extern NSString *NSHTTPPropertyStatusCodeKey;
extern NSString *NSHTTPPropertyStatusReasonKey;
extern NSString *NSHTTPPropertyServerHTTPVersionKey;
extern NSString *NSHTTPPropertyRedirectionHeadersKey;
extern NSString *NSHTTPPropertyErrorPageDataKey;

typedef enum
{
  NSURLHandleNotLoaded = 0,
  NSURLHandleLoadSucceeded,
  NSURLHandleLoadInProgress,
  NSURLHandleLoadFailed
} NSURLHandleStatus;

//=============================================================================
@protocol NSURLHandleClient
- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData;

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender;
- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender;
- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender;

- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason;
@end

//=============================================================================
@interface NSURLHandle: NSObject
{
  NSMutableArray	*clients;
  id			data; 
  NSURLHandleStatus	status;
}

+ (void) registerURLHandleClass: (Class)_urlHandleSubclass;
+ (Class) URLHandleClassForURL: (NSURL*)_url;

- (id) initWithURL: (NSURL*)_url
	    cached: (BOOL)_cached;

- (NSURLHandleStatus) status;
- (NSString*) failureReason;

- (void) addClient: (id <NSURLHandleClient>)_client;
- (void) removeClient: (id <NSURLHandleClient>)_client;

- (void) loadInBackground;
- (void) cancelLoadInBackground;

- (NSData*) resourceData;
- (NSData*) availableResourceData;

- (void) flushCachedData;

- (void) backgroundLoadDidFailWithReason: (NSString*)reason;
- (void) didLoadBytes: (NSData*)newData
	 loadComplete: (BOOL)_loadComplete;


+ (BOOL) canInitWithURL: (NSURL*)_url;
+ (NSURLHandle*) cachedHandleForURL: (NSURL*)_url;

- (id) propertyForKey: (NSString*)propertyKey;
- (id) propertyForKeyIfAvailable: (NSString*)propertyKey;
- (BOOL) writeProperty: (id)propertyValue
		forKey: (NSString*)propertyKey;
- (BOOL) writeData: (NSData*)data;

- (NSData*) loadInForeground;
- (void) beginLoadInBackground;
- (void) endLoadInBackground;

@end

#endif
