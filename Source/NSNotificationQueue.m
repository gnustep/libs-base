/** Implementation for NSNotificationQueue for GNUStep
   Copyright (C) 1995-1999 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1995
   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997
   Rewritten: 1999

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSNotificationQueue class reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSNotificationQueue.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSString.h"
#include "Foundation/NSThread.h"

#include "GSPrivate.h"
/* NotificationQueueList by Richard Frith-Macdonald
   These objects are used to maintain lists of NSNotificationQueue objects.
   There is one list per NSThread, with the first object in the list stored
   in the thread dictionary and accessed using the key below.
   */

static	NSString*	lkey = @"NotificationQueueListThreadKey";
static	NSString*	qkey = @"NotificationQueueThreadKey";

typedef struct {
  @defs(NSNotificationQueue)
} *accessQueue;


@interface	NotificationQueueList : NSObject
{
@public
  NotificationQueueList	*next;
  NSNotificationQueue	*queue;
}
+ (void) registerQueue: (NSNotificationQueue*)q;
+ (void) unregisterQueue: (NSNotificationQueue*)q;
@end

static NotificationQueueList*
currentList(void)
{
  NotificationQueueList	*list;
  NSMutableDictionary	*d;

  d = GSCurrentThreadDictionary();
  list = (NotificationQueueList*)[d objectForKey: lkey];
  if (list == nil)
    {
      list = [NotificationQueueList new];
      [d setObject: list forKey: lkey];
      RELEASE(list);	/* retained in dictionary.	*/
    }
  return list;
}

@implementation	NotificationQueueList

- (void) dealloc
{
  while (next != nil)
    {
      NotificationQueueList	*tmp = next;

      next = tmp->next;
      RELEASE(tmp);
    }
  [super dealloc];
}

+ (void) registerQueue: (NSNotificationQueue*)q
{
  NotificationQueueList	*list;
  NotificationQueueList	*elem;

  list = currentList();	/* List of queues for thread.	*/

  if (list->queue == nil)
    {
      list->queue = q;		/* Make this the default.	*/
    }

  while (list->queue != q && list->next != nil)
    {
      list = list->next;
    }

  if (list->queue == q)
    {
      return;			/* Queue already registered.	*/
    }

  elem = (NotificationQueueList*)NSAllocateObject(self, 0,
    NSDefaultMallocZone());
  elem->queue = q;
  list->next = elem;
}

+ (void) unregisterQueue: (NSNotificationQueue*)q
{
  NotificationQueueList	*list;

  list = currentList();

  if (list->queue == q)
    {
      NSMutableDictionary	*d;

      d = GSCurrentThreadDictionary();
      if (list->next)
        {
	  NotificationQueueList	*tmp = list->next;

          [d setObject: tmp forKey: lkey];
	  RELEASE(tmp);			/* retained in dictionary.	*/
        }
      else
	{
	  [d removeObjectForKey: lkey];
	}
    }
  else
    {
      while (list->next != nil)
	{
	  if (list->next->queue == q)
	    {
	      NotificationQueueList	*tmp = list->next;

	      list->next = tmp->next;
	      RELEASE(tmp);
	      break;
	    }
	}
    }
}

@end

/*
 * NSNotificationQueue queue
 */

typedef struct _NSNotificationQueueRegistration
{
  struct _NSNotificationQueueRegistration	*next;
  struct _NSNotificationQueueRegistration	*prev;
  NSNotification				*notification;
  id						name;
  id						object;
  NSArray					*modes;
} NSNotificationQueueRegistration;

struct _NSNotificationQueueList;

typedef struct _NSNotificationQueueList
{
  struct _NSNotificationQueueRegistration	*head;
  struct _NSNotificationQueueRegistration	*tail;
} NSNotificationQueueList;

/*
 * Queue functions
 *
 *  Queue             Elem              Elem              Elem
 *    head ---------> prev -----------> prev -----------> prev --> nil
 *            nil <-- next <----------- next <----------- next
 *    tail --------------------------------------------->
 */

static inline void
remove_from_queue_no_release(NSNotificationQueueList *queue,
  NSNotificationQueueRegistration *item)
{
  if (item->prev)
    {
      item->prev->next = item->next;
    }
  else
    {
      queue->tail = item->next;
      if (item->next)
	{
	  item->next->prev = NULL;
	}
    }

  if (item->next)
    {
      item->next->prev = item->prev;
    }
  else
    {
      queue->head = item->prev;
      if (item->prev)
	{
	  item->prev->next = NULL;
	}
    }
}

static void
remove_from_queue(NSNotificationQueueList *queue,
  NSNotificationQueueRegistration *item, NSZone *_zone)
{
  remove_from_queue_no_release(queue, item);
  RELEASE(item->notification);
  RELEASE(item->modes);
  NSZoneFree(_zone, item);
}

static void
add_to_queue(NSNotificationQueueList *queue, NSNotification *notification,
  NSArray *modes, NSZone *_zone)
{
  NSNotificationQueueRegistration	*item;

#if	GS_WITH_GC
  item = NSAllocateCollectable(sizeof(NSNotificationQueueRegistration),
    NSScannedOption);
#else
  item = NSZoneCalloc(_zone, 1, sizeof(NSNotificationQueueRegistration));
#endif
  if (item == 0)
    {
      [NSException raise: NSMallocException
      		  format: @"Unable to add to notification queue"];
    }

  item->notification = RETAIN(notification);
  item->name = [notification name];
  item->object = [notification object];
  item->modes = [modes copyWithZone: [modes zone]];

  item->prev = NULL;
  item->next = queue->tail;
  queue->tail = item;
  if (item->next)
    {
      item->next->prev = item;
    }
  if (!queue->head)
    {
      queue->head = item;
    }
}



/*
 * NSNotificationQueue class implementation
 */

@interface NSNotificationQueue (Private)
- (void) _postNotification: (NSNotification*)notification
		  forModes: (NSArray*)modes;
@end

/**
 * This class supports asynchronous posting of [NSNotification]s to an
 * [NSNotificationCenter].  The method to add a notification to the queue
 * returns immediately.  The queue will periodically post its oldest
 * notification to the notification center.  In a multithreaded process,
 * notifications are always sent on the thread that they are posted from.
 */
@implementation NSNotificationQueue


/**
 * Returns the default notification queue for use in this thread.  It will
 * always post notifications to the default notification center (for the
 * entire task, which may have multiple threads and therefore multiple
 * notification queues).
 */
+ (NSNotificationQueue*) defaultQueue
{
  NotificationQueueList	*list;
  NSNotificationQueue	*item;

  list = currentList();
  item = list->queue;
  if (item == nil)
    {
      item = (NSNotificationQueue*)NSAllocateObject(self,
	0, NSDefaultMallocZone());
      item = [item initWithNotificationCenter:
	[NSNotificationCenter defaultCenter]];
      if (item != nil)
	{
	  NSMutableDictionary	*d;

	  d = GSCurrentThreadDictionary();
	  [d setObject: item forKey: qkey];
	  RELEASE(item);	/* retained in dictionary.	*/
	}
    }
  return item;
}

- (id) init
{
  return [self initWithNotificationCenter:
	  [NSNotificationCenter defaultCenter]];
}

/**
 *  Initialize a new instance to post notifications to the given
 *  notificationCenter (instead of the default).
 */
- (id) initWithNotificationCenter: (NSNotificationCenter*)notificationCenter
{
  _zone = [self zone];

  // init queue
  _center = RETAIN(notificationCenter);
#if	GS_WITH_GC
  _asapQueue = NSAllocateCollectable(sizeof(NSNotificationQueueList),
    NSScannedOption);
  _idleQueue = NSAllocateCollectable(sizeof(NSNotificationQueueList),
    NSScannedOption);
#else
  _asapQueue = NSZoneCalloc(_zone, 1, sizeof(NSNotificationQueueList));
  _idleQueue = NSZoneCalloc(_zone, 1, sizeof(NSNotificationQueueList));
#endif
  if (_asapQueue == 0 || _idleQueue == 0)
    {
      DESTROY(self);
    }
  else
    {
      /*
       * insert in global queue list
       */
      [NotificationQueueList registerQueue: self];
    }
  return self;
}

- (void) dealloc
{
  NSNotificationQueueRegistration	*item;

  /*
   * remove from class instances list
   */
  [NotificationQueueList unregisterQueue: self];

  /*
   * release items from our queues
   */
  while ((item = _asapQueue->head) != 0)
    {
      remove_from_queue(_asapQueue, item, _zone);
    }
  NSZoneFree(_zone, _asapQueue);

  while ((item = _idleQueue->head) != 0)
    {
      remove_from_queue(_idleQueue, item, _zone);
    }
  NSZoneFree(_zone, _idleQueue);

  RELEASE(_center);
  [super dealloc];
}

/* Inserting and Removing Notifications From a Queue */

/**
 * Immediately remove all notifications from queue matching notification on
 * name and/or object as specified by coalesce mask, which is an OR
 * ('<code>|</code>') of the options
 * <code>NSNotificationCoalescingOnName</code>,
 * <code>NSNotificationCoalescingOnSender</code> (object), and
 * <code>NSNotificationNoCoalescing</code> (match only the given instance
 * exactly).  If both of the first options are specified, notifications must
 * match on both attributes (not just either one).  Removed notifications are
 * <em>not</em> posted.
 */
- (void) dequeueNotificationsMatching: (NSNotification*)notification
			 coalesceMask: (NSUInteger)coalesceMask
{
  NSNotificationQueueRegistration	*item;
  NSNotificationQueueRegistration	*next;
  id					name   = [notification name];
  id					object = [notification object];

  if ((coalesceMask & NSNotificationCoalescingOnName)
    && (coalesceMask & NSNotificationCoalescingOnSender))
    {
      /*
       * find in ASAP notification in queue matching both
       */
      for (item = _asapQueue->tail; item; item = next)
	{
          next = item->next;
          //PENDING: should object comparison be '==' instead of isEqual?!
          if ((object == item->object) && [name isEqual: item->name])
	    {
              remove_from_queue(_asapQueue, item, _zone);
	    }
	}
      /*
       * find in idle notification in queue matching both
       */
      for (item = _idleQueue->tail; item; item = next)
	{
          next = item->next;
          if ((object == item->object) && [name isEqual: item->name])
	    {
              remove_from_queue(_idleQueue, item, _zone);
	    }
	}
    }
  else if ((coalesceMask & NSNotificationCoalescingOnName))
    {
      /*
       * find in ASAP notification in queue matching name
       */
      for (item = _asapQueue->tail; item; item = next)
	{
          next = item->next;
          if ([name isEqual: item->name])
	    {
              remove_from_queue(_asapQueue, item, _zone);
	    }
	}
      /*
       * find in idle notification in queue matching name
       */
      for (item = _idleQueue->tail; item; item = next)
	{
          next = item->next;
          if ([name isEqual: item->name])
	    {
              remove_from_queue(_idleQueue, item, _zone);
	    }
	}
    }
  else if ((coalesceMask & NSNotificationCoalescingOnSender))
    {
      /*
       * find in ASAP notification in queue matching sender
       */
      for (item = _asapQueue->tail; item; item = next)
	{
          next = item->next;
          if (object == item->object)
	    {
              remove_from_queue(_asapQueue, item, _zone);
	    }
	}
      /*
       * find in idle notification in queue matching sender
       */
      for (item = _idleQueue->tail; item; item = next)
	{
          next = item->next;
          if (object == item->object)
	    {
              remove_from_queue(_idleQueue, item, _zone);
	    }
	}
    }
}

/**
 *  Sets notification to be posted to notification center at time dependent on
 *  postingStyle, which may be either <code>NSPostNow</code> (synchronous post),
 *  <code>NSPostASAP</code> (post soon), or <code>NSPostWhenIdle</code> (post
 *  when runloop is idle).
 */
- (void) enqueueNotification: (NSNotification*)notification
		postingStyle: (NSPostingStyle)postingStyle	
{
  [self enqueueNotification: notification
	       postingStyle: postingStyle
	       coalesceMask: NSNotificationCoalescingOnName
			      + NSNotificationCoalescingOnSender
		   forModes: nil];
}

/**
 *  Sets notification to be posted to notification center at time dependent on
 *  postingStyle, which may be either <code>NSPostNow</code> (synchronous
 *  post), <code>NSPostASAP</code> (post soon), or <code>NSPostWhenIdle</code>
 *  (post when runloop is idle).  coalesceMask determines whether this
 *  notification should be considered same as other ones already on the queue,
 *  in which case they are removed through a call to
 *  -dequeueNotificationsMatching:coalesceMask: .  The modes argument
 *  determines which [NSRunLoop] mode notification may be posted in (nil means
 *  all modes).
 */
- (void) enqueueNotification: (NSNotification*)notification
		postingStyle: (NSPostingStyle)postingStyle
		coalesceMask: (NSUInteger)coalesceMask
		    forModes: (NSArray*)modes
{
  if (coalesceMask != NSNotificationNoCoalescing)
    {
      [self dequeueNotificationsMatching: notification
			    coalesceMask: coalesceMask];
    }
  switch (postingStyle)
    {
      case NSPostNow:
	[self _postNotification: notification forModes: modes];
	break;
      case NSPostASAP:
	add_to_queue(_asapQueue, notification, modes, _zone);
	break;
      case NSPostWhenIdle:
	add_to_queue(_idleQueue, notification, modes, _zone);
	break;
    }
}

@end

@implementation NSNotificationQueue (Private)

- (void) _postNotification: (NSNotification*)notification
		  forModes: (NSArray*)modes
{
  NSString	*mode = [[NSRunLoop currentRunLoop] currentMode];

  // check to see if run loop is in a valid mode
  if (mode == nil || modes == nil
    || [modes indexOfObject: mode] != NSNotFound)
    {
      [_center postNotification: notification];
    }
}

@end

/*
 *	The following code handles sending of queued notifications by
 *	NSRunLoop.
 */

static inline void
notifyASAP(NSNotificationQueue *q, NSString *mode)
{
  NSNotificationQueueList	*list = ((accessQueue)q)->_asapQueue;

  /*
   *	post all ASAP notifications in queue
   */
  while (list->head)
    {
      NSNotificationQueueRegistration	*item = list->head;
      NSNotification			*notification = item->notification;
      NSArray				*modes = item->modes;

      remove_from_queue_no_release(list, item);
      [q _postNotification: notification forModes: modes];
      RELEASE(notification);
      RELEASE(modes);
      NSZoneFree(((accessQueue)q)->_zone, item);
    }
}

void
GSPrivateNotifyASAP(NSString *mode)
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    {
      if (item->queue)
	{
	  notifyASAP(item->queue, mode);
	}
    }
}

static inline void
notifyIdle(NSNotificationQueue *q, NSString *mode)
{
  NSNotificationQueueList	*list = ((accessQueue)q)->_idleQueue;

  /*
   *	post next IDLE notification in queue
   */
  if (list->head)
    {
      NSNotificationQueueRegistration	*item = list->head;
      NSNotification			*notification = item->notification;
      NSArray				*modes = item->modes;

      remove_from_queue_no_release(list, item);
      [q _postNotification: notification forModes: modes];
      RELEASE(notification);
      RELEASE(modes);
      NSZoneFree(((accessQueue)q)->_zone, item);
    }
  /*
   *	Post all ASAP notifications.
   */
  notifyASAP(q, mode);
}

void
GSPrivateNotifyIdle(NSString *mode)
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    {
      if (item->queue)
	{
	  notifyIdle(item->queue, mode);
	}
    }
}

BOOL
GSPrivateNotifyMore(NSString *mode)
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    {
      if (item->queue && ((accessQueue)item->queue)->_idleQueue->head)
	{
	  return YES;
	}
    }
  return NO;
}

