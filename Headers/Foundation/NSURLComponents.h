/* Definition of class NSURLComponents
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Written by: 	Gregory Casamento <greg.casamento@gmail.com>
   Date: 	July 2019
   
   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#ifndef _NSURLComponents_h_GNUSTEP_BASE_INCLUDE
#define _NSURLComponents_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSString, NSDictionary, NSArray;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
  
@interface NSURLComponents : NSObject <NSCopying>
{
#if	GS_EXPOSE(NSURLComponents)
#endif
#if     GS_NONFRAGILE
#  if	defined(GS_NSURLComponents_IVARS)
@public
GS_NSURLComponents_IVARS;
#  endif
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}
  // Creating URL components...
+ (instancetype) componentsWithString:(NSString *)URLString;
+ (instancetype) componentsWithURL:(NSURL *)url 
           resolvingAgainstBaseURL:(BOOL)resolve;
- (instancetype) init;
- (instancetype)initWithString:(NSString *)URLString;

- (instancetype)initWithURL:(NSURL *)url 
    resolvingAgainstBaseURL:(BOOL)resolve;

// Getting the URL
- (NSString *) string;
- (void) setString: (NSString *)urlString;
- (NSURL *) URL;
- (void) setURL: (NSURL *)url;
- (NSURL *)URLRelativeToURL: (NSURL *)baseURL;

// Accessing Components in Native Format
- (NSString *) fragment;
- (void) setFragment: (NSString *)fragment;
- (NSString *) host;
- (void) setHost: (NSString *)host;
- (NSString *) password;
- (void) setPassword: (NSString *)password;
- (NSString *) path;
- (void) setPath: (NSString *)path;
- (NSString *) port;
- (void) setPort: (NSString *)port;
- (NSString *) query;
- (void) setQuery: (NSString *)query;
- (NSArray *) queryItems;
- (void) setQueryItems: (NSArray *)queryItems;
- (NSString *) scheme;
- (void) setScheme: (NSString *)scheme;
- (NSString *) user;
- (void) setUser: (NSString *)user;

// Locating components of the URL string representation
- (NSRange) rangeOfFragment;
- (NSRange) rangeOfHost;
- (NSRange) rangeOfPassword;
- (NSRange) rangeOfPath;
- (NSRange) rangeOfPort;
- (NSRange) rangeOfQuery;
- (NSRange) rangeOfQueryItems;
- (NSRange) rangeOfScheme;
- (NSRange) rangeOfUser;
  
@end

#if defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSURLComponents_h_GNUSTEP_BASE_INCLUDE */

