/* Declarations for NSTimer for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the Gnustep Base Library.

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

#ifndef __NSTimer_include__
#define __NSTimer_include__

/* This class is currently thrown together.  When it is cleaned up, it
   may no longer be concrete. */

#include <gnustep/base/preface.h>
#include <Foundation/NSDate.h>

@interface NSTimer : NSObject
{
  unsigned _repeats:1;
  unsigned _is_valid:1;
  unsigned _timer_filler:6;
  unsigned _retain_count:24;
  NSDate *_fire_date;
  NSTimeInterval _interval;
  id _target;
  SEL _selector;
  id _info;
}

/* Creating timer objects. */

+ scheduledTimerWithTimeInterval: (NSTimeInterval)ti
		      invocation: invocation
			 repeats: (BOOL)f;
+ scheduledTimerWithTimeInterval: (NSTimeInterval)ti
			  target: object
			selector: (SEL)selector
                        userInfo: info
			 repeats: (BOOL)f;

+ timerWithTimeInterval: (NSTimeInterval)ti
	     invocation: invocation
		repeats: (BOOL)f;
+ timerWithTimeInterval: (NSTimeInterval)ti
		 target: object
	       selector: (SEL)selector
               userInfo: info
	        repeats: (BOOL)f;

- (void) fire;
- (void) invalidate;

- (BOOL) isValid;		/* This method not in OpenStep */

- fireDate;
- userInfo;

@end

#endif
