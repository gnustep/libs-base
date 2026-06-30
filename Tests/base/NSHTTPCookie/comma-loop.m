#if	defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import "Testing.h"

#if	defined(__unix__) || defined(__APPLE__)
#include <unistd.h>

int main()
{
  START_SET("NSHTTPCookie Set-Cookie comma scan terminates")
  ENTER_POOL
  NSURL		*url = [NSURL URLWithString: @"http://example.com/"];
  NSDictionary	*headers = [NSDictionary dictionaryWithObject: @"a=b, cd"
						       forKey: @"Set-Cookie"];
  NSArray	*cookies;
  NSHTTPCookie	*cookie;

  /* The comma-lookahead in GSCookieStrings used to run off the end of the
   * buffer (looping ~2^32 times) for a Set-Cookie that ends in token
   * characters after a comma with no '='.  A watchdog alarm bounds the test
   * in case the scan fails to terminate; the value assertions catch the
   * mis-parse the run-away scan produced. */
  alarm(30);
  cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: headers forURL: url];
  alarm(0);

  PASS([cookies count] == 1,
    "a comma not followed by a name=value pair is not a cookie separator")
  cookie = [cookies count] ? [cookies objectAtIndex: 0] : nil;
  PASS_EQUAL([cookie name], @"a", "the single cookie is parsed correctly")
  LEAVE_POOL
  END_SET("NSHTTPCookie Set-Cookie comma scan terminates")
  return 0;
}
#else
int main()
{
  START_SET("NSHTTPCookie Set-Cookie comma scan terminates")
  SKIP("test needs alarm() as a watchdog")
  END_SET("NSHTTPCookie Set-Cookie comma scan terminates")
  return 0;
}
#endif
#else
int main(void)
{
  return 0;
}
#endif
