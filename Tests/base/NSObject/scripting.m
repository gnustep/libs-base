#import <Foundation/NSObjectScripting.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import "Testing.h"

@interface ScriptingObject : NSObject

@end

@implementation ScriptingObject

@end

int
main (void)
{
  ENTER_POOL
  ScriptingObject *object = AUTORELEASE([[ScriptingObject alloc] init]);

  PASS(NSClassFromString(@"NSObjectScripting") == Nil,
    "NSObjectScripting is not a standalone class");
  PASS([object respondsToSelector: @selector(scriptingProperties)]
    && [object respondsToSelector: @selector(setScriptingProperties:)]
    && [object respondsToSelector: @selector(scriptingValueForSpecifier:)]
    && [object respondsToSelector:
      @selector(copyScriptingValue:forKey:withProperties:)]
    && [object respondsToSelector:
      @selector(newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:)],
    "NSObject subclasses inherit Cocoa's scripting category methods");

#ifdef GNUSTEP
  PASS_EXCEPTION([object scriptingProperties], NSInvalidArgumentException,
    "unimplemented scriptingProperties raises an exception");
  PASS_EXCEPTION([object setScriptingProperties: nil], NSInvalidArgumentException,
    "unimplemented setScriptingProperties: raises an exception");
  PASS_EXCEPTION([object scriptingValueForSpecifier: nil],
    NSInvalidArgumentException,
    "unimplemented specifier evaluation raises an exception");
  PASS_EXCEPTION([object copyScriptingValue: nil forKey: @"items"
    withProperties: nil], NSInvalidArgumentException,
    "unimplemented scripting copy raises an exception");
  PASS_EXCEPTION([object newScriptingObjectOfClass: [NSObject class]
    forValueForKey: @"items" withContentsValue: nil properties: nil],
    NSInvalidArgumentException,
    "unimplemented scripting creation raises an exception");
#endif

  LEAVE_POOL
  return 0;
}

