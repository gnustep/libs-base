#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSString		*top;
  NSString		*cwd;
  NSDirectoryEnumerator	*e;
  NSMutableDictionary	*found;
  NSURL			*u;

  START_SET("NSFileManager -enumeratorAtURL:...")

  top = [[mgr currentDirectoryPath]
    stringByAppendingPathComponent: @"NSFMURLEnumeratorTestDir"];
  [mgr removeItemAtPath: top error: NULL];
  PASS([mgr createDirectoryAtPath: [top stringByAppendingPathComponent: @"d"]
      withIntermediateDirectories: YES
		       attributes: nil
			    error: NULL]
    && [mgr createFileAtPath: [top stringByAppendingPathComponent: @"f"]
		    contents: [NSData data]
		  attributes: nil]
    && [mgr createFileAtPath: [top stringByAppendingPathComponent: @"d/g"]
		    contents: [NSData data]
		  attributes: nil],
    "can create the test directory")

  /* Enumerate from another directory, so that URLs resolved against the
   * working directory are wrong.
   */
  cwd = [mgr currentDirectoryPath];
  [mgr changeCurrentDirectoryPath: [top stringByAppendingPathComponent: @"d"]];

  e = [mgr enumeratorAtURL: [NSURL fileURLWithPath: top]
  includingPropertiesForKeys: nil
		   options: 0
	      errorHandler: nil];
  found = [NSMutableDictionary dictionary];
  while (nil != (u = [e nextObject]))
    {
      [found setObject: u forKey: [[u path] lastPathComponent]];
    }
  [mgr changeCurrentDirectoryPath: cwd];

  PASS([found count] == 3, "finds the files and the subdirectory")
  PASS_EQUAL([[found objectForKey: @"f"] path],
    [top stringByAppendingPathComponent: @"f"],
    "a file's URL is in the enumerated directory")
  PASS_EQUAL([[found objectForKey: @"g"] path],
    [top stringByAppendingPathComponent: @"d/g"],
    "a nested file's URL is in its subdirectory")
  PASS_EQUAL([[found objectForKey: @"d"] path],
    [top stringByAppendingPathComponent: @"d"],
    "a subdirectory's URL is in the enumerated directory")
  PASS([[[found objectForKey: @"d"] absoluteString] hasSuffix: @"/"],
    "a subdirectory's URL is a directory URL")
  PASS([[[found objectForKey: @"f"] absoluteString] hasSuffix: @"/"] == NO,
    "a file's URL is not a directory URL")

  [mgr removeItemAtPath: top error: NULL];

  END_SET("NSFileManager -enumeratorAtURL:...")

  [arp release];
  return 0;
}
