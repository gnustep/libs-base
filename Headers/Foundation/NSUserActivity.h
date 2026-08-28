/** Definition of class NSUserActivity
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Fri Nov  1 00:25:47 EDT 2019

   This file is part of the GNUstep Library.
   
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

#ifndef _NSUserActivity_h_GNUSTEP_BASE_INCLUDE
#define _NSUserActivity_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSObject.h>
#import <GNUstepBase/GSBlocks.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString, NSURL, NSSet, NSDictionary, NSMutableDictionary, NSDate;

@protocol NSUserActivityDelegate;

GS_EXPORT NSString * const NSUserActivityTypeBrowsingWeb;
GS_EXPORT NSString * const NSUserActivityDocumentURLKey;
GS_EXPORT NSString * const NSUserActivityPersistentIdentifierKey;
GS_EXPORT NSString * const NSUserActivityReferrerURLKey;
GS_EXPORT NSString * const NSUserActivitySuggestedInvocationPhraseKey;
GS_EXPORT NSString * const NSUserActivityExternalRecordURLKey;

GS_EXPORT_CLASS
@interface NSUserActivity : NSObject <NSSecureCoding>
{
#if	GS_EXPOSE(NSUserActivity)
@public
   NSString *_activityType;
   NSString *_title;
   NSMutableDictionary *_userInfo;
   NSSet *_requiredUserInfoKeys;
   NSURL *_webpageURL;
   NSURL *_referrerURL;
   NSDate *_expirationDate;
   NSSet *_keywords;
   BOOL _needsSave;
   BOOL _invalidated;
   BOOL _eligibleForHandoff;
   BOOL _eligibleForSearch;
   BOOL _eligibleForPublicIndexing;
   BOOL _supportsContinuationOnPhone;
   id _delegate;
#endif
}

- (instancetype) initWithActivityType: (NSString *)activityType;

+ (NSUserActivity *) currentActivity;

- (NSString *) activityType;

- (NSString *) title;
- (void) setTitle: (NSString *)title;

- (NSDictionary *) userInfo;
- (void) setUserInfo: (NSDictionary *)userInfo;
- (void) addUserInfoEntriesFromDictionary: (NSDictionary *)dictionary;

- (NSSet *) requiredUserInfoKeys;
- (void) setRequiredUserInfoKeys: (NSSet *)keys;

- (BOOL) needsSave;
- (void) setNeedsSave: (BOOL)flag;

- (NSURL *) webpageURL;
- (void) setWebpageURL: (NSURL *)url;

- (NSSet *) keywords;
- (void) setKeywords: (NSSet *)keywords;

- (NSDate *) expirationDate;
- (void) setExpirationDate: (NSDate *)date;

- (NSURL *) referrerURL;
- (void) setReferrerURL: (NSURL *)url;

- (BOOL) supportsContinuationOnPhone;
- (void) setSupportsContinuationOnPhone: (BOOL)flag;

- (BOOL) eligibleForHandoff;
- (void) setEligibleForHandoff: (BOOL)flag;

- (BOOL) eligibleForSearch;
- (void) setEligibleForSearch: (BOOL)flag;

- (BOOL) eligibleForPublicIndexing;
- (void) setEligibleForPublicIndexing: (BOOL)flag;

- (BOOL) isValid;

- (id) delegate;
- (void) setDelegate: (id<NSUserActivityDelegate>)delegate;

- (void) becomeCurrent;
- (void) resignCurrent;
- (void) invalidate;

@end

#if GS_PROTOCOLS_HAVE_OPTIONAL
@protocol NSUserActivityDelegate <NSObject>
@optional
- (void) userActivityWillSave: (NSUserActivity *)userActivity;
- (void) userActivityWasContinued: (NSUserActivity *)userActivity;
@end
#else
@interface NSObject (NSUserActivityDelegate)
- (void) userActivityWillSave: (NSUserActivity *)userActivity;
- (void) userActivityWasContinued: (NSUserActivity *)userActivity;
@end
#endif


#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSUserActivity_h_GNUSTEP_BASE_INCLUDE */

