/* Interface for NSRunLoop for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

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

#ifndef __NSRunLoop_h_OBJECTS_INCLUDE
#define __NSRunLoop_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>

@class NSString;

@interface NSRunLoop : NSObject
@end

/* Put this in a category to avoid unimportant errors due to behaviors. */
@interface NSRunLoop (GNUstep)

/* Getting this thread's current run loop */
+ (NSRunLoop*) currentRunLoop;
- (NSString*) currentMode;
- (NSDate*) limitDateForMode: (NSString*)mode

/* Adding timers. */
- (void) addTimer: (NSTimer*)timer forMode: (NSString*)mode;

/* Running a run loop. */
- (void) acceptInputForMode: (NSString*)mode beforeDate: (NSDate*)limit_date;
- (void) run;
- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)limit_date;
- (void) runUntilDate: (NSDate*)limit_date;

@end

extern NSString *NSDefaultRunLoopMode;
extern NSString *NSConnectionReplyMode;

#endif /*__NSRunLoop_h_OBJECTS_INCLUDE */
