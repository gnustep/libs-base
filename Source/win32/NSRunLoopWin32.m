#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSRunLoop.h"
#include "GNUstepBase/GSRunLoopCtxt.h"

@implementation NSRunLoop (mingw32)
/**
 * Adds a target to the loop in the specified mode for the 
 * win32 messages.<br />
 * Only a target+selector is added in one mode. Successive 
 * calls overwrite the previous.<br />
 */
- (void) addMsgTarget: (id)target
           withMethod: (SEL)selector
              forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  context->msgTarget = target;
  context->msgSelector = selector;
}

/**
 * Delete the target of the loop in the specified mode for the 
 * win32 messages.<br />
 */
- (void) removeMsgForMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      return;
    }
  context->msgTarget = nil;
}
@end
