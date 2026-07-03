#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

#if !defined(_WIN32)
#include <unistd.h>
#endif

static BOOL
getValue(NSURL *url, NSString *key, id *value)
{
  NSError *error = nil;

  return [url getResourceValue: value forKey: key error: &error];
}

int
main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *root = [NSTemporaryDirectory()
    stringByAppendingPathComponent: @"NSURLResourceValuesTest"];
  NSString *filePath = [root stringByAppendingPathComponent: @"file.txt"];
  NSString *hiddenPath = [root stringByAppendingPathComponent: @".hidden"];
  NSString *dirPath = [root stringByAppendingPathComponent: @"Sample.app"];
  NSString *linkPath = [root stringByAppendingPathComponent: @"link.txt"];
  NSURL *fileURL;
  NSURL *hiddenURL;
  NSURL *dirURL;
  NSURL *linkURL;
  id value = nil;

  START_SET("NSURL resource values");

  [fm removeFileAtPath: root handler: nil];
  PASS([fm createDirectoryAtPath: root attributes: nil],
    "created resource value test directory");
  PASS([@"hello" writeToFile: filePath atomically: YES],
    "created regular file");
  PASS([@"secret" writeToFile: hiddenPath atomically: YES],
    "created hidden file");
  PASS([fm createDirectoryAtPath: dirPath attributes: nil],
    "created package directory");
#if !defined(_WIN32)
  PASS(0 == symlink([filePath fileSystemRepresentation],
    [linkPath fileSystemRepresentation]), "created symbolic link");
#endif

  fileURL = [NSURL fileURLWithPath: filePath];
  hiddenURL = [NSURL fileURLWithPath: hiddenPath];
  dirURL = [NSURL fileURLWithPath: dirPath];
  linkURL = [NSURL fileURLWithPath: linkPath];

  PASS(getValue(fileURL, NSURLNameKey, &value), "NSURLNameKey succeeds");
  PASS_EQUAL(value, @"file.txt", "NSURLNameKey returns last path component");

  PASS(getValue(fileURL, NSURLIsRegularFileKey, &value),
    "NSURLIsRegularFileKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: YES],
    "regular file reports regular");
  PASS(getValue(fileURL, NSURLIsDirectoryKey, &value),
    "NSURLIsDirectoryKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: NO],
    "regular file is not a directory");
  PASS(getValue(fileURL, NSURLFileSizeKey, &value),
    "NSURLFileSizeKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithUnsignedLongLong: 5],
    "file size is reported");

  PASS(getValue(dirURL, NSURLIsDirectoryKey, &value),
    "directory NSURLIsDirectoryKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: YES],
    "directory reports directory");
  PASS(getValue(dirURL, NSURLIsPackageKey, &value),
    "NSURLIsPackageKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: YES],
    ".app directory reports package");

  PASS(getValue(hiddenURL, NSURLIsHiddenKey, &value),
    "NSURLIsHiddenKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: YES],
    "dot file reports hidden");

#if !defined(_WIN32)
  PASS(getValue(linkURL, NSURLIsSymbolicLinkKey, &value),
    "NSURLIsSymbolicLinkKey succeeds");
  PASS_EQUAL(value, [NSNumber numberWithBool: YES],
    "symbolic link reports symbolic link");
#endif

  PASS(getValue(fileURL, NSURLContentModificationDateKey, &value),
    "NSURLContentModificationDateKey succeeds");
  PASS([value isKindOfClass: [NSDate class]],
    "modification date is an NSDate");

  [fm removeFileAtPath: root handler: nil];

  END_SET("NSURL resource values");

  DESTROY(arp);
  return 0;
}
