#import "Testing.h"
#import <Foundation/Foundation.h>

static void
testDirectory(NSSearchPathDirectory dir, const char *name)
{
  NSArray *paths;
  NSEnumerator *e;
  NSString *path;

  paths = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);

  PASS(paths != nil, "%s returned a non-nil array", name);
  PASS([paths isKindOfClass: [NSArray class]],
    "%s returned an NSArray", name);

  NSLog(@"%s result: %@", name, paths);

  e = [paths objectEnumerator];
  while ((path = [e nextObject]) != nil)
    {
      PASS([path isKindOfClass: [NSString class]],
        "%s returned NSString objects", name);

      PASS([path length] > 0,
        "%s returned non-empty paths", name);

      PASS([path isAbsolutePath],
        "%s returned absolute paths when expandTilde is YES", name);

      PASS([path rangeOfString: @"//"].location == NSNotFound,
        "%s did not contain duplicate path separators", name);

      PASS([path rangeOfString: @"/./"].location == NSNotFound,
        "%s did not contain '/./' components", name);
    }

  PASS([[NSSet setWithArray: paths] count] == [paths count],
    "%s returned no duplicate paths", name);
}

int
main()
{
  START_SET("NSSearchPathForDirectoriesInDomains (NSUserDomainMask)");

  testDirectory(NSApplicationDirectory,
    "NSApplicationDirectory");
  testDirectory(NSDemoApplicationDirectory,
    "NSDemoApplicationDirectory");
  testDirectory(NSDeveloperApplicationDirectory,
    "NSDeveloperApplicationDirectory");
  testDirectory(NSAdminApplicationDirectory,
    "NSAdminApplicationDirectory");
  testDirectory(NSLibraryDirectory,
    "NSLibraryDirectory");
  testDirectory(NSUserDirectory,
    "NSUserDirectory");
  testDirectory(NSDocumentationDirectory,
    "NSDocumentationDirectory");
  testDirectory(NSDocumentDirectory,
    "NSDocumentDirectory");
  testDirectory(NSDesktopDirectory,
    "NSDesktopDirectory");
  testDirectory(NSCachesDirectory,
    "NSCachesDirectory");
  testDirectory(NSApplicationSupportDirectory,
    "NSApplicationSupportDirectory");
  testDirectory(NSDownloadsDirectory,
    "NSDownloadsDirectory");
  testDirectory(NSInputMethodsDirectory,
    "NSInputMethodsDirectory");
  testDirectory(NSMoviesDirectory,
    "NSMoviesDirectory");
  testDirectory(NSMusicDirectory,
    "NSMusicDirectory");
  testDirectory(NSPicturesDirectory,
    "NSPicturesDirectory");
  testDirectory(NSPrinterDescriptionDirectory,
    "NSPrinterDescriptionDirectory");
  testDirectory(NSSharedPublicDirectory,
    "NSSharedPublicDirectory");
  testDirectory(NSPreferencePanesDirectory,
    "NSPreferencePanesDirectory");
  testDirectory(NSItemReplacementDirectory,
    "NSItemReplacementDirectory");
  testDirectory(NSAllApplicationsDirectory,
    "NSAllApplicationsDirectory");
  testDirectory(NSAllLibrariesDirectory,
    "NSAllLibrariesDirectory");
  testDirectory(NSTrashDirectory,
    "NSTrashDirectory");

  END_SET("NSSearchPathForDirectoriesInDomains (NSUserDomainMask)");
  return 0;
}
