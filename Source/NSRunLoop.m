/** Implementation of object for waiting on several input sources
  NSRunLoop.m

   Copyright (C) 1996-1999 Free Software Foundation, Inc.

   Original by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   OPENSTEP version by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

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

   <title>NSRunLoop class reference</title>
   $Date$ $Revision$
*/

#import "common.h"
#define	EXPOSE_NSRunLoop_IVARS	1
#define	EXPOSE_NSTimer_IVARS	1
#import "Foundation/NSMapTable.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSInvocation.h"
#import "GSRunLoopCtxt.h"
#import "GSRunLoopWatcher.h"
#import "GSStream.h"

#import "GSPrivate.h"

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#include <math.h>
#include <time.h>

#if GS_USE_LIBDISPATCH_RUNLOOP
#  define RL_INTEGRATE_DISPATCH 1
#  import "GSDispatch.h"
#endif

NSRunLoopMode const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";
NSRunLoopMode const NSRunLoopCommonModes = @"NSRunLoopCommonModes";

static NSDate	*theFuture = nil;

/* Allow the 'TimerStyle' environment variable to control alternative
 * timer implementations for ease of testing.
 */
static enum {
  TS_SORTARY,	// Use a sorted array of timers in each context
  TS_MINHEAP,	// Use a minheap of timers in each context
  TS_SHAREDA	// Use sorted array shared between contexts
} timerStyle = TS_SORTARY;



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
		  order: (NSUInteger)order;
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
  NS_DURING
    {
      [target performSelector: selector withObject: argument];
    }
  NS_HANDLER
    {
      NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
        @"raised during performSelector... with target %s(%s) "
        @"and selector '%s'",
        [localException name], [localException reason],
        GSClassNameFromObject(target),
        GSObjCIsInstance(target) ? "instance" : "class",
        sel_getName(selector));
    }
  NS_ENDHANDLER
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  order: (NSUInteger)theOrder
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
@interface GSTimedPerformer: NSObject
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
  [self finalize];
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

- (void) finalize
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

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"
#endif

static inline NSDate *timerDate(NSTimer *t)
{
  return t->_date;
}
static inline BOOL timerInvalidated(NSTimer *t)
{
  return t->_invalidated;
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

      IF_NO_ARC(RETAIN(target);)
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

      IF_NO_ARC(RETAIN(target);)
      IF_NO_ARC(RETAIN(arg);)
      [perf getObjects: array];
      while (count-- > 0)
	{
	  GSTimedPerformer	*p = array[count];

	  if (p->target == target && sel_isEqual(p->selector, aSelector)
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
      if ([modes isProxy])
	{
	  for (i = 0; i < count; i++)
	    {
	      marray[i] = [modes objectAtIndex: i];
	    }
	}
      else
	{
          [modes getObjects: marray];
	}
      for (i = 0; i < count; i++)
	{
	  [loop addTimer: item->timer forMode: marray[i]];
	}
    }
}

@end

#ifdef RL_INTEGRATE_DISPATCH

#pragma clang diagnostic push
/* We have no declarations for libdispatch private functions, so we ignore
 * warnings here, knowing that we are using an undocumented feature which
 * may go away in later releases (in which case we will use another library)
 */
#pragma clang diagnostic ignored "-Wimplicit-function-declaration"

@interface GSMainQueueDrainer : NSObject <RunLoopEvents>
+ (void*) mainQueueFileDescriptor;
@end

@implementation GSMainQueueDrainer
+ (void*) mainQueueFileDescriptor
{
#if HAVE_DISPATCH_GET_MAIN_QUEUE_HANDLE_NP
  return (void*)(uintptr_t)dispatch_get_main_queue_handle_np();
#elif HAVE__DISPATCH_GET_MAIN_QUEUE_HANDLE_4CF
  return (void*)(uintptr_t)_dispatch_get_main_queue_handle_4CF();
#else
#error libdispatch missing main queue handle function
#endif
}

- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
#if HAVE_DISPATCH_MAIN_QUEUE_DRAIN_NP
  dispatch_main_queue_drain_np();
#elif HAVE__DISPATCH_MAIN_QUEUE_CALLBACK_4CF
#if defined(__linux__)
  uint64_t value;
  int fd = (int)(intptr_t)data;
  int n = eventfd_read(fd, &value);
  (void) n;
#endif
  _dispatch_main_queue_callback_4CF(NULL);
#else
#error libdispatch missing main queue callback function
#endif
}
@end

#pragma clang diagnostic pop

#endif


typedef struct {
  void                  *sharedContextInfo;
  uint8_t		modeCount;		/* Number of known modes */
  uint64_t		commonModeMask;		/* Common modes as mask */
  NSString		*modeNames[64];		/* Names of known modes */
  GSRunLoopCtxt		*contexts[64];		/* Context for each mode */
  GSIArray		timers;			/* Timers not in contexts */
} RunLoopInternal;
                               
#define internal        ((RunLoopInternal*)_internal)
                                              

@interface NSRunLoop (Private)

- (void) _addWatcher: (GSRunLoopWatcher*)item
	     forMode: (NSString*)mode;
- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode;
- (id) _init;
- (void) _removeWatcher: (void*)data
		   type: (RunLoopEventType)type
		forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)

/** Get the context for the mode name in the current run loop.
 * Returns nil if it does not exist and was not created.
 */
- (GSRunLoopCtxt*) _contextForMode: (NSString*)mode
		      shouldCreate: (BOOL)shouldCreate
{
  GSRunLoopCtxt	*c;
  unsigned	index;

  for (index = 0; index < internal->modeCount; index++)
    {
      c = internal->contexts[index];
      if ([c->mode isEqualToString: mode])
	{
	  return c;
	}
    }
  if (NO == shouldCreate)
    {
      return nil;
    }
  if (internal->modeCount > 63)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Too many nodes added to run loop"];
    }
  c = [[GSRunLoopCtxt alloc] initWithMode: mode
				    extra: &internal->sharedContextInfo];
  c->modeIndex = internal->modeCount;
  internal->contexts[internal->modeCount] = c;
  internal->modeCount++;
  NSMapInsert(_contextMap, c->mode, c);
  RELEASE(c);
  return c;
}

/* Add a watcher to the list for the specified mode.  Keep the list in
   limit-date order. */
- (void) _addWatcher: (GSRunLoopWatcher*) item forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;
  GSIArray	watchers;
  unsigned	i;

  context = [self _contextForMode: mode shouldCreate: YES];
  watchers = context->watchers;
  GSIArrayAddItem(watchers, (GSIArrayItem)((id)item));
  i = GSIArrayCount(watchers);
  if (i % 1000 == 0 && i > context->maxWatchers)
    {
      context->maxWatchers = i;
      NSLog(@"WARNING ... there are %u watchers scheduled in mode %@ of %@",
	i, mode, self);
    }
}

- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context
{
  BOOL	found = NO;

  if (context != nil)
    {
      GSIArray	performers = context->performers;
      unsigned	count = GSIArrayCount(performers);

      if (count > 0)
	{
          NSAutoreleasePool	*arp = [NSAutoreleasePool new];
	  GSRunLoopPerformer	*array[count];
	  GSRunLoopCtxt		*original;
	  unsigned		modeIndex;
	  unsigned		i;

          found = YES;

	  /* We have to remove the performers before firing, so we copy
	   * the pointers without releasing the objects, and then set
	   * the performers to be empty.  The copied objects in 'array'
	   * will be released later.
	   */
	  for (i = 0; i < count; i++)
	    {
	      array[i] = GSIArrayItemAtIndex(performers, i).obj;
	    }
          performers->count = 0;

	  /* Remove the requests that we are about to fire from all modes.
	   */
          original = context;
	  modeIndex = internal->modeCount;
	  while (modeIndex-- > 0)
	    {
	      context = internal->contexts[modeIndex];
	      if (context != original)
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

	  /* Finally, fire the requests and release them.
	   */
	  for (i = 0; i < count; i++)
	    {
	      [array[i] fire];
	      RELEASE(array[i]);
	      IF_NO_ARC([arp emptyPool];)
	    }
          [arp drain];
	}
    }
  return found;
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

  context = [self _contextForMode: mode shouldCreate: NO];
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

- (id) _init
{
  if (nil != (self = [super init]))
    {
      NSZone	*z = NSDefaultMallocZone();

      _contextStack = [NSMutableArray new];
      _contextMap = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
					 NSObjectMapValueCallBacks, 0);
      _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
      _internal = (RunLoopInternal*)NSZoneCalloc(z, 1, sizeof(RunLoopInternal));
      internal->timers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(internal->timers, z, 8);
      // The first mode must be NSDefaultRunLoopMode
      [self _contextForMode: NSDefaultRunLoopMode shouldCreate: YES];
      internal->commonModeMask |= UINT64_C(1);
    }
  return self;
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

  context = [self _contextForMode: mode shouldCreate: NO];
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
 * <p>There is one run loop per thread in an application, which
 *  may always be obtained through the <code>+currentRunLoop</code> method
 *  (you cannot use -init or +new),
 *  however unless you are using the AppKit and the <code>NSApplication</code>
 *  class, the  run loop will not be started unless you explicitly send it a
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
      NSString	*s;

      [self currentRunLoop];
      theFuture = RETAIN([NSDate distantFuture]);
      RELEASE([NSObject leakAt: &theFuture]);
      s = [[[NSProcessInfo processInfo] environment]
	objectForKey: @"TimerStyle"];
      if (s && [s caseInsensitiveCompare: @"SortAry"] == NSOrderedSame)
	{
	  timerStyle = TS_SORTARY;
	}
      else if (s && [s caseInsensitiveCompare: @"MinHeap"] == NSOrderedSame)
	{
	  timerStyle = TS_MINHEAP;
	}
      else if (s && [s caseInsensitiveCompare: @"SharedA"] == NSOrderedSame)
	{
	  timerStyle = TS_SHAREDA;
	}
      else
	{
	  timerStyle = TS_MINHEAP;
	}
    }
}

/* Declare the drainer at file scope so that the clang analyzer will not
 * report it as leaked.
 */
#ifdef RL_INTEGRATE_DISPATCH
static GSMainQueueDrainer 	*drainer = nil;
#endif

+ (NSRunLoop*) _runLoopForThread: (NSThread*) aThread
{
  GSRunLoopThreadInfo	*info = GSRunLoopInfoForThread(aThread);
  NSRunLoop             *current = info->loop;

  if (nil == current)
    {
      current = info->loop = [[self alloc] _init];
      /* If this is the main thread, set up a housekeeping timer.
       */
      if (nil != current && [GSCurrentThread() isMainThread] == YES)
        {
          NSAutoreleasePool		*arp = [NSAutoreleasePool new];
          NSNotificationCenter	        *ctr;
          NSNotification		*not;
          NSInvocation		        *inv;
          NSTimer                       *timer;
          SEL			        sel;

          ctr = [NSNotificationCenter defaultCenter];
          not = [NSNotification notificationWithName: @"GSHousekeeping"
                                              object: nil
                                            userInfo: nil];
          sel = @selector(postNotification:);
          inv = [NSInvocation invocationWithMethodSignature:
            [ctr methodSignatureForSelector: sel]];
          [inv setTarget: ctr];
          [inv setSelector: sel];
          [inv setArgument: &not atIndex: 2];
          [inv retainArguments];

          timer = [[NSTimer alloc] initWithFireDate: nil
                                           interval: 30.0
                                             target: inv
                                           selector: NULL
                                           userInfo: nil
                                            repeats: YES];
          [current addTimer: timer forMode: NSDefaultRunLoopMode];
	  RELEASE(timer);	// Retained in run loop until invalidated

          #ifdef RL_INTEGRATE_DISPATCH
	  if (nil == drainer)
	    {
	      /* We leak the queue drainer, because it's integral part of RL
	       * operations
	       */
	      drainer = [GSMainQueueDrainer new];
	    }
          [current addEvent: [GSMainQueueDrainer mainQueueFileDescriptor]
#ifdef _WIN32
                       type: ET_HANDLE
#else
                       type: ET_RDESC
#endif
                    watcher: drainer
                    forMode: NSDefaultRunLoopMode];

          #endif
          [arp drain];
        }
    }
  return current;
}

+ (NSRunLoop*) currentRunLoop
{
  return [self _runLoopForThread: nil];
}

+ (NSRunLoop*) mainRunLoop
{
  return [self _runLoopForThread: [NSThread mainThread]];
}

- (id) init
{
  DESTROY(self);
  return nil;
}

- (void) dealloc
{
  RELEASE(_contextStack);
  if (_contextMap != 0)
    {
      NSFreeMapTable(_contextMap);
    }
  RELEASE(_timedPerformers);
  if (internal)
    {
      while (internal->modeCount-- > 0)
	{
	  internal->contexts[internal->modeCount] = nil;
	  DESTROY(internal->modeNames[internal->modeCount]);
	}
      GSIArrayEmpty(internal->timers);
      NSZoneFree(internal->timers->zone, (void*)internal->timers);

      NSZoneFree(NSDefaultMallocZone(), internal);
      _internal = NULL;
    }
  DEALLOC
}

/**
 * Returns the current mode of this runloop.  If the runloop is not running
 * then this method returns nil.
 */
- (NSString*) currentMode
{
  return _currentMode;
}



/* Comparator for timers
 */
static NSComparisonResult
sorter(GSIArrayItem a, GSIArrayItem b)
{
  return [(NSTimer*)a.obj compare: (NSTimer*)b.obj];
}

static BOOL
timerToTrim(GSIArrayItem item)
{
  return ((NSTimer*)(item.obj))->_invalidated;
}

#if 0
static NSString *
logTimers(GSIArray timers)
{
  NSMutableString	*s = [NSMutableString stringWithCapacity: 1000];
  unsigned		count = GSIArrayCount(timers);
  unsigned		index;

  for (index = 0; index < count; index++)
    {
      [s appendFormat: @"    %@\n", GSIArrayItemAtIndex(timers, index).obj];
    }
  return s;
}
#endif


/**
 * Adds a timer to the loop in the specified mode.<br />
 * Timers are removed automatically when they are invalid.<br />
 */
- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode
{
  const void	*loop = (const void*)self;
  GSRunLoopCtxt	*context;
  GSMinHeap	*timerHeap;
  GSIArray      timers;
  uint64_t	modeBit;
  unsigned      i;

  if ([timer isKindOfClass: [NSTimer class]] == NO
    || [timer isProxy] == YES)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] not a valid timer",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (timer->_loop != loop && timer->_loop != nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] timer already scheduled in another runloop",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if ([mode isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] not a valid mode",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  context = [self _contextForMode: mode shouldCreate: YES];

  NSDebugMLLog(@"NSRunLoop", @"add timer for %f in %@",
    [[timer fireDate] timeIntervalSinceReferenceDate], mode);

  timer->_loop = loop;	// Not retained.

  modeBit = (UINT64_C(1) << context->modeIndex);

  if ((timer->_modeMask & modeBit) != 0)
    {
      return;	// Already present in this mode
    }
  if (TS_MINHEAP == timerStyle)
    {
      timerHeap = context->timerHeap;

      /* Timers can be scheduled in more than one mode, and if a timer fires
       * and repeats it will have updated its fire date.  That will leave it
       * incorrectly positioned in the min heap in other modes.  To handle
       * that we must track whether it is scheduled in more than one mode to
       * know if we need to check other modes for repositionng.
       */
      [timerHeap push: timer];
      i = [timerHeap count];
      if (i % 1000 == 0 && i > context->maxTimers)
	{
	  context->maxTimers = i;
	  NSLog(@"WARNING ... there are %u timers scheduled in mode %@ of %@",
	    i, mode, self);
	}
    }
  else if (TS_SHAREDA == timerStyle)
    {
      if (0 == timer->_modeMask)
	{
	  timers = internal->timers;
	  /* When the timer is first scheduled, we must add to the shared
	   * sorted array.
	   */
	  GSIArrayInsertSorted(timers, (GSIArrayItem)((id)timer), sorter);
	  i = GSIArrayCount(timers);
	  if (i % 1000 == 0 && i > context->maxTimers)
	    {
	      context->maxTimers = i;
	      NSLog(@"WARNING ... there are %u timers scheduled in %@",
		i, self);
	    }
	}
    }
  else
    {
      timers = context->timers;
      GSIArrayInsertSorted(timers, (GSIArrayItem)((id)timer), sorter);
      i = GSIArrayCount(timers);
      if (i % 1000 == 0 && i > context->maxTimers)
	{
	  context->maxTimers = i;
	  NSLog(@"WARNING ... there are %u timers scheduled in mode %@ of %@",
	    i, mode, self);
	}
    }
  timer->_modeMask |= modeBit;
}



/* Ensure that the fire date has been updated either by the timeout handler
 * updating it or by incrementing it ourselves.<br />
 * Return YES if it was updated, NO if it was invalidated.
 */
static BOOL
updateTimer(NSTimer *t, NSDate *d, NSTimeInterval now)
{
  if (timerInvalidated(t))
    {
      return NO;
    }
  if (timerDate(t) == d)
    {
      NSTimeInterval	ti = [d timeIntervalSinceReferenceDate];
      NSTimeInterval	increment = [t timeInterval];

      if (increment <= 0.0)
	{
	  /* Should never get here ... unless a subclass is returning
	   * a bad interval ... we return NO so that the timer gets
	   * removed from the loop.
	   */
	  NSLog(@"WARNING timer %@ had bad interval ... removed", t);
	  return NO;
	}

      ti += increment;	// Hopefully a single increment will do.

      if (ti < now)
	{
	  NSTimeInterval	add;

	  /* Just incrementing the date was insufficient to bring it to
	   * the current time, so we must have missed one or more fire
	   * opportunities, or the fire date has been set on the timer.
	   * If a fire date long ago has been set and the increment value
	   * is really small, we might need to increment very many times
	   * to get the new fire date.  To avoid looping for ages, we
	   * calculate the number of increments needed and do them in one
	   * go.
	   */
	  add = floor((now - ti) / increment);
	  ti += (increment * add);
	  if (ti < now)
	    {
	      ti += increment;
	    }
	}
      RELEASE(t->_date);
      t->_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
    }
  return YES;
}

/* Efficient code to find the indices of bits in a bitmask (which must
 * not be zero), clearing the bits as they are processed.
 */
#define	GET_INDEX_AND_CLEAR_BIT(mask) ({\
  int	index = __builtin_clz(mask); \
  mask &= (mask - 1); \
  index; \
})

- (NSDate*) _limitDateForContext: (GSRunLoopCtxt *)context
{
  NSDate		*when = nil;
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  uint64_t		contextModeMask = ~(UINT64_C(1)<<context->modeIndex);
  GSMinHeap		*timerHeap;
  GSIArray		timers;
  unsigned		count;
  NSTimeInterval	now;
  NSDate                *earliest;
  NSDate		*d;
  NSTimer		*timer;
  NSTimeInterval	ti;

  /* Save current time so we don't keep redoing system call to
   * get it and so that we check timer fire dates against a known
   * value at the point when the method was called.
   * If we refetched the date after firing each timer, the time
   * taken in firing the timer could be large enough so we would
   * just keep firing the timer repeatedly and never return from
   * this method.
   */
  now = GSPrivateTimeNow();

  /* Fire the oldest/first valid timer whose fire date has passed
   * and fire it.
   */
  if (TS_MINHEAP == timerStyle)
    {
      timerHeap = context->timerHeap;
      timer = [timerHeap peek];
      while (timer != nil)
	{
	  if (timerInvalidated(timer))
	    {
	      timer = [timerHeap next];
	    }
	  else
	    {
	      d = timerDate(timer);
	      ti = [d timeIntervalSinceReferenceDate];
	      if (ti < now)
		{
		  int		modeIndex;
		  uint64_t	mask;
		  uint64_t	save;
		  GSRunLoopCtxt	*c;

		  timer = [timerHeap popRetained];
		  mask = timer->_modeMask;
		  mask &= contextModeMask;
		  save = mask;
		  while (mask)
		    {
		      modeIndex = GET_INDEX_AND_CLEAR_BIT(mask);
		      c = internal->contexts[modeIndex];
		      [c->timerHeap removeObjectIdenticalTo: timer];
		    }
		  [timer fire];
		  GSPrivateNotifyASAP(_currentMode);
		  IF_NO_ARC([arp emptyPool];)
		  if (updateTimer(timer, d, now) == YES)
		    {
		      /* Updated ... replace in heap.
		       */
		      [timerHeap push: timer];
		      mask = save;
		      while (mask)
			{
			  modeIndex = GET_INDEX_AND_CLEAR_BIT(mask);
			  c = internal->contexts[modeIndex];
			  [c->timerHeap push: timer];
			}
		    }
		  RELEASE(timer);
		}
	      break;
	    }
	}

      /* Now, find the earliest remaining timer date while removing
       * any invalidated timers.
       */
      earliest = nil;
      timer = [timerHeap peek];
      while (timer != nil)
	{
	  if (timerInvalidated(timer))
	    {
	      timer = [timerHeap next];
	    }
	  else
	    {
	      earliest = timerDate(timer);
	      break;
	    }
	}
    }
  else if (TS_SHAREDA == timerStyle)
    {
      uint64_t		bit = (UINT64_C(1) << context->modeIndex);
      unsigned		index;
      GSIArrayItem	item;

   
      /* Find and remove blocks of invalidated timers
       */ 
      timers = internal->timers;
      GSIArrayTrim(timers, timerToTrim);

      count = GSIArrayCount(timers);
      for (index = 0; index < count; index++)
	{
	  item = GSIArrayItemAtIndex(timers, index);
	  timer = (NSTimer*)item.obj;
	  if (timer->_modeMask & bit)
	    {
	      break;	// First timer in current mode
	    }
	}
      if (index < count)
	{
	  d = timerDate(timer);
	  ti = [d timeIntervalSinceReferenceDate];
	  if (ti < now)
	    {
	      GSIArrayRemoveItemAtIndexNoRelease(timers, 0);
	      [timer fire];
	      GSPrivateNotifyASAP(_currentMode);
	      IF_NO_ARC([arp emptyPool];)
	      if (updateTimer(timer, d, now) == YES)
		{
		  /* Updated ... replace in array.
		   */
		  GSIArrayInsertSortedNoRetain(timers, item, sorter);
		}
	      else
		{
		  RELEASE(timer);
		}
	    }
	}

      /* Now, find the earliest remaining timer date in this mode
       */
      earliest = nil;
      count = GSIArrayCount(timers);
      for (index = 0; index < count; index++)
	{
	  timer = (NSTimer*)GSIArrayItemAtIndex(timers, index).obj;
	  if (timer->_modeMask & bit)
	    {
	      earliest = timerDate(timer);
	      break;	// First timer in current mode
	    }
	}
    }
  else
    {
      GSIArrayItem	item;

      timers = context->timers;

      GSIArrayTrim(timers, timerToTrim);
      if (GSIArrayCount(timers) > 0)
	{
	  item = GSIArrayItemAtIndex(timers, 0);
	  timer = item.obj;
	  d = timerDate(timer);
	  ti = [d timeIntervalSinceReferenceDate];
	  if (ti < now)
	    {
	      int		modeIndex;
	      uint64_t		mask;
	      uint64_t		save;
	      GSRunLoopCtxt	*c;

	      GSIArrayRemoveItemAtIndexNoRelease(timers, 0);
	      mask = timer->_modeMask;
	      mask &= contextModeMask;
	      save = mask;

	      while (mask != 0)
		{
		  unsigned	location;
		  unsigned	length;

		  modeIndex = GET_INDEX_AND_CLEAR_BIT(mask);
		  c = internal->contexts[modeIndex];

		  /* Find the timers matching our fire date.
		   */
		  GSIArrayTrim(c->timers, timerToTrim);
		  location = GSIArraySearchCount(c->timers,
		    item, sorter, &length);

		  /* Find our exact timer, and remove it.
		   */
		  while (length-- > 0)
		    {
		      if (GSIArrayItemAtIndex(c->timers,
			location + length).obj == timer)
			{
			  GSIArrayRemoveItemAtIndex(
			    c->timers, location + length);
			  break;
			}
		    }
		}
	      [timer fire];
	      GSPrivateNotifyASAP(_currentMode);
	      IF_NO_ARC([arp emptyPool];)
	      if (updateTimer(timer, d, now) == YES)
		{
		  /* Updated ... replace in array(s).
		   */
		  GSIArrayInsertSortedNoRetain(timers, item, sorter);
		  mask = save;
		  while (mask)
		    {
		      modeIndex = GET_INDEX_AND_CLEAR_BIT(mask);
		      c = internal->contexts[modeIndex];
		      GSIArrayInsertSorted(c->timers, item, sorter);
		    }
		}
	      else
		{
		  RELEASE(timer);
		}
	    }
	}
      /* Now, find the earliest remaining timer date while removing
       * any invalidated timers.
       */
      earliest = nil;
      count = GSIArrayCount(timers);
      if (count > 0)
	{
	  unsigned	i;

	  for (i = 0; i < count; i++)
	    {
	      timer = (NSTimer*)GSIArrayItemAtIndex(timers, i).obj;
	      if (!timerInvalidated(timer))
		{
		  earliest = timerDate(timer);
		  break;
		}
	    }
	  if (nil == earliest)
	    {
	      GSIArrayRemoveAllItems(timers);	// all invalidated
	    }
	  else if (i > 0)
	    {
	      GSIArrayRemoveItems(timers, 0, i);
	    }
	}
    }
  [arp drain];

  /* The earliest date of a valid timeout is retained in 'when'
   * and used as our limit date.
   */
  if (earliest != nil)
    {
      when = AUTORELEASE(RETAIN(earliest));
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

  return when;
}

/**
 * Fires timers whose fire date has passed, and checks timers and limit dates
 * for input sources, determining the earliest time that any future timeout
 * becomes due.  Returns that date/time.<br />
 * Returns distant future if the loop contains no timers, just input sources
 * without timeouts.<br />
 * Returns nil if the loop contains neither timers nor input sources.
 */
- (NSDate*) limitDateForMode: (NSString*)mode
{
  GSRunLoopCtxt		*context;
  NSDate		*when = nil;

  context = [self _contextForMode: mode shouldCreate: NO];
  if (context != nil)
    {
      NSString		*savedMode = _currentMode;

      _currentMode = mode;
      NS_DURING
	{
          when = [self _limitDateForContext: context];
	  _currentMode = savedMode;
	}
      NS_HANDLER
	{
	  _currentMode = savedMode;
	  [localException raise];
	}
      NS_ENDHANDLER

      NSDebugMLLog(@"NSRunLoop", @"limit date %f in %@",
	nil == when ? 0.0 : [when timeIntervalSinceReferenceDate], mode);
    }
  return when;
}

/**
 * Listen for events from input sources.<br />
 * If limit_date is nil or in the past, then don't wait;
 * just fire timers, poll inputs and return, otherwise block
 * (firing timers when they are due) until input is available
 * or until the earliest limit date has passed (whichever comes first).<br />
 * If the supplied mode is nil, uses NSDefaultRunLoopMode.<br />
 * If there are no input sources or timers in the mode, returns immediately.
 */
- (void) acceptInputForMode: (NSString*)mode
		 beforeDate: (NSDate*)limit_date
{
  GSRunLoopCtxt		*context;
  NSTimeInterval	ti = 0;
  int			timeout_ms;
  NSString		*savedMode = _currentMode;
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  NSAssert(mode, NSInvalidArgumentException);
  if (mode == nil)
    {
      mode = NSDefaultRunLoopMode;
    }
  context = [self _contextForMode: mode shouldCreate: NO];
  if (nil == context)
    {
      return;
    }
  _currentMode = mode;

  [self _checkPerformers: context];

  NS_DURING
    {
      BOOL      done = NO;
      NSDate    *when;

      while (NO == done)
        {
          [arp emptyPool];
          when = [self _limitDateForContext: context];
          if (nil == when)
            {
              NSDebugMLLog(@"NSRunLoop",
                @"no inputs or timers in mode %@", mode);
              GSPrivateNotifyASAP(_currentMode);
              GSPrivateNotifyIdle(_currentMode);
              /* Pause until the limit date or until we might have
               * a method to perform in this thread.
               */
              [GSRunLoopCtxt awakenedBefore: nil];
              [self _checkPerformers: context];
              GSPrivateNotifyASAP(_currentMode);
              [_contextStack removeObjectIdenticalTo: context];
              _currentMode = savedMode;
              [arp drain];
              NS_VOIDRETURN;
            }
          else
            {
              if (nil == limit_date)
                {
                  when = nil;
                }
              else
                {
                  when = [when earlierDate: limit_date];
                }
            }

          /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
          if (nil == when || (ti = [when timeIntervalSinceNow]) <= 0.0)
            {
              /* Don't wait at all. */
              timeout_ms = 0;
            }
          else
            {
              /* Wait until the LIMIT_DATE. */
              if (ti >= INT_MAX / 1000.0)
                {
                  timeout_ms = INT_MAX;	// Far future.
                }
              else
                {
                  timeout_ms = (int)(ti * 1000.0);
                }
            }

          NSDebugMLLog(@"NSRunLoop",
            @"accept I/P before %d millisec from now in %@",
            timeout_ms, mode);

	  if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
	    {
	      [_contextStack addObject: context];
	    }
          done = [context pollUntil: timeout_ms within: _contextStack];
          if (NO == done)
            {
              GSPrivateNotifyIdle(_currentMode);
              if (nil == limit_date || [limit_date timeIntervalSinceNow] <= 0.0)
                {
                  done = YES;
                }
            }
          [self _checkPerformers: context];
          GSPrivateNotifyASAP(_currentMode);
          [context endPoll];

	  /* Once a poll has been completed on a context, we can remove that
	   * context from the stack even if it is actually polling at an outer
	   * level of re-entrancy ... since the poll we have just done will
	   * have handled any events that the outer levels would have wanted
	   * to handle, and the polling for this context will be marked as
	   * ended.
	   */
	  [_contextStack removeObjectIdenticalTo: context];
        }

      _currentMode = savedMode;
    }
  NS_HANDLER
    {
      _currentMode = savedMode;
      [context endPoll];
      [_contextStack removeObjectIdenticalTo: context];
      [localException raise];
    }
  NS_ENDHANDLER
  NSDebugMLLog(@"NSRunLoop", @"accept I/P completed in %@", mode);
  [arp drain];
}

- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString              *savedMode = _currentMode;
  GSRunLoopCtxt		*context;
  NSDate		*d;

  NSAssert(mode != nil, NSInvalidArgumentException);

  /* Process any pending notifications.
   */
  GSPrivateNotifyASAP(mode);

  /* And process any performers scheduled in the loop (eg something from
   * another thread.
   */
  _currentMode = mode;
  context = [self _contextForMode: mode shouldCreate: NO];
  [self _checkPerformers: context];
  _currentMode = savedMode;

  /* Find out how long we can wait before first limit date.
   * If there are no input sources or timers, return immediately.
   */
  d = [self limitDateForMode: mode];
  if (nil == d)
    {
      [arp drain];
      return NO;
    }

  /* Use the earlier of the two dates we have (nil date is like distant past).
   */
  if (nil == date)
    {
      [self acceptInputForMode: mode beforeDate: nil];
    }
  else
    {
      /* Retain the date in case the firing of a timer (or some other event)
       * releases it.
       */
      d = [[d earlierDate: date] copy];
      [self acceptInputForMode: mode beforeDate: d];
      RELEASE(d);
    }

  [arp drain];
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
  BOOL		mayDoMore = YES;

  /* Positive values are in the future. */
  while (YES == mayDoMore)
    {
      mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
      if (nil == date || [date timeIntervalSinceNow] <= 0.0)
        {
          mayDoMore = NO;
        }
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
  unsigned	modeIndex = internal->modeCount;

  while (modeIndex-- > 0)
    {
      GSRunLoopCtxt	*context = internal->contexts[modeIndex];
      GSIArray		performers = context->performers;
      unsigned		count = GSIArrayCount(performers);

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
  unsigned	modeIndex = internal->modeCount;

  while (modeIndex-- > 0)
    {
      GSRunLoopCtxt	*context = internal->contexts[modeIndex];
      GSIArray		performers = context->performers;
      unsigned		count = GSIArrayCount(performers);

      while (count--)
	{
	  GSRunLoopPerformer	*p;

	  p = GSIArrayItemAtIndex(performers, count).obj;
	  if (p->target == target && sel_isEqual(p->selector, aSelector)
	    && (p->argument == argument || [p->argument isEqual: argument]))
	    {
	      GSIArrayRemoveItemAtIndex(performers, count);
	    }
	}
    }
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
		   order: (NSUInteger)order
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

      if ([modes isProxy])
	{
	  unsigned	i;

	  for (i = 0; i < count; i++)
	    {
	      array[i] = [modes objectAtIndex: i];
	    }
	}
      else
	{
          [modes getObjects: array];
	}
      while (count-- > 0)
	{
	  NSString	*mode = array[count];
	  unsigned	end;
	  unsigned	i;
	  GSRunLoopCtxt	*context;
	  GSIArray	performers;

	  context = [self _contextForMode: mode shouldCreate: YES];
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
	  i = GSIArrayCount(performers);
	  if (i % 1000 == 0 && i > context->maxPerformers)
	    {
	      context->maxPerformers = i;
	      if (sel_isEqual(aSelector, @selector(fire)))
		{
		  NSLog(@"WARNING ... there are %u performers scheduled"
		    @" in mode %@ of %@\n(Latest: fires %@)",
		    i, mode, self, target);
		}
	      else
		{
		  NSLog(@"WARNING ... there are %u performers scheduled"
		    @" in mode %@ of %@\n(Latest: [%@ %@])",
		    i, mode, self, NSStringFromClass([target class]),
		    NSStringFromSelector(aSelector));
		}
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
