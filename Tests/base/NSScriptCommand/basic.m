#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptCommand.h>
#import <Foundation/NSScriptCommandDescription.h>
#import <Foundation/NSScriptObjectSpecifier.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

@interface TestCommand : NSScriptCommand
@end

@implementation TestCommand

- (id) performDefaultImplementation
{
  return @"TestResult";
}

@end

int main()
{
  NSScriptCommand *command;
  NSScriptCommandDescription *commandDesc;
  NSDictionary *args;
  NSString *result;

  START_SET("NSScriptCommand initialization");

  // Test initialization with nil
  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);
  PASS(command != nil, "Can create NSScriptCommand with nil description");
  PASS([command commandDescription] == nil, "Command description is nil");
  PASS(![command isWellFormed], "Command with nil description is not well-formed");

  END_SET("NSScriptCommand initialization");

  START_SET("NSScriptCommand arguments");

  commandDesc = nil;
  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: commandDesc]);

  // Test arguments
  PASS([command arguments] != nil, "Initial arguments is non-nil");
  
  args = [NSDictionary dictionaryWithObjectsAndKeys:
          @"value1", @"key1",
          @"value2", @"key2",
          nil];
  [command setArguments: args];
  PASS([[command arguments] isEqual: args], "setArguments: works");

  END_SET("NSScriptCommand arguments");

  START_SET("NSScriptCommand evaluated arguments");

  // Test evaluated arguments
  NSDictionary *evaluated = [command evaluatedArguments];
  PASS(evaluated != nil, "evaluatedArguments returns non-nil");
  PASS([[evaluated objectForKey: @"key1"] isEqual: @"value1"],
       "Evaluated arguments contain correct values");

  // Test caching
  PASS([command evaluatedArguments] == evaluated,
       "evaluatedArguments are cached");

  // Test cache invalidation
  [command setArguments: [NSDictionary dictionary]];
  PASS([command evaluatedArguments] != evaluated,
       "Setting new arguments invalidates cache");

  END_SET("NSScriptCommand evaluated arguments");

  START_SET("NSScriptCommand direct parameter");

  // Test direct parameter
  PASS([command directParameter] == nil, "Initial direct parameter is nil");

  // Note: Can't test with real NSScriptObjectSpecifier without full implementation
  [command setDirectParameter: nil];
  PASS([command directParameter] == nil, "setDirectParameter: with nil works");

  END_SET("NSScriptCommand direct parameter");

  START_SET("NSScriptCommand receivers");

  // Test receivers specifier
  PASS([command receiversSpecifier] == nil, "Initial receivers specifier is nil");

  [command setReceiversSpecifier: nil];
  PASS([command receiversSpecifier] == nil, "setReceiversSpecifier: with nil works");

  // Test evaluated receivers
  PASS([command evaluatedReceivers] == nil,
       "evaluatedReceivers returns nil when no specifier");

  END_SET("NSScriptCommand receivers");

  START_SET("NSScriptCommand execution");

  // Test execution with custom subclass
  command = AUTORELEASE([[TestCommand alloc] initWithCommandDescription: nil]);
  result = [command executeCommand];
  PASS(result == nil, "executeCommand returns nil for non-well-formed command");

  END_SET("NSScriptCommand execution");

  START_SET("NSScriptCommand suspension");

  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);

  [command suspendExecution];
  PASS(YES, "suspendExecution doesn't crash");

  [command resumeExecutionWithResult: @"result"];
  PASS(YES, "resumeExecutionWithResult: doesn't crash");

  END_SET("NSScriptCommand suspension");

  START_SET("NSScriptCommand current command");

  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);
  PASS([command currentCommand] == command,
       "currentCommand returns self");

  END_SET("NSScriptCommand current command");

  START_SET("NSScriptCommand apple event");

  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);
  PASS([command appleEvent] == nil,
       "appleEvent returns nil by default");

  END_SET("NSScriptCommand apple event");

  return 0;
}
