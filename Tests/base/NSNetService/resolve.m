/* Publishes a service and resolves it again, then checks every address the
 * resolver returns: it must be a complete socket address of the family it
 * claims, carry the published port, and be one of this host's own interface
 * addresses (the service runs here), which catches an address whose bytes are
 * wrong as well as one with a missing family or port.  Skipped when no
 * zeroconf daemon is running.  Uses only API that macOS also has, so the same
 * test can be run there for comparison.
 */
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
/* libs-base has no zeroconf backend on Windows, and the interface check
 * uses POSIX networking headers: there the test is only skipped. */
#if !defined(_WIN32)
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <ifaddrs.h>
#include <string.h>
#include <unistd.h>

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) \
  || defined(__NetBSD__) || defined(__DragonFly__)
#define	HAVE_SA_LEN	1
#endif

static const int	testPort = 47913;

@interface Watcher : NSObject <NSNetServiceDelegate>
{
@public
  BOOL	published;
  BOOL	publishFailed;
  BOOL	resolved;
  BOOL	resolveFailed;
}
@end

@implementation Watcher
- (void) netServiceDidPublish: (NSNetService *)sender
{
  published = YES;
}
- (void) netService: (NSNetService *)sender
      didNotPublish: (NSDictionary *)errorDict
{
  publishFailed = YES;
}
- (void) netServiceDidResolveAddress: (NSNetService *)sender
{
  resolved = YES;
}
- (void) netService: (NSNetService *)sender
      didNotResolve: (NSDictionary *)errorDict
{
  resolveFailed = YES;
}
@end

/* Run the run loop until *flag or *failed is set, or the time is up. */
static void
waitFor(BOOL *flag, BOOL *failed, NSTimeInterval seconds)
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: seconds];

  while (*flag == NO && *failed == NO && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
}

/* YES if the address is one of the addresses of this host's interfaces. */
static BOOL
isLocalAddress(const struct sockaddr *sa)
{
  struct ifaddrs	*list;
  struct ifaddrs	*ifa;
  BOOL			found = NO;

  if (getifaddrs(&list) != 0)
    {
      return NO;
    }
  for (ifa = list; ifa != NULL && found == NO; ifa = ifa->ifa_next)
    {
      if (ifa->ifa_addr == NULL || ifa->ifa_addr->sa_family != sa->sa_family)
	{
	  continue;
	}
      if (sa->sa_family == AF_INET)
	{
	  found = (memcmp(&((struct sockaddr_in *)(void *)ifa->ifa_addr)->sin_addr,
	    &((const struct sockaddr_in *)(const void *)sa)->sin_addr,
	    sizeof(struct in_addr)) == 0);
	}
      else if (sa->sa_family == AF_INET6)
	{
	  found = (memcmp(&((struct sockaddr_in6 *)(void *)ifa->ifa_addr)->sin6_addr,
	    &((const struct sockaddr_in6 *)(const void *)sa)->sin6_addr,
	    sizeof(struct in6_addr)) == 0);
	}
    }
  freeifaddrs(list);
  return found;
}

#endif

int main()
{
  START_SET("NSNetService resolve")

#if defined(_WIN32)
  SKIP("NSNetService has no zeroconf backend on Windows")
#else
  {
  NSString	*name;
  NSNetService	*service;
  NSNetService	*resolver;
  Watcher	*publishWatcher = AUTORELEASE([Watcher new]);
  Watcher	*resolveWatcher = AUTORELEASE([Watcher new]);
  NSArray	*addresses;
  NSUInteger	i;


  name = [NSString stringWithFormat: @"NSNetService test %d", (int)getpid()];
  service = AUTORELEASE([[NSNetService alloc] initWithDomain: @"local."
							 type: @"_gnustep-test._tcp."
							 name: name
							 port: testPort]);
  if (service == nil)
    {
      SKIP("NSNetService is not available (no zeroconf support)")
    }
  [service setDelegate: publishWatcher];
  [service publish];
  waitFor(&publishWatcher->published, &publishWatcher->publishFailed, 10.0);
  if (publishWatcher->published == NO)
    {
      SKIP("the service could not be published (no zeroconf daemon running?)")
    }

  resolver = AUTORELEASE([[NSNetService alloc] initWithDomain: @"local."
							  type: @"_gnustep-test._tcp."
							  name: name]);
  [resolver setDelegate: resolveWatcher];
  [resolver resolveWithTimeout: 10.0];
  waitFor(&resolveWatcher->resolved, &resolveWatcher->resolveFailed, 15.0);
  PASS(resolveWatcher->resolved, "the published service resolves")

  /* Addresses keep arriving after the first one; give the others time. */
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 2.0]];

  addresses = [resolver addresses];
  PASS([addresses count] > 0, "the resolved service has at least one address")
  PASS([resolver port] == testPort, "the resolved service has the published port")
  PASS([[resolver hostName] length] > 0, "the resolved service has a host name")

  for (i = 0; i < [addresses count]; i++)
    {
      NSData			*data = [addresses objectAtIndex: i];
      const struct sockaddr	*sa = (const struct sockaddr *)[data bytes];
      NSUInteger		length = [data length];
      int			family;
      unsigned			port;

      PASS(length >= sizeof(struct sockaddr),
	"address %u holds at least a struct sockaddr", (unsigned)i)
      if (length < sizeof(struct sockaddr))
	{
	  continue;
	}
      family = sa->sa_family;
      PASS(family == AF_INET || family == AF_INET6,
	"address %u is IPv4 or IPv6 (family %d)", (unsigned)i, family)
      if (family == AF_INET)
	{
	  PASS(length == sizeof(struct sockaddr_in),
	    "IPv4 address %u is a struct sockaddr_in (length %u)",
	    (unsigned)i, (unsigned)length)
	  port = ntohs(((const struct sockaddr_in *)(const void *)sa)->sin_port);
	}
      else if (family == AF_INET6)
	{
	  PASS(length == sizeof(struct sockaddr_in6),
	    "IPv6 address %u is a struct sockaddr_in6 (length %u)",
	    (unsigned)i, (unsigned)length)
	  port = ntohs(((const struct sockaddr_in6 *)(const void *)sa)->sin6_port);
	}
      else
	{
	  continue;
	}
#if	defined(HAVE_SA_LEN)
      PASS(sa->sa_len == length,
	"address %u has sa_len set to its length (%u)", (unsigned)i, (unsigned)sa->sa_len)
#endif
      PASS(port == (unsigned)testPort,
	"address %u carries the published port (%u)", (unsigned)i, port)
      PASS(isLocalAddress(sa),
	"address %u is an address of this host", (unsigned)i)
    }

  [resolver stop];
  [service stop];
  }
#endif

  END_SET("NSNetService resolve")
  return 0;
}
