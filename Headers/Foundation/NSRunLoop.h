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
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#ifndef __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#define __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSMapTable.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSTimer, NSDate, NSPort;

/**
 * Run loop mode used to deal with input sources other than NSConnections or
 * dialog windows.  Most commonly used. Defined in
 * <code>Foundation/NSRunLoop.h</code>.
 */
GS_EXPORT NSString * const NSDefaultRunLoopMode;

@interface NSRunLoop : NSObject
{
#if	GS_EXPOSE(NSRunLoop)
  @private
  NSString		*_currentMode;
  NSMapTable		*_contextMap;
  NSMutableArray	*_contextStack;
  NSMutableArray	*_timedPerformers;
  void			*_extra;
#endif
}

+ (NSRunLoop*) currentRunLoop;

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date;

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode;

- (NSString*) currentMode;

- (NSDate*) limitDateForMode: (NSString*)mode;

- (void) run;

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

/*
 * The following interface is not yet deprecated,
 * but may be deprecated in the next release and
 * removed thereafter.
 *
 * The run loop watcher API was originally intended to perform two
 * tasks ...
 * 1. provide the most efficient API reasonably possible to integrate
 * unix networking code into the runloop.
 * 2. provide a standard mechanism to allow people to contribute
 * code to add new I/O mechanisms to GNUstep (OpenStep didn't allow this).
 * It succeeded in 1, and partially succeeded in 2 (adding support
 * for the win32 API).
 *
 * However, several years on, CPU's are even faster with respect to I/O
 * and the performance issue is less significant, and Apple have provided
 * the NSStream API which allows yoiu to write stream subclasses and add
 * them to the run loop.
 *
 * We are likely to follow Apple for compatibility, and restructure code
 * using NSStream, at which point this API will be redundant.
 */
typedef	enum {
#ifdef __MINGW__
    ET_HANDLE,	/* Watch for an I/O event on a handle.		*/
    ET_RPORT,	/* Watch for message arriving on port.		*/
    ET_WINMSG,	/* Watch for a message on a window handle.	*/
    ET_TRIGGER	/* Trigger immediately when the loop runs.	*/
#else
    ET_RDESC,	/* Watch for descriptor becoming readable.	*/
    ET_WDESC,	/* Watch for descriptor becoming writeable.	*/
    ET_RPORT,	/* Watch for message arriving on port.		*/
    ET_EDESC,	/* Watch for descriptor with out-of-band data.	*/
    ET_TRIGGER	/* Trigger immediately when the loop runs.	*/
#endif
} RunLoopEventType;
@protocol RunLoopEvents
/* This is the message sent back to a watcher when an event is observed
 * by the run loop.
 * The 'data', 'type' and 'mode' arguments are the same as the arguments
 * passed to the -addEvent:type:watcher:forMode: method.
 * The 'extra' argument varies.  For an ET_TRIGGER event, it is the same
 * as the 'data' argument.  For other events on unix it is the file
 * descriptor associated with the event (which may be the same as the
 * 'data' argument, but is not in the case of ET_RPORT).
 * For windows it will be the handle or the windows message assciated
 * with the event.
 */ 
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
@end
@interface NSObject (RunLoopEvents)
- (BOOL) runLoopShouldBlock: (BOOL*)shouldTrigger;
@end
@class	NSStream;
@interface NSRunLoop(GNUstepExtensions)
- (void) addEvent: (void*)data
	     type: (RunLoopEventType)type
	  watcher: (id<RunLoopEvents>)watcher
	  forMode: (NSString*)mode;
- (void) removeEvent: (void*)data
	        type: (RunLoopEventType)type
	     forMode: (NSString*)mode
		 all: (BOOL)removeAll;
@end

#if	defined(__cplusplus)
}
#endif

#endif /*__NSRunLoop_h_GNUSTEP_BASE_INCLUDE */
