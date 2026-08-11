#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*dirs;

  dirs = NSSearchPathForDirectoriesInDomains(GSToolsDirectory,
    NSAllDomainsMask, YES);
  PASS([dirs count] > 0, "there is at least one tools directory");

#ifdef __ANDROID__
  {
    NSFileManager	*mgr = [NSFileManager defaultManager];
    NSEnumerator	*e = [dirs objectEnumerator];
    NSString		*dir;
    BOOL		 found = NO;

    /* Every tools directory is the one the library itself was loaded from,
     * because that is the only directory a tool can be started from.
     */
    while (nil != (dir = [e nextObject]))
      {
	NSString	*lib;

	lib = [dir stringByAppendingPathComponent: @"libgnustep-base.so"];
	if ([mgr isReadableFileAtPath: lib])
	  {
	    found = YES;
	  }
      }
    PASS(found == YES,
      "a tools directory holds the gnustep-base library");
  }
#endif

  [arp release];
  return 0;
}
