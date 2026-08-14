#import <Foundation/Foundation.h>

#ifdef _WIN32
#import <winsock2.h>
#import <WS2tcpip.h>

#define close(x) closesocket(x)
#else

#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#endif

#import "HTTPServer.h"
#import "GNUstepBase/GNUstep.h"

/* Line by line over an ASCII header block.  On entry *lineStart is where to
 * read from; on return it is where the next line begins and *lineEnd is the
 * index just past the line just read.  Returns nil once the string is spent.
 */
static NSString *
nextLine(NSString *s, NSUInteger *lineStart, NSUInteger *lineEnd)
{
  NSUInteger	start = *lineStart;
  NSUInteger	end = 0;
  NSUInteger	contentsEnd = 0;

  if (start >= [s length])
    {
      return nil;
    }
  [s getLineStart:&start
              end:&end
      contentsEnd:&contentsEnd
         forRange:NSMakeRange(start, 0)];

  *lineStart = end;
  *lineEnd = end;
  return [s substringWithRange:NSMakeRange(start, contentsEnd - start)];
}

/* The length of the complete request at the front of data, or 0 when the whole
 * request has not arrived yet.  A request is complete once the blank line
 * ending the headers has been read along with as many body bytes as
 * Content-Length asks for.  A request without Content-Length has no body.
 */
static NSUInteger
requestLength(NSData *data)
{
  NSRange     end;
  NSString   *headers;
  NSString   *line;
  NSUInteger  bodyStart;
  NSUInteger  contentLength = 0;
  NSUInteger  lineStart = 0;
  NSUInteger  lineEnd = 0;

  end = [data rangeOfData:[NSData dataWithBytes:"\r\n\r\n" length:4]
                  options:0
                    range:NSMakeRange(0, [data length])];
  if (NSNotFound == end.location)
    {
      return 0;
    }
  bodyStart = NSMaxRange(end);

  headers = [[NSString alloc]
    initWithData:[data subdataWithRange:NSMakeRange(0, end.location)]
        encoding:NSASCIIStringEncoding];

  while ((line = nextLine(headers, &lineStart, &lineEnd)) != nil)
    {
      NSRange range = [line rangeOfString:@":"];

      if (NSNotFound != range.location
          && NSOrderedSame == [[line substringToIndex:range.location]
               caseInsensitiveCompare:@"Content-Length"])
        {
          contentLength = (NSUInteger)
            [[line substringFromIndex:range.location + 1] integerValue];
          break;
        }
    }

  if ([data length] < bodyStart + contentLength)
    {
      return 0;
    }

  return bodyStart + contentLength;
}

@implementation Route

+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                    response:(NSData *)response
{
  Route *r = [[Route alloc] initWithURL:url method:method];

  ASSIGN(r->_response, response);
  return AUTORELEASE(r);
}

+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                      target:(id)target
                    selector:(SEL)aSelector
{
  Route *r = [[Route alloc] initWithURL:url method:method];

  ASSIGN(r->_target, target);
  r->_selector = aSelector;
  return AUTORELEASE(r);
}

+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                     handler:(RequestHandlerBlock)block
{
  Route *r = [[Route alloc] initWithURL:url method:method];

  r->_block = block;
  return AUTORELEASE(r);
}

- (instancetype)initWithURL:(NSURL *)url
                     method:(NSString *)method
{
  self = [super init];

  if (self)
    {
      ASSIGN(_url, url);
      ASSIGN(_method, method);
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

- (NSData *)responseForRequest:(NSURLRequest *)request
{
  if (nil != _target)
    {
      return [_target performSelector:_selector withObject:request];
    }
  if (nil != _response)
    {
      return _response;
    }
  return CALL_BLOCK_RET(_block, NSData *, request);
}

- (BOOL)acceptsURL:(NSURL *)url method:(NSString *)method
{
  return [[_url path] isEqualTo:[url path]];
}

- (void)dealloc
{
  RELEASE(_url);
  RELEASE(_method);
  RELEASE(_response);
  RELEASE(_target);
  [super dealloc];
}

@end /* Route */

@implementation HTTPServer

- initWithPort:(NSInteger)port routes:(NSArray *)routes
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
      {
  CREATE_AUTORELEASE_POOL(arp);
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
  DESTROY(arp);
}
    }
}

/* One handler thread per connection: block reading requests and answer them
 * until the peer closes or an error occurs. */
- (void) handleClientSocket: (NSNumber *)clientSocketNumber
{
  int            clientSocket = [clientSocketNumber intValue];
  NSMutableData *pending = [NSMutableData data];

  while (!_stop)
    {
      BOOL done = NO;

      {
  CREATE_AUTORELEASE_POOL(arp);
          char      buffer[4096];
          NSInteger bytesRead = recv(clientSocket, buffer, sizeof(buffer), 0);

          if (bytesRead > 0)
            {
              NSUInteger length;

              [pending appendBytes: buffer length: bytesRead];

              /* One read is not one request.  The peer may send the headers
               * and the body in separate segments, and a body larger than the
               * buffer above always arrives in more than one read, so pass a
               * request to the routes only once all of its body is here.
               */
              while ((length = requestLength(pending)) > 0)
                {
                  NSData *data;

                  data = [pending subdataWithRange: NSMakeRange(0, length)];
                  [self handleConnectionData: data forSocket: clientSocket];
                  [pending replaceBytesInRange: NSMakeRange(0, length)
                                     withBytes: NULL
                                        length: 0];
                }
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
  DESTROY(arp);
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

  NSString            *firstLine = nil;
  NSMutableURLRequest *request = [NSMutableURLRequest new];
  NSUInteger           headerEndIndex = 1;
  NSUInteger           lineStart = 0;
  NSUInteger           lineEnd = 0;
  NSString            *line;
  NSCharacterSet      *set = [NSCharacterSet whitespaceCharacterSet];

  reqString = [[NSString alloc] initWithData:reqData
                                    encoding:NSUTF8StringEncoding];

  /*
   *  generic-message = Request-Line
   *                    *(message-header CRLF)
   *                    CRLF
   *                    [ message-body ]
   * Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
   */
  while ((line = nextLine(reqString, &lineStart, &lineEnd)) != nil)
    {
      NSRange   range;
      NSString *key, *value;

      /* Parse Request Line */
      if (nil == firstLine)
        {
          firstLine = [line stringByTrimmingCharactersInSet:set];
          continue;
        }

      /* Reached end of message header. Stop. */
      if ([line length] == 0)
        {
          headerEndIndex = lineEnd;
          break;
        }

      range = [line rangeOfString:@":"];
      /* Ignore this line */
      if (NSNotFound == range.location)
        {
          continue;
        }

      key = [[line substringToIndex:range.location]
        stringByTrimmingCharactersInSet:set];
      value = [[line substringFromIndex:range.location + 1]
        stringByTrimmingCharactersInSet:set];

      [request addValue:value forHTTPHeaderField:key];
    }

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
      responseData = [selectedRoute responseForRequest:[request copy]];
    }
  else
    {
      responseData = [@"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        dataUsingEncoding:NSASCIIStringEncoding];
    }

  send(sock, [responseData bytes], [responseData length], 0);
}

- (void)setRoutes:(NSArray *)routes
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
  RELEASE(_routes);
  close(_socket);
#ifdef _WIN32
  WSACleanup();
#endif
}

@end
