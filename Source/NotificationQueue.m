/* Implementation of object for queuing Notification objects
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

/* The implementation for NotificationDispatcher. */

#include <gnustep/base/prefix.h>
#include <gnustep/base/NotificationQueue.h>
#include <gnustep/base/Notification.h>
#include <gnustep/base/LinkedListNode.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Invocation.h>
#include <Foundation/NSException.h>

@implementation NotificationQueue

/* This is the default initialzer. */
- initWithNotificationDistributor: nd
{
  [super init];
  _notification_distributor = nd;
  _asap_queue = [Queue new];
  _idle_queue = [Queue new];
  return self;
}

- init
{
  return [self initWithNotificationDistributor:
		 [NotificationDistributor defaultInstance]];
}

- (void) dequeueNotificationsMatching: notification
			 coalesceMask: (unsigned)mask
{
  /* Remove from the queues notifications that match NOTIFICATION, according
     the the MASK. */
  /* xxx This method should be made much more efficient.  Currently, it
     could be a big bottleneck. */
  void remove_matching_from_queue (Queue *q)
    {
      int i;
      for (i = [q count] - 1; i >= 0; i--)
	{
	  id n = [q objectAtIndex: i];
	  /* If the aspects that need to match do match... */
	  if (( !(mask & NSNotificationCoalescingOnName)
		|| [[notification name] isEqual: [n name]])
	      &&
	      ( !(mask & NSNotificationCoalescingOnSender)
		|| [[notification object] isEqual: [n object]]))
	    /* ...then remove it. */
	    [q removeObjectAtIndex: i];
	}
    }
  remove_matching_from_queue (_asap_queue);
  remove_matching_from_queue (_idle_queue);
}

- (void) enqueueNotification: notification
		postingStyle: (NSPostingStyle)style
                coalesceMask: (unsigned)mask
		    forModes: (id <ConstantCollecting>)modes
{
  [self dequeueNotificationsMatching: notification
	coalesceMask: mask];
  
  switch (style) 
    {
    case NSPostIdle:
      [_idle_queue enqueueObject: notification];
      break;
    case NSPostASAP:
      [_asap_queue enqueueObject: notification];
      break;
    case NSPostNow:
      if ([modes containsObject: [RunLoop mode]])
	[_notification_distributor postNotification: notification];
      else
	/* xxx This is the correct behavior? */
	[_asap_queue enqueueObject: notification];
      break;
    default:
      [self error: "Bad posting style."];
    }
}

- (void) enqueueNotification: notification
		postingStyle: (NSPostingStyle)style
{
  [self enqueueNotification: notification
	postingStyle: style
	coalesceMask: (NSNotificationCoalescingOnName
		       | NSNotificationCoalescingOnSender)
	modes: nil];
}


- (void) postNotificationsWithASAPStyle
{
  id n;
  int i, c = [_asap_queue count];

  for (i = 0; i < c; i++)
    [_notification_dispatcher postNotification: 
				[_idle_queue objectAtIndex: i]];
  [_asap_queue empty];
}

- (void) postNotificationWithIdleStyle
{
  id n = [_idle_queue dequeueObject];
  [_notification_dispatcher postNotification: n];
}

@end
