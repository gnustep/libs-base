#import <Foundation/Foundation.h>

#if defined(__OBJC__) && defined(__clang__) && defined(_MSC_VER)
id __work_around_clang_bug3 = @"__unused__";
#endif

/* Not run under MSVC, for the same reason as simpleTaskTests.m. */
#if GS_HAVE_NSURLSESSION && !defined(_MSC_VER)

#import "Helpers/HTTPServer.h"
#import "Testing.h"

/* The delegate here implements only the methods which take no completion
 * handler, and answers them by messaging the task.  Nothing in this file
 * sends a delegate method a block.
 */

static NSInteger	testTimeOut = 30;

@interface PortableDelegate : NSObject
{
@public
  NSInteger	 redirectCount;
  NSInteger	 responseCount;
  NSInteger	 completeCount;
  NSMutableData *received;
  NSError	*completionError;
  BOOL		 refuseRedirect;
  BOOL		 cancelResponse;
}
@end

@implementation PortableDelegate

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      received = [[NSMutableData alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(received);
  RELEASE(completionError);
  [super dealloc];
}

- (void) URLSession: (NSURLSession *)session
	       task: (NSURLSessionTask *)task
     willRedirectToResponse: (NSHTTPURLResponse *)response
	 newRequest: (NSURLRequest *)request
{
  redirectCount += 1;
  if (refuseRedirect)
    {
      [task resumeWithRedirectRequest: nil];
    }
  else
    {
      [task resumeWithRedirectRequest: request];
    }
}

- (void) URLSession: (NSURLSession *)session
	   dataTask: (NSURLSessionDataTask *)dataTask
 didReceiveResponse: (NSURLResponse *)response
{
  responseCount += 1;
  if (cancelResponse)
    {
      [dataTask resumeWithResponseDisposition: NSURLSessionResponseCancel];
    }
  else
    {
      [dataTask resumeWithResponseDisposition: NSURLSessionResponseAllow];
    }
}

- (void) URLSession: (NSURLSession *)session
	   dataTask: (NSURLSessionDataTask *)dataTask
     didReceiveData: (NSData *)data
{
  [received appendData: data];
}

- (void) URLSession: (NSURLSession *)session
	       task: (NSURLSessionTask *)task
didCompleteWithError: (NSError *)error
{
  ASSIGN(completionError, error);
  completeCount += 1;
}

@end

static NSArray *
buildRoutes(Class routeClass, NSURL *baseURL)
{
  Route		*ok;
  Route		*redirect;
  NSString	*redirectText;

  ok = [routeClass routeWithURL: [NSURL URLWithString: @"/contentOK"]
			 method: @"GET"
		       response:
    [@"HTTP/1.1 200 OK\r\nContent-Length: 12\r\n\r\nHello World!"
      dataUsingEncoding: NSASCIIStringEncoding]];

  redirectText = [NSString stringWithFormat:
    @"HTTP/1.1 307 Temporary Redirect\r\nLocation: %@\r\n"
    @"Content-Length: 0\r\n\r\n",
    [baseURL URLByAppendingPathComponent: @"contentOK"]];
  redirect = [routeClass routeWithURL: [NSURL URLWithString: @"/redirectToOK"]
			       method: @"GET"
			     response:
    [redirectText dataUsingEncoding: NSASCIIStringEncoding]];

  return [NSArray arrayWithObjects: ok, redirect, nil];
}

/* Run the run loop until the delegate has reported a completion, or the
 * timeout expires.  Written without a block so that this file needs none. */
static void
waitForCompletion(PortableDelegate *mgr)
{
  NSDate	*end;

  end = [NSDate dateWithTimeIntervalSinceNow: testTimeOut];
  while (mgr->completeCount == 0 && [end timeIntervalSinceNow] > 0.0)
    {
      [[NSRunLoop currentRunLoop]
	runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
}

static NSURLSession *
sessionFor(PortableDelegate *mgr, NSOperationQueue *queue)
{
  return [NSURLSession
    sessionWithConfiguration: [NSURLSessionConfiguration
      defaultSessionConfiguration]
		    delegate: (id)mgr
	       delegateQueue: queue];
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  HTTPServer		*server;
  NSOperationQueue	*queue;
  NSURL			*baseURL;
  NSBundle		*bundle;
  NSString		*helperPath;
  Class			 httpServerClass;
  Class			 routeClass;

  /* The helpers live in a bundle loaded at run time, so the classes are
   * looked up rather than linked. */
  helperPath = [[[NSFileManager defaultManager] currentDirectoryPath]
    stringByAppendingString: @"/Helpers/HTTPServer.bundle"];
  bundle = [NSBundle bundleWithPath: helperPath];
  if (![bundle load])
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"failed to load HTTPServer.bundle"];
    }
  httpServerClass = [bundle principalClass];
  routeClass = [bundle classNamed: @"Route"];

  server = [[httpServerClass alloc] initWithPort: 0 routes: nil];
  queue = [[NSOperationQueue alloc] init];
  [queue setMaxConcurrentOperationCount: 1];

  baseURL = [NSURL URLWithString:
    [NSString stringWithFormat: @"http://127.0.0.1:%ld", (long)[server port]]];
  [server setRoutes: buildRoutes(routeClass, baseURL)];
  [server resume];

  START_SET("redirect answered through the task")
    PortableDelegate	*mgr = AUTORELEASE([PortableDelegate new]);
    NSURLSession	*session = sessionFor(mgr, queue);
    NSURLSessionDataTask *task;
    NSString		*body;

    task = [session dataTaskWithURL:
      [baseURL URLByAppendingPathComponent: @"redirectToOK"]];
    [task resume];
    waitForCompletion(mgr);

    PASS(1 == mgr->redirectCount,
      "the handler-less redirect method is sent once");
    PASS(1 == mgr->completeCount, "the task completes");
    PASS(nil == mgr->completionError, "the redirected transfer has no error");
    body = AUTORELEASE([[NSString alloc] initWithData: mgr->received
					     encoding: NSASCIIStringEncoding]);
    PASS_EQUAL(body, @"Hello World!",
      "resumeWithRedirectRequest: follows the redirect and the body arrives");
    [session invalidateAndCancel];
  END_SET("redirect answered through the task")

  START_SET("redirect refused through the task")
    PortableDelegate	*mgr = AUTORELEASE([PortableDelegate new]);
    NSURLSession	*session;
    NSURLSessionDataTask *task;

    mgr->refuseRedirect = YES;
    session = sessionFor(mgr, queue);
    task = [session dataTaskWithURL:
      [baseURL URLByAppendingPathComponent: @"redirectToOK"]];
    [task resume];
    waitForCompletion(mgr);

    PASS(1 == mgr->redirectCount, "the redirect method is sent once");
    PASS(1 == mgr->completeCount, "the refused task completes");
    PASS(0 == [mgr->received length],
      "resumeWithRedirectRequest: nil delivers no body");
    [session invalidateAndCancel];
  END_SET("redirect refused through the task")

  START_SET("response disposition answered through the task")
    PortableDelegate	*mgr = AUTORELEASE([PortableDelegate new]);
    NSURLSession	*session = sessionFor(mgr, queue);
    NSURLSessionDataTask *task;
    NSString		*body;

    task = [session dataTaskWithURL:
      [baseURL URLByAppendingPathComponent: @"contentOK"]];
    [task resume];
    waitForCompletion(mgr);

    PASS(1 == mgr->responseCount,
      "the handler-less didReceiveResponse method is sent once");
    body = AUTORELEASE([[NSString alloc] initWithData: mgr->received
					     encoding: NSASCIIStringEncoding]);
    PASS_EQUAL(body, @"Hello World!",
      "resumeWithResponseDisposition: allow delivers the body");
    [session invalidateAndCancel];
  END_SET("response disposition answered through the task")

  START_SET("response disposition cancel through the task")
    PortableDelegate	*mgr = AUTORELEASE([PortableDelegate new]);
    NSURLSession	*session;
    NSURLSessionDataTask *task;

    mgr->cancelResponse = YES;
    session = sessionFor(mgr, queue);
    task = [session dataTaskWithURL:
      [baseURL URLByAppendingPathComponent: @"contentOK"]];
    [task resume];
    waitForCompletion(mgr);

    PASS(1 == mgr->responseCount, "didReceiveResponse is sent once");
    PASS(1 == mgr->completeCount, "the cancelled task completes");
    PASS(nil != mgr->completionError,
      "resumeWithResponseDisposition: cancel completes with an error");
    [session invalidateAndCancel];
  END_SET("response disposition cancel through the task")

  START_SET("allTasks and tasksOfKind:")
    PortableDelegate	*mgr = AUTORELEASE([PortableDelegate new]);
    NSURLSession	*session = sessionFor(mgr, queue);
    NSURLSessionDataTask *task;
    NSArray		*all;

    task = [session dataTaskWithURL:
      [baseURL URLByAppendingPathComponent: @"contentOK"]];
    all = [session allTasks];
    PASS(1 == [all count], "allTasks reports the task the session holds");
    PASS([all containsObject: task], "allTasks contains the created task");
    PASS_EQUAL([session tasksOfKind: [NSURLSessionDataTask class]], all,
      "tasksOfKind: matches a data task");
    PASS(0 == [[session tasksOfKind: [NSURLSessionDownloadTask class]] count],
      "tasksOfKind: rejects a class the session holds none of");
    [session invalidateAndCancel];
  END_SET("allTasks and tasksOfKind:")

  [server suspend];
  RELEASE(server);
  RELEASE(queue);
  RELEASE(pool);
  return 0;
}

#else

int
main(int argc, char *argv[])
{
  return 0;
}

#endif /* GS_HAVE_NSURLSESSION */
