#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSError.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSString.h>
#import <Foundation/FoundationErrors.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSFileManager         *fm = [NSFileManager defaultManager];
  NSString              *resources;
  NSString              *empty;
  NSBundle              *bundle;
  NSBundle              *nothing;
  NSError               *error = nil;

  START_SET("NSBundle loadAndReturnError")

  resources = [[fm currentDirectoryPath]
    stringByAppendingPathComponent: @"Resources"];
  bundle = [NSBundle bundleWithPath:
    [resources stringByAppendingPathComponent: @"TestBundle.bundle"]];

  PASS([bundle preflightAndReturnError: &error],
    "-preflightAndReturnError: is YES for a bundle with an executable")
  PASS([bundle loadAndReturnError: &error],
    "-loadAndReturnError: loads a bundle")
  PASS(error == nil, "-loadAndReturnError: leaves the error alone on success")
  PASS(NSClassFromString(@"TestBundle") != Nil,
    "-loadAndReturnError: loads the bundle's classes")
  PASS([bundle loadAndReturnError: NULL],
    "-loadAndReturnError: is YES for a bundle already loaded")

  empty = [NSTemporaryDirectory()
    stringByAppendingPathComponent: @"NoExecutable.bundle"];
  [fm createDirectoryAtPath: empty
withIntermediateDirectories: YES
                 attributes: nil
                      error: NULL];
  nothing = [NSBundle bundleWithPath: empty];
  PASS([nothing preflightAndReturnError: &error] == NO,
    "-preflightAndReturnError: is NO for a bundle without an executable")
  PASS([error code] == NSExecutableNotLoadableError,
    "-preflightAndReturnError: says there is nothing to load")
  error = nil;
  PASS([nothing loadAndReturnError: &error] == NO,
    "-loadAndReturnError: is NO for a bundle without an executable")
  PASS(([[error domain] isEqual: NSCocoaErrorDomain]
    && [error code] == NSExecutableNotLoadableError),
    "-loadAndReturnError: says why it did not load")
  [fm removeItemAtPath: empty error: NULL];

  END_SET("NSBundle loadAndReturnError")

  [arp release];
  return 0;
}
