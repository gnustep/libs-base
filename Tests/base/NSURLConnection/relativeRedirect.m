/**
 *  A redirect with a relative Location is followed against the URL of
 *  the request that was redirected.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* Answers each connection with a canned response: GET /start is
 * redirected to /target, which answers with a body.
 */
@interface RedirectingServer : NSObject
{
  NSFileHandle	*listener;
}
- (NSString*) port;
- (void) run: (id)unused;
@end

@implementation RedirectingServer
- (id) init
{
  if ((self = [super init]) != nil)
    {
      listener = RETAIN([NSFileHandle fileHandleAsServerAtAddress: @"127.0.0.1"
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
  NSString	*request;
  NSString	*response;

  [listener acceptConnectionInBackgroundAndNotify];
  request = AUTORELEASE([[NSString alloc] initWithData: [h availableData]
					      encoding: NSISOLatin1StringEncoding]);
  if ([request hasPrefix: @"GET /start "])
    {
      response = @"HTTP/1.1 302 Found\r\nLocation: /target\r\n"
	@"Content-Length: 0\r\nConnection: close\r\n\r\n";
    }
  else
    {
      response = @"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
	@"Content-Length: 5\r\nConnection: close\r\n\r\nhello";
    }
  [h writeData: [response dataUsingEncoding: NSISOLatin1StringEncoding]];
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
    [NSDate dateWithTimeIntervalSinceNow: 30.0]];
  LEAVE_POOL
}
@end

int main()
{
  START_SET("relative redirect")
    RedirectingServer	*server = AUTORELEASE([RedirectingServer new]);
    NSMutableURLRequest	*request;
    NSURLResponse	*response = nil;
    NSError		*error = nil;
    NSData		*data;
    NSString		*body;

    [NSThread detachNewThreadSelector: @selector(run:)
			     toTarget: server
			   withObject: nil];
    [NSThread sleepForTimeInterval: 0.2];
    request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:
      [NSString stringWithFormat: @"http://127.0.0.1:%@/start", [server port]]]];
    [request setTimeoutInterval: 5.0];
    data = [NSURLConnection sendSynchronousRequest: request
				 returningResponse: &response
					     error: &error];
    body = AUTORELEASE([[NSString alloc] initWithData: data
					     encoding: NSUTF8StringEncoding]);
    PASS(error == nil, "a redirect with a relative Location does not fail");
    PASS_EQUAL([[response URL] path], @"/target",
      "it is followed to the Location, resolved against the request's URL");
    PASS_EQUAL(body, @"hello", "and the answer there is the response");
  END_SET("relative redirect")
  return 0;
}
