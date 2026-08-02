/* Interface for NSRunLoop for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#define __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSMapTable.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSTimer, NSDate, NSPort;

typedef NSString* NSRunLoopMode;
  
/**
 * Run loop mode used to deal with input sources other than NSConnections or
 * dialog windows.  Most commonly used. Defined in
 * <code>Foundation/NSRunLoop.h</code>.
 */
GS_EXPORT NSRunLoopMode const NSDefaultRunLoopMode;
GS_EXPORT NSRunLoopMode const NSRunLoopCommonModes;

GS_EXPORT_CLASS
@interface NSRunLoop : NSObject
{
#if	GS_EXPOSE(NSRunLoop)
  @private
  NSString		*_currentMode;
  NSMutableArray	*_contextStack;
  NSMutableArray	*_timedPerformers;
  void			*_internal;
#endif
}

/**
 * Returns the run loop instance for the current thread.
 */
+ (NSRunLoop*) currentRunLoop;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
/**
 * Returns the run loop instance of the main thread.
 */
+ (NSRunLoop*) mainRunLoop;
#endif

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date;

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode;

- (NSString*) currentMode;

- (NSDate*) limitDateForMode: (NSString*)mode;

- (void) run;

/**
 * Calls -limitDateForMode: to determine if a timeout occurs before the
 * specified date, then calls -acceptInputForMode:beforeDate: to run the
 * loop once.<br />
 * The specified date may be nil ... in which case the loop runs
 * until the limit date of the first input or timeout.<br />
 * If the specified date is in the past, this runs the loop once only,
 * to handle any events already available.<br />
 * If there are no input sources or timers in mode, this method
 * returns NO without running the loop (irrespective of the supplied
 * date argument), otherwise returns YES.
 */
- (BOOL) runMode: (NSString*)mode
      beforeDate: (NSDate*)date;

- (void) runUntilDate: (NSDate*)date;

@end

@interface NSRunLoop(OPENSTEP)

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode;

- (void) cancelPerformSelectorsWithTarget: (id)target;

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id)target
		      argument: (id)argument;

- (void) configureAsServer;

- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (NSUInteger)order
		   modes: (NSArray*)modes;

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode;

@end

#if	defined(__cplusplus)
}
#endif

#if     defined(GNUSTEP_BASE_INTERNAL)
#import	"GNUstepBase/NSRunLoop+GNUstepBase.h"
#else
#import	<GNUstepBase/NSRunLoop+GNUstepBase.h>
#endif

#endif /*__NSRunLoop_h_GNUSTEP_BASE_INCLUDE */
