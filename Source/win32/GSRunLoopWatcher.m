#include "config.h"

#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSRunLoopWatcher.h"
#include <Foundation/NSException.h>
#include <Foundation/NSPort.h>

SEL	eventSel;	/* Initialized in [NSRunLoop +initialize] */

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  RELEASE(_date);
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;

  switch (aType)
    {
      case ET_RPORT: 	type = aType;	break;
      case ET_HANDLE:   type = aType;   break;
      default: 
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"];
    }
  receiver = anObj;
  if ([receiver respondsToSelector: eventSel] == YES) 
    handleEvent = [receiver methodForSelector: eventSel];
  else
    [NSException raise: NSInvalidArgumentException
		format: @"RunLoop listener has no event handling method"];
  data = item;
  return self;
}

@end

