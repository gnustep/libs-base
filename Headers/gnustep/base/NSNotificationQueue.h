/*
   NSNotificationQueue.h

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
/* Interface for NSNotificationQueue for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>

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

#ifndef __NSNotificationQueue_h__
#define __NSNotificationQueue_h__

#include <Foundation/NSNotification.h>

@class NSMutableArray;

/*
 * Posting styles into notification queue
 */

typedef enum {
    NSPostWhenIdle,	
    NSPostASAP,		
    NSPostNow		
} NSPostingStyle;

typedef enum {
    NSNotificationNoCoalescing = 0,	
    NSNotificationCoalescingOnName = 1,	
    NSNotificationCoalescingOnSender = 2,	
} NSNotificationCoalescing;

/*
 * NSNotificationQueue class
 */

struct _NSNotificationQueueList;

@interface NSNotificationQueue : NSObject
{
    NSNotificationCenter* center;
    struct _NSNotificationQueueList* asapQueue;
    struct _NSNotificationQueueList* idleQueue;
    NSZone* zone;
}

/* Creating Notification Queues */

+ (NSNotificationQueue*)defaultQueue;
- (id)init;
- (id)initWithNotificationCenter:(NSNotificationCenter*)notificationCenter;

/* Inserting and Removing Notifications From a Queue */

- (void)dequeueNotificationsMatching:(NSNotification*)notification
  coalesceMask:(unsigned int)coalesceMask;

- (void)enqueueNotification:(NSNotification*)notification
  postingStyle:(NSPostingStyle)postingStyle;

- (void)enqueueNotification:(NSNotification*)notification
  postingStyle:(NSPostingStyle)postingStyle
  coalesceMask:(unsigned int)coalesceMask
  forModes:(NSArray*)modes;

/* Implementation used by the the NSRunLoop */

+ (void)runLoopIdle;
+ (void)runLoopASAP;
+ (BOOL)runLoopMore;
- (void)notifyIdle;
- (void)notifyASAP;
- (BOOL)notifyMore;

@end

#endif /* __NSNotificationQueue_h__ */
