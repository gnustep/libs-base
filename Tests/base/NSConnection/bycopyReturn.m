#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDistantObject.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPort.h>

@protocol BycopyReturnTester
- (bycopy NSArray*) copiedArray;
- (byref NSArray*) referencedArray;
- (NSArray*) plainArray;
@end

@interface BycopyReturnServer : NSObject <BycopyReturnTester>
@end

@implementation BycopyReturnServer
- (bycopy NSArray*) copiedArray
{
  return [NSArray arrayWithObjects: @"one", @"two", @"three", nil];
}
- (byref NSArray*) referencedArray
{
  return [NSArray arrayWithObjects: @"one", @"two", @"three", nil];
}
- (NSArray*) plainArray
{
  return [NSArray arrayWithObjects: @"one", @"two", @"three", nil];
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*expected;
  NSPort		*serverPort;
  NSPort		*clientPort;
  NSConnection		*server;
  NSConnection		*client;
  id			proxy;
  id			result;

  expected = [NSArray arrayWithObjects: @"one", @"two", @"three", nil];
  serverPort = [NSPort port];
  clientPort = [NSPort port];
  server = [[NSConnection alloc] initWithReceivePort: serverPort
					    sendPort: nil];
  [server setRootObject: AUTORELEASE([BycopyReturnServer new])];
  client = [[NSConnection alloc] initWithReceivePort: clientPort
					    sendPort: serverPort];
  [client setReplyTimeout: 10.0];
  [client setRequestTimeout: 10.0];

  proxy = [client rootProxy];
  PASS(proxy != nil && [proxy isProxy], "client gets a proxy for the root object");
  [proxy setProtocolForProxy: @protocol(BycopyReturnTester)];

  NS_DURING
    {
      result = [proxy copiedArray];
      PASS(result != nil && [result isProxy] == NO,
	"a bycopy return value arrives as a copy, not as a proxy");
      PASS_EQUAL(result, expected, "the copied return value has the contents");

      result = [proxy referencedArray];
      PASS(result != nil && [result isProxy] == YES,
	"a byref return value arrives as a proxy");

      result = [proxy plainArray];
      PASS(result != nil && [result isProxy] == YES,
	"an unqualified array return value arrives as a proxy");
      PASS([result count] == 3, "the proxy forwards messages to the array");
    }
  NS_HANDLER
    {
      PASS(0, "returning values over a connection raises no exception");
    }
  NS_ENDHANDLER

  [client invalidate];
  [server invalidate];
  RELEASE(client);
  RELEASE(server);
  [arp release]; arp = nil;
  return 0;
}
