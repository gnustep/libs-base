/* Implementation of NSTimer for GNUstep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   
   This file is part of the GNU Objective C Class Library.
   
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

#include <Foundation/NSTimer.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <gnustep/base/RunLoop.h>
#include <gnustep/base/Invocation.h>

@implementation NSTimer

/* This is the designated initializer. */
- initWithTimeInterval: (NSTimeInterval)seconds
    targetOrInvocation: t
	      selector: (SEL)sel
              userInfo: info
               repeats: (BOOL)f
{
  [super init];
  _interval = seconds;
  _fire_date = [[NSDate alloc] initWithTimeIntervalSinceNow: seconds];
  _retain_count = 0;
  _is_valid = YES;
  _target = t;
  _selector = sel;
  _info = info;
  _repeats = f;
  return self;
}

- (void) dealloc
{
  [_fire_date release];
  [super dealloc];
}

+ timerWithTimeInterval: (NSTimeInterval)ti
	     invocation: invocation
		repeats: (BOOL)f
{
  return [[[self alloc] initWithTimeInterval: ti
			targetOrInvocation: invocation
			selector: NULL
			userInfo: nil
			repeats: f]
	   autorelease];
}

+ timerWithTimeInterval: (NSTimeInterval)ti
		 target: object
	       selector: (SEL)selector
               userInfo: info
	        repeats: (BOOL)f
{
  return [[[self alloc] initWithTimeInterval: ti
			targetOrInvocation: object
			selector: selector
			userInfo: info
			repeats: f]
	   autorelease];
}

+ scheduledTimerWithTimeInterval: (NSTimeInterval)ti
		      invocation: invocation
			 repeats: (BOOL)f
{
  id t = [self timerWithTimeInterval: ti
	       invocation: invocation
	       repeats: f];
  [[RunLoop currentInstance] addTimer: t forMode: RunLoopDefaultMode];
  return t;
}

+ scheduledTimerWithTimeInterval: (NSTimeInterval)ti
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
  [[RunLoop currentInstance] addTimer: t forMode: RunLoopDefaultMode];
  return t;
}


- (void) fire
{
  if (_selector)
    [_target perform: _selector withObject: self];
  else
    [_target invoke];

  if (!_repeats)
    [self invalidate];
  else if (_is_valid)
    {
      NSTimeInterval ti = [_fire_date timeIntervalSinceReferenceDate];
      NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
      assert (now < 0.0);
      while (ti < now)		// xxx remove this
	ti += _interval;
      [_fire_date release];
      _fire_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
    }
}

- (void) invalidate
{
  assert (_is_valid);
  _is_valid = NO;
}

- (BOOL) isValid
{
  return _is_valid;
}

- fireDate
{
  return _fire_date;
}

- userInfo
{
  return _info;
}

@end
