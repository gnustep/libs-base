/* Implementation of class NSUserActivity
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

#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSString.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSUserActivity.h"

static NSUserActivity *__currentUserActivity = nil;

@implementation NSUserActivity

- (instancetype) initWithActivityType: (NSString *)activityType
{
  self = [super init];
  
  if (self != nil)
    {
      ASSIGNCOPY(_activityType, activityType);
      _userInfo = [[NSMutableDictionary alloc] init];
      _requiredUserInfoKeys = [[NSMutableSet alloc] initWithCapacity: 10];
      _keywords = [[NSMutableSet alloc] init];
    }

  return self;
}

- (instancetype) init
{
  self = [self initWithActivityType: nil];
  return self;
}

- (void) dealloc
{
  __currentUserActivity = nil;
  _delegate = nil;

  RELEASE(_activityType);
  RELEASE(_title);
  RELEASE(_userInfo);
  RELEASE(_requiredUserInfoKeys);
  RELEASE(_webpageURL);
  RELEASE(_referrerURL);
  RELEASE(_expirationDate);
  RELEASE(_keywords);
  RELEASE(_targetContentIdentifier);
  RELEASE(_persistentIdentifier);

  [super dealloc];
}

- (void) becomeCurrent
{
  __currentUserActivity = self;
}

- (void) resignCurrent
{
  __currentUserActivity = nil;
}

- (void) invalidate
{
  _valid = NO;
}

- (void) getContinuationStreamsWithCompletionHandler: (GSContinuationStreamsCompletionHandler)handler
{
}

+ (void) deleteSavedUserActivitiesWithPersistentIdentifiers: (NSArray *)persistentIdentifies completionHandler: (GSDeleteSavedCompletionHandler)handler
{
}

+ (void) deleteAllSavedUserActivitiesWithCompletionHandler: (GSDeleteSavedCompletionHandler)handler
{
}

// properties...
- (NSString *) activityType
{
  return _activityType;
}

- (NSString *) title
{
  return _title;
}

- (void) setTitle: (NSString *)title
{
  ASSIGNCOPY(_title, title);
}

- (NSDictionary *) userInfo
{
  return _userInfo;
}

- (void) setUserInfo: (NSDictionary *)userInfo
{
  ASSIGNCOPY(_userInfo, userInfo);
}

- (BOOL) needsSave
{
  return _needsSave;
}

- (void) setNeedsSave: (BOOL)needsSave
{
  _needsSave = needsSave;
}

- (NSURL *) webpageURL
{
  return _webpageURL;
}

- (void) setWebpageURL: (NSURL *)url
{
  ASSIGNCOPY(_webpageURL, url);
}

- (NSURL *) referrerURL
{
  return _referrerURL;
}

- (void) setReferrerURL: (NSURL *)url
{
  ASSIGNCOPY(_referrerURL, url);
}

- (NSDate *) expirationDate
{
  return _expirationDate;
}

- (void) setExpirationDate: (NSDate *)date
{
  ASSIGNCOPY(_expirationDate, date);
}

- (NSSet *) keywords
{
  return _keywords;
}

- (void) setKeywords: (NSArray *)keywords
{
  ASSIGNCOPY(_keywords, keywords);
}

- (BOOL) supportsContinuationStreams
{
  return _supportsContinuationStreams;
}

- (void) setSupportsContinuationStreams: (BOOL)flag
{
  _supportsContinuationStreams = flag;
}

- (id<NSUserActivityDelegate>) delegate
{
  return _delegate;
}

- (void) setDelegate: (id<NSUserActivityDelegate>)delegate
{
  _delegate = delegate;
}

- (NSString *) targetContentIdentifier
{
  return _targetContentIdentifier;
}

- (void) setTargetContentIdentifier: (NSString *)targetContentIdentifier
{
  ASSIGNCOPY(_targetContentIdentifier, targetContentIdentifier);
}

- (BOOL) isEligibleForHandoff
{
  return _eligibleForHandoff;
}

- (void) setEligibleForHandoff: (BOOL)f
{
  _eligibleForHandoff = f;
}

- (BOOL) isEligibleForSearch
{
  return _eligibleForSearch;
}

- (void) setEligibleForSearch: (BOOL)f
{
  _eligibleForSearch = f;
}

- (BOOL) isEligibleForPublicIndexing
{
  return _eligibleForPublicIndexing;
}

- (void) setEligibleForPublicIndexing: (BOOL)f
{
  _eligibleForPublicIndexing = f;
}

- (BOOL) isEligibleForPrediction
{
  return _eligibleForPrediction;
}

- (void) setEligibleForPrediction: (BOOL)f
{
  _eligibleForPrediction = f;
}

- (NSUserActivityPersistentIdentifier) persistentIdentifier
{
  return _persistentIdentifier;
}

- (void) setPersistentIdentifier: (NSUserActivityPersistentIdentifier)persistentIdentifier
{
  ASSIGNCOPY(_persistentIdentifier, persistentIdentifier);
}

@end
