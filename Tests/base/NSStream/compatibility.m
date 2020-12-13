#import "Foundation/Foundation.h"
#import "ObjectTesting.h"

#if     __APPLE__
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <errno.h>
#include <netinet/in.h>
#include <string.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <objc/runtime.h>
#endif

static NSString *
eventString(NSStream *stream, NSStreamEvent event)
{
  switch (event)
    {
      case NSStreamEventNone: return @"None";
      case NSStreamEventOpenCompleted: return @"OpenCompleted";
      case NSStreamEventHasBytesAvailable: return @"HasBytesAvailable";
      case NSStreamEventHasSpaceAvailable: return @"HasSpaceAvailable";
      case NSStreamEventEndEncountered: return @"EndEncountered"; 
      case NSStreamEventErrorOccurred: 
        return [NSString stringWithFormat: @"ErrorOccurred %ld (%@)",
          (long int)[[stream streamError] code], [stream streamError]];
    }
  return [NSString stringWithFormat: @"Unknown event %ld", (long int)event];
}

static NSString *
statusString(NSStreamStatus status)
{
  switch (status)
    {
      case NSStreamStatusNotOpen:       return @"NotOpen";
      case NSStreamStatusOpening:	return @"Opening";
      case NSStreamStatusOpen:	        return @"Open";
      case NSStreamStatusReading:	return @"Reading";
      case NSStreamStatusWriting:	return @"Writing";
      case NSStreamStatusAtEnd:	        return @"AtEnd";
      case NSStreamStatusClosed:	return @"Closed";
      case NSStreamStatusError:	        return @"Error";
    }
  return @"Unknown";
}


/* I read somewhere that a stream's delegate is commonly set to be itself,
 * so this intercept class was written to provide interception of the OSX
 * calls to -stream:handleEvent: to log the events as they are sent.
 * In fact it seems that OSX doesn't send events in that case.
 */
@interface Logger : NSObject
+ (void) intercept: (NSStream*)stream;
+ (NSMutableArray*) logsFor: (NSStream*)stream;
+ (void) remove: (NSStream*)stream;
@end

@implementation Logger

static NSMapTable       *eventHandlers = nil;
static NSMapTable       *eventLogs = nil;

+ (void) initialize
{
  if (nil == eventHandlers)
    {
      eventHandlers = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
        NSNonOwnedPointerMapValueCallBacks, 4);
      eventLogs = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
        NSObjectMapValueCallBacks, 4);
    }
}

/* Ensure there's an array to record events handled for the stream and
 * that the streams own event handler (if it exists) logs information to it.
 */
+ (void) intercept: (NSStream*)stream
{
  Class c = object_getClass(stream);
  if (NULL == NSMapGet(eventHandlers, (void*)c))
    {
      SEL s = @selector(stream:handleEvent:);
      Method m = class_getInstanceMethod(c, s);
      if (0 == m)
        {
          NSLog(@"[%s -%s] does not exist", class_getName(c), sel_getName(s));
        } 
      IMP i = method_getImplementation(m);
      const char *t = method_getTypeEncoding(m);
      class_replaceMethod(c, s, class_getMethodImplementation(self, s), t);
      NSMapInsert(eventHandlers, (void*)c, (void*)i);
    }
  if (NULL == NSMapGet(eventLogs, (void*)stream))
    {
      NSMapInsert(eventLogs, (void*)stream, (void*)[NSMutableArray array]);
    }
}

+ (NSMutableArray*) logsFor: (NSStream*)stream
{
  return (NSMutableArray*)NSMapGet(eventLogs, (void*)stream);
}

+ (void) remove: (NSStream*)stream
{
  NSMapRemove(eventLogs, (void*)stream);
}

- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event
{
  void                  (*efunc)(id, SEL, NSStream*, NSStreamEvent);
  Class                 c = object_getClass(stream);
  NSMutableArray        *ma;

  efunc = (void (*)(id, SEL, NSStream*, NSStreamEvent))
    NSMapGet(eventHandlers, (void*)c);
  ma = (NSMutableArray*)NSMapGet(eventLogs, (void*)stream);

  [ma addObject: [NSString stringWithFormat: @"%p %@ %@",
    stream, statusString([stream streamStatus]), eventString(stream, event)]];
  (*efunc)(self, _cmd, stream, event);
  [ma addObject: [NSString stringWithFormat: @"%p %@",
    stream, statusString([stream streamStatus])]];
}

@end


@interface      Server : NSObject
{
#if     __APPLE__
  int                   servSock;
  int                   accepted;
#else
  NSStream              *servStrm;
  NSInputStream         *acceptedIn;
  NSOutputStream        *acceptedOut;
#endif
  NSThread              *thread;
  NSConditionLock       *endThread;
  enum {
    WaitAndExit = 0,
  } action;
}
- (void) end;
- (void) run;
- (void) start;
@end

@implementation Server

- (BOOL) accept
{
  BOOL  result = NO;

  NSLog(@"Accepting connection");
#if     __APPLE__
  struct sockaddr       addr;
  socklen_t             len = sizeof(addr);

  accepted = accept(servSock, &addr, &len);
  if (accepted >= 0)
    {
      result = YES;
    }
#else
  [servStrm acceptWithInputStream: &acceptedIn
                     outputStream: &acceptedOut];
  if (acceptedIn && acceptedOut)
    {
      result = YES;
    }
#endif
  NSLog(@"Accept %@", result ? @"success" : @"failure");
  return result;
}

- (void) dealloc
{
#if     __APPLE__
  if (accepted >= 0)
    {
      close(accepted);
      accepted = -1;
    }
  if (servSock >= 0)
    {
      close(servSock);
      servSock = -1;
    }
#else
  [servStrm close];
  [servStrm release];
  [acceptedIn close];
  [acceptedIn release];
  [acceptedOut close];
  [acceptedOut release];
#endif
  [endThread release];
  [super dealloc];
}

- (void) end
{
  [endThread lockWhenCondition: 0];     // Get lock
  [endThread unlockWithCondition: 1];   // Tell thread it can end
  [endThread lockWhenCondition: 0];     // Wait for thread to end
  [endThread unlockWithCondition: 0];
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      uint16_t                  port = 1234;
#if     __APPLE__
      struct sockaddr_in        my_addr;
      struct hostent            *host;     
      struct in_addr            addr;     

      servSock = -1;
      accepted = -1;
      if ((host = gethostbyname("localhost")) == NULL)     
        { 
          fprintf(stderr, "Host error: %d\n", errno);
          [self dealloc];
          return nil;
        }   
      addr = *((struct in_addr *)host->h_addr);

      my_addr.sin_family = AF_INET;
      my_addr.sin_port = htons(port);
      my_addr.sin_addr = addr;

      if ((servSock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
        {
          fprintf(stderr, "Socket error: %d\n", errno);
          [self dealloc];
          return nil;
        }

      if (bind(servSock, (struct sockaddr *)&my_addr,
        sizeof(struct sockaddr)) < 0)
        {
          fprintf(stderr, "Bind error: %d\n", errno);
          [self dealloc];
          return nil;
        }

      if (listen(servSock, 5) < 0)
        {
          fprintf(stderr, "Listen error: %d\n", errno);
          [self dealloc];
          return nil;
        }
#else
      NSHost    *host = [NSHost hostWithName: @"localhost"];

      servStrm = [GSServerStream serverStreamToAddr: [host address]
                                               port: port];
      [servStrm open];
#endif

      endThread = [[NSConditionLock alloc] initWithCondition: 0];
    }
  return self;
}

- (void) run
{
  NSThread      *t;

  if ([self accept])
    {
    }
  [endThread lockWhenCondition: 1];     // Wait until thread is told to end
  t = thread;
  thread = nil;
  [endThread unlockWithCondition: 0];   // Record that thread has ended
  [t release];
}

- (void) start
{
  NSAssert(nil == thread, NSInternalInconsistencyException);
  thread = [[NSThread alloc] initWithTarget: self
                                   selector: @selector(run)
                                     object: nil];
  [thread start];
}
@end



int main()
{
  Server                *server;
  NSHost                *host = [NSHost hostWithName: @"localhost"];
  uint16_t              port = 1234;
  NSInputStream         *clientInput;
  NSOutputStream        *clientOutput;

  PASS((server = [Server new]) != nil, "can bind to address")

  /* At this point the server socket is bound and listening, so things
   * can initiate connections to it, but we haven't started a thread to
   * accept a connection.
   */

  START_SET("NSStream connect opening input and then output")

  /* Getting the streams to the server should initiate a non-blocking
   * connection to the server port.
   */
  [NSStream getStreamsToHost: host
                        port: port
                 inputStream: &clientInput
                outputStream: &clientOutput];
  PASS_EQUAL(statusString([clientInput streamStatus]),
    statusString(NSStreamStatusNotOpen),
    "after connect, client input is initially not open")
  PASS_EQUAL(statusString([clientOutput streamStatus]),
    statusString(NSStreamStatusNotOpen),
    "after connect, client output is initially not open")

  /* NB. The OSX streams documentation states that a stream is
   * its own delegate by default, and that setting a nil delegate
   * must restore that state.
   * The actual implementation is different!
   */
  PASS_EQUAL([clientInput delegate], nil,
    "input stream delegate before setting is nil, not self")
  PASS_EQUAL([clientOutput delegate], nil,
    "output stream delegate before setting is nil, not self")
  [clientInput setDelegate: nil];
  [clientOutput setDelegate: nil];
  PASS_EQUAL([clientInput delegate], nil,
    "input stream delegate after setting is nil, not self")
  PASS_EQUAL([clientOutput delegate], nil,
    "output stream delegate after setting is nil, not self")

  [Logger intercept: clientInput];
  [Logger intercept: clientOutput];

  PASS(NO == [clientInput hasBytesAvailable],
    "before open, client input does not have bytes available")
  PASS(NO == [clientOutput hasSpaceAvailable],
    "before open, client output does not have space available")

  /* Opening a connection to the server should put the stream in an
   * opening state, but it should not actually be opened until the
   * server end accepts the connection.
   */
  [clientInput open];
  PASS_EQUAL(statusString([clientInput streamStatus]),
    statusString(NSStreamStatusOpening),
    "after input open, client input is opening")
  PASS_EQUAL(statusString([clientOutput streamStatus]),
    statusString(NSStreamStatusNotOpen),
    "after input open, client output is still not open")

  [clientInput open];
  PASS_EQUAL(statusString([clientInput streamStatus]),
    statusString(NSStreamStatusOpening),
    "after input re-open, client input is opening")
  PASS_EQUAL(statusString([clientOutput streamStatus]),
    statusString(NSStreamStatusNotOpen),
    "after input re-open, client output is still not open")

  /* Start the serve thread and wait a short while for it to accept the
   * connection from the clinet, allowing the open to complete.
   */
  [server start];
  [NSThread sleepForTimeInterval: 0.1];

  /* NB. It seems that the open completes even though the runloop in this
   * thread has not run.  So either the -streamStatus method must implicitly
   * check for completion of the connection attempt or another thread must
   * be handling it and updating the status.
   */
  PASS_EQUAL(statusString([clientInput streamStatus]),
    statusString(NSStreamStatusOpen),
    "after delay, client input is open")
  PASS_EQUAL(statusString([clientOutput streamStatus]),
    statusString(NSStreamStatusNotOpen),
    "after delay, client output is still not open")
  PASS(NO == [clientInput hasBytesAvailable],
    "after open, client input does not have bytes available")


  [clientOutput open];
  PASS_EQUAL(statusString([clientOutput streamStatus]),
    statusString(NSStreamStatusOpen),
    "after output open, client output is now open")
  PASS_EQUAL(statusString([clientInput streamStatus]),
    statusString(NSStreamStatusOpen),
    "after output open, client input is still open")
  PASS([clientOutput hasSpaceAvailable],
    "after open, client output has space available")

  [server end];

  NSLog(@"In: %@", [Logger logsFor: clientInput]);
  NSLog(@"Out: %@", [Logger logsFor: clientOutput]);
  [Logger remove: clientInput];
  [Logger remove: clientOutput];
  END_SET("NSStream connect opening input and then output")

  [server release];
  return 0;
}
