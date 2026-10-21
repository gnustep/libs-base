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
#import "GSPrivate.h"

/*
 *      Setup for inline operation of arrays.
 */

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"

@class NSMapTable;
@class NSString;
@class NSThread;
@class GSRunLoopCtxt;
@class GSRunLoopWatcher;

/* This structure defines internal layout of an NSRunLoop instance which is
 * available to all contexts which implement functionality for that loop.
 */
typedef struct {
  void                  *sharedContextInfo;
  uint8_t               modeCount;              /* Number of known modes */
  BOOL			isMainThread;		/* Loop is in main thread */
  void			*dispatchHandle;	/* NULL or libdispatch info */
  uint64_t              commonModeMask;         /* Common modes as mask */
  NSMapTable            *contextMap;            /* Hash lookup by mode */
  GSRunLoopCtxt         *contexts[64];          /* Context for each mode */
  NSThread              *currentThread;         /* Our thread, not retained */
  GSRunLoopThreadInfo   *threadInfo;		/* Not retained */
  GSRunLoopCtxt         *currentContext;        /* Not retained */
  GSRunLoopCtxt         *savedContext;          /* Not retained */
} GSRLInternal;

/* These constants are the indexes (within the contexts field above) at which
 * information for the default run loop mode and the common run loop modes are
 * stored.  These contexts are guaranteed to exist for any running loop.
 */
#define	DefaultModeIndex	0	// The defualt mode (GSRunLoopCtxt)
#define	CommonModesIndex	1	// The common modes (GSRunLoopCtxtBase)


@interface	GSRunLoopCtxtBase : NSObject
{
@public
  GSRLInternal	*loop;		/** Pointer into owning loop.		*/
  NSString	*mode;		/** The mode for this context.		*/
  unsigned	modeIndex;	/** Position of mode within run loop    */
  GSIArray	watchers;	/** The inputs set for the runloop mode */
  GSMinHeap	*timerHeap;     /** The timers set for the runloop mode */
}
- (id) initWithMode: (NSString*)theMode for: (GSRLInternal*)l;
- (BOOL) runnable;	// Whether the loop can run in this mode
@end

@interface	GSRunLoopCtxt : GSRunLoopCtxtBase
{
@public
  GSIArray		performers;	/** The actions to perform regularly. */
  unsigned		maxPerformers;
  unsigned		maxWatchers;
  unsigned		maxTimers;
@protected
  GSIArray		_trigger;	// Watchers to trigger unconditionally.
  int			fairStart;	// For trying to ensure fair handling.
  BOOL			completed;	// To mark operation as completed.
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
- (id) initWithMode: (NSString*)theMode for: (GSRLInternal*)l;
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts;

/* Callbacks for a map table whose values are watchers.
 */
- (const NSMapTableValueCallBacks) watcherCallbacks;

@end

#if GS_USE_LIBDISPATCH_RUNLOOP
/* Function to drain/run libdispatch queue when an event is signalled for it.
 */
void GSPrivateDispatchDrain(void *handle) GS_ATTRIB_PRIVATE;
/* Function to return libdispatch main queue handle.
 */
void * GSPrivateDispatchHandle() GS_ATTRIB_PRIVATE;
#endif

#endif /* __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE */
