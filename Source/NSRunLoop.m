/** Implementation of object for waiting on several input sources
  NSRunLoop.m

   Copyright (C) 1996-1999 Free Software Foundation, Inc.

   Original by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   OPENSTEP version by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSRunLoop class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSPort.h"
#include "Foundation/NSTimer.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSNotificationQueue.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSStream.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSDebug.h"
#include "GSRunLoopCtxt.h"
#include "GSRunLoopWatcher.h"
#include "GSStream.h"

#include "GSPrivate.h"

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_POLL_F
#include <poll.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <time.h>
#include <limits.h>
#include <string.h>		/* for memset() */


NSString * const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

static NSDate	*theFuture = nil;

@interface NSObject (OptionalPortRunLoop)
- (void) getFds: (int*)fds count: (int*)count;
@end



/*
 *	The GSRunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once each runloop
 *	iteration has passed.
 */
@interface GSRunLoopPerformer: NSObject
{
@public
  SEL		selector;
  id		target;
  id		argument;
  unsigned	order;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
		 target: (id)target
	       argument: (id)argument
		  order: (unsigned int)order;
@end

@implementation GSRunLoopPerformer

- (void) dealloc
{
  RELEASE(target);
  RELEASE(argument);
  [super dealloc];
}

- (void) fire
{
  [target performSelector: selector withObject: argument];
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  order: (unsigned int)theOrder
{
  self = [super init];
  if (self)
    {
      selector = aSelector;
      target = RETAIN(aTarget);
      argument = RETAIN(anArgument);
      order = theOrder;
    }
  return self;
}

@end



@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation	NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
  return _timedPerformers;
}
@end

/*
 * The GSTimedPerformer class is used to hold information about
 * messages which are due to be sent to objects at a particular time.
 */
@interface GSTimedPerformer: NSObject <GCFinalization>
{
@public
  SEL		selector;
  id		target;
  id		argument;
  NSTimer	*timer;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
		 target: (id)target
	       argument: (id)argument
		  delay: (NSTimeInterval)delay;
- (void) invalidate;
@end

@implementation GSTimedPerformer

- (void) dealloc
{
  [self gcFinalize];
  TEST_RELEASE(timer);
  RELEASE(target);
  RELEASE(argument);
  [super dealloc];
}

- (void) fire
{
  DESTROY(timer);
  [target performSelector: selector withObject: argument];
  [[[NSRunLoop currentRunLoop] _timedPerformers]
    removeObjectIdenticalTo: self];
}

- (void) gcFinalize
{
  [self invalidate];
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  delay: (NSTimeInterval)delay
{
  self = [super init];
  if (self != nil)
    {
      selector = aSelector;
      target = RETAIN(aTarget);
      argument = RETAIN(anArgument);
      timer = [[NSTimer allocWithZone: NSDefaultMallocZone()]
	initWithFireDate: nil
		interval: delay
		  target: self
		selector: @selector(fire)
		userInfo: nil
		 repeats: NO];
    }
  return self;
}

- (void) invalidate
{
  if (timer != nil)
    {
      [timer invalidate];
      DESTROY(timer);
    }
}

@end



/*
 *      Setup for inline operation of arrays.
 */

#ifndef GSI_ARRAY_TYPES
#define GSI_ARRAY_TYPES       GSUNION_OBJ

#if	GS_WITH_GC == 0
#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]
#else
#define GSI_ARRAY_RELEASE(A, X)	
#define GSI_ARRAY_RETAIN(A, X)	
#endif

#include "GNUstepBase/GSIArray.h"
#endif

typedef struct {
  @defs(NSTimer)
} *tvars;

static inline NSDate *timerDate(NSTimer *t)
{
  return ((tvars)t)->_date;
}
static inline BOOL timerInvalidated(NSTimer *t)
{
  return ((tvars)t)->_invalidated;
}

static NSComparisonResult tSort(GSIArrayItem i0, GSIArrayItem i1)
{
  return [timerDate(i0.obj) compare: timerDate(i1.obj)];
}



@implementation NSObject (TimedPerformers)

/*
 * Cancels any perform operations set up for the specified target
 * in the current run loop.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
{
  NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
  unsigned		count = [perf count];

  if (count > 0)
    {
      GSTimedPerformer	*array[count];

      IF_NO_GC(RETAIN(target));
      [perf getObjects: array];
      while (count-- > 0)
	{
	  GSTimedPerformer	*p = array[count];

	  if (p->target == target)
	    {
	      [p invalidate];
	      [perf removeObjectAtIndex: count];
	    }
	}
      RELEASE(target);
    }
}

/*
 * Cancels any perform operations set up for the specified target
 * in the current loop, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
					selector: (SEL)aSelector
					  object: (id)arg
{
  NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
  unsigned		count = [perf count];

  if (count > 0)
    {
      GSTimedPerformer	*array[count];

      IF_NO_GC(RETAIN(target));
      IF_NO_GC(RETAIN(arg));
      [perf getObjects: array];
      while (count-- > 0)
	{
	  GSTimedPerformer	*p = array[count];

	  if (p->target == target && sel_eq(p->selector, aSelector)
	    && (p->argument == arg || [p->argument isEqual: arg]))
	    {
	      [p invalidate];
	      [perf removeObjectAtIndex: count];
	    }
	}
      RELEASE(arg);
      RELEASE(target);
    }
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
{
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  GSTimedPerformer	*item;

  item = [[GSTimedPerformer alloc] initWithSelector: aSelector
					     target: self
					   argument: argument
					      delay: seconds];
  [[loop _timedPerformers] addObject: item];
  RELEASE(item);
  [loop addTimer: item->timer forMode: NSDefaultRunLoopMode];
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
		 inModes: (NSArray*)modes
{
  unsigned	count = [modes count];

  if (count > 0)
    {
      NSRunLoop		*loop = [NSRunLoop currentRunLoop];
      NSString		*marray[count];
      GSTimedPerformer	*item;
      unsigned		i;

      item = [[GSTimedPerformer alloc] initWithSelector: aSelector
						 target: self
					       argument: argument
						  delay: seconds];
      [[loop _timedPerformers] addObject: item];
      RELEASE(item);
      [modes getObjects: marray];
      for (i = 0; i < count; i++)
	{
	  [loop addTimer: item->timer forMode: marray[i]];
	}
    }
}

@end



@interface NSRunLoop (Private)

- (void) _addWatcher: (GSRunLoopWatcher*)item
	     forMode: (NSString*)mode;
- (void) _checkPerformers: (GSRunLoopCtxt*)context;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode;
- (void) _removeWatcher: (void*)data
		   type: (RunLoopEventType)type
		forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)

/* Add a watcher to the list for the specified mode.  Keep the list in
   limit-date order. */
- (void) _addWatcher: (GSRunLoopWatcher*) item forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;
  GSIArray	watchers;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  watchers = context->watchers;
  GSIArrayAddItem(watchers, (GSIArrayItem)((id)item));
}

- (void) _checkPerformers: (GSRunLoopCtxt*)context
{
  CREATE_AUTORELEASE_POOL(arp);
  if (context != nil)
    {
      GSIArray	performers = context->performers;
      unsigned	count = GSIArrayCount(performers);

      if (count > 0)
	{
	  GSRunLoopPerformer	*array[count];
	  NSMapEnumerator	enumerator;
	  GSRunLoopCtxt		*context;
	  void			*mode;
	  unsigned		i;

	  /*
	   * Copy the array - because we have to cancel the requests
	   * before firing.
	   */
	  for (i = 0; i < count; i++)
	    {
	      array[i] = RETAIN(GSIArrayItemAtIndex(performers, i).obj);
	    }

	  /*
	   * Remove the requests that we are about to fire from all modes.
	   */
	  enumerator = NSEnumerateMapTable(_contextMap);
	  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
	    {
	      if (context != nil)
		{
		  GSIArray	performers = context->performers;
		  unsigned	tmpCount = GSIArrayCount(performers);

		  while (tmpCount--)
		    {
		      GSRunLoopPerformer	*p;

		      p = GSIArrayItemAtIndex(performers, tmpCount).obj;
		      for (i = 0; i < count; i++)
			{
			  if (p == array[i])
			    {
			      GSIArrayRemoveItemAtIndex(performers, tmpCount);
			    }
			}
		    }
		}
	    }
	  NSEndMapTableEnumeration(&enumerator);

	  /*
	   * Finally, fire the requests.
	   */
	  for (i = 0; i < count; i++)
	    {
	      [array[i] fire];
	      RELEASE(array[i]);
	      IF_NO_GC([arp emptyPool]);
	    }
	}
    }
  RELEASE(arp);
}

/**
 * Locates a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  context = NSMapGet(_contextMap, mode);
  if (context != nil)
    {
      GSIArray	watchers = context->watchers;
      unsigned	i = GSIArrayCount(watchers);

      while (i-- > 0)
	{
	  GSRunLoopWatcher	*info;

	  info = GSIArrayItemAtIndex(watchers, i).obj;
	  if (info->type == type && info->data == data)
	    {
	      return info;
	    }
	}
    }
  return nil;
}

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  context = NSMapGet(_contextMap, mode);
  if (context != nil)
    {
      GSIArray	watchers = context->watchers;
      unsigned	i = GSIArrayCount(watchers);

      while (i-- > 0)
	{
	  GSRunLoopWatcher	*info;

	  info = GSIArrayItemAtIndex(watchers, i).obj;
	  if (info->type == type && info->data == data)
	    {
	      info->_invalidated = YES;
	      GSIArrayRemoveItemAtIndex(watchers, i);
	    }
	}
    }
}

@end


@implementation NSRunLoop(GNUstepExtensions)

- (void) addEvent: (void*)data
             type: (RunLoopEventType)type
          watcher: (id<RunLoopEvents>)watcher
          forMode: (NSString*)mode
{
  GSRunLoopWatcher	*info;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  info = [self _getWatcher: data type: type forMode: mode];

  if (info != nil && (id)info->receiver == (id)watcher)
    {
      /* Increment usage count for this watcher. */
      info->count++;
    }
  else
    {
      /* Remove any existing handler for another watcher. */
      [self _removeWatcher: data type: type forMode: mode];

      /* Create new object to hold information. */
      info = [[GSRunLoopWatcher alloc] initWithType: type
					   receiver: watcher
					       data: data];
      /* Add the object to the array for the mode. */
      [self _addWatcher: info forMode: mode];
      RELEASE(info);		/* Now held in array.	*/
    }
}

- (void) removeEvent: (void*)data
                type: (RunLoopEventType)type
             forMode: (NSString*)mode
		 all: (BOOL)removeAll
{
  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }
  if (removeAll)
    {
      [self _removeWatcher: data type: type forMode: mode];
    }
  else
    {
      GSRunLoopWatcher	*info;

      info = [self _getWatcher: data type: type forMode: mode];

      if (info)
	{
	  if (info->count == 0)
	    {
	      [self _removeWatcher: data type: type forMode: mode];
  	    }
	  else
	    {
	      info->count--;
	    }
	}
    }
}

@end

/**
 *  <p><code>NSRunLoop</code> instances handle various utility tasks that must
 *  be performed repetitively in an application, such as processing input
 *  events, listening for distributed objects communications, firing
 *  [NSTimer]s, and sending notifications and other messages
 *  asynchronously.</p>
 *
 * <p>In general, there is one run loop per thread in an application, which
 *  may always be obtained through the <code>+currentRunLoop</code> method,
 *  however unless you are using the AppKit and the [NSApplication] class, the
 *  run loop will not be started unless you explicitly send it a
 *  <code>-run</code> message.</p>
 *
 * <p>At any given point, a run loop operates in a single <em>mode</em>, usually
 * <code>NSDefaultRunLoopMode</code>.  Other options include
 * <code>NSConnectionReplyMode</code>, and certain modes used by the AppKit.</p>
 */
@implementation NSRunLoop

+ (void) initialize
{
  if (self == [NSRunLoop class])
    {
      [self currentRunLoop];
      theFuture = RETAIN([NSDate distantFuture]);
    }
}

/**
 * Returns the run loop instance for the current thread.
 */
+ (NSRunLoop*) currentRunLoop
{
  extern NSRunLoop	*GSRunLoopForThread();

  return GSRunLoopForThread(nil);
}

/* This is the designated initializer. */
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _contextStack = [NSMutableArray new];
      _contextMap = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
					 NSObjectMapValueCallBacks, 0);
      _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
#ifdef	HAVE_POLL_F
      _extra = objc_malloc(sizeof(pollextra));
      memset(_extra, '\0', sizeof(pollextra));
#endif
    }
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) gcFinalize
{
#ifdef	HAVE_POLL_F
  if (_extra != 0)
    {
      pollextra	*e = (pollextra*)_extra;

      if (e->index != 0)
	objc_free(e->index);
      objc_free(e);
    }
#endif
  RELEASE(_contextStack);
  if (_contextMap != 0)
    {
      NSFreeMapTable(_contextMap);
    }
  RELEASE(_timedPerformers);
}

/**
 * Returns the current mode of this runloop.  If the runloop is not running
 * then this method returns nil.
 */
- (NSString*) currentMode
{
  return _currentMode;
}


/**
 * Adds a timer to the loop in the specified mode.<br />
 * Timers are removed automatically when they are invalid.<br />
 */
- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;
  GSIArray	timers;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  timers = context->timers;
  GSIArrayInsertSorted(timers, (GSIArrayItem)((id)timer), tSort);
}


/**
 * Fires timers whose fire date has passed, and checks timers and limit dates
 * for input sources, determining the earliest time that any future timeout
 * becomes due.  Returns that date/time.
 */
- (NSDate*) limitDateForMode: (NSString*)mode
{
  GSRunLoopCtxt		*context;
  NSDate		*when = nil;

  context = NSMapGet(_contextMap, mode);
  if (context != nil)
    {
      NSString		*savedMode = _currentMode;
      CREATE_AUTORELEASE_POOL(arp);

      _currentMode = mode;
      NS_DURING
	{
	  extern NSTimeInterval GSTimeNow(void);
	  GSIArray		timers = context->timers;
	  NSTimeInterval	now;
	  NSTimer		*t;

	  /*
	   * Save current time so we don't keep redoing system call to
	   * get it.  We must refetch the time after every operation
	   * (such as a timer firing) which might cause a significant
	   * delay making the saved value outdated.
	   */
	  now = GSTimeNow();

	  /*
	   * Fire housekeeping timer as necessary
	   */
	  while ((t = context->housekeeper) != nil
	    && ([timerDate(t) timeIntervalSinceReferenceDate] <= now))
	    {
	      [t fire];
	      IF_NO_GC([arp emptyPool]);
	      now = GSTimeNow();
	    }

	  /*
	   * Handle normal timers ... remove invalidated timers and fire any
	   * whose date has passed.
	   */
	  while (GSIArrayCount(timers) != 0)
	    {
	      NSTimer	*min_timer = GSIArrayItemAtIndex(timers, 0).obj;

	      if (timerInvalidated(min_timer) == YES)
		{
		  GSIArrayRemoveItemAtIndex(timers, 0);
		  min_timer = nil;
		  continue;
		}

	      if ([timerDate(min_timer) timeIntervalSinceReferenceDate] > now)
		{
		  when = [timerDate(min_timer) copy];
		  break;
		}

	      GSIArrayRemoveItemAtIndexNoRelease(timers, 0);
	      /* Firing will also increment its fireDate, if it is repeating. */
	      [min_timer fire];
	      now = GSTimeNow();
	      if (timerInvalidated(min_timer) == NO)
		{
		  GSIArrayInsertSortedNoRetain(timers,
		    (GSIArrayItem)((id)min_timer), tSort);
		}
	      else
		{
		  RELEASE(min_timer);
		}
	      GSPrivateNotifyASAP();		/* Post notifications. */
	      IF_NO_GC([arp emptyPool]);
	    }
	  _currentMode = savedMode;
	}
      NS_HANDLER
	{
	  _currentMode = savedMode;
	  [localException raise];
	}
      NS_ENDHANDLER

      RELEASE(arp);

      if (when != nil)
	{
	  AUTORELEASE(when);
	}
      else
        {
	  GSIArray		watchers = context->watchers;
	  unsigned		i = GSIArrayCount(watchers);

	  while (i-- > 0)
	    {
	      GSRunLoopWatcher	*w = GSIArrayItemAtIndex(watchers, i).obj;

	      if (w->_invalidated == YES)
	        {
		  GSIArrayRemoveItemAtIndex(watchers, i);
		}
	    }
	  if (GSIArrayCount(context->watchers) > 0)
	    {
	      when = theFuture;
	    }
	}

      NSDebugMLLog(@"NSRunLoop", @"limit date %f",
	[when timeIntervalSinceReferenceDate]);
    }
  return when;
}

/**
 * Listen for events from input sources.<br />
 * If limit_date is nil or in the past, then don't wait;
 * just poll inputs and return,
 * otherwise block until input is available or until the
 * earliest limit date has passed (whichever comes first).<br />
 * If the supplied mode is nil, uses NSDefaultRunLoopMode.
 */
- (void) acceptInputForMode: (NSString*)mode
		 beforeDate: (NSDate*)limit_date
{
  GSRunLoopCtxt		*context;
  NSTimeInterval	ti;
  int			timeout_ms;
  NSString		*savedMode = _currentMode;
  CREATE_AUTORELEASE_POOL(arp);

  NSAssert(mode, NSInvalidArgumentException);
  if (mode == nil)
    {
      mode = NSDefaultRunLoopMode;
    }
  _currentMode = mode;
  context = NSMapGet(_contextMap, mode);

  [self _checkPerformers: context];

  NS_DURING
    {
      GSIArray		watchers;
      unsigned		i;

      /*
       * If we have a housekeeping timer, and it is earlier than the
       * limit date we have been given, we use the date of the housekeeper
       * to determine when to stop.
       */
      if (limit_date != nil && context != nil && context->housekeeper != nil
	&& [timerDate(context->housekeeper) timeIntervalSinceReferenceDate]
	  < [limit_date timeIntervalSinceReferenceDate])
	{
	  limit_date = timerDate(context->housekeeper);
	}

      if ((context == nil || (watchers = context->watchers) == 0
	|| (i = GSIArrayCount(watchers)) == 0))
	{
	  NSDebugMLLog(@"NSRunLoop", @"no inputs in mode %@", mode);
	  GSPrivateNotifyASAP();
	  GSPrivateNotifyIdle();
	  /*
	   * Pause for as long as possible (up to the limit date)
	   */
	  [NSThread sleepUntilDate: limit_date];
	  ti = [limit_date timeIntervalSinceNow];
	  GSPrivateCheckTasks();
	  if (context != nil)
	    {
	      [self _checkPerformers: context];
	    }
	  GSPrivateNotifyASAP();
	  _currentMode = savedMode;
	  RELEASE(arp);
	  NS_VOIDRETURN;
	}

      /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
      if (limit_date == nil
       || (ti = [limit_date timeIntervalSinceNow]) <= 0.0)
	{
	  /* Don't wait at all. */
	  timeout_ms = 0;
	}
      else
	{
	  /* Wait until the LIMIT_DATE. */
	  NSDebugMLLog(@"NSRunLoop", @"accept I/P before %f (sec from now %f)",
	    [limit_date timeIntervalSinceReferenceDate], ti);
	  if (ti >= INT_MAX / 1000)
	    {
	      timeout_ms = INT_MAX;	// Far future.
	    }
	  else
	    {
	      timeout_ms = ti * 1000;
	    }
	}

      if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
	{
	  [_contextStack addObject: context];
	}
      if ([context pollUntil: timeout_ms within: _contextStack] == NO)
	{
	  GSPrivateNotifyIdle();
	}
      [self _checkPerformers: context];
      GSPrivateNotifyASAP();
      _currentMode = savedMode;
      /*
       * Once a poll has been completed on a context, we can remove that
       * context from the stack even if it actually polling at an outer
       * level of re-entrancy ... since the poll we have just done will
       * have handled any events that the outer levels would have wanted
       * to handle, and the polling for this context will be marked as ended.
       */
      [context endPoll];
      [_contextStack removeObjectIdenticalTo: context];
    }
  NS_HANDLER
    {
      _currentMode = savedMode;
      [context endPoll];
      [_contextStack removeObjectIdenticalTo: context];
      [localException raise];
    }
  NS_ENDHANDLER
  RELEASE(arp);
}

/**
 * Calls -acceptInputForMode:beforeDate: to run the loop once.<br />
 * The specified date may be nil ... in which case the loop runs
 * until the limit date of the first input or timeout.<br />
 * If the specified date is in the past, runs the loop once only, to
 * handle any events already available.<br />
 * If there are no input sources in mode, returns NO without running the loop,
 * otherwise returns YES.
 */
- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDate	*d;

  NSAssert(mode != nil, NSInvalidArgumentException);

  /* Find out how long we can wait before first limit date. */
  d = [self limitDateForMode: mode];
  if (d == nil)
    {
      NSDebugMLLog(@"NSRunLoop", @"run mode with nothing to do");
      /*
       * Notify if any tasks have completed.
       */
      if (GSPrivateCheckTasks() == YES)
	{
	  GSPrivateNotifyASAP();
	}
      RELEASE(arp);
      return NO;
    }

  /*
   * Use the earlier of the two dates we have.
   * Retain the date in case the firing of a timer (or some other event)
   * releases it.
   */
  if (date != nil)
    {
      d = [d earlierDate: date];
    }
  IF_NO_GC(RETAIN(d));

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode beforeDate: d];

  RELEASE(d);
  RELEASE(arp);
  return YES;
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain.
 */
- (void) run
{
  [self runUntilDate: theFuture];
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain, or date is reached, whichever occurs first.
 */
- (void) runUntilDate: (NSDate*)date
{
  double	ti = [date timeIntervalSinceNow];
  BOOL		mayDoMore = YES;

  /* Positive values are in the future. */
  while (ti > 0 && mayDoMore == YES)
    {
      NSDebugMLLog(@"NSRunLoop", @"run until date %f seconds from now", ti);
      mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
      ti = [date timeIntervalSinceNow];
    }
}

@end



/**
 * OpenStep-compatibility methods for [NSRunLoop].  These methods are also
 * all in OS X.
 */
@implementation	NSRunLoop (OPENSTEP)

/**
 * Adds port to be monitored in given mode.
 */
- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
  [self addEvent: (void*)port
	    type: ET_RPORT
	 watcher: (id<RunLoopEvents>)port
	 forMode: (NSString*)mode];
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver.
 */
- (void) cancelPerformSelectorsWithTarget: (id) target
{
  NSMapEnumerator	enumerator;
  GSRunLoopCtxt		*context;
  void			*mode;

  enumerator = NSEnumerateMapTable(_contextMap);

  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
      if (context != nil)
	{
	  GSIArray	performers = context->performers;
	  unsigned	count = GSIArrayCount(performers);

	  while (count--)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, count).obj;
	      if (p->target == target)
		{
		  GSIArrayRemoveItemAtIndex(performers, count);
		}
	    }
	}
    }
  NSEndMapTableEnumeration(&enumerator);
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
- (void) cancelPerformSelector: (SEL)aSelector
			target: (id) target
		      argument: (id) argument
{
  NSMapEnumerator	enumerator;
  GSRunLoopCtxt		*context;
  void			*mode;

  enumerator = NSEnumerateMapTable(_contextMap);

  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
      if (context != nil)
	{
	  GSIArray	performers = context->performers;
	  unsigned	count = GSIArrayCount(performers);

	  while (count--)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, count).obj;
	      if (p->target == target && sel_eq(p->selector, aSelector)
		&& (p->argument == argument || [p->argument isEqual: argument]))
		{
		  GSIArrayRemoveItemAtIndex(performers, count);
		}
	    }
	}
    }
  NSEndMapTableEnumeration(&enumerator);
}

/**
 *  Configure event processing for acting as a server process for distributed
 *  objects.  (In the current implementation this is a no-op.)
 */
- (void) configureAsServer
{
  return;	/* Nothing to do here */
}

/**
 * Sets up sending of aSelector to target with argument.<br />
 * The selector is sent before the next runloop iteration (unless
 * cancelled before then) in any of the specified modes.<br />
 * The target and argument objects are retained.<br />
 * The order value is used to determine the order in which messages
 * are sent if multiple messages have been set up. Messages with a lower
 * order value are sent first.<br />
 * If the modes array is empty, this method has no effect.
 */
- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (unsigned int)order
		   modes: (NSArray*)modes
{
  unsigned		count = [modes count];

  if (count > 0)
    {
      NSString			*array[count];
      GSRunLoopPerformer	*item;

      item = [[GSRunLoopPerformer alloc] initWithSelector: aSelector
						   target: target
						 argument: argument
						    order: order];

      [modes getObjects: array];
      while (count-- > 0)
	{
	  NSString	*mode = array[count];
	  unsigned	end;
	  unsigned	i;
	  GSRunLoopCtxt	*context;
	  GSIArray	performers;

	  context = NSMapGet(_contextMap, mode);
	  if (context == nil)
	    {
	      context = [[GSRunLoopCtxt alloc] initWithMode: mode
						      extra: _extra];
	      NSMapInsert(_contextMap, context->mode, context);
	      RELEASE(context);
	    }
	  performers = context->performers;

	  end = GSIArrayCount(performers);
	  for (i = 0; i < end; i++)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, i).obj;
	      if (p->order > order)
		{
		  GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
		  break;
		}
	    }
	  if (i == end)
	    {
	      GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
	    }
	}
      RELEASE(item);
    }
}

/**
 * Removes port to be monitored from given mode.
 * Ports are also removed if they are detected to be invalid.
 */
- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
  [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end

@implementation	NSRunLoop (Housekeeper)
- (void) _setHousekeeper: (NSTimer*)timer
{
  GSRunLoopCtxt	*context;

  context = NSMapGet(_contextMap, NSDefaultRunLoopMode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: NSDefaultRunLoopMode
					      extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  if (context->housekeeper != timer)
    {
      [context->housekeeper invalidate];
      DESTROY(context->housekeeper);
    }
  if (timer != nil)
    {
      context->housekeeper = RETAIN(timer);
    }
}
@end

