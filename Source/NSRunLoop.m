/* Implementation of object for waiting on several input seurces
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
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

#include <sys/types.h>
#if	!defined(__WIN32__) || defined(__CYGWIN__)
#include <time.h>
#include <sys/time.h>
#endif /* !__WIN32__ */
#include <limits.h>
#include <string.h>		/* for memset() */

static int	debug_run_loop = 0;
static NSDate	*theFuture = nil;



/*
 *	The 'RunLoopWatcher' class was written to permit the (relatively)
 *	easy addition of new events to be watched for in the runloop.
 *
 *	To add a new type of event, the 'RunLoopEventType' enumeration must be
 *	extended, and the methods must be modified to handle the new type.
 *
 *	The internal variables if the RunLoopWatcher are used as follows -
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
 *	To set this variable, the method adding the RunLoopWatcher to the
 *	runloop must ask the 'receiver' (or its delegate) to supply a date
 *	using the '[-limitDateForMode: ]' message.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */
 
static SEL	eventSel = @selector(receivedEvent:type:extra:forMode:);

@interface RunLoopWatcher: NSObject
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
- initWithType: (RunLoopEventType)type
      receiver: (id)anObj
          data: (void*)data;
@end

@implementation	RunLoopWatcher

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
    handleEvent = 0;
  data = item;
  return self;
}

@end

/*
 *	Two optimisation functions that depend on a hack that the layout of
 *	the NSTimer class is known to be the same as RunLoopWatcher for the
 *	first two elements.
 */
static inline NSDate* timerDate(NSTimer* timer)
{
  return ((RunLoopWatcher*)timer)->_date;
}

static inline BOOL timerInvalidated(NSTimer* timer)
{
  return ((RunLoopWatcher*)timer)->_invalidated;
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
#define GSI_ARRAY_RETAIN(X)	(X).obj
#endif

#include <base/GSIArray.h>

static NSComparisonResult aSort(GSIArrayItem i0, GSIArrayItem i1)
{
  return [((RunLoopWatcher *)(i0.obj))->_date 
           compare: ((RunLoopWatcher *)(i1.obj))->_date];
}



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
 *	The RunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once a particular
 *	runloop iteration has passed.
 */
@interface RunLoopPerformer: NSObject <GCFinalization>
{
  SEL		selector;
  id		target;
  id		argument;
  unsigned	order;
  NSArray	*modes;
  NSTimer	*timer;
}

- (void) fire;
- initWithSelector: (SEL)aSelector
	    target: (id)target
          argument: (id)argument
             order: (unsigned int)order
             modes: (NSArray*)modes;
- (BOOL) matchesSelector: (SEL)aSelector
		  target: (id)aTarget
		argument: (id)anArgument;
- (NSArray*) modes;
- (unsigned int) order;
- (void) setTimer: (NSTimer*)timer;
@end

@implementation RunLoopPerformer

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(target);
  RELEASE(argument);
  RELEASE(modes);
  [super dealloc];
}

- (void) fire
{
  if (timer != nil)
    {
      timer = nil;
      AUTORELEASE(RETAIN(self));
      [[[NSRunLoop currentInstance] _timedPerformers]
		removeObjectIdenticalTo: self];
    }
  [target performSelector: selector withObject: argument];
}

- (void) gcFinalize
{
  [timer invalidate];
}

- initWithSelector: (SEL)aSelector
	    target: (id)aTarget
          argument: (id)anArgument
             order: (unsigned int)theOrder
             modes: (NSArray*)theModes
{
  self = [super init];
  if (self)
    {
      selector = aSelector;
      target = RETAIN(aTarget);
      argument = RETAIN(anArgument);
      order = theOrder;
      modes = [theModes copy];
    }
  return self;
}

- (BOOL) matchesSelector: (SEL)aSelector
		  target: (id)aTarget
		argument: (id)anArgument
{
  if (selector == aSelector)
    {
      if (target == aTarget)
	{
	  if ([argument isEqual: anArgument])
	    {
	      return YES;
	    }
	}
    }
  return NO;
}

- (NSArray*) modes
{
  return modes;
}

- (unsigned int) order
{
  return order;
}

- (void) setTimer: (NSTimer*)t
{
  timer = t;
}
@end

@implementation NSObject (TimedPerformers)

+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
					selector: (SEL)aSelector
					  object: (id)arg
{
  NSMutableArray	*array;
  int			i;

  RETAIN(target);
  RETAIN(arg);
  array = [[NSRunLoop currentInstance] _timedPerformers];
  for (i = [array count]; i > 0; i--)
    {
      if ([[array objectAtIndex: i-1] matchesSelector: aSelector
					       target: target
					     argument: arg])
	{
	  [array removeObjectAtIndex: i-1];
	}
    }
  RELEASE(arg);
  RELEASE(target);
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
{
  NSMutableArray	*array;
  RunLoopPerformer	*item;

  array = [[NSRunLoop currentInstance] _timedPerformers];
  item = [[RunLoopPerformer alloc] initWithSelector: aSelector
					     target: self
					   argument: argument
					      order: 0
					      modes: nil];
  [array addObject: item];
  [item setTimer: [NSTimer scheduledTimerWithTimeInterval: seconds
						   target: item
						 selector: @selector(fire)
						 userInfo: nil
						  repeats: NO]];
  RELEASE(item);
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
		 inModes: (NSArray*)modes
{
  NSRunLoop		*loop;
  NSMutableArray	*array;
  RunLoopPerformer	*item;
  NSTimer		*timer;
  int			i;

  if (modes == nil || [modes count] == 0)
    {
      return;
    }
  loop = [NSRunLoop currentInstance];
  array = [loop _timedPerformers];
  item = [[RunLoopPerformer alloc] initWithSelector: aSelector
					     target: self
					   argument: argument
					      order: 0
					      modes: nil];
  [array addObject: item];
  timer = [NSTimer timerWithTimeInterval: seconds
				  target: item
				selector: @selector(fire)
				userInfo: nil
				 repeats: NO];
  [item setTimer: timer];
  RELEASE(item);
  for (i = 0; i < [modes count]; i++)
    {
      [loop addTimer: timer forMode: [modes objectAtIndex: i]];
    }
}

@end


@interface NSRunLoop (Private)

- (void) _addWatcher: (RunLoopWatcher*)item
	     forMode: (NSString*)mode;
- (void) _checkPerformers;
- (RunLoopWatcher*) _getWatcher: (void*)data
			   type: (RunLoopEventType)type
		        forMode: (NSString*)mode;
- (NSMutableArray*) _performers;
- (void) _removeWatcher: (void*)data
		   type: (RunLoopEventType)type
		forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)

/* Add a watcher to the list for the specified mode.  Keep the list in
   limit-date order. */
- (void) _addWatcher: (RunLoopWatcher*) item forMode: (NSString*)mode
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
  RunLoopPerformer	*item;
  NSArray		*array = [NSArray arrayWithArray: _performers];
  int			count = [array count];
  unsigned		pos;
  int			i;

  for (i = 0; i < count; i++)
    {
      item = (RunLoopPerformer*)[array objectAtIndex: i];

      pos = [_performers indexOfObjectIdenticalTo: item];
      if (pos != NSNotFound)
	{
	  if ([[item modes] containsObject: _current_mode])
	    {
	      [_performers removeObjectAtIndex: pos];
	      [item fire];
	    }
	}
    }
}


@implementation NSRunLoop(GNUstepExtensions)

+ currentInstance
{
  return [self currentRunLoop];
}

+ (NSString*) currentMode
{
  return [[NSRunLoop currentRunLoop] currentMode];
}

+ (void) run
{
  [[NSRunLoop currentRunLoop] run];
}

+ (void) runUntilDate: date
{
  [[NSRunLoop currentRunLoop] runUntilDate: date];
}

+ (void) runUntilDate: date forMode: (NSString*)mode
{
  [[NSRunLoop currentRunLoop] runUntilDate: date forMode: mode];
}

+ (BOOL) runOnceBeforeDate: date 
{
  return [[NSRunLoop currentRunLoop] runOnceBeforeDate: date];
}

+ (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode
{
  return [[NSRunLoop currentRunLoop] runOnceBeforeDate: date forMode: mode];
}

- (void) addEvent: (void*)data
             type: (RunLoopEventType)type
          watcher: (id<RunLoopEvents>)watcher
          forMode: (NSString*)mode
{
  RunLoopWatcher	*info;

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
      info = [[RunLoopWatcher alloc] initWithType: type
					 receiver: watcher
					     data: data];
      /* Add the object to the array for the mode. */
      [self _addWatcher: info forMode: mode];
      RELEASE(info);		/* Now held in array.	*/
    }
}

- (void) addReadDescriptor: (int)fd
		    object: (id <FdListening>)listener
		   forMode: (NSString*)mode
{
  return [self addEvent: (void*)fd
		   type: ET_RDESC
		watcher: (id<RunLoopEvents>)listener
		forMode: mode];
}

  /* Add our new handler information to the array. */
- (void) addWriteDescriptor: (int)fd
		     object: (id <FdSpeaking>)speaker
		    forMode: (NSString*)mode
{
  return [self addEvent: (void*)fd
		   type: ET_WDESC
		watcher: (id<RunLoopEvents>)speaker
		forMode: mode];
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
      RunLoopWatcher	*info;

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

- (void) removeReadDescriptor: (int)fd 
		      forMode: (NSString*)mode
{
  return [self removeEvent: (void*)fd type: ET_RDESC forMode: mode all: NO];
}

- (void) removeWriteDescriptor: (int)fd
		       forMode: (NSString*)mode
{
  return [self removeEvent: (void*)fd type: ET_WDESC forMode: mode all: NO];
}

- (BOOL) runOnceBeforeDate: date
{
  return [self runOnceBeforeDate: date forMode: _current_mode];
}

/* Running the run loop once through for timers and input listening. */

- (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode
{
  return [self runMode: mode beforeDate: date];
}

- (void) runUntilDate: date forMode: (NSString*)mode
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

@end



@implementation NSRunLoop

#if	GS_WITH_GC == 0
static SEL	wRelSel = @selector(release);
static SEL	wRetSel = @selector(retain);
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
#if	GS_WITH_GC == 0
      wRelImp = [[RunLoopWatcher class] instanceMethodForSelector: wRelSel];
      wRetImp = [[RunLoopWatcher class] instanceMethodForSelector: wRetSel];
#endif
    }
}

+ (NSRunLoop*) currentRunLoop
{
  static NSString	*key = @"NSRunLoopThreadKey";
  NSMutableDictionary	*d;
  NSRunLoop*	r;

  d = GSCurrentThreadDictionary();
  r = [d objectForKey: key];
  if (r == nil)
    {
      r = [NSRunLoop new];
      [d setObject: r forKey: key];
      RELEASE(r);
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
  _performers = [[NSMutableArray alloc] initWithCapacity: 8];
  _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
  _rfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				  WatcherMapValueCallBacks, 0);
  _wfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				  WatcherMapValueCallBacks, 0);
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(_performers);
  RELEASE(_timedPerformers);
  [super dealloc];
}

- (void) gcFinalize
{
  NSFreeMapTable(_mode_2_timers);
  NSFreeMapTable(_mode_2_watchers);
  NSFreeMapTable(_rfdMap);
  NSFreeMapTable(_wfdMap);
}

- (NSString*) currentMode
{
  return _current_mode;
}


/* Adding timers.  They are removed when they are invalid. */

- (void) addTimer: timer
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
  CREATE_AUTORELEASE_POOL(arp);
  id			saved_mode;
  NSDate		*when;
  GSIArray		timers;
  GSIArray		watchers;
  NSTimer		*min_timer = nil;
  RunLoopWatcher	*min_watcher = nil;

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

- (RunLoopWatcher*) _getWatcher: (void*)data
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
	  RunLoopWatcher	*info;

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
	  RunLoopWatcher	*info;

	  info = GSIArrayItemAtIndex(watchers, i).obj;
	  if (info->type == type && info->data == data)
	    {
	      info->_invalidated = YES;
	      GSIArrayRemoveItemAtIndex(watchers, i);
	    }
	}
    }
}




/* Listen to input sources.
   If LIMIT_DATE is nil, then don't wait; i.e. call select() with 0 timeout */

- (void) acceptInputForMode: (NSString*)mode 
		 beforeDate: limit_date
{
  CREATE_AUTORELEASE_POOL(arp);
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds;			/* The file descriptors we will listen to. */
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  fd_set write_fds;		/* Copy for listening for write-ready fds. */
  int select_return;
  int fd_index;
  id saved_mode;
  int num_inputs = 0;

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
      [self _checkPerformers];
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
  memset(&fds, '\0', sizeof(fds));
  memset(&write_fds, '\0', sizeof(write_fds));
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  /* Do the pre-listening set-up for the file descriptors of this mode. */
  {
      GSIArray	watchers;

      watchers = NSMapGet(_mode_2_watchers, mode);
      if (watchers) {
	  int	i;

	  for (i = GSIArrayCount(watchers); i > 0; i--) {
	      RunLoopWatcher	*info;
	      int		fd;

	      info = GSIArrayItemAtIndex(watchers, i-1).obj;
	      if (info->_invalidated == YES) {
		GSIArrayRemoveItemAtIndex(watchers, i-1);
		continue;
              }
	      switch (info->type) {
		case ET_WDESC: 
	          fd = (int)info->data;
	          FD_SET (fd, &write_fds);
	          NSMapInsert(_wfdMap, (void*)fd, info);
	          num_inputs++;
		  break;

		case ET_RDESC: 
	          fd = (int)info->data;
	          FD_SET (fd, &fds);
	          NSMapInsert(_rfdMap, (void*)fd, info);
	          num_inputs++;
		  break;

		case ET_RPORT: 
		  {
		    id	port = info->receiver;
		    int port_fd_count = 128; // xxx #define this constant
		    int port_fd_array[port_fd_count];

		    if ([port respondsTo: @selector(getFds:count:)])
		      [port getFds: port_fd_array count: &port_fd_count];
		    if (debug_run_loop)
		      printf("\tNSRunLoop listening to %d sockets\n",
			    port_fd_count);

		    while (port_fd_count--)
		      {
			FD_SET (port_fd_array[port_fd_count], &fds);
			NSMapInsert(_rfdMap, 
				     (void*)port_fd_array[port_fd_count],
				    info);
			num_inputs++;
		      }
		  }
		  break;
	      }
	  }
      }
  }

  /* Wait for incoming data, listening to the file descriptors in _FDS. */
  read_fds = fds;
  exception_fds = fds;

  /* Detect if the NSRunLoop is idle, and if necessary - dispatch the
     notifications from NSNotificationQueue's idle queue? */
  if (num_inputs == 0 && GSNotifyMore())
    {
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
      select_return = select (FD_SETSIZE, &read_fds, &write_fds, &exception_fds,
			  select_timeout);
    }
  else
    select_return = select (FD_SETSIZE, &read_fds, &write_fds, &exception_fds,
			  select_timeout);

  if (debug_run_loop)
    printf ("\tNSRunLoop select returned %d\n", select_return);

  if (select_return < 0)
    {
      if (errno == EINTR)
	{
	  select_return = 0;
	}
      else
	{
	  /* Some exceptional condition happened. */
	  /* xxx We can do something with exception_fds, instead of
	     aborting here. */
	  perror ("[NSRunLoop acceptInputForMode: beforeDate: ] select()");
	  abort ();
	}
    }
  if (select_return == 0)
    {
      NSResetMapTable(_rfdMap);
      NSResetMapTable(_wfdMap);
      GSNotifyIdle();
      [self _checkPerformers];
      _current_mode = saved_mode;
      RELEASE(arp);
      return;
    }
  
  /*
   *	Look at all the file descriptors select() says are ready for reading;
   *	notify the corresponding object for each of the ready fd's.
   *	NB. It is possible for a watcher to be missing from the map - if
   *	the event handler of a previous watcher has 'run' the loop again
   *	before returning.
   */
  for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
    {
      if (FD_ISSET (fd_index, &write_fds))
        {
	  RunLoopWatcher	*watcher;

	  watcher = NSMapGet(_wfdMap, (void*)fd_index);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call it's receivers
	       * event handling method.
	       */
	      if (watcher->handleEvent != 0)
		{
		  (*watcher->handleEvent)(watcher->receiver,
			eventSel, watcher->data, watcher->type,
			(void*)(gsaddr)fd_index, _current_mode);
		}
	      else if (watcher->type == ET_WDESC)
		{
		  [watcher->receiver readyForWritingOnFileDescriptor:
				(int)(gsaddr)fd_index];
		}
	    }
	  GSNotifyASAP();
	  if (--select_return == 0)
	    break;
        }
      if (FD_ISSET (fd_index, &read_fds))
        {
	  RunLoopWatcher	*watcher;

	  watcher = (RunLoopWatcher*)NSMapGet(_rfdMap, (void*)fd_index);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call it's receivers
	       * event handling method.
	       */
	      if (watcher->handleEvent != 0)
		{
		  (*watcher->handleEvent)(watcher->receiver,
			eventSel, watcher->data, watcher->type,
			(void*)(gsaddr)fd_index, _current_mode);
		}
	      else if (watcher->type == ET_RDESC || watcher->type == ET_RPORT)
		{
		  [watcher->receiver readyForReadingOnFileDescriptor:
				(int)(gsaddr)fd_index];
		}
	    }
	  GSNotifyASAP();
	  if (--select_return == 0)
	    break;
        }
    }


  /* Clean up before returning. */
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  [self _checkPerformers];
  GSNotifyASAP();
  _current_mode = saved_mode;
  RELEASE(arp);
}

- (BOOL) runMode: (NSString*)mode beforeDate: date
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
      return NO;
    }

  /*
   * Use the earlier of the two dates we have.
   * Retain the date in case the firing of a timer (or some other event)
   * releases it.
   */
  d = [d earlierDate: date];
  RETAIN(d);

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode beforeDate: d];

  RELEASE(d);

  return YES;
}

- (void) run
{
  [self runUntilDate: theFuture];
}

- (void) runUntilDate: date
{
  [self runUntilDate: date forMode: _current_mode];
}


/* NSRunLoop mode strings. */

id NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

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
			target: target
		      argument: argument
{
  RunLoopPerformer	*item;
  int			count = [_performers count];
  int			i;

  RETAIN(target);
  RETAIN(argument);
  for (i = count; i > 0; i--)
    {
      item = (RunLoopPerformer*)[_performers objectAtIndex: (i-1)];

      if ([item matchesSelector: aSelector target: target argument: argument])
	{
	  [_performers removeObjectAtIndex: (i-1)];
	}
    }
  RELEASE(argument);
  RELEASE(target);
}

- (void) configureAsServer
{
/* Nothing to do here */
}

- (void) performSelector: (SEL)aSelector
		  target: target
		argument: argument
		   order: (unsigned int)order
		   modes: (NSArray*)modes
{
  RunLoopPerformer	*item;
  int			count = [_performers count];

  item = [[RunLoopPerformer alloc] initWithSelector: aSelector
					     target: target
					   argument: argument
					      order: order
					      modes: modes];
  /* Add new item to list - reverse ordering */
  if (count == 0)
    {
      [_performers addObject: item];
    }
  else
    {
      int	i;

      for (i = 0; i < count; i++)
	{
	  if ([[_performers objectAtIndex: i] order] <= order)
	    {
	      [_performers insertObject: item atIndex: i];
	      break;
	    }
	}
      if (i == count)
	{
	  [_performers addObject: item];
	}
    }
  RELEASE(item);
}

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
  return [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end

