/* Implementation of NSTimer for GNUstep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   
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

#include <config.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSInvocation.h>

@implementation NSTimer

/* This is the designated initializer. */
- initWithTimeInterval: (NSTimeInterval)seconds
    targetOrInvocation: t
	      selector: (SEL)sel
              userInfo: info
               repeats: (BOOL)f
{
  if (seconds <= 0)
    seconds = 1;
  _interval = seconds;
  _date = [[NSDate allocWithZone: [self zone]]
    initWithTimeIntervalSinceNow: seconds];
  _target = t;
  _selector = sel;
  _info = info;
  _repeats = f;
  return self;
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
		        invocation: invocation
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithTimeInterval: ti
			targetOrInvocation: invocation
			selector: NULL
			userInfo: nil
			repeats: f]);
}

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: object
			  selector: (SEL)selector
			  userInfo: info
			   repeats: (BOOL)f
{
  return AUTORELEASE([[self alloc] initWithTimeInterval: ti
			targetOrInvocation: object
			selector: selector
			userInfo: info
			repeats: f]);
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				 invocation: invocation
				    repeats: (BOOL)f
{
  id t = [self timerWithTimeInterval: ti
	       invocation: invocation
	       repeats: f];
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
  return t;
}

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: object
				   selector: (SEL)selector
				   userInfo: info
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
  if (_selector)
    [_target performSelector: _selector withObject: self];
  else
    [_target invoke];

  if (!_repeats)
    [self invalidate];
  else if (!_invalidated)
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
	NSLog(@"Missed %d timeouts at %f second intervals", inc, _interval);
#endif
      RELEASE(_date);
      _date = [[NSDate allocWithZone: [self zone]]
	initWithTimeIntervalSinceReferenceDate: nxt];
    }
}

- (void) invalidate
{
  NSAssert(_invalidated == NO, NSInternalInconsistencyException);
  _invalidated = YES;
}

- (BOOL) isValid
{
  return !_invalidated;
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
  return [_date compare: anotherTimer->_date];
}

@end
