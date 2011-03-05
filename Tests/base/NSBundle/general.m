#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

@interface	TestClass : NSObject
@end

@implementation	TestClass
@end

int main()
{ 
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSBundle *classBundle, *gnustepBundle, *identifierBundle, *bundle;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path, *exepath;

  
  PASS((
    [(gnustepBundle = [NSBundle bundleForLibrary: @"gnustep-base"])
      isKindOfClass: [NSBundle class]]),
    "+bundleForLibrary: makes a bundle for us")
  
  PASS([gnustepBundle principalClass] == [NSObject class], 
    "-principalClass returns NSObject for the +bundleForLibrary:gnustep-base");
  
  classBundle = [NSBundle bundleForClass: [TestClass class]];

  TEST_FOR_CLASS(@"NSBundle",classBundle,
    "+bundleForClass: makes a bundle for us");

  NSLog(@"%@", [classBundle principalClass]);
  PASS([classBundle principalClass] == [TestClass class], 
    "-principalClass returns TestClass for +bundleForClass:[TestClass class]");

  PASS(classBundle == [NSBundle mainBundle], 
    "-mainBundle is the same as +bundleForClass:[TestClass class]");

  PASS([[gnustepBundle classNamed: @"NSArray"] isEqual: [NSArray class]]
    && [[NSArray class] isEqual: [gnustepBundle classNamed: @"NSArray"]],
    "-classNamed returns the correct class");
  
  TEST_STRING([gnustepBundle resourcePath],"-resourcePath returns a string");
  
  [gnustepBundle setBundleVersion:42];
  PASS([gnustepBundle bundleVersion] == 42,
    "we can set and get gnustep bundle version");
  
  PASS([gnustepBundle load], "-load behaves properly on the gnustep bundle");

  exepath = [gnustepBundle executablePath];
  PASS([fm fileExistsAtPath: exepath],
    "-executablePath returns an executable path (gnustep bundle)");

  path = [[[fm currentDirectoryPath]
    stringByAppendingPathComponent:@"Resources"]
      stringByAppendingPathComponent: @"TestBundle.bundle"];

  bundle = [NSBundle bundleWithPath: path];
  PASS([bundle isKindOfClass:[NSBundle class]],
    "+bundleWithPath returns an NSBundle");

  exepath = [bundle executablePath];
  PASS([fm fileExistsAtPath: exepath],
    "-executablePath returns an executable path (real bundle)");
  
  identifierBundle
    = [NSBundle bundleWithIdentifier: @"Test Bundle Identifier 1"];
  PASS(identifierBundle == bundle,
    "+bundleWithIdentifier returns correct bundle");

  identifierBundle
    = [NSBundle bundleWithIdentifier: @"Test Bundle Identifier 2"];
  PASS(identifierBundle == nil,
    "+bundleWithIdentifier returns nil for non-existent identifier");

  [arp release]; arp = nil;
  return 0;
}
