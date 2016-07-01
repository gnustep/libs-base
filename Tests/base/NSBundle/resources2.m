#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPathUtilities.h>

@interface NSObject (TestMock)
- (NSString*)test;
@end


static void _testBundle(NSString* name, NSString* className)
{
  NSBundle *bundle;
  NSArray  *arr, *carr;
  NSString *path, *localPath;
  path = [[[[[NSFileManager defaultManager] currentDirectoryPath]
    stringByStandardizingPath] stringByAppendingPathComponent: @"Resources"]
      stringByAppendingPathComponent: name];
  bundle = [NSBundle bundleWithPath: path];
  arr = [bundle pathsForResourcesOfType: @"txt" inDirectory: nil];
  PASS((arr && [arr count]),
    "-pathsForResourcesOfType:inDirectory: returns an array");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array contains non-localized resource");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/English.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array contains localized resource");

  /* --- [NSBundle +pathsForResourcesOfType:inDirectory:] --- */
  carr = [NSBundle pathsForResourcesOfType: @"txt" inDirectory: path];
  PASS([arr isEqual: carr],
    "+pathsForResourcesOfType:inDirectory: returns same array");

  /* --- [NSBundle -pathsForResourcesOfType:inDirectory:forLocalization:] --- */
  arr = [bundle pathsForResourcesOfType: @"txt" inDirectory: nil
    forLocalization: @"English"];
  PASS((arr && [arr count]),
    "-pathsForResourcesOfType:inDirectory:forLocalization returns an array");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array contains non-localized resource");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/English.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array contains localized resource");

  /* --- [NSBundle -pathsForResourcesOfType:inDirectory:forLocalization:] --- */
  arr = [bundle pathsForResourcesOfType: @"txt" inDirectory: nil
    forLocalization: @"en"];
  PASS((arr && [arr count]),
    "-pathsForResources... returns an array for 'en'");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array for 'en' contains non-localized resource");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/English.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array for 'en' contains localized resource");

  /* --- [NSBundle -pathsForResourcesOfType:inDirectory:forLocalization:] --- */
  arr = [bundle pathsForResourcesOfType: @"txt" inDirectory: nil
    forLocalization: @"German"];
  PASS((arr && [arr count]),
    "-pathsForResources... returns an array for 'German'");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array for 'German' contains non-localized resource");
  localPath = [path stringByAppendingPathComponent:
    @"Resources/de.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath],
    "Returned array for 'German' contains localized resource");
  Class clz = [bundle classNamed: className];
  PASS(clz, "Class can be loaded from bundle");
  id obj = [clz new];
  PASS(obj, "Objects from bundle-loaded classes can be instantiated");
  PASS_EQUAL([obj test], @"Something", "Correct method called");
  [obj release];
}

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  START_SET("Bundle")
  _testBundle(@"TestBundle.bundle", @"TestBundle");
  END_SET("Bundle")
  START_SET("Framework")
  _testBundle(@"TestFramework.framework", @"TestFramework");
  END_SET("Framework");
  [arp release]; arp = nil;
  return 0;
}
