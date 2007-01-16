/* Interface of NSDistributedNotificationCenter class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
   */

#ifndef __NSDistributedNotificationCenter_h_GNUSTEP_BASE_INCLUDE
#define __NSDistributedNotificationCenter_h_GNUSTEP_BASE_INCLUDE

#ifndef	STRICT_OPENSTEP

#include	<Foundation/NSObject.h>
#include	<Foundation/NSLock.h>
#include	<Foundation/NSNotification.h>


/**
 *  Enumeration of possible values for specifying how
 *  [NSDistributedNotificationCenter] deals with notifications when the
 *  process to which the notification should be delivered is suspended:
 <example>
 {
  NSNotificationSuspensionBehaviorDrop,       // drop the notification
  NSNotificationSuspensionBehaviorCoalesce,   // drop all for this process but the latest-sent notification
  NSNotificationSuspensionBehaviorHold,       // queue all notifications for this process until it is resumed
  NSNotificationSuspensionBehaviorDeliverImmediately  // resume the process and deliver
}
 </example>
 */
typedef enum {
  NSNotificationSuspensionBehaviorDrop,
  NSNotificationSuspensionBehaviorCoalesce,
  NSNotificationSuspensionBehaviorHold,
  NSNotificationSuspensionBehaviorDeliverImmediately
} NSNotificationSuspensionBehavior;

/**
 *  Type for [NSDistributedNotificationCenter+notificationCenterForType:] -
 *  localhost current user broadcast only.  This is the only type on OS X.
 */
GS_EXPORT NSString* const NSLocalNotificationCenterType;
#ifndef NO_GNUSTEP

/**
 *  Type of [NSDistributedNotificationCenter+notificationCenterForType:] -
 *  all users on the local host.  This type is available only on GNUstep.
 */
GS_EXPORT NSString* const GSPublicNotificationCenterType;

/**
 *  Type of [NSDistributedNotificationCenter+notificationCenterForType:] -
 *  localhost and LAN broadcast.  This type is available only on GNUstep.
 */
GS_EXPORT NSString* const GSNetworkNotificationCenterType;
#endif

@interface	NSDistributedNotificationCenter : NSNotificationCenter
{
  NSRecursiveLock *_centerLock;	/* For thread safety.		*/
  NSString	*_type;		/* Type of notification center.	*/
  id		_remote;	/* Proxy for center.		*/
  BOOL		_suspended;	/* Is delivery suspended?	*/
}
+ (NSNotificationCenter*) defaultCenter;
+ (NSNotificationCenter*) notificationCenterForType: (NSString*)type;

- (void) addObserver: (id)anObserver
	    selector: (SEL)aSelector
		name: (NSString*)notificationName
	      object: (NSString*)anObject;
- (void) addObserver: (id)anObserver
	    selector: (SEL)aSelector
		name: (NSString*)notificationName
	      object: (NSString*)anObject
  suspensionBehavior: (NSNotificationSuspensionBehavior)suspensionBehavior;
- (void) postNotification: (NSNotification*)notification;
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject;
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo;
- (void) postNotificationName: (NSString*)notificationName
		       object: (NSString*)anObject
		     userInfo: (NSDictionary*)userInfo
	   deliverImmediately: (BOOL)deliverImmediately;
- (void) removeObserver: (id)anObserver
		   name: (NSString*)notificationName
		 object: (NSString*)anObject;
- (void) setSuspended: (BOOL)flag;
- (BOOL) suspended;

@end

#endif
#endif

