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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#ifndef __NSDistributedNotificationCenter_h_GNUSTEP_BASE_INCLUDE
#define __NSDistributedNotificationCenter_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>
#include	<Foundation/NSLock.h>

@class	NSString;

typedef enum {
  NSNotificationSuspensionBehaviorDrop,
  NSNotificationSuspensionBehaviorCoalesce,
  NSNotificationSuspensionBehaviorHold,
  NSNotificationSuspensionBehaviorDeliverImmediately
} NSNotificationSuspensionBehavior;

extern NSString	*NSLocalNotificationCenterType;

@interface	NSDistributedNotificationCenter : NSObject
{
  NSRecursiveLock *centerLock;	/* For thread safety.		*/
  id		remote;		/* Proxy for center.		*/
  BOOL		suspended;	/* Is delivery suspended?	*/
}
+ (id) defaultCenter;
+ (id) notificationCenterForType: (NSString*)type;

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
- (void) setSuspended: (BOOL)suspended;
- (BOOL) suspended;

@end

#endif

