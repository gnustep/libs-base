/*
   NSNotificationQueue.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

/* Implementation for NSNotificationQueue for GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

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

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>

/* NotificationQueueList by Richard Frith-Macdonald
   These objects are used to maintain lists of NSNotificationQueue objects.
   There is one list per NSThread, with the first object in the list stored
   in the thread dictionary and accessed using the key below.
   */

static	NSString*	tkey = @"NotificationQueueListThreadKey";

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
currentList()
{
  NotificationQueueList	*list;
  NSMutableDictionary	*d;

  d = GSCurrentThreadDictionary();
  list = (NotificationQueueList*)[d objectForKey: tkey];
  if (list == nil)
    {
      list = [NotificationQueueList new];
      [d setObject: list forKey: tkey];
      RELEASE(list);	/* retained in dictionary.	*/
    }
  return list;
}

@implementation	NotificationQueueList

+ (void) registerQueue: (NSNotificationQueue*)q
{
  NotificationQueueList*	list;
  NotificationQueueList*	elem;

  if (q == nil)
    return;			/* Can't register nil object.	*/

  list = currentList();	/* List of queues for thread.	*/

  if (list->queue == nil)
    list->queue = q;		/* Make this the default.	*/

  while (list->queue != q && list->next != nil)
    list = list->next;

  if (list->queue == q)
    return;			/* Queue already registered.	*/

  elem = (NotificationQueueList*)NSAllocateObject(self, 0,
    NSDefaultMallocZone());
  elem->queue = q;
  list->next = elem;
}

+ (void)unregisterQueue: (NSNotificationQueue*)q
{
  NotificationQueueList*	list;

  if (q == nil)
    return;

  list = currentList();

  if (list->queue == q)
    {
      NSMutableDictionary	*d;

      d = GSCurrentThreadDictionary();
      if (list->next)
        {
	  NotificationQueueList*	tmp = list->next;

          [d setObject: tmp forKey: tkey];
	  RELEASE(tmp);			/* retained in dictionary.	*/
        }
      else
	[d removeObjectForKey: tkey];
    }
  else
    {
      while (list->next != nil)
	{
	  if (list->next->queue == q)
	    {
	      NotificationQueueList*	tmp = list->next;

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
  struct _NSNotificationQueueRegistration* next;
  struct _NSNotificationQueueRegistration* prev;
  NSNotification* notification;
  id name;
  id object;
  NSArray* modes;
} NSNotificationQueueRegistration;

struct _NSNotificationQueueList;

typedef struct _NSNotificationQueueList
{
  struct _NSNotificationQueueRegistration* head;
  struct _NSNotificationQueueRegistration* tail;
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
remove_from_queue_no_release(
    NSNotificationQueueList* queue,
    NSNotificationQueueRegistration* item)
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
remove_from_queue(
    NSNotificationQueueList* queue,
    NSNotificationQueueRegistration* item,
    NSZone* zone)
{
  remove_from_queue_no_release(queue, item);
  RELEASE(item->notification);
  RELEASE(item->modes);
  NSZoneFree(zone, item);
}

static void
add_to_queue(
    NSNotificationQueueList* queue,
    NSNotification* notification,
    NSArray* modes,
    NSZone* zone)
{
    NSNotificationQueueRegistration* item =
	    NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueRegistration));
	
    item->notification = RETAIN(notification);
    item->name = [notification name];
    item->object = [notification object];
    item->modes = [modes copyWithZone: [modes zone]];

    item->prev = NULL;
    item->next = queue->tail;
    queue->tail = item;
    if (item->next)
	item->next->prev = item;
    if (!queue->head)
	queue->head = item;
}



/*
 * NSNotificationQueue class implementation
 */

@implementation NSNotificationQueue

+ (NSNotificationQueue*)defaultQueue
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
    }
  return item;
}

- (id)init
{
  return [self initWithNotificationCenter: 
	  [NSNotificationCenter defaultCenter]];
}

- (id)initWithNotificationCenter: (NSNotificationCenter*)notificationCenter
{
  zone = [self zone];

  // init queue
  center = RETAIN(notificationCenter);
  asapQueue = NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueList));
  idleQueue = NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueList));

  // insert in global queue list
  [NotificationQueueList registerQueue: self];

  return self;
}

- (void)dealloc
{
    NSNotificationQueueRegistration* item;

    // remove from classs instances list
    [NotificationQueueList unregisterQueue: self];

    // release self
    for (item = asapQueue->head; item; item=item->prev)
	remove_from_queue(asapQueue, item, zone);
    NSZoneFree(zone, asapQueue);

    for (item = idleQueue->head; item; item=item->prev)
	remove_from_queue(idleQueue, item, zone);
    NSZoneFree(zone, idleQueue);

    RELEASE(center);
    [super dealloc];
}

/* Inserting and Removing Notifications From a Queue */

- (void)dequeueNotificationsMatching: (NSNotification*)notification
  coalesceMask: (NSNotificationCoalescing)coalesceMask
{
    NSNotificationQueueRegistration* item;
    NSNotificationQueueRegistration* next;
    id name   = [notification name];
    id object = [notification object];

    // find in ASAP notification in queue
    for (item = asapQueue->tail; item; item=next) {
	next = item->next;
	if ((coalesceMask & NSNotificationCoalescingOnName)
	    && [name isEqual: item->name])
	    {
		remove_from_queue(asapQueue, item, zone);
		continue;
	    }
	if ((coalesceMask & NSNotificationCoalescingOnSender)
	    && (object == item->object))
	    {
		remove_from_queue(asapQueue, item, zone);
		continue;
	    }
    }

    // find in idle notification in queue
    for (item = idleQueue->tail; item; item=next) {
	next = item->next;
	if ((coalesceMask & NSNotificationCoalescingOnName)
	    && [name isEqual: item->name])
	    {
		remove_from_queue(asapQueue, item, zone);
		continue;
	    }
	if ((coalesceMask & NSNotificationCoalescingOnSender)
	    && (object == item->object))
	    {
		remove_from_queue(asapQueue, item, zone);
		continue;
	    }
    }
}

- (void) postNotification: (NSNotification*)notification
		 forModes: (NSArray*)modes
{
  NSString	*mode = [NSRunLoop currentMode];

  // check to see if run loop is in a valid mode
  if (mode == nil || modes == nil
    || [modes indexOfObject: mode] != NSNotFound)
    {
      [center postNotification: notification];
    }
}

- (void)enqueueNotification: (NSNotification*)notification
  postingStyle: (NSPostingStyle)postingStyle	
{
    [self enqueueNotification: notification
	    postingStyle: postingStyle
	    coalesceMask: NSNotificationCoalescingOnName +
			 NSNotificationCoalescingOnSender
	    forModes: nil];
}

- (void)enqueueNotification: (NSNotification*)notification
  postingStyle: (NSPostingStyle)postingStyle
  coalesceMask: (NSNotificationCoalescing)coalesceMask
  forModes: (NSArray*)modes
{
    if (coalesceMask != NSNotificationNoCoalescing)
	[self dequeueNotificationsMatching: notification
		coalesceMask: coalesceMask];

    switch (postingStyle) {
	case NSPostNow: 
		[self postNotification: notification forModes: modes];
		break;
	case NSPostASAP: 
		add_to_queue(asapQueue, notification, modes, zone);
		break;
	case NSPostWhenIdle: 
		add_to_queue(idleQueue, notification, modes, zone);
		break;
    }
}

@end

/*
 *	The following code handles sending of queued notifications by
 *	NSRunLoop.
 */

static inline void notifyASAP(NSNotificationQueue *q)
{
  NSNotificationQueueList	*list = ((accessQueue)q)->asapQueue;

  /*
   *	post all ASAP notifications in queue
   */
  while (list->head)
    {
      NSNotificationQueueRegistration	*item = list->head;
      NSNotification	*notification = item->notification;
      NSArray		*modes = item->modes;

      remove_from_queue_no_release(list, item);
      [q postNotification: notification forModes: modes];
      RELEASE(notification);
      RELEASE(modes);
      NSZoneFree(((accessQueue)q)->zone, item);
    }
}

void
GSNotifyASAP()
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    if (item->queue)
      notifyASAP(item->queue);
}

static inline void notifyIdle(NSNotificationQueue *q)
{
  NSNotificationQueueList	*list = ((accessQueue)q)->idleQueue;

  /*
   *	post next IDLE notification in queue
   */
  if (list->head)
    {
      NSNotificationQueueRegistration	*item = list->head;
      NSNotification	*notification = item->notification;
      NSArray		*modes = item->modes;

      remove_from_queue_no_release(list, item);
      [q postNotification: notification forModes: modes];
      RELEASE(notification);
      RELEASE(modes);
      NSZoneFree(((accessQueue)q)->zone, item);
      /*
       *	Post all ASAP notifications.
       */
      GSNotifyASAP();
    }
}

void
GSNotifyIdle()
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    if (item->queue)
      notifyIdle(item->queue);
}

BOOL
GSNotifyMore()
{
  NotificationQueueList	*item;

  for (item = currentList(); item; item = item->next)
    if (item->queue && ((accessQueue)item->queue)->idleQueue->head)
      return YES;
  return NO;
}

