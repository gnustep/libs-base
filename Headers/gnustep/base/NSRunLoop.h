/* Interface for NSRunLoop for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

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

#ifndef __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#define __NSRunLoop_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <Foundation/NSMapTable.h>

@class NSTimer, NSDate, NSPort;

/* Mode strings. */
extern id NSDefaultRunLoopMode;

@interface NSRunLoop : NSObject
{
  @private id _current_mode;
  @private NSMapTable *_mode_2_timers;
  @private NSMapTable *_mode_2_watchers;
  @private NSMutableArray *_performers;
}

+ (NSRunLoop*) currentRunLoop;

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)date;

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode;

- (NSString*) currentMode;

- (NSDate*)limitDateForMode: (NSString*)mode;

- (void) run;

- (BOOL) runMode: (NSString*)mode
      beforeDate: (NSDate*)date;

- (void) runUntilDate: (NSDate*)limit_date;

@end

@interface NSRunLoop(OPENSTEP)

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode;

- (void) cancelPerformSelector: (SEL)aSelector
			target: target
		      argument: argument;

- (void) configureAsServer;

- (void) performSelector: (SEL)aSelector
		  target: target
		argument: argument
		   order: (unsigned int)order
		   modes: (NSArray*)modes;

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode;

@end

/*
 *	GNUstep extensions
 */

@protocol FdListening
- (void) readyForReadingOnFileDescriptor: (int)fd;
@end
@protocol FdSpeaking
- (void) readyForWritingOnFileDescriptor: (int)fd;
@end

typedef	enum {
    ET_RDESC,   /* Watch for descriptor becoming readable.      */
    ET_WDESC,   /* Watch for descriptor becoming writeable.     */
    ET_RPORT    /* Watch for message arriving on port.          */
} RunLoopEventType;

@protocol RunLoopEvents
/*
 *	Callback message sent to object waiting for an event in the
 *	runloop when the limit-date for the operation is reached.
 *	If an NSDate object is returned, the operation is restarted
 *	with the new limit-date, otherwise it is removed from the
 *	run loop.
 */
- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode;
/*
 *	Callback message sent to object when the event it it waiting
 *	for occurs.  The 'data' and 'type' valueds are those passed in the
 *	original addEvent:type:watcher:forMode: method.
 *	The 'extra' value may be additional data returned depending
 *	on the type of event.
 */
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
@end

@interface NSRunLoop(GNUstepExtensions)

+ currentInstance;
+ (NSString*) currentMode;
+ (void) run;
+ (BOOL) runOnceBeforeDate: date;
+ (BOOL) runOnceBeforeDate: date
		   forMode: (NSString*)mode;
+ (void) runUntilDate: date;
+ (void) runUntilDate: date
	      forMode: (NSString*)mode;
- (BOOL) runOnceBeforeDate: (NSDate*)date;
- (BOOL) runOnceBeforeDate: (NSDate*)date
		   forMode: (NSString*)mode;
- (void) runUntilDate: (NSDate*)limit_date
	      forMode: (NSString*)mode;
/*
 *	These next two are general purpose methods for letting objects
 *	ask the runloop to watch for events for them.  Only one object
 *	at a time may be watching for a particular event in a mode, but
 *	that object may add itsself as a watcher many times as long as
 *	each addition is matched by a removal (the run loop keeps count).
 *	Alternatively, the 'removeAll' parameter may be set to 'YES' for
 *	[-removeEvent:type:forMode:all:] in order to remove the watcher
 *	irrespective of the number of times it has been added.
 */
- (void) addEvent: (void*)data
	     type: (RunLoopEventType)type
	  watcher: (id<RunLoopEvents>)watcher
	  forMode: (NSString*)mode;
- (void) removeEvent: (void*)data
	        type: (RunLoopEventType)type
	     forMode: (NSString*)mode
		 all: (BOOL)removeAll;
/*
 *	The next four methods are rendered obsolete by
 *	[-addEvent:type:watcher:forMode:] and
 *	[-removeEvent:type:forMode:]
 */
- (void) addReadDescriptor: (int)fd
		    object: (id <FdListening>)listener
		   forMode: (NSString*)mode;
- (void) addWriteDescriptor: (int)fd
		     object: (id <FdSpeaking>)speaker
		    forMode: (NSString*)mode;
- (void) removeReadDescriptor: (int)fd
		      forMode: (NSString*)mode;
- (void) removeWriteDescriptor: (int)fd
		       forMode: (NSString*)mode;
@end

/* xxx This interface will probably change. */
@interface NSObject (OptionalPortRunLoop)
/* If a InPort object responds to this, it is sent just before we are
   about to wait listening for input.
   This interface will probably change. */
- (void) getFds: (int*)fds count: (int*)count;
@end

#endif /*__NSRunLoop_h_GNUSTEP_BASE_INCLUDE */
