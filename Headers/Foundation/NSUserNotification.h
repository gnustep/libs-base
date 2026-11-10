/**Interface for NSUserNotification for GNUstep
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Marcus Mueller <znek@mulle-kybernetik.com>
   Date: 2014

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

#ifndef __NSUserNotification_h_INCLUDE
#define __NSUserNotification_h_INCLUDE

#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8,GS_API_LATEST)
#if __has_feature(objc_default_synthesize_properties)

#import <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif


@class NSString, NSDictionary, NSArray, NSDateComponents, NSDate, NSTimeZone, NSImage, NSAttributedString;
@class NSMutableArray;

@protocol NSUserNotificationCenterDelegate;

enum
{
  NSUserNotificationActivationTypeNone				= 0,
  NSUserNotificationActivationTypeContentsClicked		= 1,
  NSUserNotificationActivationTypeActionButtonClicked           = 2
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)
  ,NSUserNotificationActivationTypeReplied			= 3
#endif
};
typedef NSInteger NSUserNotificationActivationType;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10,GS_API_LATEST)
@interface NSUserNotificationAction : NSObject
{
  NSString *_identifier;
  NSString *_title;
}

@property (copy, readonly, nullable) NSString *identifier;
@property (copy, readonly, nullable) NSString *title;

+ (instancetype) actionWithIdentifier:(NSString *) identifier
                                title:(NSString *) title;

@end
#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_8,GS_API_LATEST) */

GS_EXPORT_CLASS
@interface NSUserNotification : NSObject <NSCopying>
{
  NSString *_title;
  NSString *_subtitle;
  NSString *_informativeText;
  NSImage *_contentImage;
  NSString *_identifier;

  BOOL _hasActionButton;
  NSString *_actionButtonTitle;
  NSString *_otherButtonTitle;
  BOOL _hasReplyButton;

  NSDate *_deliveryDate;
  NSDate *_actualDeliveryDate;
  NSDateComponents *_deliveryRepeatInterval;
  NSTimeZone *_deliveryTimeZone;
  
  BOOL _presented;
  BOOL _remote;
  NSString *_soundName;
  NSUserNotificationActivationType _activationType;
  NSUserNotificationAction *_additionalActivationAction;
  NSArray *_additionalActions;

  NSDictionary *_userInfo;

  NSAttributedString *_response;
  NSString *_responsePlaceholder;

#if	GS_EXPOSE(NSUserNotification)
  @public
  id _uniqueId;
#endif
}

@property (copy, nullable) NSString *title;
@property (copy, nullable) NSString *subtitle;
@property (copy, nullable) NSString *informativeText;
@property BOOL hasActionButton;
@property (copy) NSString *actionButtonTitle;
@property (copy) NSString *otherButtonTitle;

@property (copy, nullable) NSDate *deliveryDate;
@property (copy, nullable) NSDate *actualDeliveryDate;
@property (copy, nullable) NSDateComponents *deliveryRepeatInterval;
@property (copy, nullable) NSTimeZone *deliveryTimeZone;

@property (readonly, getter=isPresented) BOOL presented;
@property (readonly, getter=isRemote) BOOL remote;
@property (copy, nullable) NSString *soundName;

@property (readonly) NSUserNotificationActivationType activationType;

@property (copy, nullable) NSDictionary *userInfo;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)

@property (copy, nullable) NSImage *contentImage;
@property (copy, nullable) NSString *identifier;
@property BOOL hasReplyButton;
@property (copy, readonly, nullable) NSAttributedString *response;
@property (copy, nullable) NSString *responsePlaceholder;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10,GS_API_LATEST)

@property (copy, readonly, nullable) NSUserNotificationAction *additionalActivationAction;
@property (copy, nullable) NSArray *additionalActions;

#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_10,GS_API_LATEST) */
#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST) */

@end

GS_EXPORT NSString * const NSUserNotificationDefaultSoundName;

GS_EXPORT_CLASS
@interface NSUserNotificationCenter : NSObject
{
#if	GS_EXPOSE(NSUserNotificationCenter)
  NSMutableArray *_scheduledNotifications;
  NSMutableArray *_deliveredNotifications;
  id <NSUserNotificationCenterDelegate> _delegate;
#endif
}

+ (NSUserNotificationCenter *)defaultUserNotificationCenter;

@property (assign) id <NSUserNotificationCenterDelegate> delegate;
@property (copy) NSArray *scheduledNotifications;

- (void) scheduleNotification: (NSUserNotification *)notification;
- (void) removeScheduledNotification: (NSUserNotification *)notification;

@property (copy, readonly) NSArray *deliveredNotifications;

- (void) deliverNotification: (NSUserNotification *)notification;
- (void) removeDeliveredNotification: (NSUserNotification *)notification;
- (void) removeAllDeliveredNotifications;

@end


@protocol NSUserNotificationCenterDelegate <NSObject>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (NSUserNotificationCenterDelegateMethods)
#endif

- (void) userNotificationCenter: (NSUserNotificationCenter *)center
         didDeliverNotification: (NSUserNotification *)notification;
- (void) userNotificationCenter: (NSUserNotificationCenter *)center
        didActivateNotification: (NSUserNotification *)notification;
- (BOOL) userNotificationCenter: (NSUserNotificationCenter *)center
      shouldPresentNotification: (NSUserNotification *)notification;

@end

#if	defined(__cplusplus)
}
#endif

#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_8,GS_API_LATEST) */
#endif /* __has_feature(objc_default_synthesize_properties) */
#endif	/* __NSUserNotification_h_INCLUDE */
