/* Implementation of object for waiting on several input sources
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/* October 1996 - extensions to permit file descriptors to be watched
   for being readable or writable added by Richard Frith-Macdonald
   (richard@brainstorm.co.uk) */

/* Andrews original comments - may still be valid even now -

   Does it strike anyone else that NSNotificationCenter,
   NSNotificationQueue, NSNotification, NSRunLoop, the "notifications"
   a run loop sends the objects on which it is listening, NSEvent, and
   the event queue maintained by NSApplication are all much more
   intertwined/similar than OpenStep gives them credit for?

   I wonder if these classes could be re-organized a little to make a
   more uniform, "grand-unified" mechanism for: events,
   event-listening, event-queuing, and event-distributing.  It could
   be quite pretty.

   (GNUstep would definitely provide classes that were compatible with
   all these OpenStep classes, but those classes could be wrappers
   around fundamentally cleaner GNU classes.  RMS has advised using an
   underlying organization/implementation different from NeXT's
   whenever that makes sense---it helps legally distinguish our work.)

   Thoughts and insights, anyone?

   */

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Heap.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSThread.h>

#include <sys/types.h>
#ifndef __WIN32__
#include <time.h>
#include <sys/time.h>
#endif /* !__WIN32__ */
#include <limits.h>
#include <string.h>		/* for memset() */

/* On some systems FD_ZERO is a macro that uses bzero().
   Just define it to use memset(). */
#define bzero(PTR, LEN) memset (PTR, 0, LEN)

static int debug_run_loop = 0;

/*
 *	The 'RunLoopWatcher' class was written to permit the (relatively)
 *	easy addition of new events to be watched for in the runloop.
 *
 *	To add a new type of event, the 'RunLoopEventType' enumeration must be
 *	extended, and the methods must be modified to handle the new type.
 *
 *	The internal variables if the RunLoopWatcher are used as follows -
 *	If 'invalidated' is set, the wather should be disabled and should
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
 *	NSRunLoops [-acceptInputForMode:beforeDate:] method MUST contain
 *	code to watch for events of each type.
 *
 *	The 'limit' variable contains a date after which the event is useless
 *	and the watcher can be removed from the runloop.  If this is nil
 *	then the watcher will only be removed if explicitly requested.
 *
 *	To set this variable, the method adding the RunLoopWatcher to the
 *	runloop must ask the 'receiver' (or its delegate) to supply a date
 *	using the '[-limitDateForMode:]' message.
 *
 */
 
@interface RunLoopWatcher: NSObject
{
  BOOL			invalidated;
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  NSDate		*limit;
  unsigned 		count;
}
- (void) eventFor: (void*)info
	     mode: (NSString*)mode;
- (void*) getData;
- (NSDate*) getLimit;
- (id) getReceiver;
- (RunLoopEventType) getType;
- (BOOL) decrement;
- (void) increment;
- initWithType: (RunLoopEventType)type
      receiver: (id)anObj
          data: (void*)data;
- (void) invalidate;
- (BOOL) isValid;
- (void) setData: (void*)item;
- (void) setLimit: (NSDate*)when;
- (void) setReceiver: (id)anObj;
@end

@implementation	RunLoopWatcher

- (void) dealloc
{
  [self invalidate];
  [limit release];
  [receiver release];
  [super dealloc];
}

- (BOOL) decrement
{
  if (count > 0)
    {
      count--;
      if (count > 0)
	{
	  return YES;
	}
    }
  return NO;
}

- (void) eventFor: (void*)info
	     mode: (NSString*)mode
{
  if ([self isValid] == NO)
    {
      return;
    }

  if ([receiver respondsToSelector:
		@selector(receivedEvent:type:extra:forMode:)])
    {
      [receiver receivedEvent: data type: type extra: info forMode: mode];
    }
  else
    {
      switch (type)
	{
	  case ET_RDESC:
	  case ET_RPORT:
	    [receiver readyForReadingOnFileDescriptor: (int)info];
	    break;

	  case ET_WDESC:
	    [receiver readyForWritingOnFileDescriptor: (int)info];
	    break;
	}
    }
}

- (void*) getData
{
  return data;
}

- (NSDate*) getLimit
{
  return limit;
}

- (id) getReceiver
{
  return receiver;
}

- (RunLoopEventType) getType
{
  return type;
}

- (void) increment
{
  count++;
}

- initWithType: (RunLoopEventType)aType
      receiver: (id)anObj
          data: (void*)item
{
  self = [super init];
  if (self)
    {
      invalidated = NO;
      switch (aType)
	{
	  case ET_RDESC:	type = aType;	break;
	  case ET_WDESC:	type = aType;	break;
	  case ET_RPORT:	type = aType;	break;
	  default:
	    [NSException raise: NSInvalidArgumentException
		        format: @"NSRunLoop - unknown event type"];
	}
      [self setReceiver: anObj];
      [self setData: item];
      [self setLimit: nil];
      count = 0;
    }
  return self;
}

- (void) invalidate
{
  invalidated = YES;
}

- (BOOL) isValid
{
  if (invalidated == YES)
    {
      return NO;
    }
  if ([receiver respondsToSelector: @selector(isValid)] &&
      [receiver isValid] == NO)
    {
      [self invalidate];
      return NO;
    }
  return YES;
}

- (void) setData: (void*)item
{
  data = item;
}

- (void) setLimit: (NSDate*)when
{
  NSDate*	d = [when retain];

  [limit release];
  limit = d;
}

- (void) setReceiver: (id)anObject
{
  id	obj = receiver;

  receiver = [anObject retain];

  [obj release];
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
 *	The RunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once a particular
 *	runloop iteration has passed.
 */
@interface RunLoopPerformer: NSObject
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
  [timer invalidate];
  [target release];
  [argument release];
  [modes release];
  [super dealloc];
}

- (void) fire
{
  if (timer != nil)
    {
      timer = nil;
      [[self retain] autorelease];
      [[[NSRunLoop currentInstance] _timedPerformers]
		removeObjectIdenticalTo: self];
    }
  [target performSelector: selector withObject: argument];
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
      target = [aTarget retain];
      argument = [anArgument retain];
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
	  if ([argument isEqual:anArgument])
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

  [target retain];
  [arg retain];
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
  [arg release];
  [target release];
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
  [item release];
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
  [item release];
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
  NSMutableArray	*watchers;
  id			obj;
  NSDate		*limit;
  int			count;

  watchers = NSMapGet (_mode_2_watchers, mode);
  if (watchers == nil)
    {
      watchers = [NSMutableArray new];
      NSMapInsert (_mode_2_watchers, mode, watchers);
      [watchers release];
      count = 0;
    }
  else
    {
      count = [watchers count];
    }

  /*
   *	If the receiver or its delegate (if any) respond to
   *	'limitDateForMode:' then we ask them for the limit date for
   *	this watcher.
   */
  obj = [item getReceiver];
  if ([obj respondsToSelector: @selector(limitDateForMode:)])
    {
      [item setLimit: [obj limitDateForMode:mode]];
    }
  else if ([obj respondsToSelector: @selector(delegate)])
    {
      obj = [obj delegate];
      if ([obj respondsToSelector: @selector(limitDateForMode:)])
	{
	  [item setLimit: [obj limitDateForMode:mode]];
	}
    }
  limit = [item getLimit];

  /*
   *	Make sure that the items in the watchers list are ordered.
   */
  if (limit == nil || count == 0)
    {
      [watchers addObject:item];
    }
  else
    {
      int	i;

      for (i = 0; i < count; i++)
	{
	  NSDate*	when = [[watchers objectAtIndex:i] getLimit];

	  if (when == nil || [limit earlierDate:when] == when)
	    {
	      [watchers insertObject:item atIndex:i];
	      break;
	    }
	}
      if (i == count)
	{
	  [watchers addObject:item];
	}
    }
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

  if (info && [info getReceiver] == (id)watcher)
    {
      /* Increment usage count for this watcher. */
      [info increment];
    }
  else
    {
      /* Remove any existing handler for another watcher. */
      [self _removeWatcher: data type: type forMode: mode];

      /* Create new object to hold information. */
      info = [[RunLoopWatcher alloc] initWithType: type
					 receiver: watcher
					     data: data];
      /* Add the object to the array for the mode and keep count. */
      [self _addWatcher:info forMode:mode];
      [info increment];

      [info release];		/* Now held in array.	*/
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
  
      if (info && [info decrement] == NO)
	{
	  [self _removeWatcher: data type: type forMode: mode];
  	}
    }
}

- (void) removeReadDescriptor: (int)fd 
		      forMode: (NSString*)mode
{
  return [self removeEvent:(void*)fd type: ET_RDESC forMode:mode all:NO];
}

- (void) removeWriteDescriptor: (int)fd
		       forMode: (NSString*)mode
{
  return [self removeEvent:(void*)fd type: ET_WDESC forMode:mode all:NO];
}

- (BOOL) runOnceBeforeDate: date
{
  return [self runOnceBeforeDate: date forMode: _current_mode];
}

/* Running the run loop once through for timers and input listening. */

- (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode
{
  return [self runMode:mode beforeDate:date];
}

- (void) runUntilDate: date forMode: (NSString*)mode
{
  volatile double ti;
  BOOL mayDoMore = YES;

  ti = [date timeIntervalSinceNow];
  /* Positive values are in the future. */
  while (ti > 0 && mayDoMore == YES)
    {
      id arp = [NSAutoreleasePool new];
      if (debug_run_loop)
	printf ("\tNSRunLoop run until date %f seconds from now\n", ti);
      mayDoMore = [self runMode: mode beforeDate: date];
      [arp release];
      ti = [date timeIntervalSinceNow];
    }
}

@end



@implementation NSRunLoop

+ currentRunLoop
{
  static NSString	*key = @"NSRunLoopThreadKey";
  NSRunLoop*	r;
  NSThread*	t;

  t = [NSThread currentThread];
  r = [[t threadDictionary] objectForKey: key];
  if (r == nil)
    {
      r = [NSRunLoop new];
      [[t threadDictionary] setObject: r forKey: key];
      [r release];
    }
  return r;
}

+ (void) initialize
{
  if (self == [NSRunLoop class])
    [self currentRunLoop];
}

/* This is the designated initializer. */
- init
{
  [super init];
  _current_mode = NSDefaultRunLoopMode;
  _mode_2_timers = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
				     NSObjectMapValueCallBacks, 0);
  _mode_2_watchers = NSCreateMapTable (NSObjectMapKeyCallBacks,
					   NSObjectMapValueCallBacks, 0);
  _performers = [[NSMutableArray alloc] initWithCapacity:8];
  _timedPerformers = [[NSMutableArray alloc] initWithCapacity:8];
  return self;
}

- (void) dealloc
{
  NSFreeMapTable(_mode_2_timers);
  NSFreeMapTable(_mode_2_watchers);
  [_performers release];
  [_timedPerformers release];
  [super dealloc];
}

- (NSString*) currentMode
{
  return _current_mode;
}


/* Adding timers.  They are removed when they are invalid. */

- (void) addTimer: timer
	  forMode: (NSString*)mode
{
  Heap *timers;

  timers = NSMapGet (_mode_2_timers, mode);
  if (!timers)
    {
      timers = [Heap new];
      NSMapInsert (_mode_2_timers, mode, timers);
      [timers release];
    }
  /* xxx Should we make sure it isn't already there? */
  [timers addObject: timer];
}


/* Fire appropriate timers and determine the earliest time that anything
  watched for becomes useless. */

- limitDateForMode: (NSString*)mode
{
  id			saved_mode;
  Heap			*timers;
  NSTimer		*min_timer = nil;
  RunLoopWatcher	*min_watcher = nil;
  NSArray		*watchers;
  NSDate		*when;

  saved_mode = _current_mode;
  _current_mode = mode;

  timers = NSMapGet(_mode_2_timers, mode);
  if (timers)
    {
      while ((min_timer = [timers minObject]) != nil)
	{
	  if (![min_timer isValid])
	    {
	      [timers removeFirstObject];
	      min_timer = nil;
	      continue;
	    }

	  if ([[min_timer fireDate] timeIntervalSinceNow] > 0)
	    {
	      break;
	    }

	  [min_timer retain];
	  [timers removeFirstObject];
	  /* Firing will also increment its fireDate, if it is repeating. */
	  [min_timer fire];
	  if ([min_timer isValid])
	    {
	      [timers addObject: min_timer];
	    }
	  [min_timer release];
	  min_timer = nil;
	  [NSNotificationQueue runLoopASAP];	/* Post notifications. */
	}
    }

  /* Is this right? At the moment we invalidate and discard watchers
     whose limit-dates have passed. */
  watchers = NSMapGet(_mode_2_watchers, mode);
  if (watchers)
    {
      while ([watchers count] > 0)
	{
	  min_watcher = (RunLoopWatcher*)[watchers objectAtIndex:0];

	  if (![min_watcher isValid])
	    {
	      [watchers removeObjectAtIndex:0];
	      min_watcher = nil;
	      continue;
	    }

	  when = [min_watcher getLimit];
	  if (when == nil || [when timeIntervalSinceNow] > 0)
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
	      obj = [min_watcher getReceiver];
	      if ([obj respondsToSelector:
		      @selector(timedOutEvent:type:forMode:)])
		{
		  nxt = [obj timedOutEvent:[min_watcher getData]
				      type:[min_watcher getType]
				   forMode:_current_mode];
		}
	      else if ([obj respondsToSelector:@selector(delegate)])
		{
		  obj = [obj delegate];
		  if ([obj respondsToSelector:
			    @selector(timedOutEvent:type:forMode:)])
		    {
		      nxt = [obj timedOutEvent:[min_watcher getData]
					  type:[min_watcher getType]
				       forMode:_current_mode];
		    }
		}
	      if (nxt && [nxt timeIntervalSinceNow] > 0.0)
		{
		  /*
		   *	If the watcher has been given a revised limit date -
		   *	re-insert it into the queue in the correct place.
		   */
		  [min_watcher retain];
		  [min_watcher setLimit:nxt];
		  [watchers removeObjectAtIndex:0];
		  [self _addWatcher:min_watcher forMode:mode];
		  [min_watcher release];
		}
	      else
		{
		  /*
		   *	If the watcher is now useless - invalidate it and
		   *	remove it from the queue so that we don't need to
		   *	check it again.
		   */
		  [min_watcher invalidate];
		  [watchers removeObjectAtIndex:0];
		}
	      min_watcher = nil;
	    }
	}
    }

  /*
   *	If there are timers - set limit date to the earliest of them.
   */
  if (min_timer)
    {
      when = [min_timer fireDate];
    }
  else
    {
      when = nil;
    }

  /*
   *	If there are watchers, set the limit date to that of the earliest
   *	watcher (or leave it as the date of the earliest timer if that is
   *	before the watchers limit).
   *	NB. A watcher without a limit date watches forever - so it's limit
   *	is effectively some time in the distant future.
   */
  if (min_watcher)
    {
      NSDate*	lim;

      if ([min_watcher getLimit] == nil)	/* No limit for watcher	*/
	{
	  lim = [NSDate distantFuture];		/* - watches forever.	*/
	}
      else
	{
	  lim = [min_watcher getLimit];
	}

      if (when == nil)
	{
	  when = lim;
	}
      else
	{
	  when = [when earlierDate:lim];
	}
    }

  /*
   *	'when' will only be nil if there are neither timers nor watchers
   *	outstanding.
   */
  if (when && debug_run_loop)
    {
      printf ("\tNSRunLoop limit date %f\n",
	    [when timeIntervalSinceReferenceDate]);
    }
  _current_mode = saved_mode;

  return when;
}

- (RunLoopWatcher*) _getWatcher: (void*)data
			   type: (RunLoopEventType)type
		        forMode: (NSString*)mode
{
  NSArray		*watchers;
  RunLoopWatcher	*info;
  int			count;

  if (mode == nil)
    {
      mode = _current_mode;
    }

  watchers = NSMapGet (_mode_2_watchers, mode);
  if (watchers == nil)
    {
      return nil;
    }
  for (count = 0; count < [watchers count]; count++)
    {
      info = [watchers objectAtIndex: count];

      if ([info getType] == type)
	{
	  if ([info getData] == data)
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
  NSMutableArray	*watchers;

  if (mode == nil)
    {
      mode = _current_mode;
    }

  watchers = NSMapGet (_mode_2_watchers, mode);
  if (watchers)
    {
      int	i;

      for (i = [watchers count]; i > 0; i--)
	{
	  RunLoopWatcher*	info;

	  info = (RunLoopWatcher*)[watchers objectAtIndex:(i-1)];
	  if ([info getType] == type && [info getData] == data)
	    {
	      [info invalidate];
	      [watchers removeObject: info];
	    }
	}
    }
}




/* Listen to input sources.
   If LIMIT_DATE is nil, then don't wait; i.e. call select() with 0 timeout */

- (void) acceptInputForMode: (NSString*)mode 
		 beforeDate: limit_date
{
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds;			/* The file descriptors we will listen to. */
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  fd_set write_fds;		/* Copy for listening for write-ready fds. */
  int select_return;
  int fd_index;
  NSMapTable *rfd_2_object;
  NSMapTable *wfd_2_object;
  id saved_mode;
  int num_inputs = 0;

  assert (mode);
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
  else if ((ti = [limit_date timeIntervalSinceNow]) < LONG_MAX
	    && ti > 0.0)
    {
      /* Wait until the LIMIT_DATE. */
      if (debug_run_loop)
	printf ("\tNSRunLoop accept input before %f (seconds from now %f)\n", 
		[limit_date timeIntervalSinceReferenceDate], ti);
      /* If LIMIT_DATE has already past, return immediately. */
      if (ti < 0)
	{
          [self _checkPerformers];
	  if (debug_run_loop)
	    printf ("\tNSRunLoop limit date past, returning\n");
          _current_mode = saved_mode;
	  return;
	}
      timeout.tv_sec = ti;
      timeout.tv_usec = (ti - timeout.tv_sec) * 1000000.0;
      select_timeout = &timeout;
    }
  else if (ti <= 0.0)
    {
      /* The LIMIT_DATE has already past; return immediately without
	 polling any inputs. */
      _current_mode = saved_mode;
      return;
    }
  else
    {
      /* Wait forever. */
      if (debug_run_loop)
	printf ("\tNSRunLoop accept input waiting forever\n");
      select_timeout = NULL;
    }

  /* Get ready to listen to file descriptors.
     Initialize the set of FDS we'll pass to select(), and create
     an empty map for keeping track of which object is associated
     with which file descriptor. */
  FD_ZERO (&fds);
  FD_ZERO (&write_fds);
  rfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);
  wfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);

  /* Do the pre-listening set-up for the file descriptors of this mode. */
  {
      NSArray	*watchers;

      watchers = NSMapGet (_mode_2_watchers, mode);
      if (watchers) {
	  int	i;

	  for (i = [watchers count]; i > 0; i--) {
	      RunLoopWatcher*	info = [watchers objectAtIndex:(i-1)];
	      int fd;

	      if ([info isValid] == NO) {
		[watchers removeObjectAtIndex:(i-1)];
		continue;
              }
	      switch ([info getType]) {
		case ET_WDESC:
	          fd = (int)[info getData];
	          FD_SET (fd, &write_fds);
	          NSMapInsert (wfd_2_object, (void*)fd, info);
	          num_inputs++;
		  break;

		case ET_RDESC:
	          fd = (int)[info getData];
	          FD_SET (fd, &fds);
	          NSMapInsert (rfd_2_object, (void*)fd, info);
	          num_inputs++;
		  break;

		case ET_RPORT:
		  {
		    id	port = [info getReceiver];
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
			NSMapInsert (rfd_2_object, 
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
  if (num_inputs == 0 && [NSNotificationQueue runLoopMore])
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
      /* Some exceptional condition happened. */
      /* xxx We can do something with exception_fds, instead of
	 aborting here. */
      perror ("[TcpInPort receivePacketWithTimeout:] select()");
      abort ();
    }
  else if (select_return == 0)
    {
      NSFreeMapTable (rfd_2_object);
      NSFreeMapTable (wfd_2_object);
      [NSNotificationQueue runLoopIdle];
      [self _checkPerformers];
      _current_mode = saved_mode;
      return;
    }
  
  /* Look at all the file descriptors select() says are ready for reading;
     notify the corresponding object for each of the ready fd's. */
  for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
    {
      if (FD_ISSET (fd_index, &write_fds))
        {
	  id watcher = (id) NSMapGet (wfd_2_object, (void*)fd_index);
	  assert (watcher);
	  [watcher eventFor:(void*)fd_index mode:_current_mode];
          [NSNotificationQueue runLoopASAP];
        }
      if (FD_ISSET (fd_index, &read_fds))
        {
	  id watcher = (id) NSMapGet (rfd_2_object, (void*)fd_index);
	  assert (watcher);
	  [watcher eventFor:(void*)fd_index mode:_current_mode];
          [NSNotificationQueue runLoopASAP];
        }
    }
  /* Clean up before returning. */
  NSFreeMapTable (rfd_2_object);
  NSFreeMapTable (wfd_2_object);

  [self _checkPerformers];
  [NSNotificationQueue runLoopASAP];
  _current_mode = saved_mode;
}

- (BOOL) runMode: (NSString*)mode beforeDate: date
{
  id	d;

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

  /* Use the earlier of the two dates we have. */
  d = [[d earlierDate:date] retain];

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode beforeDate: d];

  [d release];
  return YES;
}

- (void) run
{
  [self runUntilDate: [NSDate distantFuture]];
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

  [target retain];
  [argument retain];
  for (i = count; i > 0; i--)
    {
      item = (RunLoopPerformer*)[_performers objectAtIndex:(i-1)];

      if ([item matchesSelector:aSelector target:target argument:argument])
	{
	  [_performers removeObjectAtIndex:(i-1)];
	}
    }
  [argument release];
  [target release];
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
      [_performers addObject:item];
    }
  else
    {
      int	i;

      for (i = 0; i < count; i++)
	{
	  if ([[_performers objectAtIndex:i] order] <= order)
	    {
	      [_performers insertObject:item atIndex:i];
	      break;
	    }
	}
      if (i == count)
	{
	  [_performers addObject:item];
	}
    }
  [item release];
}

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
  return [self removeEvent:(void*)port type: ET_RPORT forMode:mode all:NO];
}

@end

