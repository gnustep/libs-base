/* Declarations for NSTimer for GNUStep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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
   */ 

#ifndef __NSTimer_include__
#define __NSTimer_include__

/* This class is currently thrown together.  When it is cleaned up, it
   may no longer be concrete. */

#include <Foundation/NSDate.h>

/*
 *	NB. NSRunLoop is optimised using a hack that knows about the
 *	class layout for the fire date and invialidation flag in NSTimer.
 *	These MUST remain the first two items in the class.
 */
@interface NSTimer : NSObject
{
  NSDate 	*_date;		/* Must be first - for NSRunLoop optimisation */
  BOOL		_invalidated;	/* Must be 2nd - for NSRunLoop optimisation */
  BOOL		_repeats;
  NSTimeInterval _interval;
  id	_target;
  SEL	_selector;
  id	_info;
}

/* Creating timer objects. */

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				 invocation: (NSInvocation*)invocation
				    repeats: (BOOL)f;
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
				     target: object
				   selector: (SEL)selector
				   userInfo: info
				    repeats: (BOOL)f;

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
		        invocation: (NSInvocation*)invocation
			   repeats: (BOOL)f;
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
			    target: object
			  selector: (SEL)selector
			  userInfo: info
			   repeats: (BOOL)f;

- (void) fire;
- (void) invalidate;

#ifndef	STRICT_OPENSTEP
- (BOOL) isValid;
- (NSTimeInterval) timeInterval;
#endif

- (NSDate*) fireDate;
- (id) userInfo;

@end

#endif
