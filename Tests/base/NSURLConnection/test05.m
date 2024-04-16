/**
 *  Tests for HTTPS without authorization.
 *  (must be the same as test04.m except for the use of HTTPS).
 */
#import <Foundation/Foundation.h>
#import "Helpers/NSURLConnectionTest.h"
#import "Helpers/TestWebServer.h"
#import <Testing.h>

int main(int argc, char **argv, char **env)
{

#if !defined(HAVE_GNUTLS)
testHopeful = YES;
#endif

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

  if (loaded)
    {
      NSDictionary *d;
      Class testClass;
      NSDictionary *refs;
      TestWebServer *server;
      NSURLConnectionTest *testCase;
      BOOL debug = GSDebugSet(@"dflt");

      testClass = [bundle principalClass]; // NSURLConnectionTest

      // the extra dictionary commanding to use HTTPS
      d = [NSDictionary dictionaryWithObjectsAndKeys:
	@"HTTPS", @"Protocol",
	nil];
      // create a shared TestWebServer instance for performance
      server = [[[testClass testWebServerClass] alloc]
	initWithAddress: @"localhost"
	port: @"1231"
	mode: NO
        extra: d];
      [server setDebug: debug];
      [server start: d]; // localhost:1231 HTTPS

      /* Simple GET via HTTPS without authorization with empty response's
       * body and the response's status code 204 (by default)
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      /* the reference set difference (from the default reference set)
       * we expect the flags must not be set because we request a path
       * with no authorization See NSURLConnectionTest.h for details
       * (the key words are 'TestCase' and 'ReferenceFlags')
       */
      refs = [NSDictionary dictionaryWithObjectsAndKeys:
	@"NO", @"GOTUNAUTHORIZED", 
	@"NO", @"AUTHORIZED",        
	@"NO", @"NOTAUTHORIZED",     
	nil];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
	server, @"Instance", // we use the shared TestWebServer instance
	@"/withoutauth", @"Path", // the path commands to use no authorization
	refs, @"ReferenceFlags", // the expected reference set difference
	nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess],
	"HTTPS... no auth...GET https://localhost:1231/withoutauth");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /* Simple GET via HTTPS without authorization with the response's
       * status code 400 and non-empty response's body
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      /* the reference set difference (from the default reference set)
       * we expect the flags must not be set because we request a path
       * with no authorization. See NSURLConnectionTest.h for details
       * (the key words are 'TestCase' and 'ReferenceFlags')
       */
      refs = [NSDictionary dictionaryWithObjectsAndKeys:
	@"NO", @"GOTUNAUTHORIZED", 
	@"NO", @"AUTHORIZED",        
	@"NO", @"NOTAUTHORIZED",     
	nil];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
	server, @"Instance", // we use the shared TestWebServer instance
	@"400/withoutauth", @"Path", // request the handler responding with 400
	@"400", @"StatusCode", // the expected status code
	@"You have issued a request with invalid data", @"Content", // the expected response's body
	refs, @"ReferenceFlags", // the expected reference set difference
	nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "HTTPS... no auth... response 400... GET https://localhost:1231/400/withoutauth");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /*
       *  Simple POST via HTTPS with the response's status code 400 and
       *  non-empty response's body
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      /* the reference set difference (from the default reference set)
       * we expect the flags must not be set because we request a path
       * with no authorization. See NSURLConnectionTest.h for details
       * (the key words are 'TestCase' and 'ReferenceFlags')
       */
      refs = [NSDictionary dictionaryWithObjectsAndKeys:
	@"NO", @"GOTUNAUTHORIZED", 
	@"NO", @"AUTHORIZED",        
	@"NO", @"NOTAUTHORIZED",     
	nil];
      // the extra dictionary with test case's parameters
      d = [NSDictionary dictionaryWithObjectsAndKeys:
	server, @"Instance", // we use the shared TestWebServer instance
	@"400/withoutauth", @"Path", // request the handler responding with 400
	@"400", @"StatusCode", // the expected status code
	@"You have issued a request with invalid data", @"Content", // expected
	@"Some payload", @"Payload", // the custom payload
	@"POST", @"Method",    // use POST
	refs, @"ReferenceFlags", // the expected reference set difference
	nil];
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "HTTPS... no auth... payload... response 400 .... POST https://localhost:1231/400/withoutauth");
      [testCase tearDownTest: d];
      DESTROY(testCase);

      /* Tests redirecting... it uses an auxilliary TestWebServer instance
       * and proceeds in two stages. The first one is to get the status
       * code 301 and go to the URL given in the response's header 'Location'.
       * The second stage is a simple GET on the given URL with the status
       * code 204 and empty response's body.
       */
      testCase = [testClass new];
      [testCase setDebug: debug];
      /* the reference set difference (from the default reference set)
       * we expect the flags must not be set because we request a path
       * with no authorization. See NSURLConnectionTest.h for details
       * (the key words are 'TestCase' and 'ReferenceFlags')
       */
      refs = [NSDictionary dictionaryWithObjectsAndKeys:
			     @"NO", @"GOTUNAUTHORIZED", 
			   @"NO", @"AUTHORIZED",        
			   @"NO", @"NOTAUTHORIZED",     
			   @"YES", @"GOTREDIRECT",
			   nil];
      /* the extra dictionary with test case's parameters
       */
      d = [NSDictionary dictionaryWithObjectsAndKeys:
	server, @"Instance", // we use the shared TestWebServer instance
	@"/301/withoutauth", @"Path", // request a redirect
	@"/withoutauth", @"RedirectPath", // the URL's path of redirecting 
	@"YES", @"IsAuxilliary", // start an auxilliary TestWebServer instance
        @"1238", @"AuxPort",   // the port of the auxilliary instance			
	refs, @"ReferenceFlags", // the expected reference set difference
	nil];      
      [testCase setUpTest: d];
      [testCase startTest: d];
      PASS([testCase isSuccess], "HTTPS... no auth... redirecting... GET https://localhost:1231/301/withoutauth");
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

#if !defined(HAVE_GNUTLS)
testHopeful = NO;
#endif

  return 0;
}
