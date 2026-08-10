#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTask.h>

/* A launch path with no directory in it is looked up in PATH, and a process
 * can be started with no PATH at all.
 */
int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSProcessInfo		*info = [NSProcessInfo processInfo];
  NSTask		*task = AUTORELEASE([NSTask new]);
  NSError		*err = nil;
  BOOL			 launched;

  if (NO == [info respondsToSelector: @selector(setValue:inEnvironment:)])
    {
      [arp release];
      return 0;
    }
  [info setValue: nil inEnvironment: @"PATH"];
  [info setValue: nil inEnvironment: @"Path"];
  PASS_EQUAL([[info environment] objectForKey: @"PATH"], nil,
    "PATH can be removed from the environment")

  [task setLaunchPath: @"gnustep-a-program-which-is-not-installed"];
  launched = [task launchAndReturnError: &err];
  PASS(NO == launched,
    "a program which is not on PATH does not launch when PATH is unset")
  PASS(err != nil, "and the failure is reported")

  [arp release]; arp = nil;
  return 0;
}
