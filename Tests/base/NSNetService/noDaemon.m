/* With the system bus (and so the zeroconf daemon) out of reach, searching
 * for and resolving services must be reported to the delegate as a failure.
 * The avahi client does not exist then, and calling into avahi without one
 * aborts the process in an assertion.  Only the avahi backend is affected; any
 * other backend is skipped.
 */
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
#if !defined(_WIN32)
#include <stdlib.h>

@interface Watcher : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
@public
  BOOL	searchFailed;
  BOOL	resolveFailed;
}
@end

@implementation Watcher
- (void) netServiceBrowser: (NSNetServiceBrowser *)browser
	      didNotSearch: (NSDictionary *)errorDict
{
  searchFailed = YES;
}
- (void) netService: (NSNetService *)sender
      didNotResolve: (NSDictionary *)errorDict
{
  resolveFailed = YES;
}
@end
#endif

int main()
{
  START_SET("NSNetService without a daemon")

#if defined(_WIN32)
  SKIP("NSNetService has no zeroconf backend on Windows")
#else
  Watcher		*watcher = AUTORELEASE([Watcher new]);
  NSNetServiceBrowser	*browser;
  NSNetService		*service;
  NSDate		*limit;

  setenv("DBUS_SYSTEM_BUS_ADDRESS", "unix:path=/nonexistent", 1);
  browser = AUTORELEASE([NSNetServiceBrowser new]);
  if (browser == nil
    || [NSStringFromClass([browser class]) isEqual: @"GSAvahiNetServiceBrowser"]
    == NO)
    {
      SKIP("the avahi backend is not in use")
    }
  [browser setDelegate: watcher];
  [browser searchForServicesOfType: @"_gnustep-test._tcp." inDomain: @"local."];
  limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];
  while (watcher->searchFailed == NO && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  PASS(watcher->searchFailed, "a search reports didNotSearch without a daemon")

  service = AUTORELEASE([[NSNetService alloc] initWithDomain: @"local."
						        type: @"_gnustep-test._tcp."
						        name: @"NSNetService test"]);
  [service setDelegate: watcher];
  [service resolveWithTimeout: 5.0];
  limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];
  while (watcher->resolveFailed == NO && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
  PASS(watcher->resolveFailed, "a resolve reports didNotResolve without a daemon")
#endif

  END_SET("NSNetService without a daemon")
  return 0;
}
