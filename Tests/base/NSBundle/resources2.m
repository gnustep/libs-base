#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPathUtilities.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSString *path, *localPath;
  NSBundle *bundle;
  NSArray  *arr, *carr;
  
  path = [[[[NSFileManager defaultManager] currentDirectoryPath]
		    stringByAppendingPathComponent:@"Resources"]
		   stringByAppendingPathComponent: @"TestBundle.bundle"];

  /* --- [NSBundle -pathsForResourcesOfType:inDirectory:] --- */
  bundle = [NSBundle bundleWithPath: path];
  arr = [bundle pathsForResourcesOfType:@"txt" inDirectory: nil];
  PASS((arr && [arr count]), "-pathsForResourcesOfType:inDirectory: returns an array");
  localPath = [path stringByAppendingPathComponent: @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath], "Returned array contains non-localized resource");
  localPath = [path stringByAppendingPathComponent: @"Resources/English.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath], "Returned array contains localized resource");

  /* --- [NSBundle +pathsForResourcesOfType:inDirectory:] --- */
  carr = [NSBundle pathsForResourcesOfType:@"txt" inDirectory: path];
  PASS([arr isEqual: carr], "+pathsForResourcesOfType:inDirectory: returns same array");

  /* --- [NSBundle -pathsForResourcesOfType:inDirectory:forLocalization:] --- */
  arr = [bundle pathsForResourcesOfType:@"txt" inDirectory: nil forLocalization: @"English"];
  PASS((arr && [arr count]), "-pathsForResourcesOfType:inDirectory:forLocalization returns an array");
  localPath = [path stringByAppendingPathComponent: @"Resources/NonLocalRes.txt"];
  PASS([arr containsObject: localPath], "Returned array contains non-localized resource");
  localPath = [path stringByAppendingPathComponent: @"Resources/English.lproj/TextRes.txt"];
  PASS([arr containsObject: localPath], "Returned array contains localized resource");

  [arp release]; arp = nil;
  return 0;
}
