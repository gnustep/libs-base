#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int
main(void)
{
  NSAutoreleasePool *arp;
  NSURLSession *session;
  NSURLSessionWebSocketTask *task;
  NSURLSessionWebSocketMessage *dataMessage;
  NSURLSessionWebSocketMessage *stringMessage;
  NSURL *url;
  NSData *payload;

  arp = [NSAutoreleasePool new];

  url = [NSURL URLWithString: @"ws://example.com/socket"];
  payload = [@"hello" dataUsingEncoding: NSUTF8StringEncoding];

  TEST_FOR_CLASS(@"NSURLSessionWebSocketMessage",
    AUTORELEASE([NSURLSessionWebSocketMessage alloc]),
    "NSURLSessionWebSocketMessage +alloc returns an NSURLSessionWebSocketMessage");

  dataMessage = AUTORELEASE([[NSURLSessionWebSocketMessage alloc]
    initWithData: payload]);
  PASS(dataMessage != nil, "data websocket message can be created");
  PASS([dataMessage type] == NSURLSessionWebSocketMessageTypeData,
    "data websocket message reports the data type");
  PASS_EQUAL([dataMessage data], payload,
    "data websocket message stores the input payload");
  PASS([dataMessage string] == nil,
    "data websocket message has no string payload");

  stringMessage = AUTORELEASE([[NSURLSessionWebSocketMessage alloc]
    initWithString: @"hello"]);
  PASS(stringMessage != nil, "string websocket message can be created");
  PASS([stringMessage type] == NSURLSessionWebSocketMessageTypeString,
    "string websocket message reports the string type");
  PASS_EQUAL([stringMessage string], @"hello",
    "string websocket message stores the input string");
  PASS([stringMessage data] == nil,
    "string websocket message has no data payload");

  session = [NSURLSession sharedSession];
  task = [session webSocketTaskWithURL: url];

  PASS(task != nil, "NSURLSession can create a websocket task from a ws URL");
  PASS([task isKindOfClass: [NSURLSessionWebSocketTask class]],
    "created websocket task has the expected class");
  PASS([task closeCode] == NSURLSessionWebSocketCloseCodeInvalid,
    "new websocket task starts with an invalid close code");
  PASS([task closeReason] == nil,
    "new websocket task starts with no close reason");

  [task setMaximumMessageSize: 4096];
  PASS([task maximumMessageSize] == 4096,
    "maximumMessageSize setter and getter round-trip");

  [task sendMessage: dataMessage
  completionHandler: ^(NSError *error) {
    PASS(error != nil, "queued sendMessage fails when the task is closed before sending");
  }];
  PASS(YES, "sendMessage accepts an asynchronous completion handler");

  [task receiveMessageWithCompletionHandler:
    ^(NSURLSessionWebSocketMessage *message, NSError *error) {
      PASS(message == nil, "receive completion has no message yet");
      PASS(error == nil, "receive completion has no error yet");
    }];
  PASS(YES, "receiveMessageWithCompletionHandler accepts an asynchronous completion handler");

  [task sendPingWithPongReceiveHandler: ^(NSError *error) {
    PASS(error != nil, "queued ping fails when the task is closed before a pong arrives");
  }];
  PASS(YES, "sendPingWithPongReceiveHandler accepts a completion handler");

  [task cancelWithCloseCode: NSURLSessionWebSocketCloseCodeNormalClosure
                     reason: payload];
  PASS([task closeCode] == NSURLSessionWebSocketCloseCodeNormalClosure,
    "cancelWithCloseCode updates the close code");
  PASS_EQUAL([task closeReason], payload,
    "cancelWithCloseCode stores the close reason");

  [arp release];
  return 0;
}
