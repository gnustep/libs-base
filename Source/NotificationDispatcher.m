/* Implementation of object for broadcasting Notification objects
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

/* The implementation for NotificationDispatcher. */

/* NeXT says you can only have one NotificationCenter per task;
   I don't think GNU needs this restriction with its corresponding
   NotificationDistributor class. */

#include <gnustep/base/NotificationDispatcher.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/LinkedListNode.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Invocation.h>
#include <Foundation/NSException.h>


/* NotificationRequest class - One of these objects is created for
   each -addObserver... request.  It holds the requested invocation,
   name and object.  Each object is placed
   (1) in one LinkedList, as keyed by the NAME/OBJECT parameters (accessible
   through one of the ivars: anonymous_nr_list, object_2_nr_list, 
   name_2_nr_list), and 
   (2) in the Array, as keyed by the OBSERVER (as accessible through
   the ivar observer_2_nr_array.

   To post a notification in satisfaction of this request, 
   send -postNotification:.  */

@interface NotificationRequest : LinkedListNode
{
  int _retain_count;
  id _name;
  id _object;
}

- initWithName: n object: o;
- (NSString*) notificationName;
- notificationObject;
- (void) postNotification: n;
@end

@implementation NotificationRequest

- initWithName: n object: o
{
  [super init];
  _retain_count = 0;
  _name = [n retain];
  _object = o;
  /* Note that OBJECT is not retained.  See the comment for
     -addObserver... in NotificationDispatcher.h. */
  return self;
}

/* Implement these retain/release methods here for efficiency, since
   NotificationRequest's get retained and released by all their
   holders.  Doing this is a judgement call; I'm choosing speed over
   space. */

- retain
{
  _retain_count++;
  return self;
}

- (oneway void) release
{
  if (!_retain_count--)
    [self dealloc];
}

- (unsigned) retainCount
{
  return _retain_count;
}

- (void) dealloc
{
  [_name release];
  [super dealloc];
}

- (NSString*) notificationName
{
  return _name;
}

- notificationObject
{
  return _object;
}

- (void) postNotification: n
{
  [self subclassResponsibility: _cmd];
}

@end


@interface NotificationInvocation : NotificationRequest
{
  id _invocation;
}
- initWithInvocation: i name: n object: o;
@end

@implementation NotificationInvocation

- initWithInvocation: i name: n object: o
{
  [super initWithName: n object: o];
  _invocation = [i retain];
  return self;
}

- (void) dealloc
{
  [_invocation release];
  [super dealloc];
}

- (void) postNotification: n
{
  [_invocation invokeWithObject: n];
}

@end


@interface NotificationPerformer : NotificationRequest
{
  id _target;
  SEL _selector;
}
- initWithTarget: t selector: (SEL)s name: n object: o;
@end

@implementation NotificationPerformer

- initWithTarget: t selector: (SEL)s name: n object: o
{
  [super initWithName: n object: o];
  /* Note that TARGET is not retained.  See the comment for
     -addObserver... in NotificationDispatcher.h. */
  _target = t;
  _selector = s;
  return self;
}

- (void) postNotification: n
{
  [_target perform: _selector withObject: n];
}

@end




@implementation NotificationDispatcher

/* The default instance, most often the only one created.
   It is accessed by the class methods at the end of this file.
   There is no need to mutex locking of this variable. */
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
  _anonymous_nr_list = [LinkedList new];

  /* Use NSNonOwnedPointerOrNullMapKeyCallBacks so we won't retain
     the object.  We will, however, retain the values, which are
     LinkedList's. */
  _object_2_nr_list = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /* Use NSObjectMapKeyCallBacks so we retain the NAME.  We also retain
     the values, which are LinkedList's. */
  _name_2_nr_list = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  /* Use NSNonOwnedPointerOrNullMapKeyCallBacks so we won't retain
     the observer.  We will, however, retain the values, which are Array's. */
  _observer_2_nr_array = 
    NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
		      NSObjectMapValueCallBacks, 0);

  _lock = [NSRecursiveLock new];

  return self;
}

- (void) dealloc
{
  [_anonymous_nr_list release];
  NSFreeMapTable( _object_2_nr_list);
  NSFreeMapTable (_name_2_nr_list);
  NSFreeMapTable (_observer_2_nr_array);
  [_lock release];
  [super dealloc];
}


/* Adding new observers. */

/* This is the (private) designated method for adding observers.  If we 
   came from -addInvocation... then OBSERVER is actually an Invocation. */

- (void) _addObserver: observer
  notificationRequest: nr
                 name: (NSString*)name
	       object: object
{
  /* If observer is nil, there is nothing to do; return. */
  if (!observer)
    return;

  [_lock lock];

  /* Record the notification request in an array keyed by OBSERVER. */
  {
    /* Find the array of all the requests by OBSERVER. */
    Array *nr_array = NSMapGet (_observer_2_nr_array, observer);
    if (!nr_array)
      {
	nr_array = [Array new];
	/* nr_array is retained; observer is not. */
	NSMapInsert (_observer_2_nr_array, observer, nr_array);
	/* Now that nr_array is retained by the map table, release it;
	   this way the array will be completely released when the
	   map table is done with it. */
	[nr_array release];
      }
    [nr_array appendObject: nr];
  }

  /* Record the NotificationRequest in one of three MapTable->LinkedLists. */

  /* Record the request in one, and only one, LinkedList.  The LinkedList
     is stored in a hash table accessed by a key.  Which key is used
     depends on what combination of NAME and OBJECT are non-nil. */
  if (!name)
    {
      if (!object)
	{
	  /* This NotificationRequest will get posted notifications
	     for all NAME and OBJECT combinations. */
	  [_anonymous_nr_list appendObject: nr];
	}
      else
	{
	  LinkedList *nr_list = NSMapGet (_object_2_nr_list, object);
	  if (!nr_list)
	    {
	      nr_list = [LinkedList new];
	      /* nr_list is retained; object is not retained. */
	      NSMapInsert (_object_2_nr_list, object, nr_list);
	      /* Now that nr_list is retained by the map table, release it;
		 this way the list will be completely released when the
		 map table is done with it. */
	      [nr_list release];
	    }
	  [nr_list appendObject: nr];
	}
    }
  else
    {
      LinkedList *nr_list = NSMapGet (_name_2_nr_list, name);
      if (!nr_list)
	{
	  nr_list = [LinkedList new];
	  /* nr_list is retained; object is not retained. */
	  NSMapInsert (_name_2_nr_list, name, nr_list);
	  /* Now that nr_list is retained by the map table, release it;
	     this way the list will be completely released when the
	     map table is done with it. */
	  [nr_list release];
	}
      [nr_list appendObject: nr];
    }

  [_lock unlock];
}

- (void) addInvocation: (id <Invoking>)invocation
		  name: (NSString*)name
                object: object
{
  id nr;

  /* Create the NotificationRequest object that will hold this
     observation request.  This will retain INVOCATION and NAME. */
  nr = [[NotificationInvocation alloc] 
	 initWithInvocation: invocation
	 name: name
	 object: object];

  /* Record it in all the right places. */
  [self _addObserver: invocation
	notificationRequest: nr
	name: name
	object: object];

  /* Since nr was retained when it was added to the Array and
     LinkedList above, we can release it now. */
  [nr release];
}


/* For those that want to specify a selector instead of an invocation
   as a way to contact the observer. */

- (void) addObserver: observer
            selector: (SEL)sel
                name: (NSString*)name
	      object: object
{
  id nr;

  /* Create the NotificationRequest object that will hold this
     observation request.  This will retain INVOCATION and NAME. */
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

  /* Since nr was retained when it was added to the Array and
     LinkedList above, we can release it now. */
  [nr release];
}


/* Removing objects. */

/* A private method.
   Remove the NR object from its one LinkedList; if this is the last
   element of that LinkedList, and the LinkedList is map-accessible,
   also release the LinkedList. */

- (void) _removeFromLinkedListNotificationRequest: nr
{
  id nr_list = [nr linkedList];

  /* See if, instead of removing the NR from its LinkedList, we can
     actually release the entire list. */
  if ([nr_list count] == 1
      && nr_list != _anonymous_nr_list)
    {
      id nr_name;
      id nr_object;
      LinkedList *mapped_nr_list;

      assert ([nr_list firstObject] == nr);
      if ((nr_name = [nr notificationName]))
	{
	  mapped_nr_list = NSMapGet (_name_2_nr_list, nr_name);
	  assert (mapped_nr_list == nr_list);
	  NSMapRemove (_name_2_nr_list, nr_name);
	}
      else 
	{
	  nr_object = [nr notificationObject];
	  assert (nr_object);
	  mapped_nr_list = NSMapGet (_object_2_nr_list, nr_object);
	  assert (mapped_nr_list == nr_list);
	  NSMapRemove (_object_2_nr_list, nr_object);
	}
    }
  else
    [nr_list removeObject: nr];
}


/* Removing notification requests. */

/* Remove all notification requests that would be sent to INVOCATION. */ 

- (void) removeInvocation: invocation
{
  [self removeObserver: invocation];
}

/* Remove the notification requests matching NAME and OBJECT that
   would be sent to INVOCATION.  As with adding an observation
   request, nil NAME or OBJECT act as wildcards. */

- (void) removeInvocation: invocation
                     name: (NSString*)name
                   object: object
{
  [self removeObserver: invocation
	name: name
	object: object];
}



/* Remove all records pertaining to OBSERVER.  For instance, this 
   should be called before the OBSERVER is -dealloc'ed. */

- (void) removeObserver: observer
{
  Array *observer_nr_array;
  NotificationRequest *nr;

  /* If OBSERVER is nil, do nothing; just return.  NOTE: This *does not*
     remove all requests with a nil OBSERVER; it would be too easy to
     unintentionally remove other's requests that way.  If you need to
     remove a request with a nil OBSERVER, use -removeObserver:name:object: */
  if (!observer)
    return;

  [_lock lock];

  /* Get the array of NotificationRequest's associated with OBSERVER. */
  observer_nr_array = NSMapGet (_observer_2_nr_array, observer);

  if (!observer_nr_array)
    /* OBSERVER was never registered for any notification requests with us.
       Nothing to do. */
    return;

  /* Remove each of these from it's LinkedList. */
  FOR_ARRAY (observer_nr_array, nr)
    {
      [self _removeFromLinkedListNotificationRequest: nr];
    }
  END_FOR_ARRAY (observer_nr_array);

  /* Remove from the MapTable the list of NotificationRequest's
     associated with OBSERVER.  This also releases the observer_nr_array,
     and its contents. */
  NSMapRemove (_observer_2_nr_array, observer);

  [_lock unlock];
}


/* Remove the notification requests for the given parameters.  As with
   adding an observation request, nil NAME or OBJECT act as wildcards. */

- (void) removeObserver: observer
		   name: (NSString*)name
                 object: object
{
  Array *observer_nr_array;

  /* If both NAME and OBJECT are nil, this call is the same as 
     -removeObserver:, so just call it. */
  if (!name && !object)
    [self removeObserver: observer];

  /* We are now guaranteed that at least one of NAME and OBJECT is non-nil. */

  [_lock lock];

  /* Get the list of NotificationRequest's associated with OBSERVER. */
  observer_nr_array = NSMapGet (_observer_2_nr_array, observer);

  if (!observer_nr_array)
    /* OBSERVER was never registered for any notification requests with us.
       Nothing to do. */
    return;

  /* Find those NotificationRequest's from the array that
     match NAME and OBJECT, and remove them from the array and 
     their linked list. */
  /* xxx If we thought the LinkedList from the map table keyed on NAME
     would be shorter, we could use that instead. */
  {
    NotificationRequest *nr;
    int count = [observer_nr_array count];
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
	    [self _removeFromLinkedListNotificationRequest: nr];
	  }
      }
    /* xxx If there are some LinkedList's that are empty, I should
       remove them from the map table's. */
  }

  [_lock unlock];
}


/* Post NOTIFICATION to all the observers that match its NAME and OBJECT. */

- (void) postNotification: notification
{
  /* This cast avoids complaints about different types for the -name method. */
  id notification_name = [(Notification*)notification name];
  id notification_object = [notification object];
  id nr;
  LinkedList *nr_list;

  /* Make sure the notification has a name. */
  if (!notification_name)
    [NSException raise: NSInvalidArgumentException
		 format: @"Tried to post a notification with no name."];

  [_lock lock];

  /* Post the notification to all the observers that specified neither
     NAME or OBJECT. */
  if ([_anonymous_nr_list count])
    {
      FOR_COLLECTION (_anonymous_nr_list, nr)
	{
	  [nr postNotification: notification];
	}
      END_FOR_COLLECTION (_anonymous_nr_list);
    }

  /* Post the notification to all the observers that specified OBJECT,
     but didn't specify NAME. */
  if (notification_object)
    {
      nr_list = NSMapGet (_object_2_nr_list, notification_object);
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
  nr_list = NSMapGet (_name_2_nr_list, notification_name);
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

  [_lock unlock];
}

- (void) postNotificationName: (NSString*)name 
		       object: object
{
  [self postNotification: [Notification notificationWithName: name
					object: object]];
}

- (void) postNotificationName: (NSString*)name 
		       object: object
		     userInfo: info
{
  [self postNotification: [Notification notificationWithName: name
					object: object
					userInfo: info]];
}



/* Class methods. */

+ defaultInstance
{
  return default_notification_dispatcher;
}

+ (void) addInvocation: (id <Invoking>)invocation
		  name: (NSString*)name
                object: object
{
  [default_notification_dispatcher addInvocation: invocation
				   name: name
				   object: object];
}

+ (void) addObserver: observer
            selector: (SEL)sel
                name: (NSString*)name
	      object: object
{
  [default_notification_dispatcher addObserver: observer
				   selector: sel
				   name: name
				   object: object];
}

+ (void) removeInvocation: invocation
{
  [default_notification_dispatcher removeInvocation: invocation];
}

+ (void) removeInvocation: invocation
                     name: (NSString*)name
                   object: object
{
  [default_notification_dispatcher removeInvocation: invocation
				   name: name
				   object: object];
}

+ (void) removeObserver: observer
{
  [default_notification_dispatcher removeObserver: observer];
}

+ (void) removeObserver: observer
		   name: (NSString*)name
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

+ (void) postNotificationName: (NSString*)name 
		       object: object
{
  [default_notification_dispatcher postNotificationName: name
				   object: object];
}

+ (void) postNotificationName: (NSString*)name 
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
