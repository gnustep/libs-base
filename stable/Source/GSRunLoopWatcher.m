#include "config.h"

#include "GNUstepBase/preface.h"
#include "GSRunLoopWatcher.h"
#include <Foundation/NSException.h>
#include <Foundation/NSPort.h>

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;
  receiver = anObj;
  data = item;
  switch (aType)
    {
#if	defined(__MINGW32__)
      case ET_HANDLE:   type = aType;   break;
      case ET_WINMSG:   type = aType;   break;
#else
      case ET_EDESC: 	type = aType;	break;
      case ET_RDESC: 	type = aType;	break;
      case ET_WDESC: 	type = aType;	break;
#endif
      case ET_RPORT: 	type = aType;	break;
      case ET_TRIGGER: 	type = aType;	break;
      default: 
	RELEASE(self);
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"];
    }

  if ([anObj respondsToSelector: @selector(runLoopShouldBlock:)])
    {
      checkBlocking = YES;
    }

  if (![anObj respondsToSelector: @selector(receivedEvent:type:extra:forMode:)])
    {
      RELEASE(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"RunLoop listener has no event handling method"];
    }
  return self;
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  if (checkBlocking == YES)
    {
      BOOL result = [(id)receiver runLoopShouldBlock: trigger];
      return result;
    }
  else if (type == ET_TRIGGER)
    {
      *trigger = YES;
      return NO;	// By default triggers may fire immediately
    }
  *trigger = YES;
  return YES;		// By default we must wait for input sources
}
@end

