#import <Foundation/Foundation.h>
#import <GNUstepBase/NSTask+GNUstepBase.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*path;

  path = [NSTask launchPathForTool: @"this-tool-does-not-exist"];
  PASS(path == nil, "launchPathForTool: answers nil for an unknown tool");

  /* A test binary has no JNI context on Android, so the package directory
   * contributes nothing and the tool directories answer, as on every other
   * platform.
   */
  path = [NSTask launchPathForTool: @"gdnc"];
  if (nil == path)
    {
      testHopeful = YES;
      PASS(NO, "gdnc is installed and found");
      testHopeful = NO;
    }
  else
    {
      /* Windows carries an extension: the answer there is gdnc.EXE, or any
       * other of +[NSTask executableExtensions].
       */
      PASS([[[path lastPathComponent] stringByDeletingPathExtension]
	isEqual: @"gdnc"],
	"launchPathForTool: answers a path ending in the tool name");
      PASS([[NSFileManager defaultManager] isExecutableFileAtPath: path],
	"the path it answers is executable");
    }

  [arp release];
  return 0;
}
