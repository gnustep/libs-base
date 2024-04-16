/**
 *  Tests for HTTP.
 */
#import <Foundation/Foundation.h>
#import "Helpers/NSURLConnectionTest.h"
#import "Helpers/TestWebServer.h"
#import <Testing.h>

int main(int argc, char **argv, char **env)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSFileManager *fm;
  NSBundle *bundle;
  BOOL loaded;
  NSString *helperPath;

  // load the test suite's classes
  fm = [NSFileManager defaultManager];
  helperPath = [[fm currentDirectoryPath]
		 stringByAppendingString: @"/Helpers/TestConnection.bundle"];
  bundle = [NSBundle bundleWithPath: helperPath];
  loaded = [bundle load];

  if(loaded)
    {
      NSDictionary *d;
      Class testClass;
      NSDictionary *refs;
      TestWebServer *server;
      NSURLConnectionTest *testCase;
      BOOL debug = GSDebugSet(@"dflt");
  
      testClass = [bundle principalClass]; // NSURLConnectionTest

      // create a shared TestWebServer instance for performance
      server = [[testClass testWebServerClass] new];
      [server setDebug: debug];
      [server start: nil]; // localhost:1234 HTTP

      /*
       *  Simple GET via HTTP with empty response's body and
       *  the response's status code 204 (by default)
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
			  server, @"Instance", // we use the shared TestWebServer instance
			nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "GET http://localhost:1234/");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /*
       *  Simple GET via HTTP with the response's status code 400 and
       *  non-empty response's body
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
			  server, @"Instance", // we use the shared TestWebServer instance
			@"400", @"Path",       // request the handler responding with 400
			@"400", @"StatusCode", // the expected status code
			@"You have issued a request with invalid data", @"Content", // the expected response's body
			nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "response 400 .... GET http://localhost:1234/400");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /*
       *  Simple POST via HTTP with the response's status code 400 and
       *  non-empty response's body
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
			  server, @"Instance", // we use the shared TestWebServer instance
			@"400", @"Path",       // request the handler responding with 400
			@"400", @"StatusCode", // the expected status code
			@"You have issued a request with invalid data", @"Content", // the expected response's body
			@"Some payload", @"Payload", // the custom payload
			@"POST", @"Method",    // use POST
			nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "payload... response 400 .... POST http://localhost:1234/400");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /*
       *  Tests redirecting... it uses an auxilliary TestWebServer instance and proceeds
       *  in two stages. The first one is to get the status code 301 and go to the URL
       *  given in the response's header 'Location'. The second stage is a simple GET on
       *  the given URL with the status code 204 and empty response's body.
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      // the reference set difference (from the default reference set) we expect
      refs = [NSDictionary dictionaryWithObjectsAndKeys:
			     @"YES", @"GOTREDIRECT",
			    nil];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
			  server, @"Instance", // we use the shared TestWebServer instance
			@"/301", @"Path",      // request the handler responding with a redirect
			@"/", @"RedirectPath", // the URL's path of redirecting
			@"YES", @"IsAuxilliary", // start an auxilliary TestWebServer instance
			refs, @"ReferenceFlags", // the expected reference set difference
			nil];      
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "redirecting... GET http://localhost:1234/301");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      // cleaning
      [server stop];
      DESTROY(server);
    }
  else
    {
      // no classes no tests
      [NSException raise: NSInternalInconsistencyException
		  format: @"can't load bundle TestConnection"];
    }

  DESTROY(arp);
  
  return 0;
}
