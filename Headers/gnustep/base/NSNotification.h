/* Interface for NSNotification and NSNotificationCenter for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

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

#ifndef __NSNotification_h_GNUSTEP_BASE_INCLUDE
#define __NSNotification_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSString;
@class NSDictionary;

@protocol Notifying
- (NSString*) name;
- object;
- userInfo;
@end

@protocol NotificationPosting
- (void) postNotification: (id <Notifying>)notification;
@end

@interface NSNotification : NSObject <Notifying,NSCopying>
{
  id _name;
  id _object;
  id _info;
}

/* Creating a Notification Object */
+ (NSNotification*) notificationWithName: (NSString*)name
   object: object;

+ (NSNotification*) notificationWithName: (NSString*)name
   object: object
   userInfo: (NSDictionary*)user_info;

/* Querying a Notification Object */

- (NSString*) name;
- object;
- (NSDictionary*) userInfo;

@end


#include <base/NotificationDispatcher.h>

/* Put this in a category to avoid unimportant errors due to behaviors. */
@interface NSNotificationCenter : NSObject
  /* Make the instance size of this class match exactly the instance
     size of NotificationDispatcher.  Thus, behavior_class_add_class() will not
     have to increase the instance size of NSNotificationCenter, and
     NSNotificationCenter can safely be subclassed. */
  char _NSNotificationCenter_placeholder[(sizeof(struct NotificationDispatcher)
                                  - sizeof(struct NSObject))];

@end

#ifndef	NO_GNUSTEP
@interface NSNotificationCenter (GNUstep)

/* Getting the default NotificationCenter */

+ (NSNotificationCenter*) defaultCenter;

/* Adding and removing observers */

- (void) addObserver: anObserver
	    selector: (SEL)selector
                name: (NSString*)name
	      object: object;

- (void) removeObserver: anObserver;
- (void) removeObserver: anObserver
		   name: (NSString*)name
                 object: object;

/* Posting Notifications */

- (void) postNotification: (NSNotification*)aNotification;
- (void) postNotificationName: (NSString*)name
		       object: object;
- (void) postNotificationName: (NSString*)name
		       object: object
		     userInfo: (NSDictionary*)user_info;
@end
#endif

#endif /*__NSNotification_h_GNUSTEP_BASE_INCLUDE */
