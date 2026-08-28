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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#define EXPOSE_NSUserActivity_IVARS 1

#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSString.h"
#import "Foundation/NSUserActivity.h"

#define GSUserActivityTypeKey @"activityType"
#define GSUserActivityTitleKey @"title"
#define GSUserActivityUserInfoKey @"userInfo"
#define GSUserActivityRequiredKeysKey @"requiredUserInfoKeys"
#define GSUserActivityNeedsSaveKey @"needsSave"
#define GSUserActivityWebpageURLKey @"webpageURL"
#define GSUserActivityKeywordsKey @"keywords"
#define GSUserActivityExpirationDateKey @"expirationDate"
#define GSUserActivityReferrerURLKey @"referrerURL"
#define GSUserActivityEligibleForHandoffKey @"eligibleForHandoff"
#define GSUserActivityEligibleForSearchKey @"eligibleForSearch"
#define GSUserActivityEligibleForPublicIndexingKey @"eligibleForPublicIndexing"
#define GSUserActivitySupportsContinuationOnPhoneKey @"supportsContinuationOnPhone"
#define GSUserActivityInvalidatedKey @"invalidated"

NSString * const NSUserActivityTypeBrowsingWeb = @"NSUserActivityTypeBrowsingWeb";
NSString * const NSUserActivityDocumentURLKey = @"NSUserActivityDocumentURLKey";
NSString * const NSUserActivityPersistentIdentifierKey = @"NSUserActivityPersistentIdentifierKey";
NSString * const NSUserActivityReferrerURLKey = @"NSUserActivityReferrerURLKey";
NSString * const NSUserActivitySuggestedInvocationPhraseKey = @"NSUserActivitySuggestedInvocationPhraseKey";
NSString * const NSUserActivityExternalRecordURLKey = @"NSUserActivityExternalRecordURLKey";

static NSUserActivity *GSCurrentUserActivity = nil;

@implementation NSUserActivity

+ (BOOL) supportsSecureCoding
{
   return YES;
}

+ (NSUserActivity *) currentActivity
{
   return GSCurrentUserActivity;
}

- (id) init
{
   RELEASE(self);
   [NSException raise: NSInternalInconsistencyException
                     format: @"Use -initWithActivityType: to create an NSUserActivity."];
   return nil;
}

- (instancetype) initWithActivityType: (NSString *)activityType
{
   if (activityType == nil || [activityType length] == 0)
      {
         RELEASE(self);
         [NSException raise: NSInvalidArgumentException
                           format: @"activityType must not be nil or empty."];
      }

   self = [super init];
   if (self != nil)
      {
         ASSIGNCOPY(_activityType, activityType);
         _eligibleForHandoff = YES;
         _eligibleForSearch = NO;
         _eligibleForPublicIndexing = NO;
         _supportsContinuationOnPhone = NO;
         _needsSave = NO;
         _invalidated = NO;
      }
   return self;
}

- (void) dealloc
{
   DESTROY(_activityType);
   DESTROY(_title);
   DESTROY(_userInfo);
   DESTROY(_requiredUserInfoKeys);
   DESTROY(_webpageURL);
   DESTROY(_referrerURL);
   DESTROY(_expirationDate);
   DESTROY(_keywords);

   if (GSCurrentUserActivity == self)
      {
         GSCurrentUserActivity = nil;
      }

   [super dealloc];
}

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
   NSMutableDictionary *copy;

   copy = [userInfo mutableCopy];
   ASSIGN(_userInfo, copy);
   RELEASE(copy);
}

- (void) addUserInfoEntriesFromDictionary: (NSDictionary *)dictionary
{
   if (dictionary == nil)
      {
         return;
      }

   if (_userInfo == nil)
      {
         _userInfo = [dictionary mutableCopy];
      }
   else
      {
         [_userInfo addEntriesFromDictionary: dictionary];
      }
}

- (NSSet *) requiredUserInfoKeys
{
   return _requiredUserInfoKeys;
}

- (void) setRequiredUserInfoKeys: (NSSet *)keys
{
   ASSIGNCOPY(_requiredUserInfoKeys, keys);
}

- (BOOL) needsSave
{
   return _needsSave;
}

- (void) setNeedsSave: (BOOL)flag
{
   _needsSave = flag;
}

- (NSURL *) webpageURL
{
   return _webpageURL;
}

- (void) setWebpageURL: (NSURL *)url
{
   ASSIGNCOPY(_webpageURL, url);
}

- (NSSet *) keywords
{
   return _keywords;
}

- (void) setKeywords: (NSSet *)keywords
{
   ASSIGNCOPY(_keywords, keywords);
}

- (NSDate *) expirationDate
{
   return _expirationDate;
}

- (void) setExpirationDate: (NSDate *)date
{
   ASSIGNCOPY(_expirationDate, date);
}

- (NSURL *) referrerURL
{
   return _referrerURL;
}

- (void) setReferrerURL: (NSURL *)url
{
   ASSIGNCOPY(_referrerURL, url);
}

- (BOOL) supportsContinuationOnPhone
{
   return _supportsContinuationOnPhone;
}

- (void) setSupportsContinuationOnPhone: (BOOL)flag
{
   _supportsContinuationOnPhone = flag;
}

- (BOOL) eligibleForHandoff
{
   return _eligibleForHandoff;
}

- (void) setEligibleForHandoff: (BOOL)flag
{
   _eligibleForHandoff = flag;
}

- (BOOL) eligibleForSearch
{
   return _eligibleForSearch;
}

- (void) setEligibleForSearch: (BOOL)flag
{
   _eligibleForSearch = flag;
}

- (BOOL) eligibleForPublicIndexing
{
   return _eligibleForPublicIndexing;
}

- (void) setEligibleForPublicIndexing: (BOOL)flag
{
   _eligibleForPublicIndexing = flag;
}

- (BOOL) isValid
{
   return _invalidated == NO;
}

- (id) delegate
{
   return _delegate;
}

- (void) setDelegate: (id<NSUserActivityDelegate>)delegate
{
   _delegate = delegate;
}

- (void) becomeCurrent
{
   if (_invalidated)
      {
         return;
      }

   if (_needsSave && _delegate &&
         [_delegate respondsToSelector: @selector(userActivityWillSave:)])
      {
         [_delegate userActivityWillSave: self];
         _needsSave = NO;
      }

   if (GSCurrentUserActivity != self)
      {
         NSUserActivity *old = GSCurrentUserActivity;
         GSCurrentUserActivity = RETAIN(self);
         RELEASE(old);
      }
}

- (void) resignCurrent
{
   if (GSCurrentUserActivity == self)
      {
         RELEASE(GSCurrentUserActivity);
         GSCurrentUserActivity = nil;
      }
}

- (void) invalidate
{
   _invalidated = YES;
   [self resignCurrent];
}

- (void) encodeWithCoder: (NSCoder *)coder
{
   if ([coder allowsKeyedCoding])
      {
         [coder encodeObject: _activityType forKey: GSUserActivityTypeKey];
         [coder encodeObject: _title forKey: GSUserActivityTitleKey];
         [coder encodeObject: _userInfo forKey: GSUserActivityUserInfoKey];
         [coder encodeObject: _requiredUserInfoKeys forKey: GSUserActivityRequiredKeysKey];
         [coder encodeBool: _needsSave forKey: GSUserActivityNeedsSaveKey];
         [coder encodeObject: _webpageURL forKey: GSUserActivityWebpageURLKey];
         [coder encodeObject: _keywords forKey: GSUserActivityKeywordsKey];
         [coder encodeObject: _expirationDate forKey: GSUserActivityExpirationDateKey];
         [coder encodeObject: _referrerURL forKey: GSUserActivityReferrerURLKey];
         [coder encodeBool: _eligibleForHandoff forKey: GSUserActivityEligibleForHandoffKey];
         [coder encodeBool: _eligibleForSearch forKey: GSUserActivityEligibleForSearchKey];
         [coder encodeBool: _eligibleForPublicIndexing forKey: GSUserActivityEligibleForPublicIndexingKey];
         [coder encodeBool: _supportsContinuationOnPhone forKey: GSUserActivitySupportsContinuationOnPhoneKey];
         [coder encodeBool: _invalidated forKey: GSUserActivityInvalidatedKey];
      }
   else
      {
         [coder encodeObject: _activityType];
         [coder encodeObject: _title];
         [coder encodeObject: _userInfo];
         [coder encodeObject: _requiredUserInfoKeys];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_needsSave];
         [coder encodeObject: _webpageURL];
         [coder encodeObject: _keywords];
         [coder encodeObject: _expirationDate];
         [coder encodeObject: _referrerURL];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_eligibleForHandoff];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_eligibleForSearch];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_eligibleForPublicIndexing];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_supportsContinuationOnPhone];
         [coder encodeValueOfObjCType: @encode(BOOL) at: &_invalidated];
      }
}

- (id) initWithCoder: (NSCoder *)coder
{
   self = [super init];
   if (self != nil)
      {
         _eligibleForHandoff = YES;
         _eligibleForSearch = NO;
         _eligibleForPublicIndexing = NO;
         _supportsContinuationOnPhone = NO;
         _needsSave = NO;
         _invalidated = NO;

         if ([coder allowsKeyedCoding])
            {
               NSString *type;
               NSDictionary *info;

               type = [coder decodeObjectForKey: GSUserActivityTypeKey];
               if (type == nil)
                  {
                     RELEASE(self);
                     [NSException raise: NSInvalidUnarchiveOperationException
                                       format: @"Missing activityType when decoding NSUserActivity."];
                  }
               _activityType = [type copy];
               _title = [[coder decodeObjectForKey: GSUserActivityTitleKey] copy];
               info = [coder decodeObjectForKey: GSUserActivityUserInfoKey];
               if (info != nil)
                  {
                     _userInfo = [info mutableCopy];
                  }
               _requiredUserInfoKeys = [[coder decodeObjectForKey: GSUserActivityRequiredKeysKey] copy];
               _needsSave = [coder decodeBoolForKey: GSUserActivityNeedsSaveKey];
               _webpageURL = [[coder decodeObjectForKey: GSUserActivityWebpageURLKey] copy];
               _keywords = [[coder decodeObjectForKey: GSUserActivityKeywordsKey] copy];
               _expirationDate = [[coder decodeObjectForKey: GSUserActivityExpirationDateKey] copy];
               _referrerURL = [[coder decodeObjectForKey: GSUserActivityReferrerURLKey] copy];
               _eligibleForHandoff = [coder decodeBoolForKey: GSUserActivityEligibleForHandoffKey];
               _eligibleForSearch = [coder decodeBoolForKey: GSUserActivityEligibleForSearchKey];
               _eligibleForPublicIndexing = [coder decodeBoolForKey: GSUserActivityEligibleForPublicIndexingKey];
               _supportsContinuationOnPhone = [coder decodeBoolForKey: GSUserActivitySupportsContinuationOnPhoneKey];
               if ([coder containsValueForKey: GSUserActivityInvalidatedKey])
                  {
                     _invalidated = [coder decodeBoolForKey: GSUserActivityInvalidatedKey];
                  }
               else
                  {
                     _invalidated = NO;
                  }
            }
         else
            {
               NSString *type;
               NSDictionary *info;

               type = [coder decodeObject];
               if (type == nil)
                  {
                     RELEASE(self);
                     [NSException raise: NSInvalidUnarchiveOperationException
                                       format: @"Missing activityType when decoding NSUserActivity."];
                  }
               _activityType = [type copy];
               _title = [[coder decodeObject] copy];
               info = [coder decodeObject];
               if (info != nil)
                  {
                     _userInfo = [info mutableCopy];
                  }
               _requiredUserInfoKeys = [[coder decodeObject] copy];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_needsSave];
               _webpageURL = [[coder decodeObject] copy];
               _keywords = [[coder decodeObject] copy];
               _expirationDate = [[coder decodeObject] copy];
               _referrerURL = [[coder decodeObject] copy];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_eligibleForHandoff];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_eligibleForSearch];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_eligibleForPublicIndexing];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_supportsContinuationOnPhone];
               [coder decodeValueOfObjCType: @encode(BOOL) at: &_invalidated];
            }
         _delegate = nil;
      }
   return self;
}

@end

