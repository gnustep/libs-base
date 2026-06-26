#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptCommandDescription.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

int main()
{
  NSAutoreleasePool *pool;
  NSScriptCommandDescription *desc;
  NSScriptCommandDescription *desc2;
  NSString *suiteName;
  NSString *commandName;
  FourCharCode eventCode;
  FourCharCode classCode;

  pool = [NSAutoreleasePool new];

  START_SET("NSScriptCommandDescription initialization");

  suiteName = @"TestSuite";
  commandName = @"TestCommand";
  eventCode = 'TEST';
  classCode = 'TCMD';

  desc = [[NSScriptCommandDescription alloc] initWithSuiteName: suiteName
                                                   commandName: commandName
                                                appleEventCode: eventCode
                                            appleEventClassCode: classCode];
  PASS(desc != nil, "Can create NSScriptCommandDescription instance");

  END_SET("NSScriptCommandDescription initialization");

  START_SET("NSScriptCommandDescription properties");

  // Test suite name
  PASS([[desc suiteName] isEqual: suiteName], "Suite name property works");

  // Test command name
  PASS([[desc commandName] isEqual: commandName], "Command name property works");

  // Test apple event code
  PASS([desc appleEventCode] == eventCode, "Apple event code property works");

  // Test apple event class code
  PASS([desc appleEventClassCode] == classCode, "Apple event class code property works");

  END_SET("NSScriptCommandDescription properties");

  START_SET("NSScriptCommandDescription return type");

  // Test return type (should be nil by default)
  PASS([desc returnType] == nil, "Return type is nil by default");

  // Test return apple event code (should be 0 by default)
  PASS([desc returnAppleEventCode] == 0, "Return apple event code is 0 by default");

  END_SET("NSScriptCommandDescription return type");

  START_SET("NSScriptCommandDescription arguments");

  // Test argument names
  NSArray *argNames = [desc argumentNames];
  PASS(argNames != nil, "argumentNames returns non-nil");
  PASS([argNames count] == 0, "argumentNames initially empty");

  // Test type for non-existent argument
  NSString *argType = [desc typeForArgumentWithName: @"nonExistent"];
  PASS(argType == nil, "typeForArgumentWithName: returns nil for non-existent argument");

  // Test apple event code for non-existent argument
  FourCharCode argCode = [desc appleEventCodeForArgumentWithName: @"nonExistent"];
  PASS(argCode == 0, "appleEventCodeForArgumentWithName: returns 0 for non-existent argument");

  // Test optional check for non-existent argument
  PASS(![desc isOptionalArgumentWithName: @"nonExistent"],
       "isOptionalArgumentWithName: returns NO for non-existent argument");

  END_SET("NSScriptCommandDescription arguments");

  START_SET("NSScriptCommandDescription multiple instances");

  desc2 = [[NSScriptCommandDescription alloc] initWithSuiteName: @"Suite2"
                                                     commandName: @"Command2"
                                                  appleEventCode: 'TST2'
                                              appleEventClassCode: 'CMD2'];
  
  PASS(desc2 != nil, "Can create second instance");
  PASS(![[desc2 suiteName] isEqual: [desc suiteName]],
       "Second instance has different suite name");
  PASS(![[desc2 commandName] isEqual: [desc commandName]],
       "Second instance has different command name");
  PASS([desc2 appleEventCode] != [desc appleEventCode],
       "Second instance has different event code");

  END_SET("NSScriptCommandDescription multiple instances");

  [desc release];
  [desc2 release];
  [pool release];
  return 0;
}
