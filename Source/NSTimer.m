/** Implementation of NSTimer for GNUstep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   
   Rewrite by: Richard Frith-Macdonald <rfm@gnu.org>

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

   <title>NSTimer class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSInvocation.h>

@class	NSGDate;
static Class	NSDate_class;

@implementation NSTimer

+ (void) initialize
{
  if (self == [NSTimer class])
    {
      NSDate_class = [NSGDate class];
    }
}

/*
 * <init />
 * Initialise a newly allocated NSTimer object.
 */
- (id) initWithTimeInterval: (NSTimeInterval)seconds
	 targetOrInvocation: (id)t
		   selector: (SEL)sel
		   userInfo: info
		    repeats: (BOOL)f
{
  if (seconds <= 0)
    {
      seconds = 0.0001;
    }
  _interval = seconds;
  _date = [[NSDate_class allocWithZone: [self zone]]
    initWithTimeIntervalSinceNow: seconds];
  _target = t;
  _selector = sel;
  _info = info;
  _repeats = f;
  return self;
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
		        invocation: (NSInvocation*)invocation
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithTimeInterval: ti
				     targetOrInvocation: invocation
					       selector: NULL
					       userInfo: nil
						repeats: f]);
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: (id)object
			  selector: (SEL)selector
			  userInfo: (id)info
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithTimeInterval: ti
				     targetOrInvocation: object
					       selector: selector
					       userInfo: info
						repeats: f]);
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				 invocation: (NSInvocation*)invocation
				    repeats: (BOOL)f
{
  id t = [self timerWithTimeInterval: ti
	       invocation: invocation
	       repeats: f];
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  return t;
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: (id)object
				   selector: (SEL)selector
				   userInfo: (id)info
				    repeats: (BOOL)f
{
  id t = [self timerWithTimeInterval: ti
			      target: object
			    selector: selector
			    userInfo: info
			     repeats: f];
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  return t;
}

- (void) dealloc
{
  RELEASE(_date);
  [super dealloc];
}

- (void) fire
{
  if (_selector == 0)
    {
      [(NSInvocation*)_target invoke];
    }
  else
    {
      [_target performSelector: _selector withObject: self];
    }

  if (_repeats == NO)
    {
      [self invalidate];
    }
  else if (_invalidated == NO)
    {
      NSTimeInterval	now = GSTimeNow();
      NSTimeInterval	nxt = [_date timeIntervalSinceReferenceDate];
      int		inc = -1;

      while (nxt <= now)		// xxx remove this
	{
	  inc++;
	  nxt += _interval;
	}
#ifdef	LOG_MISSED
      if (inc > 0)
	{
	  NSLog(@"Missed %d timeouts at %f second intervals", inc, _interval);
	}
#endif
      RELEASE(_date);
      _date = [[NSDate_class allocWithZone: [self zone]]
	initWithTimeIntervalSinceReferenceDate: nxt];
    }
}

- (void) invalidate
{
  /* OPENSTEP allows this method to be called multiple times. */
  //NSAssert(_invalidated == NO, NSInternalInconsistencyException);
  _invalidated = YES;
}

- (BOOL) isValid
{
  if (_invalidated == NO)
    return YES;
  else
    return NO;
}

- (NSDate*) fireDate
{
  return _date;
}

- (NSTimeInterval) timeInterval
{
  return _interval;
}

- (id) userInfo
{
  return _info;
}

- (NSComparisonResult) compare: (NSTimer*)anotherTimer
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
      return [_date compare: anotherTimer->_date];
    }
  return 0;
}

@end
