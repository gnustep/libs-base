/* Interface to object for broadcasting Notification objects
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

   This file is part of the GNU Objective C Class Library.

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

#ifndef __NotificationDispatcher_h_OBJECTS_INCLUDE
#define __NotificationDispatcher_h_OBJECTS_INCLUDE

/* A class for posting notifications to observer objects that request 
   them.

   This implementation has several advantages over OpenStep's
   NSNotificationCenter:

   (1) Heavier use of hash tables and the use of LinkedList's make it 
       faster.  Removing from the middle of LinkedList's is much more
       efficient than removing from the middle of Array's.

   (2) The way in which notifications are dispatched can be specified as
       invocation objects instead of just selectors.  Invocation objects
       are more flexible than selectors in that they can hold more context
       and, if desired, can call C functions instead of sending a message
       to an object, (this way you may be able to avoid creating a new
       class just to handle certain notifications).

   (3) Instead of sending +defaultCenter, you can simply send -add..., 
       -remove... and -post... messages directly to the class object.
       The class uses a static variable directly, instead of taking
       the time for the extra +defaultCenter method call.  It's both
       easier for the user and more time efficient.

   Although it offers extra features, the implementation has an 
   OpenStep-style interface also.

   */

#include <objects/stdobjects.h>
#include <objects/LinkedList.h>
#include <Foundation/NSMapTable.h>
#include <objects/NSString.h>

@interface NotificationDispatcher : NSObject
{
  /* For those observer requests with NAME=nil and OBJECT=nil. */
  LinkedList *anonymous_nr_list;
  /* For those observer requests with NAME=nil and OBJECT!=nil. */
  NSMapTable *object_2_nr_list;
  /* For those observer requests with NAME!=nil, OBJECT may or may not =nil .*/
  NSMapTable *name_2_nr_list;

  /* The keys are observers; the values are Array's containing all
     NotificationInvocation objects associated with the observer key. */
  NSMapTable *observer_2_nr_array;

  /* `nr' stands for Notification Request Object; the interface for
      this class is defined in the .m file.  One of these is created
      for each -add... call. */
}


/* Adding new observers. */

/* Register observer to receive future notifications that match NAME
   and OBJECT.  A nil passed as either NAME or OBJECT acts as a wild-card.
   If NAME is nil, send to the observer all notification pertaining to 
   OBJECT.  If OBJECT is nil, send to the observer all notification 
   pertaining to NAME.  If both OBJECT and NAME are nil, send to the 
   observer all notifications. 

   The notification will be posted by sending -invokeWithObject: to 
   INVOCATION argument.  The argument of -invokeWithObject: will be
   a Notification object.  This use of Invocation objects is more 
   flexible than using a selector, since Invocation's can be set up
   with more arguments, hold more context, and can be C functions.

   Typically, in cases that INVOCATION is a MethodInvocation, the 
   target of INVOCATION will the OBSERVER, but this is not required.
   When OBSERVER is not the same as the target, and is non-nil, it can
   still be useful for organizational help in removing a coherent set
   of observation requests, when used as an argument to -removeObserver:.

   Neither OBSERVER nor OBJECT are retained; this is so these objects
   can tell when there are no outstanding non-notification references
   remaining.  If an object may have added itself as an observer, it 
   should call +removeObserver: in its -dealloc method.

   INVOCATION and NAME, however, are retained. */

- (void) addObserver: observer
          invocation: (id <Invoking>)invocation
                name: (id <String>)name
	      object: object;

/* For those that want the simplicity of specifying a selector instead of
   an invocation as a way to contact the observer.

   The notification will be posted by sending -perform:withObject:
   to the observer, with SEL and OBJECT as arguments. 

   Comments above about retaining apply here also. */

- (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object;

/* Class versions of the above two methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) addObserver: observer
          invocation: (id <Invoking>)invocation
                name: (id <String>)name
	      object: object;
+ (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object;



/* Removing observers. */

/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: observer;

/* Remove the notification requests for the given parameters.  As with
   adding an observation request, nil NAME or OBJECT act as wildcards. */

- (void) removeObserver: observer
		   name: (id <String>)name
                 object: object;

/* Class versions of the above two methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) removeObserver: observer;
+ (void) removeObserver: observer
		   name: (id <String>)name
                 object: object;



/* Post NOTIFICATION to all the observers that match its NAME and OBJECT. */

- (void) postNotification: notification;
- (void) postNotificationName: (id <String>)name 
		       object: object;
- (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: (id <ConstantKeyedCollecting>)info_dictionary;

/* Class versions of the above two methods that send these messages
   to the default NotificationDispatcher for the class. */

+ (void) postNotification: notification;
+ (void) postNotificationName: (id <String>)name 
		       object: object;
+ (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: (id <ConstantKeyedCollecting>)info_dictionary;

@end

@interface NotificationDispatcher (OpenStepCompat)
+ defaultCenter;
@end

#endif /* __NotificationDispatcher_h_OBJECTS_INCLUDE */
