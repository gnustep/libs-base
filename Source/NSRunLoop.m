/** Implementation of object for waiting on several input seurces
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSRunLoop class reference</title>
   $Date$ $Revision$
*/

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSDebug.h>

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#if HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#include <time.h>
#include <limits.h>
#include <string.h>		/* for memset() */

static int	debug_run_loop = 0;
static NSDate	*theFuture = nil;

extern BOOL	GSCheckTasks();


/*
 *	The 'GSRunLoopWatcher' class was written to permit the (relatively)
 *	easy addition of new events to be watched for in the runloop.
 *
 *	To add a new type of event, the 'RunLoopEventType' enumeration must be
 *	extended, and the methods must be modified to handle the new type.
 *
 *	The internal variables if the GSRunLoopWatcher are used as follows -
 *
 *	The '_date' variable contains a date after which the event is useless
 *	and the watcher can be removed from the runloop.
 *
 *	If '_invalidated' is set, the watcher should be disabled and should
 *	be removed from the runloop when next encountered.
 *
 *	The 'data' variable is used to identify the  resource/event that the
 *	watcher is interested in.
 *
 *	The 'receiver' is the object which should be told when the event
 *	occurs.  This object is retained so that we know it will continue
 *	to exist and can handle a callback.
 *
 *	The 'type' variable indentifies the type of event watched for.
 *	NSRunLoops [-acceptInputForMode: beforeDate: ] method MUST contain
 *	code to watch for events of each type.
 *
 *	To set this variable, the method adding the GSRunLoopWatcher to the
 *	runloop must ask the 'receiver' (or its delegate) to supply a date
 *	using the '[-limitDateForMode: ]' message.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */
 
static SEL	eventSel;	/* Initialized in [NSRunLoop +initialize] */

@interface GSRunLoopWatcher: NSObject
{
@public
  NSDate		*_date;		/* First to match layout of NSTimer */
  BOOL			_invalidated;	/* 2nd to match layout of NSTimer */
  IMP			handleEvent;	/* New-style event handling */
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  unsigned 		count;
}
- (id) initWithType: (RunLoopEventType)type
	   receiver: (id)anObj
	       data: (void*)data;
@end

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  RELEASE(_date);
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;

  switch (aType)
    {
      case ET_EDESC: 	type = aType;	break;
      case ET_RDESC: 	type = aType;	break;
      case ET_WDESC: 	type = aType;	break;
      case ET_RPORT: 	type = aType;	break;
      default: 
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"];
    }
  receiver = anObj;
  if ([receiver respondsToSelector: eventSel] == YES) 
    handleEvent = [receiver methodForSelector: eventSel];
  else
    [NSException raise: NSInvalidArgumentException
		format: @"RunLoop listener has no event handling method"];
  data = item;
  return self;
}

@end

/*
 *	Two optimisation functions that depend on a hack that the layout of
 *	the NSTimer class is known to be the same as GSRunLoopWatcher for the
 *	first two elements.
 */
static inline NSDate* timerDate(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_date;
}

static inline BOOL timerInvalidated(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_invalidated;
}



/*
 *      Setup for inline operation of arrays.
 */

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#if	GS_WITH_GC == 0
#define GSI_ARRAY_RELEASE(X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(X)	[(X).obj retain]
#else
#define GSI_ARRAY_RELEASE(X)	
#define GSI_ARRAY_RETAIN(X)	
#endif

#include <base/GSIArray.h>

static NSComparisonResult aSort(GSIArrayItem i0, GSIArrayItem i1)
{
  return [((GSRunLoopWatcher *)(i0.obj))->_date 
    compare: ((GSRunLoopWatcher *)(i1.obj))->_date];
}



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
      target = aTarget;
      argument = anArgument;
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
 *	The GSTimedPerformer class is used to hold information about
 *	messages which are due to be sent to objects at a particular time.
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
@end

@implementation GSTimedPerformer

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(target);
  RELEASE(argument);
  [super dealloc];
}

- (void) fire
{
  timer = nil;
  [target performSelector: selector withObject: argument];
  [[[NSRunLoop currentRunLoop] _timedPerformers]
    removeObjectIdenticalTo: self];
}

- (void) gcFinalize
{
  if (timer != nil)
    [timer invalidate];
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  delay: (NSTimeInterval)delay
{
  self = [super init];
  if (self)
    {
      selector = aSelector;
      target = RETAIN(aTarget);
      argument = RETAIN(anArgument);
      timer = [NSTimer timerWithTimeInterval: delay
				      target: self
				    selector: @selector(fire)
				    userInfo: nil
				     repeats: NO];
    }
  return self;
}
@end

@implementation NSObject (TimedPerformers)

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
	    && [p->argument isEqual: arg])
	    {
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
- (void) _checkPerformers;
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
  GSIArray	watchers;
  id		obj;

  watchers = NSMapGet(_mode_2_watchers, mode);
  if (watchers == 0)
    {
      NSZone	*z = [self zone];

      watchers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(watchers, z, 8);
      NSMapInsert(_mode_2_watchers, mode, watchers);
    }

  /*
   *	If the receiver or its delegate (if any) respond to
   *	'limitDateForMode: ' then we ask them for the limit date for
   *	this watcher.
   */
  obj = item->receiver;
  if ([obj respondsToSelector: @selector(limitDateForMode:)])
    {
      NSDate	*d = [obj limitDateForMode: mode];

      item->_date = RETAIN(d);
    }
  else if ([obj respondsToSelector: @selector(delegate)])
    {
      obj = [obj delegate];
      if (obj != nil && [obj respondsToSelector: @selector(limitDateForMode:)])
	{
	  NSDate	*d = [obj limitDateForMode: mode];

	  item->_date = RETAIN(d);
	}
      else
	item->_date = RETAIN(theFuture);
    }
  else
    item->_date = RETAIN(theFuture);
  GSIArrayInsertSorted(watchers, (GSIArrayItem)item, aSort);
}

- (void) _checkPerformers
{
  GSIArray	performers = NSMapGet(_mode_2_performers, _current_mode);
  unsigned	count;

  if (performers != 0 && (count = GSIArrayCount(performers)) > 0)
    {
      GSRunLoopPerformer	*array[count];
      NSMapEnumerator		enumerator;
      GSIArray			tmp;
      void			*mode;
      unsigned			i;

      /*
       * Copy the array - because we have to cancel the requests before firing.
       */
      for (i = 0; i < count; i++)
	{
	  array[i] = RETAIN(GSIArrayItemAtIndex(performers, i).obj);
	}

      /*
       * Remove the requests that we are about to fire from all modes.
       */
      enumerator = NSEnumerateMapTable(_mode_2_performers);
      while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&tmp))
	{
	  unsigned	tmpCount = GSIArrayCount(tmp);

	  while (tmpCount--)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(tmp, tmpCount).obj;
	      for (i = 0; i < count; i++)
		{
		  if (p == array[i])
		    {
		      GSIArrayRemoveItemAtIndex(tmp, tmpCount);
		    }
		}
	    }
	}

      /*
       * Finally, fire the requests.
       */
      for (i = 0; i < count; i++)
	{
	  [array[i] fire];
	  RELEASE(array[i]);
	}
    }
}

- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode
{
  GSIArray		watchers;

  if (mode == nil)
    {
      mode = _current_mode;
    }

  watchers = NSMapGet(_mode_2_watchers, mode);
  if (watchers)
    {
      unsigned		i = GSIArrayCount(watchers);

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

- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode
{
  GSIArray	watchers;

  if (mode == nil)
    {
      mode = _current_mode;
    }

  watchers = NSMapGet(_mode_2_watchers, mode);
  if (watchers)
    {
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

+ (id) currentInstance
{
  return [self currentRunLoop];
}

+ (NSString*) currentMode
{
  return [[self currentRunLoop] currentMode];
}

+ (void) run
{
  [[self currentRunLoop] run];
}

- (void) addEvent: (void*)data
             type: (RunLoopEventType)type
          watcher: (id<RunLoopEvents>)watcher
          forMode: (NSString*)mode
{
  GSRunLoopWatcher	*info;

  if (mode == nil)
    {
      mode = _current_mode;
    }

  info = [self _getWatcher: data type: type forMode: mode];

  if (info && info->receiver == (id)watcher)
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
      mode = _current_mode;
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

/* Running the run loop once through for timers and input listening. */

- (BOOL) runOnceBeforeDate: (NSDate*)date forMode: (NSString*)mode
{
  return [self runMode: mode beforeDate: date];
}

- (BOOL) runOnceBeforeDate: (NSDate*)date
{
  return [self runOnceBeforeDate: date forMode: _current_mode];
}

- (void) runUntilDate: (NSDate*)date forMode: (NSString*)mode
{
  double	ti = [date timeIntervalSinceNow];
  BOOL		mayDoMore = YES;

  /* Positive values are in the future. */
  while (ti > 0 && mayDoMore == YES)
    {
      if (debug_run_loop)
	printf ("\tNSRunLoop run until date %f seconds from now\n", ti);
      mayDoMore = [self runMode: mode beforeDate: date];
      ti = [date timeIntervalSinceNow];
    }
}

+ (void) runUntilDate: (NSDate*)date forMode: (NSString*)mode
{
  [[self currentRunLoop] runUntilDate: date forMode: mode];
}

+ (void) runUntilDate: (NSDate*)date
{
  [[self currentRunLoop] runUntilDate: date];
}

+ (BOOL) runOnceBeforeDate: (NSDate*)date forMode: (NSString*)mode
{
  return [[self currentRunLoop] runOnceBeforeDate: date forMode: mode];
}

+ (BOOL) runOnceBeforeDate: (NSDate*)date 
{
  return [[self currentRunLoop] runOnceBeforeDate: date];
}

@end



@implementation NSRunLoop

#if	GS_WITH_GC == 0
static SEL	wRelSel;
static SEL	wRetSel;
static IMP	wRelImp;
static IMP	wRetImp;

static void
wRelease(void* t, id w)
{
  (*wRelImp)(w, wRelSel);
}

static id
wRetain(void* t, id w)
{
  return (*wRetImp)(w, wRetSel);
}

const NSMapTableValueCallBacks WatcherMapValueCallBacks = 
{
  (NSMT_retain_func_t) wRetain,
  (NSMT_release_func_t) wRelease,
  (NSMT_describe_func_t) 0
};
#else
#define	WatcherMapValueCallBacks	NSOwnedPointerMapValueCallBacks 
#endif

static void*
aRetain(void* t, GSIArray a)
{
  return t;
}

static void
aRelease(void* t, GSIArray a)
{
  GSIArrayEmpty(a);
  NSZoneFree(a->zone, (void*)a);
}

const NSMapTableValueCallBacks ArrayMapValueCallBacks = 
{
  (NSMT_retain_func_t) aRetain,
  (NSMT_release_func_t) aRelease,
  (NSMT_describe_func_t) 0
};


+ (void) initialize
{
  if (self == [NSRunLoop class])
    {
      [self currentRunLoop];
      theFuture = RETAIN([NSDate distantFuture]);
      eventSel = @selector(receivedEvent:type:extra:forMode:);
#if	GS_WITH_GC == 0
      wRelSel = @selector(release);
      wRetSel = @selector(retain);
      wRelImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRelSel];
      wRetImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRetSel];
#endif
    }
}

+ (NSRunLoop*) currentRunLoop
{
  static NSString	*key = @"NSRunLoopThreadKey";
  NSMutableDictionary	*d;
  NSRunLoop		*r;

  d = GSCurrentThreadDictionary();
  r = [d objectForKey: key];
  if (r == nil)
    {
      if (d != nil)
	{
	  r = [self new];
	  [d setObject: r forKey: key];
	  RELEASE(r);
	}
    }
  return r;
}

/* This is the designated initializer. */
- (id) init
{
  [super init];
  _current_mode = NSDefaultRunLoopMode;
  _mode_2_timers = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
				     ArrayMapValueCallBacks, 0);
  _mode_2_watchers = NSCreateMapTable (NSObjectMapKeyCallBacks,
					   ArrayMapValueCallBacks, 0);
  _mode_2_performers = NSCreateMapTable (NSObjectMapKeyCallBacks,
					   ArrayMapValueCallBacks, 0);
  _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
  _efdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				  WatcherMapValueCallBacks, 0);
  _rfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				  WatcherMapValueCallBacks, 0);
  _wfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				  WatcherMapValueCallBacks, 0);
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(_timedPerformers);
  [super dealloc];
}

- (void) gcFinalize
{
  NSFreeMapTable(_mode_2_timers);
  NSFreeMapTable(_mode_2_watchers);
  NSFreeMapTable(_mode_2_performers);
  NSFreeMapTable(_efdMap);
  NSFreeMapTable(_rfdMap);
  NSFreeMapTable(_wfdMap);
}

- (NSString*) currentMode
{
  return _current_mode;
}


/* Adding timers.  They are removed when they are invalid. */

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode
{
  GSIArray timers;

  timers = NSMapGet(_mode_2_timers, mode);
  if (!timers)
    {
      NSZone	*z = [self zone];

      timers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(timers, z, 8);
      NSMapInsert(_mode_2_timers, mode, timers);
    }
  GSIArrayInsertSorted(timers, (GSIArrayItem)timer, aSort);
}


/* Fire appropriate timers and determine the earliest time that anything
  watched for becomes useless. */

- (NSDate*) limitDateForMode: (NSString*)mode
{
  id			saved_mode;
  NSDate		*when;
  GSIArray		timers;
  GSIArray		watchers;
  NSTimer		*min_timer = nil;
  GSRunLoopWatcher	*min_watcher = nil;
  CREATE_AUTORELEASE_POOL(arp);

  saved_mode = _current_mode;
  _current_mode = mode;

  timers = NSMapGet(_mode_2_timers, mode);
  if (timers)
    {
      while (GSIArrayCount(timers) != 0)
	{
	  min_timer = GSIArrayItemAtIndex(timers, 0).obj;
	  if (timerInvalidated(min_timer) == YES)
	    {
	      GSIArrayRemoveItemAtIndex(timers, 0);
	      min_timer = nil;
	      continue;
	    }

	  if ([timerDate(min_timer) timeIntervalSinceNow] > 0)
	    {
	      break;
	    }

	  GSIArrayRemoveItemAtIndexNoRelease(timers, 0);
	  /* Firing will also increment its fireDate, if it is repeating. */
	  [min_timer fire];
	  if (timerInvalidated(min_timer) == NO)
	    {
	      GSIArrayInsertSortedNoRetain(timers,
		(GSIArrayItem)min_timer, aSort);
	    }
	  else
	    {
	      RELEASE(min_timer);
	    }
	  min_timer = nil;
	  GSNotifyASAP();		/* Post notifications. */
	}
    }

  /* Is this right? At the moment we invalidate and discard watchers
     whose limit-dates have passed. */
  watchers = NSMapGet(_mode_2_watchers, mode);
  if (watchers)
    {
      while (GSIArrayCount(watchers) != 0)
	{
	  min_watcher = GSIArrayItemAtIndex(watchers, 0).obj;

	  if (min_watcher->_invalidated == YES)
	    {
	      GSIArrayRemoveItemAtIndex(watchers, 0);
	      min_watcher = nil;
	      continue;
	    }

	  if ([min_watcher->_date timeIntervalSinceNow] > 0)
	    {
	      break;
	    }
	  else
	    {
	      id	obj;
	      NSDate	*nxt = nil;

	      /*
	       *	If the receiver or its delegate wants to know about
	       *	timeouts - inform it and give it a chance to set a
	       *	revised limit date.
	       */
	      GSIArrayRemoveItemAtIndexNoRelease(watchers, 0);
	      obj = min_watcher->receiver;
	      if ([obj respondsToSelector: 
		      @selector(timedOutEvent:type:forMode:)])
		{
		  nxt = [obj timedOutEvent: min_watcher->data
				      type: min_watcher->type
				   forMode: _current_mode];
		}
	      else if ([obj respondsToSelector: @selector(delegate)])
		{
		  obj = [obj delegate];
		  if (obj != nil && [obj respondsToSelector: 
			    @selector(timedOutEvent:type:forMode:)])
		    {
		      nxt = [obj timedOutEvent: min_watcher->data
					  type: min_watcher->type
				       forMode: _current_mode];
		    }
		}
	      if (nxt && [nxt timeIntervalSinceNow] > 0.0)
		{
		  /*
		   *	If the watcher has been given a revised limit date -
		   *	re-insert it into the queue in the correct place.
		   */
		  ASSIGN(min_watcher->_date, nxt);
		  GSIArrayInsertSortedNoRetain(watchers,
		    (GSIArrayItem)min_watcher, aSort);
		}
	      else
		{
		  /*
		   *	If the watcher is now useless - invalidate and
		   *	release it.
		   */
		  min_watcher->_invalidated = YES;
		  RELEASE(min_watcher);
		}
	      min_watcher = nil;
	    }
	}
    }

  _current_mode = saved_mode;
  RELEASE(arp);

  /*
   *	If there are timers - set limit date to the earliest of them.
   *	If there are watchers, set the limit date to that of the earliest
   *	watcher (or leave it as the date of the earliest timer if that is
   *	before the watchers limit).
   */
  if (min_timer)
    {
      when = timerDate(min_timer);
      if (min_watcher != nil
	&& [min_watcher->_date compare: when] == NSOrderedAscending)
	{
	  when = min_watcher->_date;
	}
    }
  else if (min_watcher)
    {
      when = min_watcher->_date;
    }
  else
    {
      return nil;	/* Nothing waiting to be done.	*/
    }

  if (debug_run_loop)
    {
      printf ("\tNSRunLoop limit date %f\n",
	[when timeIntervalSinceReferenceDate]);
    }

  return when;
}

/* Listen to input sources.
   If LIMIT_DATE is nil, then don't wait; i.e. call select() with 0 timeout */

- (void) acceptInputForMode: (NSString*)mode 
		 beforeDate: (NSDate*)limit_date
{
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  fd_set write_fds;		/* Copy for listening for write-ready fds. */
  int select_return;
  int fdIndex;
  int fdEnd;
  id saved_mode;
  int num_inputs = 0;		/* Number of descriptors being monitored. */
  int end_inputs = 0;		/* Highest numbered descriptor plus one. */
  CREATE_AUTORELEASE_POOL(arp);

  NSAssert(mode, NSInvalidArgumentException);
  saved_mode = _current_mode;
  _current_mode = mode;

  /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
  if (!limit_date)
    {
      /* Don't wait at all. */
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
    }
  else if ((ti = [limit_date timeIntervalSinceNow])
	< LONG_MAX && ti > 0.0)
    {
      /* Wait until the LIMIT_DATE. */
      if (debug_run_loop)
	printf ("\tNSRunLoop accept input before %f (seconds from now %f)\n", 
		[limit_date timeIntervalSinceReferenceDate], ti);
      /* If LIMIT_DATE has already past, return immediately. */
      timeout.tv_sec = ti;
      timeout.tv_usec = (ti - timeout.tv_sec) * 1000000.0;
      select_timeout = &timeout;
    }
  else if (ti <= 0.0)
    {
      /* The LIMIT_DATE has already past; return immediately without
	 polling any inputs. */
      GSCheckTasks();
      [self _checkPerformers];
      GSNotifyASAP();
      if (debug_run_loop)
	printf ("\tNSRunLoop limit date past, returning\n");
      _current_mode = saved_mode;
      RELEASE(arp);
      return;
    }
  else
    {
      /* Wait forever. */
      if (debug_run_loop)
	printf ("\tNSRunLoop accept input waiting forever\n");
      select_timeout = NULL;
    }

  /*
   *	Get ready to listen to file descriptors.
   *	Initialize the set of FDS we'll pass to select(), and make sure we
   *	have empty maps for keeping track of which watcher is associated
   *	with which file descriptor.
   *	The maps may not have been emptied if a previous call to this
   *	method was terminated by an exception.
   */
  memset(&exception_fds, '\0', sizeof(exception_fds));
  memset(&read_fds, '\0', sizeof(read_fds));
  memset(&write_fds, '\0', sizeof(write_fds));
  NSResetMapTable(_efdMap);
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  /*
   * Do the pre-listening set-up for the file descriptors of this mode.
   */
  {
    GSIArray	watchers;

    watchers = NSMapGet(_mode_2_watchers, mode);
    if (watchers)
      {
	unsigned	i = GSIArrayCount(watchers);

	while (i-- > 0)
	  {
	    GSRunLoopWatcher	*info;
	    int			fd;

	    info = GSIArrayItemAtIndex(watchers, i).obj;
	    if (info->_invalidated == YES)
	      {
		GSIArrayRemoveItemAtIndex(watchers, i);
		continue;
	      }
	    switch (info->type)
	      {
		case ET_EDESC: 
		  fd = (int)info->data;
		  if (fd > end_inputs)
		    end_inputs = fd;
		  FD_SET (fd, &exception_fds);
		  NSMapInsert(_efdMap, (void*)fd, info);
		  num_inputs++;
		  break;

		case ET_RDESC: 
		  fd = (int)info->data;
		  if (fd > end_inputs)
		    end_inputs = fd;
		  FD_SET (fd, &read_fds);
		  NSMapInsert(_rfdMap, (void*)fd, info);
		  num_inputs++;
		  break;

		case ET_WDESC: 
		  fd = (int)info->data;
		  if (fd > end_inputs)
		    end_inputs = fd;
		  FD_SET (fd, &write_fds);
		  NSMapInsert(_wfdMap, (void*)fd, info);
		  num_inputs++;
		  break;

		case ET_RPORT: 
		  if ([info->receiver isValid] == NO)
		    {
		      /*
		       * We must remove an invalidated port.
		       */
		      info->_invalidated = YES;
		      GSIArrayRemoveItemAtIndex(watchers, i);
		    }
		  else
		    {
		      id port = info->receiver;
		      int port_fd_count = 128; // xxx #define this constant
		      int port_fd_array[port_fd_count];

		      if ([port respondsToSelector: @selector(getFds:count:)])
			[port getFds: port_fd_array count: &port_fd_count];
		      if (debug_run_loop)
			printf("\tNSRunLoop listening to %d sockets\n",
			      port_fd_count);

		      while (port_fd_count--)
			{
			  fd = port_fd_array[port_fd_count];
			  FD_SET (port_fd_array[port_fd_count], &read_fds);
			  if (fd > end_inputs)
			    end_inputs = fd;
			  NSMapInsert(_rfdMap, 
			    (void*)port_fd_array[port_fd_count], info);
			  num_inputs++;
			}
		    }
		  break;
	      }
	  }
      }
  }
  end_inputs++;

  /*
   * If there are notifications in the 'idle' queue, we try an instantaneous
   * select so that, if there is no input pending, we can service the queue.
   * Similarly, if a task has completed, we need to deliver it's notifications.
   */
  if (GSCheckTasks() || GSNotifyMore())
    {
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
      select_return = select (end_inputs, &read_fds, &write_fds, &exception_fds,
			  select_timeout);
    }
  else
    select_return = select (end_inputs, &read_fds, &write_fds, &exception_fds,
			  select_timeout);

  if (debug_run_loop)
    printf ("\tNSRunLoop select returned %d\n", select_return);

  if (select_return < 0)
    {
      if (errno == EINTR)
	{
	  GSCheckTasks();
	  select_return = 0;
	}
#ifdef __MINGW__
      else if (errno == 0)
        {
	  /* MinGW often returns an errno == 0. Not sure why */
	    select_return = 0;
        }
#endif
      else
	{
	  /* Some exceptional condition happened. */
	  /* xxx We can do something with exception_fds, instead of
	     aborting here. */
	  NSLog (@"select() error in -acceptInputForMode:beforeDate: '%s'",
		GSLastErrorStr(errno));
	  abort ();
	}
    }
  if (select_return == 0)
    {
      NSResetMapTable(_efdMap);
      NSResetMapTable(_rfdMap);
      NSResetMapTable(_wfdMap);
      GSNotifyIdle();
      [self _checkPerformers];
      _current_mode = saved_mode;
      RELEASE(arp);
      return;
    }
  
  /*
   *	Look at all the file descriptors select() says are ready for action;
   *	notify the corresponding object for each of the ready fd's.
   *	NB. It is possible for a watcher to be missing from the map - if
   *	the event handler of a previous watcher has 'run' the loop again
   *	before returning.
   *	NB. Each time this roop is entered, the starting position (_fdStart)
   *	is incremented - this is to ensure a fair distribtion over all
   *	inputs where multiple inputs are in use.  Note - _fdStart can be
   *	modified while we are in the loop (by recursive calls).
   */
  if (_fdStart >= end_inputs)
    {
      _fdStart = 0;
      fdIndex = 0;
      fdEnd = 0;
    }
  else
    {
      _fdStart++;
      fdIndex = _fdStart;
      fdEnd = _fdStart;
    }
  do
    {
      BOOL	found = NO;

      if (FD_ISSET (fdIndex, &exception_fds))
        {
	  GSRunLoopWatcher	*watcher;

	  watcher = (GSRunLoopWatcher*)NSMapGet(_efdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call it's receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, _current_mode);
	    }
	  GSNotifyASAP();
	  found = YES;
        }
      if (FD_ISSET (fdIndex, &write_fds))
        {
	  GSRunLoopWatcher	*watcher;

	  watcher = NSMapGet(_wfdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call it's receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, _current_mode);
	    }
	  GSNotifyASAP();
	  found = YES;
        }
      if (FD_ISSET (fdIndex, &read_fds))
        {
	  GSRunLoopWatcher	*watcher;

	  watcher = (GSRunLoopWatcher*)NSMapGet(_rfdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call it's receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fdIndex, _current_mode);
	    }
	  GSNotifyASAP();
	  found = YES;
        }
      if (found == YES && --select_return == 0)
	{
	  break;
	}
      if (++fdIndex >= end_inputs)
	{
	  fdIndex = 0;
	}
    }
  while (fdIndex != fdEnd);


  /* Clean up before returning. */
  NSResetMapTable(_efdMap);
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  [self _checkPerformers];
  GSNotifyASAP();
  _current_mode = saved_mode;
  RELEASE(arp);
}

- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date
{
  id	d;

  NSAssert(mode && date, NSInvalidArgumentException);
  /* If date has already passed, simply return. */
  if ([date timeIntervalSinceNow] < 0)
    {
      if (debug_run_loop)
	{
	  printf ("\tNSRunLoop run mode with date already past\n");
	}
      /*
       * Notify if any tasks have completed.
       */
      if (GSCheckTasks() == YES)
	{
	  GSNotifyASAP();
	}
      return NO;
    }

  /* Find out how long we can wait before first limit date. */
  d = [self limitDateForMode: mode];
  if (d == nil)
    {
      if (debug_run_loop)
	{
	  printf ("\tNSRunLoop run mode with nothing to do\n");
	}
      /*
       * Notify if any tasks have completed.
       */
      if (GSCheckTasks() == YES)
	{
	  GSNotifyASAP();
	}
      return NO;
    }

  /*
   * Use the earlier of the two dates we have.
   * Retain the date in case the firing of a timer (or some other event)
   * releases it.
   */
  d = [d earlierDate: date];
  IF_NO_GC(RETAIN(d));

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode beforeDate: d];

  RELEASE(d);

  return YES;
}

- (void) run
{
  [self runUntilDate: theFuture];
}

- (void) runUntilDate: (NSDate*)date
{
  double	ti = [date timeIntervalSinceNow];
  BOOL		mayDoMore = YES;

  /* Positive values are in the future. */
  while (ti > 0 && mayDoMore == YES)
    {
      if (debug_run_loop)
	printf ("\tNSRunLoop run until date %f seconds from now\n", ti);
      mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
      ti = [date timeIntervalSinceNow];
    }
}

@end



@implementation	NSRunLoop (OPENSTEP)

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
  return [self addEvent: (void*)port
		   type: ET_RPORT
		watcher: (id<RunLoopEvents>)port
		forMode: (NSString*)mode];
}

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id) target
		      argument: (id) argument
{
  NSMapEnumerator	enumerator;
  GSIArray		performers;
  void			*mode;

  enumerator = NSEnumerateMapTable(_mode_2_performers);

  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&performers))
    {
      unsigned	count = GSIArrayCount(performers);

      while (count--)
	{
	  GSRunLoopPerformer	*p;

	  p = GSIArrayItemAtIndex(performers, count).obj;
	  if (p->target == target && sel_eq(p->selector, aSelector)
	    && p->argument == argument)
	    {
	      GSIArrayRemoveItemAtIndex(performers, count);
	    }
	}
    }
}

- (void) configureAsServer
{
/* Nothing to do here */
}

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
	  GSIArray	performers = NSMapGet(_mode_2_performers, mode);
	  unsigned	end;
	  unsigned	i;

	  if (performers == 0)
	    {
	      NSZone	*z = [self zone];

	      performers = NSZoneMalloc(z, sizeof(GSIArray_t));
	      GSIArrayInitWithZoneAndCapacity(performers, z, 8);
	      NSMapInsert(_mode_2_performers, mode, performers);
	    }

	  end = GSIArrayCount(performers);
	  for (i = 0; i < end; i++)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, i).obj;
	      if (p->order <= order)
		{
		  GSIArrayInsertItem(performers, (GSIArrayItem)item, i);
		  break;
		}
	    }
	  if (i == end)
	    {
	      GSIArrayInsertItem(performers, (GSIArrayItem)item, i);
	    }
	}
      RELEASE(item);
    }
}

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
  return [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end

