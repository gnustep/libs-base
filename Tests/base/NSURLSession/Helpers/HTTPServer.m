#import <Foundation/Foundation.h>

#import <dispatch/dispatch.h>

#ifdef _WIN32
#import <winsock2.h>

#define close(x) closesocket(x)
#else

#import <netinet/in.h>
#import <sys/socket.h>

#endif

#import "HTTPServer.h"

@interface
NSString (ServerAdditions)
- (void)enumerateLinesUsingBlock2:
  (void (^)(NSString *line, NSUInteger lineEndIndex, BOOL *stop))block;
@end

@implementation
NSString (ServerAdditions)

- (void)enumerateLinesUsingBlock2:
  (void (^)(NSString *line, NSUInteger lineEndIndex, BOOL *stop))block
{
  NSUInteger length;
  NSUInteger lineStart, lineEnd, contentsEnd;
  NSRange    currentLocationRange;
  BOOL       stop;

  length = [self length];
  lineStart = lineEnd = contentsEnd = 0;
  stop = NO;

  // Enumerate through the string line by line
  while (lineStart < length && !stop)
    {
      NSString *line;
      NSRange   lineRange;

      currentLocationRange = NSMakeRange(lineStart, 0);
      [self getLineStart:&lineStart
                     end:&lineEnd
             contentsEnd:&contentsEnd
                forRange:currentLocationRange];

      lineRange = NSMakeRange(lineStart, contentsEnd - lineStart);
      line = [self substringWithRange:lineRange];

      // Execute the block
      block(line, lineEnd, &stop);

      // Move to the next line
      lineStart = lineEnd;
    }
}
@end

/* We don't need this once toll-free bridging works */
NSData *
copyDispatchDataToNSData(dispatch_data_t dispatchData)
{
  NSMutableData *mutableData =
    [NSMutableData dataWithCapacity:dispatch_data_get_size(dispatchData)];

  dispatch_data_apply(dispatchData, ^bool(dispatch_data_t region, size_t offset,
                                          const void *buffer, size_t size) {
    [mutableData appendBytes:buffer length:size];
    return true; // Continue iterating
  });

  return [mutableData copy];
}

@implementation Route
{
  NSString           *_method;
  NSURL              *_url;
  RequestHandlerBlock _block;
}
+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                     handler:(RequestHandlerBlock)block
{
  return [[Route alloc] initWithURL:url method:method handler:block];
}

- (instancetype)initWithURL:(NSURL *)url
                     method:(NSString *)method
                    handler:(RequestHandlerBlock)block
{
  self = [super init];

  if (self)
    {
      _url = url;
      _method = method;
      _block = block;
    }

  return self;
}

- (NSString *)method
{
  return _method;
}
- (NSURL *)url
{
  return _url;
}
- (RequestHandlerBlock)block
{
  return _block;
}

- (BOOL)acceptsURL:(NSURL *)url method:(NSString *)method
{
  return [[_url path] isEqualTo:[url path]];
}

@end /* Route */

@implementation HTTPServer
{
  _Atomic(BOOL)     _stop;
  int               _socket;
  NSInteger         _port;
  NSArray<Route *> *_routes;
  dispatch_queue_t  _queue;
  dispatch_queue_t  _acceptQueue;
}

- initWithPort:(NSInteger)port routes:(NSArray<Route *> *)routes
{
  self = [super init];
  if (!self)
    {
      return nil;
    }

#ifdef _WIN32
  WSADATA wsaData;

  // Initialise WinSock2 API
  if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0)
    {
      NSLog(@"Error Creating Socket: %d", WSAGetLastError());
      return nil;
    }
#endif

  _stop = YES;
  _socket = socket(AF_INET, SOCK_STREAM, 0);
  if (_socket == -1)
    {
      NSLog(@"Error creating socket %s", strerror(errno));
      return nil;
    }

  _routes = [routes copy];

  struct sockaddr_in serverAddr;
  NSUInteger         addrLen = sizeof(struct sockaddr_in);
  serverAddr.sin_family = AF_INET;
  serverAddr.sin_port = NSSwapHostShortToBig(port);
  serverAddr.sin_addr.s_addr = INADDR_ANY;

  int rc;
  int yes = 1;
  rc = setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
  if (rc == -1)
    {
      NSLog(@"Error setting socket options %s", strerror(errno));
      return nil;
    }

  rc = bind(_socket, (struct sockaddr *) &serverAddr, sizeof(struct sockaddr));
  if (rc < 0)
    {
      NSLog(@"Error binding to socket %s", strerror(errno));
      return nil;
    }

  // Get Port Number
  if (getsockname(_socket, (struct sockaddr *) &serverAddr, &addrLen) == -1)
    {
      NSLog(@"Error getting socket name %s", strerror(errno));
      return nil;
    }
  _port = NSSwapBigShortToHost(serverAddr.sin_port);

  rc = listen(_socket, 20);
  if (rc < 0)
    {
      NSLog(@"Error listening on socket %s", strerror(errno));
      return nil;
    }

  _queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  _acceptQueue = dispatch_queue_create("org.gnustep.HTTPServer.AcceptQueue",
                                       DISPATCH_QUEUE_CONCURRENT);

  return self;
}

- (void)acceptConnection
{
  struct sockaddr_in clientAddr;
  dispatch_io_t      ioChannel;
  NSUInteger         sin_size;
  int                clientSocket;

  sin_size = sizeof(struct sockaddr_in);
  clientSocket = accept(_socket, (struct sockaddr *) &clientAddr, &sin_size);
  if (clientSocket < 0)
    {
      NSLog(@"Error accepting connection %s", strerror(errno));
      return;
    }

  ioChannel
    = dispatch_io_create(DISPATCH_IO_STREAM, clientSocket, _queue,
                         ^(int error) {
                           close(clientSocket);

                           if (error)
                             {
                               NSLog(@"Error creating dispatch I/O channel %s",
                                     strerror(error));
                               return;
                             }
                         });

  dispatch_io_set_low_water(ioChannel, 1);

  dispatch_io_read(ioChannel, 0, SIZE_MAX, _queue,
                   ^(bool done, dispatch_data_t data, int error) {
                     if (error)
                       {
                         NSLog(@"Error reading data %s", strerror(error));
                         dispatch_io_close(ioChannel, DISPATCH_IO_STOP);
                         return;
                       }
                     if (data && dispatch_data_get_size(data) != 0)
                       {
                         [self handleConnectionData:data
                                          forSocket:clientSocket];
                       }
                     if (done)
                       {
                         dispatch_io_close(ioChannel, DISPATCH_IO_STOP);
                       }
                   });
}

- (void)handleConnectionData:(dispatch_data_t)data forSocket:(int)sock
{
  NSData    *reqData;
  NSString  *reqString;
  NSRange    bodyRange;
  NSString  *method, *url, *version;
  NSURL     *requestURL;
  NSScanner *scanner;
  Route     *selectedRoute = nil;

  __block NSString            *firstLine = nil;
  __block NSMutableURLRequest *request = [NSMutableURLRequest new];
  __block NSUInteger           headerEndIndex = 1;

  reqData = copyDispatchDataToNSData(data);
  reqString = [[NSString alloc] initWithData:reqData
                                    encoding:NSUTF8StringEncoding];

  /*
   *  generic-message = Request-Line
   *                    *(message-header CRLF)
   *                    CRLF
   *                    [ message-body ]
   * Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
   */
  [reqString enumerateLinesUsingBlock2:^(NSString  *line,
                                         NSUInteger lineEndIndex, BOOL *stop) {
    NSRange         range;
    NSString       *key, *value;
    NSCharacterSet *set;

    set = [NSCharacterSet whitespaceCharacterSet];

    /* Parse Request Line */
    if (nil == firstLine)
      {
        firstLine = [line stringByTrimmingCharactersInSet:set];
        return;
      }

    /* Reached end of message header. Stop. */
    if ([line length] == 0)
      {
        *stop = YES;
        headerEndIndex = lineEndIndex;
      }

    range = [line rangeOfString:@":"];
    /* Ignore this line */
    if (NSNotFound == range.location)
      {
        return;
      }

    key = [[line substringToIndex:range.location]
      stringByTrimmingCharactersInSet:set];
    value = [[line substringFromIndex:range.location + 1]
      stringByTrimmingCharactersInSet:set];

    [request addValue:value forHTTPHeaderField:key];
  }];

  /* Calculate remaining body range */
  bodyRange = NSMakeRange(headerEndIndex, [reqData length] - headerEndIndex);
  reqData = [reqData subdataWithRange:bodyRange];

  /* Parse Request Line */
  scanner = [NSScanner scannerWithString:firstLine];
  [scanner scanUpToString:@" " intoString:&method];
  [scanner scanUpToString:@" " intoString:&url];
  [scanner scanUpToString:@" " intoString:&version];

  requestURL = [NSURL URLWithString:url];

  [request setURL:requestURL];
  [request setHTTPMethod:method];
  [request setHTTPBody:reqData];

  for (Route *r in _routes)
    {
      if ([r acceptsURL:requestURL method:method])
        {
          selectedRoute = r;
          break;
        }
    }

  NSData *responseData;
  if (selectedRoute)
    {
      responseData = [selectedRoute block]([request copy]);
    }
  else
    {
      responseData = [@"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        dataUsingEncoding:NSASCIIStringEncoding];
    }

  send(sock, [responseData bytes], [responseData length], 0);
}

- (void)setRoutes:(NSArray<Route *> *)routes
{
  _routes = [routes copy];
}

- (NSInteger)port
{
  return _port;
}

- (void)resume
{
  if (_stop)
    {
      _stop = NO;
      dispatch_async(_acceptQueue, ^{
        while (!_stop)
          {
            [self acceptConnection];
          }
      });
    }
}
- (void)suspend
{
  _stop = YES;
}

- (void)dealloc
{
#ifndef __APPLE__
  dispatch_release(_acceptQueue);
#endif

  close(_socket);
#ifdef _WIN32
  WSACleanup();
#endif
}

@end
