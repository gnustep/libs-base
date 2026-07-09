#import <Foundation/Foundation.h>

#ifdef _WIN32
#import <winsock2.h>
#import <WS2tcpip.h>

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

  struct sockaddr_in	serverAddr;
  socklen_t		addrLen = sizeof(struct sockaddr_in);

  serverAddr.sin_family = AF_INET;
  serverAddr.sin_port = NSSwapHostShortToBig(port);
  serverAddr.sin_addr.s_addr = INADDR_ANY;

  int rc;
  int yes = 1;
  rc = setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes,
    sizeof(int));
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

  return self;
}

/* The accept loop runs on its own thread (see -resume).  It blocks in
 * accept() and hands each accepted connection to its own handler thread, so
 * several connections can be served at once without libdispatch. */
- (void) acceptLoop
{
  while (!_stop)
    {
      @autoreleasepool
        {
          struct sockaddr_in	clientAddr;
          socklen_t      	sin_size = sizeof(struct sockaddr_in);
          int                	clientSocket;

          clientSocket = accept(_socket, (struct sockaddr *) &clientAddr,
            &sin_size);
          if (clientSocket < 0)
            {
              if (_stop)
                {
                  break;
                }
              NSLog(@"Error accepting connection %s", strerror(errno));
              continue;
            }

          [NSThread detachNewThreadSelector: @selector(handleClientSocket:)
                                   toTarget: self
                                 withObject: [NSNumber numberWithInt:
                                   clientSocket]];
        }
    }
}

/* One handler thread per connection: block reading requests and answer them
 * until the peer closes or an error occurs. */
- (void) handleClientSocket: (NSNumber *)clientSocketNumber
{
  int clientSocket = [clientSocketNumber intValue];

  while (!_stop)
    {
      BOOL done = NO;

      @autoreleasepool
        {
          char      buffer[4096];
          NSInteger bytesRead = recv(clientSocket, buffer, sizeof(buffer), 0);

          if (bytesRead > 0)
            {
              NSData *data = [NSData dataWithBytes: buffer length: bytesRead];
              [self handleConnectionData: data forSocket: clientSocket];
            }
          else
            {
              /* 0 means the peer closed the connection; < 0 is an error. */
              if (bytesRead < 0)
                {
                  NSLog(@"Error reading data %s", strerror(errno));
                }
              done = YES;
            }
        }

      if (done)
        {
          break;
        }
    }

  close(clientSocket);
}

- (void)handleConnectionData:(NSData *)reqData forSocket:(int)sock
{
  NSString  *reqString;
  NSRange    bodyRange;
  NSString  *method, *url, *version;
  NSURL     *requestURL;
  NSScanner *scanner;
  Route     *selectedRoute = nil;

  __block NSString            *firstLine = nil;
  __block NSMutableURLRequest *request = [NSMutableURLRequest new];
  __block NSUInteger           headerEndIndex = 1;

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
      [NSThread detachNewThreadSelector: @selector(acceptLoop)
                               toTarget: self
                             withObject: nil];
    }
}
- (void)suspend
{
  _stop = YES;
}

- (void)dealloc
{
  close(_socket);
#ifdef _WIN32
  WSACleanup();
#endif
}

@end
