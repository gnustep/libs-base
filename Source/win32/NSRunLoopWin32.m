#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSRunLoop.h"
#include "Foundation/NSDebug.h"
#include "../GSRunLoopCtxt.h"

@implementation NSRunLoop (mingw32)
- (void) addMsgTarget: (id)target
           withMethod: (SEL)selector
              forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  GSOnceMLog(@"This method is deprecated, use -addEvent:type:watcher:forMode");
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
