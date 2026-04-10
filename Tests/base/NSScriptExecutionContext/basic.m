#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptExecutionContext.h>
#import <Foundation/NSScriptCommand.h>
#import <Foundation/NSScriptCommandDescription.h>

int main()
{
  NSScriptExecutionContext *context;
  NSScriptCommand *command;

  START_SET("NSScriptExecutionContext singleton");

  // Test shared instance
  context = [NSScriptExecutionContext sharedScriptExecutionContext];
  PASS(context != nil, "sharedScriptExecutionContext returns instance");

  // Test singleton property
  PASS([NSScriptExecutionContext sharedScriptExecutionContext] == context,
       "sharedScriptExecutionContext returns same instance");

  END_SET("NSScriptExecutionContext singleton");

  START_SET("NSScriptExecutionContext top level object");

  // Test initial top level object
  PASS([context topLevelObject] == nil, "Initial top level object is nil");

  // Create a test command
  command = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);

  // Set top level object
  [context setTopLevelObject: command];
  PASS([context topLevelObject] == command, "setTopLevelObject: works");

  // Change top level object
  NSScriptCommand *command2;
  command2 = AUTORELEASE([[NSScriptCommand alloc] initWithCommandDescription: nil]);
  [context setTopLevelObject: command2];
  PASS([context topLevelObject] == command2, "Can change top level object");

  // Set to nil
  [context setTopLevelObject: nil];
  PASS([context topLevelObject] == nil, "Can set top level object to nil");

  END_SET("NSScriptExecutionContext top level object");

  return 0;
}
