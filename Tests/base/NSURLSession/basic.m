#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

#import "delegate.g"

int main()
{
  START_SET("NSURLSession basic")

  NSURLSessionConfiguration     *defaultConfigObject;
  NSURLSession                  *defaultSession;
  NSURLSessionDataTask          *dataTask;
  NSMutableURLRequest           *urlRequest;
  NSURL                         *url;
  NSOperationQueue              *mainQueue;
  NSString                      *params;
  MyDelegate                    *object;

  object = AUTORELEASE([MyDelegate new]);
  mainQueue = [NSOperationQueue mainQueue];
  defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
  defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject
                                                 delegate: object
                                            delegateQueue: mainQueue];
  url = [NSURL URLWithString:
    @"http://hayageek.com/examples/jquery/ajax-post/ajax-post.php"];
  params = @"name=Ravi&loc=India&age=31&submit=true";
  urlRequest = [NSMutableURLRequest requestWithURL: url];
  [urlRequest setHTTPMethod: @"POST"];
  [urlRequest setHTTPBody: [params dataUsingEncoding: NSUTF8StringEncoding]];
  if ([urlRequest respondsToSelector: @selector(setDebug:)])
    {
      [urlRequest setDebug: YES];
    }

  dataTask = [defaultSession dataTaskWithRequest: urlRequest];
  [dataTask resume];

  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 60.0];
  while ([object finished] == NO
    && [limit timeIntervalSinceNow] > 0.0)
    {
      ENTER_POOL
      NSDate    *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                               beforeDate: when];
      LEAVE_POOL
    }

  PASS(YES == [object finished], "request completed")
  PASS_EQUAL([object taskError], nil, "request did not error")

  NSString *expect = @"Data from server: {\"name\":\"Ravi\",\"loc\":\"India\",\"age\":\"31\",\"submit\":\"true\"}<br>";
  PASS_EQUAL([object taskText], expect, "request returned text")

  END_SET("NSURLSession basic")
  return 0;
}
