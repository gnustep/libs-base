/** Implementation of NSTimer for GNUstep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

   Rewrite by: Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSTimer class reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "Foundation/NSTimer.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSException.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSInvocation.h"

@class	NSGDate;
@interface NSGDate : NSObject	// Help the compiler
@end
static Class	NSDate_class;

/**
 * An <code>NSTimer</code> provides a way to send a message at some time in
 * the future, possibly repeating every time a fixed interval has passed. To
 * use a timer, you can either create one that will automatically be added to
 * the run loop in the current thread (using the -addTimer:forMode: method),
 * or you can create it without adding it then add it to an [NSRunLoop]
 * explicitly later.
 */
@implementation NSTimer

+ (void) initialize
{
  if (self == [NSTimer class])
    {
      NSDate_class = [NSGDate class];
    }
}

/**
 * <init />
 * Initialise the receive, a newly allocated NSTimer object.<br />
 * The fd argument specifies an initial fire date ... if it is not
 * supplied (a nil object) then the ti argument is used to create
 * a start date relative to the current time.<br />
 * The ti argument specifies the time (in seconds) between the firing.
 * If it is less than or equal to 0.0 then a small interval is chosen
 * automatically.<br />
 * The f argument specifies whether the timer will fire repeatedly
 * or just once.<br />
 * If the selector argument is zero, then then object is an invocation
 * to be used when the timer fires.  otherwise, the object is sent the
 * message specified by the selector and with the timer as an argument.<br />
 * The fd, object and info arguments will be retained until the timer is
 * invalidated.<br />
 */
- (id) initWithFireDate: (NSDate*)fd
	       interval: (NSTimeInterval)ti
		 target: (id)object
	       selector: (SEL)selector
	       userInfo: (id)info
		repeats: (BOOL)f
{
  if (ti <= 0)
    {
      ti = 0.0001;
    }
  _interval = ti;
  if (fd == nil)
    {
      _date = [[NSDate_class allocWithZone: NSDefaultMallocZone()]
        initWithTimeIntervalSinceNow: _interval];
    }
  else
    {
      _date = [fd copy];
    }
  _target = RETAIN(object);
  _selector = selector;
  _info = RETAIN(info);
  _repeats = f;
  if (_repeats == NO)
    {
      _interval = 0.0;
    }
  return self;
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, invocation will be performed.<br />
 * NB. To make the timer operate, you must add it to a run loop.
 */
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
		        invocation: (NSInvocation*)invocation
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithFireDate: nil
					   interval: ti
					     target: invocation
					   selector: NULL
					   userInfo: nil
					    repeats: f]);
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * NB. To make the timer operate, you must add it to a run loop.
 */
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: (id)object
			  selector: (SEL)selector
			  userInfo: (id)info
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithFireDate: nil
					   interval: ti
					     target: object
					   selector: selector
					   userInfo: info
					    repeats: f]);
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, invocation will be performed.<br />
 * This timer will automatically be added to the current run loop and
 * will fire in the default run loop mode.
 */
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				 invocation: (NSInvocation*)invocation
				    repeats: (BOOL)f
{
  id t = [[self alloc] initWithFireDate: nil
			       interval: ti
				 target: invocation
			       selector: NULL
			       userInfo: nil
				repeats: f];
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  RELEASE(t);
  return t;
}

/**
 * Create a timer which will fire after ti seconds and, if f is YES,
 * every ti seconds thereafter. On firing, the target object will be
 * sent a message specified by selector and with the timer as its
 * argument.<br />
 * This timer will automatically be added to the current run loop and
 * will fire in the default run loop mode.
 */
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: (id)object
				   selector: (SEL)selector
				   userInfo: (id)info
				    repeats: (BOOL)f
{
  id t = [[self alloc] initWithFireDate: nil
			       interval: ti
				 target: object
			       selector: selector
			       userInfo: info
				repeats: f];
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  RELEASE(t);
  return t;
}

- (void) dealloc
{
  if (_invalidated == NO)
    {
      [self invalidate];
    }
  RELEASE(_date);
  [super dealloc];
}

/**
 * Fires the timer ... either performs an invocation or sends a message
 * to a target object, depending on how the timer was set up.<br />
 * If the timer is not set to repeat, it is automatically invalidated.<br />
 * Exceptions raised during firing of the timer are caught and logged.
 */
- (void) fire
{
  if (_selector == 0)
    {
      NS_DURING
	{
	  [(NSInvocation*)_target invoke];
	}
      NS_HANDLER
	{
	  NSLog(@"*** NSTimer ignoring exception '%@' (reason '%@') "
	   @"raised during posting of timer with target %p and selector '%@'",
	    [localException name], [localException reason], _target,
	    NSStringFromSelector([_target selector]));
	}
      NS_ENDHANDLER
    }
  else
    {
      NS_DURING
	{
	  [_target performSelector: _selector withObject: self];
	}
      NS_HANDLER
	{
	  NSLog(@"*** NSTimer ignoring exception '%@' (reason '%@') "
	    @"raised during posting of timer with target %p and selector '%@'",
	    [localException name], [localException reason], _target,
	    NSStringFromSelector(_selector));
	}
      NS_ENDHANDLER
    }

  if (_repeats == NO)
    {
      [self invalidate];
    }
}

/**
 * Marks the timer as invalid, causing its target/invocation and user info
 * objects to be released.<br />
 * Invalidated timers are automatically removed from the run loop when it
 * detects them.
 */
- (void) invalidate
{
  /* OPENSTEP allows this method to be called multiple times. */
  //NSAssert(_invalidated == NO, NSInternalInconsistencyException);
  _invalidated = YES;
  if (_target != nil)
    {
      DESTROY(_target);
    }
  if (_info != nil)
    {
      DESTROY(_info);
    }
}

/**
 * Checks to see if the timer has been invalidated.
 */
- (BOOL) isValid
{
  if (_invalidated == NO)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

/**
 * Returns the date/time at which the timer is next due to fire.
 */
- (NSDate*) fireDate
{
  return _date;
}

/**
 * Change the fire date for the receiver.<br />
 * NB. You should <em>NOT</em> use this method for a timer which has
 * been added to a run loop.  The only time when it is safe to modify
 * the fire date of a timer in a run loop is for a repeating timer
 * when the timer is actually in the process of firing.
 */
- (void) setFireDate: (NSDate*)fireDate
{
  ASSIGN(_date, fireDate);
}

/**
 * Returns the interval between firings, or zero if the timer
 * does not repeat.
 */
- (NSTimeInterval) timeInterval
{
  return _interval;
}

/**
 * Returns the user info which was set for the timer when it was created,
 * or nil if none was set or the timer is invalid.
 */
- (id) userInfo
{
  return _info;
}

/**
 * Compares timers based on the date at which they should next fire.
 */
- (NSComparisonResult) compare: (id)anotherTimer
{
  if (anotherTimer == self)
    {
      return NSOrderedSame;
    }
  else if (anotherTimer == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }
  else
    {
      return [_date compare: ((NSTimer*)anotherTimer)->_date];
    }
  return 0;
}

@end
