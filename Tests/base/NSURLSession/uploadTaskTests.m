#include "Foundation/NSDate.h"
#import <Foundation/Foundation.h>
#include <Foundation/NSProgress.h>
#include <Foundation/NSString.h>

#if defined(__OBJC__) && defined(__clang__) && defined(_MSC_VER)
id __work_around_clang_bug2 = @"__unused__";
#endif

#if GS_HAVE_NSURLSESSION

#import "Helpers/HTTPServer.h"
#import "NSRunLoop+TimeOutAdditions.h"
#import "URLManager.h"
#import "Testing.h"

#if __has_feature(blocks)
DEFINE_BLOCK_TYPE(dataCompletionHandler, void,
  NSData *, NSURLResponse *, NSError *);
#endif

/* Timeout in Seconds */
static NSInteger      testTimeOut = 60;
static NSTimeInterval expectedCountOfTasksToComplete = 0;

/* Accessed in delegate on different thread.
 */
/* Updated under countLock. */
static volatile NSInteger currentCountOfCompletedTasks = 0;
static NSLock            *countLock;

/* Expected Content */
static NSString *largeBodyPath;
static NSData   *largeBodyContent;

/* The large upload route checks the request, so it needs a target rather
 * than a fixed response. */
@interface LargeUploadRoute : NSObject
- (NSData *)responseForRequest:(NSURLRequest *)req;
@end

@implementation LargeUploadRoute
- (NSData *)responseForRequest:(NSURLRequest *)req
{
  PASS_EQUAL([req valueForHTTPHeaderField:@"Request-Key"],
             @"Request-Value",
             "Request contains user-specific header line");
  PASS_EQUAL([req valueForHTTPHeaderField:@"Content-Type"],
             @"text/plain",
             "Request contains the correct Content-Type");
  PASS_EQUAL([req HTTPBody], largeBodyContent, "HTTPBody is correct");

  return [@"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nHeader-Key: "
          @"Header-Value\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
}
@end

static LargeUploadRoute *largeUploadRoute;

static NSArray *
createRoutes(Class routeClass)
{
  Route *routeOKWithContent;
  Route *routeLargeUpload;
  NSURL *routeOKWithContentURL;
  NSURL *routeLargeUploadURL;

  routeOKWithContentURL = [NSURL URLWithString:@"/smallUploadOK"];
  routeLargeUploadURL = [NSURL URLWithString:@"/largeUploadOK"];

  routeOKWithContent = [routeClass
    routeWithURL:routeOKWithContentURL
          method:@"POST"
        response:
      [@"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nHeader-Key: "
       @"Header-Value\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

  largeUploadRoute = [LargeUploadRoute new];
  routeLargeUpload = [routeClass
    routeWithURL:routeLargeUploadURL
          method:@"POST"
          target:largeUploadRoute
        selector:@selector(responseForRequest:)];

  return [NSArray arrayWithObjects:
    routeOKWithContent, routeLargeUpload, nil];
}

#if __has_feature(blocks)
static void
testLargeUploadWithBlock(NSURL *baseURL)
{
  NSURLSession           *session;
  NSURLSessionDataTask   *dataTask;
  NSURLSessionUploadTask *uploadTask;
  NSMutableURLRequest    *request;
  NSURL                  *url;
  dataCompletionHandler   handler;

  expectedCountOfTasksToComplete += 2;

  url = [baseURL URLByAppendingPathComponent:@"largeUploadOK"];
  session = [NSURLSession sharedSession];
  request = [NSMutableURLRequest requestWithURL:url];

  [request setHTTPBody:largeBodyContent];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"Request-Value" forHTTPHeaderField:@"Request-Key"];
  [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];

  /* The completion handler for the two requests */
  handler = ^(NSData *data, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    PASS([data length] == 0, "Received empty data object");
    PASS(nil != response, "Response is not nil");
    PASS([response isKindOfClass:[NSHTTPURLResponse class]],
         "Response is a NSHTTPURLResponse");
    PASS(nil == error, "Error is nil");

    PASS_EQUAL([[httpResponse allHeaderFields] objectForKey:@"Header-Key"],
               @"Header-Value", "Response contains custom header line");

    [countLock lock];
    currentCountOfCompletedTasks += 1;
    [countLock unlock];
  };

  dataTask = [session dataTaskWithRequest:request completionHandler:handler];
  uploadTask = [session uploadTaskWithRequest:request
                                     fromData:largeBodyContent
                            completionHandler:handler];

  [dataTask resume];
  [uploadTask resume];
}
#endif

int
main(int argc, char *argv[])
{
  {
  CREATE_AUTORELEASE_POOL(arp);
    NSBundle         *bundle;
    NSString         *helperPath;
    NSString         *currentDirectory;
    NSURL            *baseURL;
    NSFileManager    *fm;
    NSArray          *routes;
    HTTPServer       *server;
    NSDate           *deadline;

    Class httpServerClass;
    Class routeClass;

    fm = [NSFileManager defaultManager];
    currentDirectory = [fm currentDirectoryPath];
    helperPath =
      [currentDirectory stringByAppendingString:@"/Helpers/HTTPServer.bundle"];
    countLock = [[NSLock alloc] init];

    bundle = [NSBundle bundleWithPath:helperPath];
    if (![bundle load])
      {
        [NSException raise:NSInternalInconsistencyException
                    format:@"failed to load HTTPServer.bundle"];
      }

    /* Load Test Data */
    largeBodyPath =
      [currentDirectory stringByAppendingString:@"/Resources/largeBody.txt"];
    largeBodyContent = [NSData dataWithContentsOfFile:largeBodyPath];
    PASS(nil != largeBodyContent, "can load %s", [largeBodyPath UTF8String]);

    httpServerClass = [bundle principalClass];
    routeClass = [bundle classNamed:@"Route"];
    routes = createRoutes(routeClass);
    server = [[httpServerClass alloc] initWithPort:0 routes:routes];
    if (!server)
      {
        [NSException raise:NSInternalInconsistencyException
                    format:@"failed to create HTTPServer"];
      }

    baseURL =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%ld",
                                                      [server port]]];

    NSLog(@"Server started with baseURL: %@", baseURL);

    [server resume];

    /* Call Test Functions here! */
#if __has_feature(blocks)
    testLargeUploadWithBlock(baseURL);
#endif

    deadline = [NSDate dateWithTimeIntervalSinceNow:testTimeOut];
    while (expectedCountOfTasksToComplete != currentCountOfCompletedTasks
      && [[NSRunLoop currentRunLoop] runSliceUntil:deadline])
      ;

    [server suspend];
    PASS(expectedCountOfTasksToComplete == currentCountOfCompletedTasks,
         "All transfers were completed before a timeout occurred");

    [server release];
    [countLock release];
  DESTROY(arp);
}
  return 0;
}

#else

int
main(int argc, char *argv[])
{
  return 0;
}

#endif