#ifndef __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE
#define __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE
/** 
   Copyright (C) 2008-2026 Free Software Foundation, Inc.

   By: Richard Frith-Macdonald <richard@brainstorm.co.uk>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#import "common.h"
#import "Foundation/NSException.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSRunLoop.h"
#import "GNUstepBase/GSMinHeap.h"

/*
 *      Setup for inline operation of arrays.
 */

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"

#ifdef  HAVE_POLL
typedef struct{
  int   limit;
  short *index;
}pollextra;
#endif

@class NSString;
@class GSRunLoopWatcher;

@interface	GSRunLoopCtxt : NSObject
{
@public
  void		*extra;		/** Copy of the RunLoop ivar.		*/
  NSString	*mode;		/** The mode for this context.		*/
  GSIArray	performers;	/** The actions to perform regularly.	*/
  unsigned	maxPerformers;
  GSIArray	timers;
  unsigned	maxTimers;
  GSIArray	watchers;	/** The inputs set for the runloop mode */
  unsigned	maxWatchers;
@protected
  GSIArray	_trigger;	// Watchers to trigger unconditionally.
  int		fairStart;	// For trying to ensure fair handling.
  BOOL		completed;	// To mark operation as completed.
}
/* Check to see of the thread has been awakened, blocking until it
 * does get awakened or until the limit date has been reached.
 * A date in the past (or nil) results in a check followed by an
 * immediate return.
 */
+ (BOOL) awakenedBefore: (NSDate*)when;

/* Remove any callback for the specified event which is set for an
 * uncompleted poll operation.<br />
 * This is called by nested event loops on contexts in outer loops
 * when they handle an event ... removing the event from the outer
 * loop ensures that it won't get handled twice, once by the inner
 * loop and once by the outer one.
 */
- (void) endEvent: (void*)data
              for: (GSRunLoopWatcher*)watcher;

- (void) endPoll;
- (id) initWithMode: (NSString*)theMode extra: (void*)e;
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts;

/* Callbacks for a map table whose values are watchers.
 */
- (const NSMapTableValueCallBacks) watcherCallbacks;

@end

#endif /* __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE */
