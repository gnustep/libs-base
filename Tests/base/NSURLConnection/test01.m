/**
 *  The test makes connections to not-listening services.
 *  One for HTTP and one for HTTPS.
 *  The NSURLConnection delegate is supposed to catch an
 *  error in that two cases and sets it's ivars accordingly.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

@interface Delegate : NSObject
{
  BOOL _done;
  NSError *_error;
}
- (void) reset;
- (NSError *) error;
- (BOOL) done;
- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error;
@end

@implementation Delegate

- (void) reset
{
  _done = NO;
  _error = nil;
}

- (NSError *) error
{
  return _error;
}

- (BOOL) done
{
  return _done;
}

- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error
{
  _error = error;
  _done = YES;
}

@end

int main(int argc, char **argv, char **env)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSTimeInterval timing;
  NSTimeInterval duration;

  NSString *urlString;
  NSURLRequest *req;
  Delegate *del;
  
  /* The following test cases depend on the GSInetServerStream
   * class which is completely broken on Windows.
   *
   * See: https://github.com/gnustep/libs-base/issues/266
   *
   * We will mark the test cases as hopeful on Windows.
   */
#if defined(_WIN32)
  NSLog(@"Marking local web server tests as hopeful because GSInetServerStream is broken on Windows");
  testHopeful = YES;
#endif

  duration = 0.0;
  timing = 0.1;
  urlString = @"http://localhost:19750";
  req = [NSURLRequest requestWithURL: [NSURL URLWithString: urlString]];
  del = [[Delegate new] autorelease];
  [NSURLConnection connectionWithRequest: req
				delegate: del];
  while (![del done] && duration < 3.0)
    {
      [[NSRunLoop currentRunLoop]
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: timing]];
      duration += timing;
    }
  PASS([del done], "http test completes");
  PASS([del done] && nil != [del error],
    "connection to dead(not-listening) HTTP service");
  [del reset];

  duration = 0.0;
  urlString = @"https://localhost:19750";
  req = [NSURLRequest requestWithURL: [NSURL URLWithString: urlString]];
  [NSURLConnection connectionWithRequest: req
				delegate: del];
  while (![del done] && duration < 3.0)
    {
      [[NSRunLoop currentRunLoop]
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: timing]];
      duration += timing;
    }
  PASS([del done], "https test completes");
  PASS([del done] && nil != [del error],
    "connection to dead(not-listening) HTTPS service");
  [del reset];

  [arp release]; arp = nil;

#if defined(_WIN32)
  testHopeful = NO;
#endif

  return 0;
}
