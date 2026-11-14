/**
 *  A TLS stream whose handshake has not completed must neither be
 *  reported as open nor hang a writer.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* Accepts plain TCP connections on an unused loopback port, and either
 * closes them at once or keeps them open without ever answering.
 */
@interface Server : NSObject
{
  NSFileHandle		*listener;
  NSMutableArray	*held;
  BOOL			closes;
}
- (id) initClosing: (BOOL)flag;
- (int) port;
- (void) run: (id)unused;
@end

@implementation Server
- (id) initClosing: (BOOL)flag
{
  if ((self = [super init]) != nil)
    {
      closes = flag;
      held = [NSMutableArray new];
      listener = RETAIN([NSFileHandle
	fileHandleAsServerAtAddress: @"127.0.0.1"
			    service: @"0"
			   protocol: @"tcp"]);
    }
  return self;
}

- (int) port
{
  return [[listener socketLocalService] intValue];
}

- (void) accepted: (NSNotification*)n
{
  NSFileHandle	*h;

  h = [[n userInfo] objectForKey: NSFileHandleNotificationFileHandleItem];
  [listener acceptConnectionInBackgroundAndNotify];
  if (closes)
    {
      [h closeFile];
    }
  else
    {
      [held addObject: h];
    }
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
    [NSDate dateWithTimeIntervalSinceNow: 30.0]];
  LEAVE_POOL
}
@end

/* Writes a request as soon as the output stream says it has space.
 */
@interface Client : NSObject
{
@public
  NSInputStream		*ip;
  NSOutputStream	*op;
  BOOL			opened;
  BOOL			writable;
  BOOL			failed;
  BOOL			ended;
}
@end

@implementation Client
- (void) dealloc
{
  [ip setDelegate: nil];
  [op setDelegate: nil];
  [ip close];
  [op close];
  DESTROY(ip);
  DESTROY(op);
  DEALLOC
}

- (id) initWithPort: (int)port
{
  if ((self = [super init]) != nil)
    {
      NSRunLoop	*loop = [NSRunLoop currentRunLoop];

      [NSStream getStreamsToHost: [NSHost hostWithName: @"127.0.0.1"]
			    port: port
		     inputStream: &ip
		    outputStream: &op];
      RETAIN(ip);
      RETAIN(op);
      [ip setDelegate: self];
      [op setDelegate: self];
      [ip setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	       forKey: NSStreamSocketSecurityLevelKey];
      [op setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
	       forKey: NSStreamSocketSecurityLevelKey];
      [ip scheduleInRunLoop: loop forMode: NSDefaultRunLoopMode];
      [op scheduleInRunLoop: loop forMode: NSDefaultRunLoopMode];
      [ip open];
      [op open];
    }
  return self;
}

- (void) runFor: (NSTimeInterval)seconds
{
  NSDate	*limit = [NSDate dateWithTimeIntervalSinceNow: seconds];

  while (NO == failed && NO == ended && [limit timeIntervalSinceNow] > 0.0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: limit];
    }
}

- (void) stream: (NSStream*)s handleEvent: (NSStreamEvent)event
{
  const char	*request = "GET / HTTP/1.0\r\n\r\n";

  switch (event)
    {
      case NSStreamEventOpenCompleted:
	if (s == op)
	  {
	    opened = YES;
	  }
	break;
      case NSStreamEventHasSpaceAvailable:
	writable = YES;
	[op write: (const uint8_t*)request maxLength: strlen(request)];
	break;
      case NSStreamEventErrorOccurred:
	failed = YES;
	break;
      case NSStreamEventEndEncountered:
	ended = YES;
	break;
      default:
	break;
    }
}
@end

int main()
{
  START_SET("TLS stream handshake")
#if GS_USE_GNUTLS
    Server	*server;
    Client	*client;
    const char	*request = "GET / HTTP/1.0\r\n\r\n";

    server = AUTORELEASE([[Server alloc] initClosing: YES]);
    [NSThread detachNewThreadSelector: @selector(run:)
			     toTarget: server
			   withObject: nil];
    [NSThread sleepForTimeInterval: 0.2];
    client = AUTORELEASE([[Client alloc] initWithPort: [server port]]);
    [client runFor: 5.0];
    PASS(client->failed,
      "a connection closed during the handshake fails")
    PASS(NO == client->opened && NO == client->writable,
      "and its output stream is never reported open or writable")
    PASS([client->op streamStatus] == NSStreamStatusError,
      "and its output stream has an error")

    server = AUTORELEASE([[Server alloc] initClosing: NO]);
    [NSThread detachNewThreadSelector: @selector(run:)
			     toTarget: server
			   withObject: nil];
    [NSThread sleepForTimeInterval: 0.2];
    client = AUTORELEASE([[Client alloc] initWithPort: [server port]]);
    [client runFor: 0.5];
    PASS([client->op write: (const uint8_t*)request
		 maxLength: strlen(request)] == 0,
      "a write during the handshake returns without writing")
    PASS([client->op streamStatus] != NSStreamStatusError,
      "and leaves the stream usable")
#else
    SKIP("TLS support is not built in")
#endif
  END_SET("TLS stream handshake")
  return 0;
}
