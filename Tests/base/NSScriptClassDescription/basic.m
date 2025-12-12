#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSScriptClassDescription.h>
#import <Foundation/NSScriptCommandDescription.h>
#import <Foundation/NSString.h>

@interface TestScriptableObject : NSObject
@end

@implementation TestScriptableObject
@end

int main()
{
  NSScriptClassDescription *desc;
  NSScriptClassDescription *superDesc;
  NSString *suiteName;
  NSString *className;
  FourCharCode appleEventCode;
  Class implClass;

  START_SET("NSScriptClassDescription initialization");

  // Test basic initialization
  suiteName = @"TestSuite";
  className = @"TestScriptableObject";
  appleEventCode = 'TST1';
  
  desc = AUTORELEASE([[NSScriptClassDescription alloc] initWithSuiteName: suiteName
                                                               className: className
                                                          appleEventCode: appleEventCode
                                                              superclass: nil]);
  PASS(desc != nil, "Can create NSScriptClassDescription instance");

  END_SET("NSScriptClassDescription initialization");

  START_SET("NSScriptClassDescription properties");

  // Test suite name
  PASS([[desc suiteName] isEqual: suiteName], "Suite name property works");

  // Test class name
  PASS([[desc className] isEqual: className], "Class name property works");

  // Test apple event code
  PASS([desc appleEventCode] == appleEventCode, "Apple event code property works");

  // Test implementation class
  implClass = [desc implementationClass];
  PASS(implClass == [TestScriptableObject class],
       "Implementation class lookup works");

  END_SET("NSScriptClassDescription properties");

  START_SET("NSScriptClassDescription hierarchy");

  // Test superclass description
  superDesc = AUTORELEASE([[NSScriptClassDescription alloc] initWithSuiteName: @"BaseSuite"
                                                                     className: @"NSObject"
                                                                appleEventCode: 'BASE'
                                                                    superclass: nil]);
  
  desc = AUTORELEASE([[NSScriptClassDescription alloc] initWithSuiteName: @"DerivedSuite"
                                                               className: @"TestScriptableObject"
                                                          appleEventCode: 'DRV1'
                                                              superclass: superDesc]);
  
  PASS(desc != nil, "Can create derived class description");
  PASS([desc superclassDescription] != nil, "Superclass description is set");

  END_SET("NSScriptClassDescription hierarchy");

  START_SET("NSScriptClassDescription commands");

  desc = AUTORELEASE([[NSScriptClassDescription alloc] initWithSuiteName: suiteName
                                                               className: className
                                                          appleEventCode: appleEventCode
                                                              superclass: nil]);

  // Test command description lookup
  NSScriptCommandDescription *cmdDesc;
  cmdDesc = [desc commandDescriptionWithAppleEventClass: 'core'
                                      andAppleEventCode: 'clon'];
  PASS(cmdDesc == nil, "Command description lookup returns nil for unregistered commands");

  // Test command support
  PASS([desc supportsCommand: nil] == NO,
       "supportsCommand: returns NO for nil command");

  END_SET("NSScriptClassDescription commands");

  START_SET("NSScriptClassDescription keys");

  // Test type for key
  NSString *keyType = [desc typeForKey: @"someProperty"];
  PASS(keyType == nil, "typeForKey: returns nil for stub implementation");

  // Test location required
  PASS([desc isLocationRequiredToCreateForKey: @"items"] == NO,
       "isLocationRequiredToCreateForKey: returns NO by default");

  END_SET("NSScriptClassDescription keys");

  START_SET("NSScriptClassDescription class methods");

  // Register the description
  [NSScriptClassDescription registerClassDescription: desc
                                             forClass: [TestScriptableObject class]];

  // Test class description lookup
  NSScriptClassDescription *foundDesc;
  foundDesc = [NSScriptClassDescription classDescriptionForClass: [TestScriptableObject class]];
  PASS(foundDesc == desc, "classDescriptionForClass: finds registered description");

  END_SET("NSScriptClassDescription class methods");

  return 0;
}
