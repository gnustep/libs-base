/** Declaration of extension methods for base additions

   Copyright (C) 2003-2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   and:         Adam Fedor <fedor@gnu.org>

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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/

#ifndef	INCLUDED_NSRunLoop_GNUstepBase_h
#define	INCLUDED_NSRunLoop_GNUstepBase_h

#if	defined(GNUSTEP_BASE_INTERNAL)
#import "GNUstepBase/GSVersionMacros.h"
#import "Foundation/NSRunLoop.h"
#else
#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSRunLoop.h>
#endif

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

/** This type specifies the kinds of event which may be 'watched' in a
 * run loop.
 */
typedef	enum {
#ifdef _WIN32
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

/** This protocol defines the mandatory interface a run loop watcher must
 * provide in order for it to be notified of events occurring in the loop
 * it is watching.<br />
 * Optional methods are documented in the NSObject(RunLoopEvents)
 * category.
 */
@protocol RunLoopEvents <NSObject>
/** This is the message sent back to a watcher when an event is observed
 * by the run loop.<br />
 * The 'data', 'type' and 'mode' arguments are the same as the arguments
 * passed to the -addEvent:type:watcher:forMode: method.<br />
 * The 'extra' argument varies.  For an ET_TRIGGER event, it is the same
 * as the 'data' argument.  For other events on unix it is the file
 * descriptor associated with the event (which may be the same as the
 * 'data' argument, but is not in the case of ET_RPORT).<br />
 * For windows it will be the handle or the windows message assciated
 * with the event.
 */ 
- (void) receivedEvent: (const void*)data
		  type: (RunLoopEventType)type
		 extra: (const void*)extra
	       forMode: (NSString*)mode;
@end

/** This informal protocol defiens optional methods of the run loop watcher.
 */
@interface NSObject (RunLoopEvents)
/** Called by the run loop to find out whether it needs to block to wait
 * for events for this watcher.  The shouldTrigger flag is used to inform
 * the run loop if tit should immediately trigger a received event for the
 * watcher.
 */
- (BOOL) runLoopShouldBlock: (BOOL*)shouldTrigger;
@end

/** The 'GSRunLoopWatcher' class was written to permit the (relatively)
 * easy addition of new events to be watched for in the runloop.
 *
 * To add a new type of event, the 'RunLoopEventType' enumeration must be
 * extended, and the methods must be modified to handle the new type.
 *
 * The internal variables if the GSRunLoopWatcher are used as follows -
 *
 * If '_invalidated' is set, the watcher should be disabled and should
 * be removed from the runloop when next encountered.
 *
 * If 'checkBlocking' is set, the run loop should ask the watcher
 * whether it should block and/or trigger each loop iteration.
 *
 * The 'data' variable is used to identify the  resource/event that the
 * watcher is interested in.  Its meaning is system dependent.
 *
 * The 'receiver' is the object which should be told when the event
 * occurs.  This object is NOT retained so that we can avoid retain
 * loops.  It is the responsibility of the receiver to invalidate
 * the watcher before it is destroyed.
 *
 * The 'type' variable indentifies the type of event watched for.
 * NSRunLoops [-acceptInputForMode: beforeDate: ] method MUST contain
 * code to watch for events of each type.
 *
 * NB.  This class is private to NSRunLoop and must not be subclassed.
 */

@class NSDate;

GS_EXPORT_CLASS
@interface GSRunLoopWatcher: NSObject
{
#if	defined(GNUSTEP_BASE_INTERNAL)
@public
#endif
  NSRunLoop		*_loop;		// the loop this watcher is monitoring
  uint64_t		_modeMask;	// modes to which monitoring applies
  BOOL			_invalidated;
  BOOL			checkBlocking;
  RunLoopEventType	type;
  const void		*data;
  id<RunLoopEvents>	receiver;
  unsigned 		count;
}

/** Returns the event data being watched for.
 */
- (const void*) data;

- (id) initWithType: (RunLoopEventType)type
	   receiver: (id<RunLoopEvents>)anObj
	       data: (const void*)data;

/** Used by the run loop to fire the event that is being watched for.
 * The arguments are the extra data to be sent to the receiver and the
 * mode that the event occurred in.
 */
- (void) fireEvent: (const void*)extra forMode: (NSString*)mode;

/** Invalidates the receiver.  Once this is done the watcher will not fire
 * again and attempts to scheduled it in a run loop will be ignored.
 */
- (void) invalidate;

/** Returns whether the receiver is stoill valid (has not been invalidated).
 */
- (BOOL) isValid;

/** Returns a boolean indicating whether the receiver needs the loop to
 * block to wait for input, or whether the loop can run through at once.
 * It also sets *trigger to say whether the receiver should be triggered
 * once the input test has been done or not.
 */
- (BOOL) runLoopShouldBlock: (BOOL*)trigger;

/** Returns the event type being watched for.
 */
- (RunLoopEventType) type;

@end

/**
 * The run loop watcher API was originally intended to perform two
 * tasks ...
 * 1. provide the most efficient API reasonably possible to integrate
 * unix networking code into the runloop.
 * 2. provide a standard mechanism to allow people to contribute
 * code to add new I/O mechanisms to GNUstep (OpenStep didn't allow this).
 * It succeeded in 1, and partially succeeded in 2 (adding support
 * for the win32 API).
 */
@interface NSRunLoop(GNUstepExtensions)

/** Adds the specified watcher to the specified modea  Does nothing if the
 * watcher has already been added for this mode.
 * Raises an exception if the watcher has been added to another loop or if
 * the mode 
 */
- (void) addWatcher: (GSRunLoopWatcher*)watcher
	    forMode: (NSString*)mode;

/** Checks to see if a watcher is scheduled in the loop/mode and returns it.
 * Returns nil if it is not present.
 */
- (GSRunLoopWatcher*) findWatcherEvent: (const void*)data
				  type: (RunLoopEventType)type
			       forMode: (NSString*)mode;

/** Removes the watcher from the mode/loop if it is there.
 */
- (void) removeWatcher: (GSRunLoopWatcher*)watcher
	       forMode: (NSString*)mode;

/** Adds a watcher to the receiver ... the watcher is used to monitor events
 * of the specified type which are associted with the event handle data and
 * it operates in the specified run loop modes.<br />
 * The watcher is not retained, but remains in place until a corresponding
 * call to -removeEvent:type:forMode:all: is made.  If is the watchers
 * responsibility to ensure that it is removed from the run loop safely.
 */
- (void) addEvent: (const void*)data
	     type: (RunLoopEventType)type
	  watcher: (id<RunLoopEvents>)watcher
	  forMode: (NSString*)mode;
/** Removes a watcher from the receiver ... the watcher must have been 
 * previously added using -addEvent:type:watcher:forMode:<br />
 * This method mirrors exactly one addition of a watcher unless removeAll
 * is YES, in which case it removes all additions of watchers matching the
 * other paramters.
 */
- (void) removeEvent: (const void*)data
	        type: (RunLoopEventType)type
	     forMode: (NSString*)mode
		 all: (BOOL)removeAll;
@end


#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSRunLoop_GNUstepBase_h */

