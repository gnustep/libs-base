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
 *	The '_date' variable contains a date after which the event is useless
 *	and the watcher can be removed from the runloop.
 *
 *	If '_invalidated' is set, the watcher should be disabled and should
 *	be removed from the runloop when next encountered.
 *
 *	The 'data' variable is used to identify the  resource/event that the
 *	watcher is interested in.
 *
 *	The 'receiver' is the object which should be told when the event
 *	occurs.  This object is retained so that we know it will continue
 *	to exist and can handle a callback.
 *
 *	The 'type' variable indentifies the type of event watched for.
 *	NSRunLoops [-acceptInputForMode: beforeDate: ] method MUST contain
 *	code to watch for events of each type.
 *
 *	To set this variable, the method adding the GSRunLoopWatcher to the
 *	runloop must ask the 'receiver' (or its delegate) to supply a date
 *	using the '[-limitDateForMode: ]' message.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */

#include "config.h"
#include "GNUstepBase/preface.h"
#include <Foundation/NSRunLoop.h>

@class NSDate;

extern SEL	eventSel;	/* Initialized in [NSRunLoop +initialize] */

@interface GSRunLoopWatcher: NSObject
{
@public
  NSDate		*_date;		/* First to match layout of NSTimer */
  BOOL			_invalidated;	/* 2nd to match layout of NSTimer */
  IMP			handleEvent;	/* New-style event handling */
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  unsigned 		count;
}
- (id) initWithType: (RunLoopEventType)type
	   receiver: (id)anObj
	       data: (void*)data;
@end

/*
 *	Two optimisation functions that depend on a hack that the layout of
 *	the NSTimer class is known to be the same as GSRunLoopWatcher for the
 *	first two elements.
 */
static inline NSDate* timerDate(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_date;
}

static inline BOOL timerInvalidated(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_invalidated;
}

#endif /* __GSRunLoopWatcher_h_GNUSTEP_BASE_INCLUDE */
