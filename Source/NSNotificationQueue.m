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
#include <gnustep/base/preface.h>
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

@interface	NotificationQueueList : NSObject
{
    NotificationQueueList*	next;
    NSNotificationQueue*	queue;
}
+ (NotificationQueueList*) currentList;
+ (void)registerQueue:(NSNotificationQueue*)q;
+ (void)unregisterQueue:(NSNotificationQueue*)q;
- (NotificationQueueList*) next;
- (NSNotificationQueue*) queue;
@end

@implementation	NotificationQueueList
+ (NotificationQueueList*) currentList
{
  NotificationQueueList*	list;
  NSThread*			t;

  t = [NSThread currentThread];
  list = (NotificationQueueList*)[[t threadDictionary] objectForKey:tkey];
  if (list == nil)
    {
      list = [NotificationQueueList new];
      [[t threadDictionary] setObject:list forKey:tkey];
      [list release];	/* retained in dictionary.	*/
    }
  return list;
}

+ (void)registerQueue:(NSNotificationQueue*)q
{
  NotificationQueueList*	list;
  NotificationQueueList*	elem;

  if (q == nil)
    return;			/* Can't register nil object.	*/

  list = [self currentList];	/* List of queues for thread.	*/

  if (list->queue == nil)
    list->queue = q;		/* Make this the default.	*/

  while (list->queue != q && list->next != nil)
    list = list->next;

  if (list->queue == q)
    return;			/* Queue already registered.	*/

  elem = [NotificationQueueList new];
  elem->queue = q;
  list->next = elem;
}

+ (void)unregisterQueue:(NSNotificationQueue*)q
{
  NotificationQueueList*	list;

  if (q == nil)
    return;

  list = [self currentList];

  if (list->queue == q)
    {
      NSThread*	t;

      t = [NSThread currentThread];
      if (list->next)
        {
	  NotificationQueueList*	tmp = list->next;

          [[t threadDictionary] setObject:tmp forKey:tkey];
	  [tmp release];	/* retained in dictionary.	*/
        }
      else
	[[t threadDictionary] removeObjectForKey:tkey];
    }
  else
    while (list->next != nil)
      {
	if (list->next->queue == q)
	  {
	    NotificationQueueList*	tmp = list->next;

	    list->next = tmp->next;
	    [tmp release];
	    break;
	  }
      }
}

- (NotificationQueueList*) next
{
    return next;
}

- (NSNotificationQueue*) queue
{
    return queue;
}
@end

static BOOL	validMode(NSArray* modes)
{
  BOOL ok = NO;
  NSString* mode = [[NSRunLoop currentRunLoop] currentMode];

  // check to see if run loop is in a valid mode
  if (!mode || !modes)
    ok = YES;
  else
    {
      int i;
	
      for (i = [modes count]; i > 0; i--)
	if ([mode isEqual:[modes objectAtIndex:i-1]])
	  {
	    ok = YES;
	    break;
	  }
    }
  return ok;
}

/*
 * NSNotificationQueue queue
 */

typedef struct _NSNotificationQueueRegistration {
    struct _NSNotificationQueueRegistration* next;
    struct _NSNotificationQueueRegistration* prev;
    NSNotification* notification;
    id name;
    id object;
    NSArray* modes;
} NSNotificationQueueRegistration;

struct _NSNotificationQueueList;

typedef struct _NSNotificationQueueList {
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

static void
remove_from_queue(
    NSNotificationQueueList* queue,
    NSNotificationQueueRegistration* item,
    NSZone* zone)
{
    if (item->prev)
	item->prev->next = item->next;
    else {
	queue->tail = item->next;
	if (item->next)
	    item->next->prev = NULL;
    }

    if (item->next)
	item->next->prev = item->prev;
    else {
	queue->head = item->prev;
	if (item->prev)
	    item->prev->next = NULL;
    }
    [item->notification release];
    [item->modes release];
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
	
    item->notification = [notification retain];
    item->name = [notification name];
    item->object = [notification object];
    item->modes = [modes copyWithZone:[modes zone]];

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
  NotificationQueueList* list;
  NSNotificationQueue*	item;

  list = [NotificationQueueList currentList];
  item = [list queue];
  if (item == nil)
    item = [self new];

  return item;
}

- (id)init
{
    return [self initWithNotificationCenter:
	    [NSNotificationCenter defaultCenter]];
}

- (id)initWithNotificationCenter:(NSNotificationCenter*)notificationCenter
{
    zone = [self zone];

    // init queue
    center = [notificationCenter retain];
    asapQueue = NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueList));
    idleQueue = NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueList));

    // insert in global queue list
    [NotificationQueueList registerQueue:self];

    return self;
}

- (void)dealloc
{
    NSNotificationQueueRegistration* item;

    // remove from classs instances list
    [NotificationQueueList unregisterQueue:self];

    // release self
    for (item = asapQueue->head; item; item=item->prev)
	remove_from_queue(asapQueue, item, zone);
    NSZoneFree(zone, asapQueue);

    for (item = idleQueue->head; item; item=item->prev)
	remove_from_queue(idleQueue, item, zone);
    NSZoneFree(zone, idleQueue);

    [center release];
    [super dealloc];
}

/* Inserting and Removing Notifications From a Queue */

- (void)dequeueNotificationsMatching:(NSNotification*)notification
  coalesceMask:(NSNotificationCoalescing)coalesceMask
{
    NSNotificationQueueRegistration* item;
    NSNotificationQueueRegistration* next;
    id name   = [notification name];
    id object = [notification object];

    // find in ASAP notification in queue
    for (item = asapQueue->tail; item; item=next) {
	next = item->next;
	if ((coalesceMask & NSNotificationCoalescingOnName)
	    && [name isEqual:item->name])
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
	    && [name isEqual:item->name])
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

- (void)postNotification:(NSNotification*)notification forModes:(NSArray*)modes
{
    if (validMode(modes))
	[center postNotification:notification];
}

- (void)enqueueNotification:(NSNotification*)notification
  postingStyle:(NSPostingStyle)postingStyle	
{
    [self enqueueNotification:notification
	    postingStyle:postingStyle
	    coalesceMask:NSNotificationCoalescingOnName +
			 NSNotificationCoalescingOnSender
	    forModes:nil];
}

- (void)enqueueNotification:(NSNotification*)notification
  postingStyle:(NSPostingStyle)postingStyle
  coalesceMask:(NSNotificationCoalescing)coalesceMask
  forModes:(NSArray*)modes
{
    if (coalesceMask != NSNotificationNoCoalescing)
	[self dequeueNotificationsMatching:notification
		coalesceMask:coalesceMask];

    switch (postingStyle) {
	case NSPostNow:
		[self postNotification:notification forModes:modes];
		break;
	case NSPostASAP:
		add_to_queue(asapQueue, notification, modes, zone);
		break;
	case NSPostWhenIdle:
		add_to_queue(idleQueue, notification, modes, zone);
		break;
    }
}

/*
 * NotificationQueue internals
 */

+ (void)runLoopIdle
{
  NotificationQueueList* item;

  for (item=[NotificationQueueList currentList]; item; item=[item next])
    [[item queue] notifyIdle];
}

+ (BOOL)runLoopMore
{
  NotificationQueueList* item;

  for (item=[NotificationQueueList currentList]; item; item = [item next])
    if ([[item queue] notifyMore] == YES)
      return YES;
  return NO;
}

+ (void)runLoopASAP
{
  NotificationQueueList* item;

  for (item=[NotificationQueueList currentList]; item; item=[item next])
    [[item queue] notifyASAP];
}

- (BOOL)notifyMore
{
  if (idleQueue->head)
    return YES;
  return NO;
}

- (void)notifyIdle
{
    // post next IDLE notification in queue
    if (idleQueue->head) {
        NSNotification*	notification = [idleQueue->head->notification retain];
        NSArray*	modes = [idleQueue->head->modes retain];

	remove_from_queue(idleQueue, idleQueue->head, zone);
	[self postNotification:notification forModes:modes];
	[notification release];
	[modes release];
	// Post all ASAP notifications.
	[NSNotificationQueue runLoopASAP];
    }
}

- (void)notifyASAP
{
    // post all ASAP notifications in queue
    while (asapQueue->head) {
        NSNotification*	notification = [asapQueue->head->notification retain];
        NSArray*	modes = [asapQueue->head->modes retain];

	remove_from_queue(asapQueue, asapQueue->head, zone);
	[self postNotification:notification forModes:modes];
	[notification release];
	[modes release];
    }
}

@end

