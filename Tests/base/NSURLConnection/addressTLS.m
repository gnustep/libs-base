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
  NSFileHandle	*h;
  NSString	*response;

  h = [[n userInfo] objectForKey: NSFileHandleNotificationFileHandleItem];
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

@interface StreamHandler :  NSObject
{
  NSInputStream		*ip;
  NSOutputStream	*op;
  NSMutableData		*md;
  BOOL 			written;
  BOOL			done;
}
@end
@implementation	StreamHandler
- (void) dealloc
{
  DESTROY(ip);
  DESTROY(op);
  DESTROY(md);
  DEALLOC
}
- (NSData*) data
{
  return AUTORELEASE([md copy]);
}
- (BOOL) done
{
  return done;
}
- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      md = [NSMutableData new];
    }
  return self;
}
- (void) setInput: (NSInputStream*)i andOutput: (NSOutputStream*)o
{
  ASSIGN(ip, i);
  [ip setDelegate: self];
  ASSIGN(op, o);
  [op setDelegate: self];
}
- (void) stream: (NSStream*)theStream handleEvent: (NSStreamEvent)streamEvent
{
  static uint8_t buffer[4096];
  int readSize;

  NSDebugMLLog(@"NSStream", @"Got %ld on %p",
    (long int)streamEvent, theStream);
  switch (streamEvent)
    {
    case NSStreamEventOpenCompleted: 
      {
	if (theStream == op)
	  {
	    written = NO;
	  }
	break;
      }
    case NSStreamEventHasSpaceAvailable: 
      {
        NSAssert(theStream==op, @"Wrong stream for reading");
        if (written == NO)
          {
	    char	*rawstring = "GET / HTTP/1.0\r\n\r\n";

            // Since this is so short it is pretty safe to assume one write
	    //NSLog(@"Written request");
	    written = YES;
            [op write: (const uint8_t*)rawstring
	    maxLength: strlen((char*)rawstring)];
	  }
/*
	else
	  {
            [op close];
	    [op removeFromRunLoop: [NSRunLoop currentRunLoop]
			  forMode: NSDefaultRunLoopMode];
	    NSLog(@"Closed %p", op);
          }          
*/
        break;
      }
    case NSStreamEventHasBytesAvailable: 
      {
        NSAssert(theStream==ip, @"Wrong stream for reading");
        readSize = [ip read: buffer maxLength: 4096];
        if (readSize < 0)
          {
            // it is possible that readSize<0 but not an Error.
	    // For example would block
	    NSLog(@"%@", [ip streamError]);
            NSAssert([ip streamError]==nil, @"read error");
          }
        else if (readSize == 0)
	  {
            [ip close];
	    [ip removeFromRunLoop: [NSRunLoop currentRunLoop]
			  forMode: NSDefaultRunLoopMode];
	    // NSLog(@"Closed %p", ip);
	  }
        else
	  {
	    [md appendBytes: buffer length: readSize];
	    NSLog(@"Read %d: %*.*s", readSize, readSize, readSize, buffer);
	  }
        break;
      }
    case NSStreamEventEndEncountered: 
      {
        [theStream close];
	[theStream removeFromRunLoop: [NSRunLoop currentRunLoop]
			     forMode: NSDefaultRunLoopMode];
        NSLog(@"Close %p", theStream);
        done = YES;
        break;
      }
    default: 
      {
        NSAssert1(1, @"Error! code is %ld",
          (long int)[[theStream streamError] code]);
	done = YES;
        break;
      }  
    }
}
@end

static NSData *
streamData(NSString *host, TLSServer *server)
{
  NSInputStream		*ip;
  NSOutputStream	*op;
  StreamHandler	*handler;
  NSDate	*limit;
  NSRunLoop	*loop;
  NSData	*data;
  
  ENTER_POOL
  handler = AUTORELEASE([StreamHandler new]);

  loop = [NSRunLoop currentRunLoop];
  [NSStream getStreamsToHost: [NSHost hostWithName: host]
			port: [[server port] intValue]
		 inputStream: &ip
		outputStream: &op];
  [handler setInput: ip andOutput: op];

  [ip setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	   forKey: NSStreamSocketSecurityLevelKey];
  [op setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	   forKey: NSStreamSocketSecurityLevelKey];
/* Remote host addresses should really be set using GSTLSRemoteHosts,
 * but the GSTLS session will detect an address set as the GSTLSServerName
 * and move it to GSTLSRemoteHosts when required.
 */
//  [ip setProperty: host forKey: GSTLSRemoteHosts];
//  [op setProperty: host forKey: GSTLSRemoteHosts];
  [ip setProperty: host forKey: GSTLSServerName];
  [op setProperty: host forKey: GSTLSServerName];
  [ip setProperty: @"YES" forKey: GSTLSVerify];
  [op setProperty: @"YES" forKey: GSTLSVerify];
  [ip scheduleInRunLoop: loop forMode: NSDefaultRunLoopMode];
  [op scheduleInRunLoop: loop forMode: NSDefaultRunLoopMode];
  [ip open];
  [op open];

  limit = [NSDate dateWithTimeIntervalSinceNow: 1.0];
  while ([handler done] == NO && [limit timeIntervalSinceNow] > 0.0)
    {
      [loop runMode: NSDefaultRunLoopMode beforeDate: limit];
    }

  [ip setDelegate: nil];
  [op setDelegate: nil];

  data = [handler data];
  if ([data length] > 0)
    {
      data = RETAIN([NSData dataWithBytes: (const uint8_t*)"hello" length: 5]);
    }
  else
    {
      data = nil;
    }
  LEAVE_POOL
  return AUTORELEASE(data);
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
    [defs registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
      [dir stringByAppendingPathComponent: @"addressTLS/ca.crt"], GSTLSCAFile,
      @"9", GSTLSDebug,
      nil]];

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

    PASS(ALLOWED(streamData(@"localhost", name)),
      "NSStream accepts a certificate for the host name")
    PASS(!ALLOWED(streamData(@"localhost", other)),
      "NSStream refuses a certificate for another host name")
    PASS(ALLOWED(streamData(@"127.0.0.1", address)),
      "NSStream accepts a certificate for the address in the URL")
    PASS(!ALLOWED(streamData(@"127.0.0.1", name)),
      "NSStream refuses a name certificate for an address URL")
    PASS(!ALLOWED(streamData(@"127.0.0.1", other)),
      "NSStream refuses a certificate for another address")

#else
    SKIP("TLS support is not built in")
#endif
  END_SET("TLS verification of address URLs")
  return 0;
}
