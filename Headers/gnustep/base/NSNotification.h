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

#include <gnustep/base/preface.h>
#include <gnustep/base/Notification.h>

@class NSString;
@class NSDictionary;

@interface NSNotification : NSObject
{
  /* Make the instance size of this class match exactly the instance
     size of Notification.  Thus, behavior_class_add_class() will not
     have to increase the instance size of NSNotification, and
     NSNotification can safely be subclassed. */
  char _NSNotification_placeholder[(sizeof(struct NSObject)
				    - sizeof(struct Notification))];
}
@end

/* Put this in a category to avoid unimportant errors due to behaviors. */
@interface NSNotification (GNUstep) <NSCopying>

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


/* Put this in a category to avoid unimportant errors due to behaviors. */
@interface NSNotificationCenter : NSObject
@end

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

#endif /*__NSNotification_h_GNUSTEP_BASE_INCLUDE */
