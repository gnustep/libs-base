/* Implementation of object for broadcasting Notification objects
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

#include <objects/NotificationDispatcher.h>
#include <objects/Notification.h>
#include <objects/LinkedListNode.h>
#include <objects/Array.h>
#include <objects/Invocation.h>
#include <Foundation/NSException.h>

/* The implementation for NotificationDispatcher.

   First we define an object for holding the observer's 
   notification requests: */


/* One of these objects is created for each -addObserver... request.
   It holds the requested invocation, name and object.  Each object
   is placed
   (1) in one LinkedList, as keyed by the NAME/OBJECT parameters (accessible
   through one of the ivars: anonymous_nr_list, object_2_nr_list, 
   name_2_nr_list), and 
   (2) in the Array, as keyed by the OBSERVER (as accessible through
   the ivar observer_2_nr_array.

   To post a notification in satisfaction of this request, 
   send -postNotification:.
   */

@interface NotificationRequest : LinkedListNode
{
  int retain_count;
  id name;
  id object;
}

- initWithName: n object: o;
- (id <String>) notificationName;
- notificationObject;
- (void) postNotification: n;
@end

@implementation NotificationRequest

- initWithName: n object: o
{
  [super init];
  retain_count = 0;
  name = [n retain];
  object = o;
  /* Note that OBJECT is not retained.  See the comment for
     -addObserver... in NotificationDispatcher.h. */
  return self;
}

/* Implement these retain/release methods here for efficiency, since
   NotificationInvocation's get retained and released by all their
   holders.  Doing this is a judgement call; I'm choosing speed over
   space. */

- retain
{
  retain_count++;
  return self;
}

- (oneway void) release
{
  if (!retain_count--)
    [self dealloc];
}

- (unsigned) retainCount
{
  return retain_count;
}

- (void) dealloc
{
  [name release];
  [super dealloc];
}

- (id <String>) notificationName
{
  return name;
}

- notificationObject
{
  return object;
}

- (void) postNotification: n
{
  [self subclassResponsibility: _cmd];
}

@end


@interface NotificationInvocation : NotificationRequest
{
  id invocation;
}
- initWithInvocation: i name: n object: o;
@end

@implementation NotificationInvocation

- initWithInvocation: i name: n object: o
{
  [super initWithName: n object: o];
  invocation = [i retain];
  return self;
}

- (void) dealloc
{
  [invocation release];
  [super dealloc];
}

- (void) postNotification: n
{
  [invocation invokeWithObject: n];
}

@end


@interface NotificationPerformer : NotificationRequest
{
  id target;
  SEL selector;
}
- initWithTarget: t selector: (SEL)s name: n object: o;
@end

@implementation NotificationPerformer

- initWithTarget: t selector: (SEL)s name: n object: o
{
  [super initWithName: n object: o];
  /* Note that TARGET is not retained.  See the comment for
     -addObserver... in NotificationDispatcher.h. */
  target = t;
  selector = s;
  return self;
}

- (void) postNotification: n
{
  [target perform: selector withObject: n];
}

@end




@implementation NotificationDispatcher

/* The default instance, most often the only one created.
   It is accessed by the class methods at the end of this file. */
static NotificationDispatcher *default_notification_dispatcher = nil;

+ (void) initialize
{
  if (self == [NotificationDispatcher class])
    default_notification_dispatcher = [self new];
}



/* Initializing. */

- init
{
  [super init];
  anonymous_nr_list = [LinkedList new];

  /* Use NSNonOwnedPointerOrNullMapKeyCallBacks so we won't retain
     the object.  We will, however, retain the LinkedList's. */
  object_2_nr_list = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /* Likewise. */
  /* xxx Should we retain NAME here after all? */
  name_2_nr_list = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /* Likewise. */
  observer_2_nr_array = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  return self;
}


/* Adding new observers. */

/* This is the designated method for adding observers. */
- (void) _addObserver: observer
  notificationRequest: nr
                 name: (id <String>)name
	       object: object
{
  /* Record the request in an array of all the requests by this observer. */
  if (observer)
    {
      Array *nr_array = NSMapGet (observer_2_nr_array, observer);
      if (!nr_array)
	{
	  nr_array = [Array new];
	  /* nr_array is retained; observer is not. */
	  NSMapInsert (observer_2_nr_array, observer, nr_array);
	  [nr_array release];
	}
      [nr_array appendObject: nr];
    }     

  /* Record the request in one, and only one, LinkedList.  The LinkedList
     is stored in a hash table accessed by a key.  Which key is used
     depends on what combination of NAME and OBJECT are non-nil. */
  if (!name)
    {
      if (!object)
	{
	  [anonymous_nr_list appendObject: nr];
	}
      else
	{
	  LinkedList *nr_list = NSMapGet (object_2_nr_list, object);
	  if (!nr_list)
	    {
	      nr_list = [LinkedList new];
	      /* nr_list is retained; object is not retained. */
	      NSMapInsert (object_2_nr_list, object, nr_list);
	      [nr_list release];
	    }
	  [nr_list appendObject: nr];
	}
    }
  else
    {
      LinkedList *nr_list = NSMapGet (name_2_nr_list, name);
      if (!nr_list)
	{
	  nr_list = [LinkedList new];
	  /* nr_list is retained; object is not retained. */
	  NSMapInsert (name_2_nr_list, name, nr_list);
	  [nr_list release];
	}
      [nr_list appendObject: nr];
    }

  /* Since nr was retained when it was added to the collection above,
     we can release it now. */
  [nr release];
}

- (void) addObserver: observer
          invocation: (id <Invoking>)invocation
                name: (id <String>)name
	      object: object
{
  /* The NotificationInvocation we create to hold this request. */
  id nr;

  /* Create the NotificationInvocation object that will hold
     this observation request.  This will retain INVOCATION and NAME. */
  nr = [[NotificationInvocation alloc] 
	 initWithInvocation: invocation
	 name: name
	 object: object];

  /* Record it in all the right places. */
  [self _addObserver: observer
	notificationRequest: nr
	name: name
	object: object];
}


/* For those that want to specify a selector instead of an invocation
   as a way to contact the observer. 
   If for some reason we didn't want to use Invocation's, we could 
   additionally create another kind of "NotificationInvocation" that 
   just used selector's instead. */

- (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object
{
  /* The NotificationInvocation we create to hold this request. */
  id nr;

  /* Create the NotificationInvocation object that will hold
     this observation request.  This will retain INVOCATION and NAME. */
  nr = [[NotificationPerformer alloc] 
	 initWithTarget: observer
	 selector: sel
	 name: name
	 object: object];

  /* Record it in all the right places. */
  [self _addObserver: observer
	notificationRequest: nr
	name: name
	object: object];
}


/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: observer
{
  Array *observer_nr_array;
  NotificationInvocation *nr;

  /* Get the array of NotificationInvocation's associated with OBSERVER. */
  observer_nr_array = NSMapGet (observer_2_nr_array, observer);

  if (!observer_nr_array)
    /* OBSERVER was never registered for any notification requests with us.
       Nothing to do. */
    return;

  /* Remove each of these from it's LinkedList. */
  FOR_ARRAY (observer_nr_array, nr)
    {
      [[nr linkedList] removeObject: nr];
    }
  END_FOR_ARRAY (observer_nr_array);

  /* Remove from the MapTable the list of NotificationInvocation's
     associated with OBSERVER.  This also releases the observer_nr_array,
     and its contents. */
  NSMapRemove (observer_2_nr_array, observer);
}


/* Remove the notification requests for the given parameters.  As with
   adding an observation request, nil NAME or OBJECT act as wildcards. */

- (void) removeObserver: observer
		   name: (id <String>)name
                 object: object
{
  Array *observer_nr_array;
  NotificationInvocation *nr;

  /* Get the list of NotificationInvocation's associated with OBSERVER. */
  observer_nr_array = NSMapGet (observer_2_nr_array, observer);

  if (!observer_nr_array)
    /* OBSERVER was never registered for any notification requests with us.
       Nothing to do. */
    return;

  /* Find those NotificationInvocation's from the array that
     match NAME and OBJECT, and remove them from the array and 
     their linked list. */
  {
    NotificationInvocation *nr;
    int count = [observer_nr_array count];
    unsigned matching_nr_indices[count];
    int i;

    for (i = count-1; i >= 0; i--)
      {
	nr = [observer_nr_array objectAtIndex: i];
	if ((!name || [name isEqual: [nr notificationName]])
	    && (!object || [object isEqual: [nr notificationObject]]))
	  {
	    /* We can remove from the array, even though we are "enumerating" 
	       over it, because we are enumerating from back-to-front, 
	       and the indices of yet-to-come objects don't change when
	       high-indexed objects are removed. */
	    [observer_nr_array removeObjectAtIndex: i];
	    [[nr linkedList] removeObject: nr];
	  }
      }
    /* xxx If there are some LinkedList's that are empty, I should
       remove them from the map table's. */
  }
}


/* Post NOTIFICATION to all the observers that match its NAME and OBJECT. */

- (void) postNotification: notification
{
  /* This cast avoids complaints about different types for -name. */
  id notification_name = [(Notification*)notification name];
  id notification_object = [notification object];
  id nr;
  LinkedList *nr_list;

  /* Make sure the notification has a name. */
  if (!notification_name)
    [NSException raise: NSInvalidArgumentException
		 format: @"Tried to post a notification with no name."];

  /* Post the notification to all the observers that specified neither
     NAME or OBJECT. */
  if ([anonymous_nr_list count])
    {
      FOR_COLLECTION (anonymous_nr_list, nr)
	{
	  [nr postNotification: notification];
	}
      END_FOR_COLLECTION (anonymous_nr_list);
    }

  /* Post the notification to all the observers that specified OBJECT,
     but didn't specify NAME. */
  if (notification_object)
    {
      nr_list = NSMapGet (object_2_nr_list, notification_object);
      if (nr_list)
	{
	  FOR_COLLECTION (nr_list, nr)
	    {
	      [nr postNotification: notification];
	    }
	  END_FOR_COLLECTION (nr_list);
	}
    }

  /* Post the notification to all the observers of NAME; (and if the
     observer's OBJECT is non-nil, don't send unless the observer's OBJECT
     matches the notification's OBJECT). */
  nr_list = NSMapGet (name_2_nr_list, notification_name);
  if (nr_list)
    {
      FOR_COLLECTION (nr_list, nr)
	{
	  id nr_object = [nr notificationObject];
	  if (!nr_object || nr_object == notification_object)
	    [nr postNotification: notification];
	}
      END_FOR_COLLECTION (nr_list);
    }
}

- (void) postNotificationName: (id <String>)name 
		       object: object
{
  [self postNotification: [Notification notificationWithName: name
					object: object]];
}

- (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: info
{
  [self postNotification: [Notification notificationWithName: name
					object: object
					userInfo: info]];
}



/* Class methods. */

+ (void) addObserver: observer
          invocation: (id <Invoking>)invocation
                name: (id <String>)name
	      object: object
{
  [default_notification_dispatcher addObserver: observer
				   invocation: invocation
				   name: name
				   object: object];
}

+ (void) addObserver: observer
            selector: (SEL)sel
                name: (id <String>)name
	      object: object
{
  [default_notification_dispatcher addObserver: observer
				   selector: sel
				   name: name
				   object: object];
}

+ (void) removeObserver: observer
{
  [default_notification_dispatcher removeObserver: observer];
}

+ (void) removeObserver: observer
		   name: (id <String>)name
                 object: object
{
  [default_notification_dispatcher removeObserver: observer
				   name: name
				   object: object];
}

+ (void) postNotification: notification
{
  [default_notification_dispatcher postNotification: notification];
}

+ (void) postNotificationName: (id <String>)name 
		       object: object
{
  [default_notification_dispatcher postNotificationName: name
				   object: object];
}

+ (void) postNotificationName: (id <String>)name 
		       object: object
		     userInfo: info
{
  [default_notification_dispatcher postNotificationName: name
				   object: object
				   userInfo: info];
}

@end

@implementation NotificationDispatcher (OpenStepCompat)

/* For OpenStep compatibility. */
+ defaultCenter
{
  return default_notification_dispatcher;
}

@end
