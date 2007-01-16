#ifndef __GSRunLoopWatcher_h_GNUSTEP_BASE_INCLUDE
#define __GSRunLoopWatcher_h_GNUSTEP_BASE_INCLUDE

/*
 *	The 'GSRunLoopWatcher' class was written to permit the (relatively)
 *	easy addition of new events to be watched for in the runloop.
 *
 *	To add a new type of event, the 'RunLoopEventType' enumeration must be
 *	extended, and the methods must be modified to handle the new type.
 *
 *	The internal variables if the GSRunLoopWatcher are used as follows -
 *
 *	If '_invalidated' is set, the watcher should be disabled and should
 *	be removed from the runloop when next encountered.
 *
 *	If 'checkBlocking' is set, the run loop should ask the watcher
 *	whether it should block and/or trigger each loop iteration.
 *
 *	The 'data' variable is used to identify the  resource/event that the
 *	watcher is interested in.  Its meaning is system dependent.
 *
 *	The 'receiver' is the object which should be told when the event
 *	occurs.  This object is retained so that we know it will continue
 *	to exist and can handle a callback.
 *
 *	The 'type' variable indentifies the type of event watched for.
 *	NSRunLoops [-acceptInputForMode: beforeDate: ] method MUST contain
 *	code to watch for events of each type.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */

#include "config.h"
#include "GNUstepBase/preface.h"
#include <Foundation/NSRunLoop.h>

@class NSDate;

@interface GSRunLoopWatcher: NSObject
{
@public
  BOOL			_invalidated;
  BOOL			checkBlocking;
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  unsigned 		count;
}
- (id) initWithType: (RunLoopEventType)type
	   receiver: (id)anObj
	       data: (void*)data;
/**
 * Returns a boolean indicating whether the receiver needs the loop to
 * block to wait for input, or whether the loop can run through at once.
 * It also sets *trigger to say whether the receiver should be triggered
 * once the input test has been done or not.
 */
- (BOOL) runLoopShouldBlock: (BOOL*)trigger;
@end

#endif /* __GSRunLoopWatcher_h_GNUSTEP_BASE_INCLUDE */
