/* Interface to object for broadcasting Notification objects
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

   This file is part of the Gnustep Base Library.

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

#ifndef __NotificationDispatcher_h_GNUSTEP_BASE_INCLUDE
#define __NotificationDispatcher_h_GNUSTEP_BASE_INCLUDE

/* A class for posting notifications to observer objects that request 
   them.

   This implementation has several advantages over OpenStep's
   NSNotificationCenter:

   (1) Heavy use of hash tables and the use of LinkedList's make it 
       faster.  Removing from the middle of LinkedList's is much more
       efficient than removing from the middle of Array's.

   (2) The way in which notifications are dispatched can be specified as
       invocation objects instead of just selectors.  Invocation objects
       are more flexible than selectors in that they can hold more context
       and, if desired, can call C functions instead of sending a message
       to an object; (this way you may be able to avoid creating a new
       class just to handle certain notifications).

   (3) Instead of sending +defaultCenter, you can simply send +add..., 
       +remove... and +post... messages directly to the class object.
       The class uses a static variable directly, instead of taking
       the time for the extra +defaultCenter method call.  It's both
       easier for the user and more time efficient.

   (4) You can call -addObserver:... with both name and object being
       nil.  This request will receive postings of *all* notifications.
       Wow.

   Although it offers extra features, the implementation has an 
   OpenStep-style interface also.

   */

#include <gnustep/base/preface.h>
#include <gnustep/base/LinkedList.h>
#include <gnustep/base/Array.h>
#include <Foundation/NSMapTable.h>
#include <gnustep/base/NSString.h>

@interface NotificationDispatcher : NSObject
{
  /* `nr' stands for Notification Request Object; the interface for
      this class is defined in the .m file.  One of these is created
      for each -add... call. */

  /* For those observer requests with NAME=nil and OBJECT=nil. */
  LinkedList *_anonymous_nr_list;
  /* For those observer requests with NAME=nil and OBJECT!=nil. */
  NSMapTable *_object_2_nr_list;
  /* For those observer requests with NAME!=nil, OBJECT may or may not =nil .*/
  NSMapTable *_name_2_nr_list;

  /* The keys are observers; the values are Array's containing all
     NotificationInvocation objects associated with the observer key. */
  NSMapTable *_observer_2_nr_array;
}


/* Adding new observers. */

/* Register INVOCATION to receive future notifictions that match NAME
   and OBJECT.  A nil passed as either NAME or OBJECT acts as a
   wild-card.  If NAME is nil, the NotificationDispatcher will send to
   the observer all notification pertaining to OBJECT.  If OBJECT is
   nil, the NotificationDispatcher will send to the observer all
   notification pertaining to NAME.  If both OBJECT and NAME are nil,
   send to the observer all notifications.

   The notification will be posted by sending -invokeWithObject: to
   INVOCATION argument.  The argument of -invokeWithObject: will be a
   Notification object.  This use of Invocation objects is more
   flexible than using a selector, since Invocation's can be set up
   with more arguments, hold more context, and can be C functions.

   OBJECT is not retained; this is done so these objects can tell when
   there are no outstanding non-notification references remaining.  If
   an object may have added itself as an observer, it should call
   +removeObserver: in its -dealloc method.

   INVOCATION and NAME, however, are retained. */

- (void) addInvocation: (id <Invoking>)invocation
                  name: (id <String>)name
	        object: object;

/* Register OBSERVER to receive future notifications that match NAME
   and OBJECT.  A nil passed as either NAME or OBJECT acts as a
   wild-card.  If NAME is nil, the NotificationDispatcher will send to
   the observer all notification pertaining to OBJECT.  If OBJECT is
   nil, the NotificationDispatcher will send to the observer all
   notification pertaining to NAME.  If both OBJECT and NAME are nil,
   send to the observer all notifications.

   The notification will be posted by sending -perform:withObject:
   to the observer, with SEL and a Notification object as arguments. 

   Neither OBSERVER nor OBJECT are retained; this is done so these
   objects can tell when there are no outstanding non-notification
   references remaining.  If an object may have added itself as an
   observer, it should call +removeObserver: in its -dealloc method.

   INVOCATION and NAME, however, are retained. */

- (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object;

/* Class versions of the above two methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) addInvocation: (id <Invoking>)invocation
                  name: (id <String>)name
	        object: object;
+ (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object;



/* Removing observers. */

/* Remove all notification requests that would be sent to INVOCATION. */ 

- (void) removeInvocation: invocation;

/* Remove the notification requests matching NAME and OBJECT that
   would be sent to INVOCATION.  As with adding an observation
   request, nil NAME or OBJECT act as wildcards. */

- (void) removeInvocation: invocation
                     name: (id <String>)name
                   object: object;

/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: observer;

/* Remove the notification requests for the given NAME and OBJECT
   parameters.  As with adding an observation request, nil NAME or
   OBJECT act as wildcards. */

- (void) removeObserver: observer
		   name: (id <String>)name
                 object: object;

/* Class versions of the above four methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) removeInvocation: invocation;
+ (void) removeInvocation: invocation
                     name: (id <String>)name
                   object: object;
+ (void) removeObserver: observer;
+ (void) removeObserver: observer
		   name: (id <String>)name
                 object: object;



/* Post NOTIFICATION to all the observers that match its NAME and OBJECT. 
   The INFO arguent does not have to be a Dictionary.  If there is a single 
   object that should be associated with the notification, you can simply
   pass that single object instead of a Dictionary containing the object. */

- (void) postNotification: notification;
- (void) postNotificationName: (id <String>)name 
		       object: object;
- (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: info;

/* Class versions of the above three methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) postNotification: notification;
+ (void) postNotificationName: (id <String>)name 
		       object: object;
+ (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: info;

+ defaultInstance;

@end

@interface NotificationDispatcher (OpenStepCompat)
+ defaultCenter;
@end

#endif /* __NotificationDispatcher_h_GNUSTEP_BASE_INCLUDE */
