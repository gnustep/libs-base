/* Definition of class NSUserActivity
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: heron
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#ifndef _NSUserActivity_h_GNUSTEP_BASE_INCLUDE
#define _NSUserActivity_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#import <GNUstepBase/GSBlocks.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

GS_EXPORT NSString* const NSUserActivityBrowsingWeb;

@class NSString, NSInputStream, NSOutputStream, NSError, NSDictionary, NSSet, NSURL, NSDate;

typedef NSString* NSUserActivityPersistentIdentifier;

@protocol NSUserActivityDelegate;

DEFINE_BLOCK_TYPE(GSContinuationStreamsCompletionHandler, void, NSInputStream*, NSOutputStream*, NSError*);

DEFINE_BLOCK_TYPE_NO_ARGS(GSDeleteSavedCompletionHandler, void);

GS_EXPORT_CLASS
@interface NSUserActivity : NSObject
{
  NSString *_activityType;
  NSString *_title;
  NSDictionary *_userInfo;
  NSSet *_requiredUserInfoKeys;
  NSURL *_webpageURL;
  NSURL *_referrerURL;
  NSDate *_expirationDate;
  NSSet *_keywords;
  id<NSUserActivityDelegate> _delegate;
  NSString *_targetContentIndentifier;

  BOOL _supportsContinuationStreams;
  BOOL _needsSave;
  BOOL _valid;
}

- (instancetype) initWithActivityType: (NSString *)activityType;

- (instancetype) init;

- (void) becomeCurrent;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
- (void) resignCurrent;
#endif

- (void) invalidate;

- (void) getContinuationStreamsWithCompletionHandler: (GSContinuationStreamsCompletionHandler)handler;

+ (void) deleteSavedUserActivitiesWithPersistentIdentifiers: (NSArray *)persistentIdentifies completionHandler: (GSDeleteSavedCompletionHandler)handler;

+ (void) deleteAllSavedUserActivitiesWithCompletionHandler: (GSDeleteSavedCompletionHandler)handler;

// properties...
- (NSString *) activityType;

- (NSString *) title;

- (void) setTitle: (NSString *)title;

- (NSDictionary *) userInfo;

- (void) setUserInfo: (NSDictionary *)userInfo;

- (BOOL) needsSave;

- (void) setNeedsSave: (BOOL)needsSave;

- (NSURL *) webpageURL;

- (void) setWebpageURL: (NSURL *)url;

- (NSURL *) referrerURL;

- (void) setReferrerURL: (NSURL *)url;

- (NSDate *) expirationDate;

- (void) setExpirationDate: (NSDate *)date;

- (NSArray *) keywords;

- (void) setKeywords: (NSArray *)keywords;

- (BOOL) supportsContinuationStreams;

- (void) setSupportsContinuationStreams: (BOOL)flag;

- (id<NSUserActivityDelegate>) delegate;

- (void) setDelegate: (id<NSUserActivityDelegate>)delegate;

- (NSString *) targetContentIdentifier;

- (void) setTargetContentIdentifier: (NSString *)targetContentIdentifier;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
- (BOOL) isEligibleForHandoff;

- (void) setEligibleForHandoff: (BOOL)f;

- (BOOL) isEligibleForSearch;

- (void) setEligibleForSearch: (BOOL)f;

- (BOOL) isEligibleForPublicIndexing;

- (void) setEligibleForPublicIndexing: (BOOL)f;

- (BOOL) isEligibleForPrediction;

- (void) setEligibleForPrediction: (BOOL)f;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_15, GS_API_LATEST)
- (NSUserActivityPersistentIdentifier) persistentIdentifier;

- (void) setPersistentIdentifier: (NSUserActivityPersistentIdentifier)persistentIdentifier;
#endif
@end

@protocol NSUserActivityDelegate <NSObject>

- (void) userActivityWillSave: (NSUserActivity *)activity;

- (void) userActivityWasContinued: (NSUserActivity *)activity;

- (void) userActivity: (NSUserActivity *)activity didRecieveInputStream: (NSInputStream *)inputStream outputStream: (NSOutputStream *)outputStream;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSUserActivity_h_GNUSTEP_BASE_INCLUDE */
