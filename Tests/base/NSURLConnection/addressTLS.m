/**
 *  An https URL whose host is an IP address is verified against that
 *  address, never against a name found by looking the address up.
 */
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSTLS.h>
#import "Testing.h"

/* Serves one certificate over TLS on an unused loopback port.
 */
@interface TLSServer : NSObject
{
  NSFileHandle	*listener;
  NSDictionary	*options;
}
- (id) initWithCertificate: (NSString*)name;
- (NSString*) port;
- (void) run: (id)unused;
@end

@implementation TLSServer
- (id) initWithCertificate: (NSString*)name
{
  if ((self = [super init]) != nil)
    {
      NSString	*dir = [[NSFileManager defaultManager] currentDirectoryPath];

      dir = [dir stringByAppendingPathComponent: @"addressTLS"];
      options = RETAIN(([NSDictionary dictionaryWithObjectsAndKeys:
	[dir stringByAppendingPathComponent:
	  [name stringByAppendingPathExtension: @"crt"]], GSTLSCertificateFile,
	[dir stringByAppendingPathComponent: @"server.key"],
	GSTLSCertificateKeyFile,
	@"NO", GSTLSVerify,
	nil]));
      listener = RETAIN([[NSFileHandle sslClass]
	fileHandleAsServerAtAddress: @"127.0.0.1"
			    service: @"0"
			   protocol: @"tcp"]);
    }
  return self;
}

- (NSString*) port
{
  return [listener socketLocalService];
}

- (void) accepted: (NSNotification*)n
{
  NSFileHandle	*h = [[n userInfo] objectForKey: NSFileHandleNotificationFileHandleItem];
  NSString	*response;

  [listener acceptConnectionInBackgroundAndNotify];
  [h sslSetOptions: options];
  if ([h sslAccept] == YES)
    {
      [h availableData];
      response = @"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
	@"Content-Length: 5\r\nConnection: close\r\n\r\nhello";
      [h writeData: [response dataUsingEncoding: NSISOLatin1StringEncoding]];
    }
  [h closeFile];
}

- (void) run: (id)unused
{
  ENTER_POOL
  [[NSNotificationCenter defaultCenter] addObserver: self
    selector: @selector(accepted:)
    name: NSFileHandleConnectionAcceptedNotification
    object: listener];
  [listener acceptConnectionInBackgroundAndNotify];
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 60.0]];
  LEAVE_POOL
}
@end

static TLSServer *
startServer(NSString *certificate)
{
  TLSServer	*server;

  server = AUTORELEASE([[TLSServer alloc] initWithCertificate: certificate]);
  [NSThread detachNewThreadSelector: @selector(run:)
			   toTarget: server
			 withObject: nil];
  [NSThread sleepForTimeInterval: 0.2];
  return server;
}

/* Fetches the URL through NSURLConnection, returning the body if the
 * connection was allowed.
 */
static NSData *
connectionData(NSString *host, TLSServer *server)
{
  NSURL			*url;
  NSMutableURLRequest	*request;
  NSURLResponse		*response = nil;
  NSError		*error = nil;

  url = [NSURL URLWithString:
    [NSString stringWithFormat: @"https://%@:%@/", host, [server port]]];
  request = [NSMutableURLRequest requestWithURL: url
    cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
    timeoutInterval: 10.0];
  return [NSURLConnection sendSynchronousRequest: request
			       returningResponse: &response
					   error: &error];
}

/* The same fetch through NSURLHandle.
 */
static NSData *
handleData(NSString *host, TLSServer *server)
{
  NSURL	*url;

  url = [NSURL URLWithString:
    [NSString stringWithFormat: @"https://%@:%@/", host, [server port]]];
  return [NSData dataWithContentsOfURL: url];
}

#define	ALLOWED(d)	([(d) length] == 5)

int main()
{
  START_SET("TLS verification of address URLs")
#if GS_USE_GNUTLS
    NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
    NSString		*dir = [[NSFileManager defaultManager] currentDirectoryPath];
    TLSServer		*name;
    TLSServer		*address;
    TLSServer		*other;

    /* The test authority must be in place before the TLS code initialises.
     */
    [defs registerDefaults: [NSDictionary dictionaryWithObject:
      [dir stringByAppendingPathComponent: @"addressTLS/ca.crt"]
      forKey: GSTLSCAFile]];

    name = startServer(@"name");
    address = startServer(@"address");
    other = startServer(@"other");

    PASS(ALLOWED(connectionData(@"localhost", name)),
      "NSURLConnection accepts a certificate for the host name")
    PASS(!ALLOWED(connectionData(@"localhost", other)),
      "NSURLConnection refuses a certificate for another host name")
    PASS(!ALLOWED(connectionData(@"localhost", address)),
      "NSURLConnection refuses an address certificate for a host name")
    PASS(ALLOWED(connectionData(@"127.0.0.1", address)),
      "NSURLConnection accepts a certificate for the address in the URL")
    PASS(!ALLOWED(connectionData(@"127.0.0.1", name)),
      "NSURLConnection refuses a name certificate for an address URL")
    PASS(!ALLOWED(connectionData(@"127.0.0.1", other)),
      "NSURLConnection refuses a certificate for another address")

    PASS(ALLOWED(handleData(@"localhost", name)),
      "NSURLHandle accepts a certificate for the host name")
    PASS(!ALLOWED(handleData(@"localhost", other)),
      "NSURLHandle refuses a certificate for another host name")
    PASS(ALLOWED(handleData(@"127.0.0.1", address)),
      "NSURLHandle accepts a certificate for the address in the URL")
    PASS(!ALLOWED(handleData(@"127.0.0.1", name)),
      "NSURLHandle refuses a name certificate for an address URL")
    PASS(!ALLOWED(handleData(@"127.0.0.1", other)),
      "NSURLHandle refuses a certificate for another address")
#else
    SKIP("TLS support is not built in")
#endif
  END_SET("TLS verification of address URLs")
  return 0;
}
