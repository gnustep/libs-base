#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSDictionary  *dict;
  NSArray *cookies;
  NSURL *url;
  NSHTTPCookie  *cookie;
  
  TEST_FOR_CLASS(@"NSHTTPCookie", [NSHTTPCookie alloc],
    "NSHTTPCookie +alloc returns an NSHTTPCookie");
  
  dict = [NSDictionary dictionaryWithObjectsAndKeys: @"myname", @"Name", 
  	@"myvalue", @"Value", @"/", @"Path", @".test.com", @"Domain", nil];
  cookie = [NSHTTPCookie cookieWithProperties: dict];
  TEST_FOR_CLASS(@"NSHTTPCookie", cookie,
    "NSHTTPCookie +cookieWithProperties: returns an NSHTTPCookie");
  
  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    @"myname", NSHTTPCookieName,
    @"myvalue", NSHTTPCookieValue,
    @"/mypath", NSHTTPCookiePath,
    @".test.com", NSHTTPCookieDomain,
    @"http://www.origin.org", NSHTTPCookieOriginURL,
    @"0", NSHTTPCookieVersion,
    @"FALSE", NSHTTPCookieDiscard,
    @"FALSE", NSHTTPCookieSecure,
    nil];
  cookie = [NSHTTPCookie cookieWithProperties: dict];
  TEST_FOR_CLASS(@"NSHTTPCookie", cookie,
    "NSHTTPCookie +cookieWithProperties: works with all constants");
  
  dict = [NSDictionary dictionaryWithObjectsAndKeys: @"myname", @"Name", 
  	@"myvalue", @"Value", @".test.com", @"Domain", nil];
  cookie = [NSHTTPCookie cookieWithProperties: dict];
  PASS(cookie == nil, "cookie without path returns nil");

  dict = [NSDictionary dictionaryWithObject:
    @"S=calendar=R7tjDKqNB5L8YTZSvf29Bg;Expires=Wed, 09-Mar-2011 23:00:35 GMT"
 	                             forKey: @"Set-Cookie"];

  url = [NSURL URLWithString: @"http://www.google.com/calendar/feeds/default/"];
  cookies= [NSHTTPCookie cookiesWithResponseHeaderFields: dict forURL: url];
  TEST_FOR_CLASS(@"NSArray", cookies,
    "NSHTTPCookie +cookiesWithResponseHeaderFields: returns an NSArray");
  PASS([cookies count ] == 1, "cookies array contains a cookie");
  cookie = [cookies objectAtIndex: 0];
  PASS([[cookie name] isEqual: @"S"], "NSHTTPCookie returns proper name");
  PASS([[cookie value] isEqual: @"calendar=R7tjDKqNB5L8YTZSvf29Bg"],
  	   "NSHTTPCookie returns proper value");
  PASS([[cookie domain] isEqual: [url host]], 
  	   "NSHTTPCookie returns proper domain");
  
  dict = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
  PASS_EQUAL([dict objectForKey: @"Cookie"],
    @"S=calendar=R7tjDKqNB5L8YTZSvf29Bg",
    "NSHTTPCookie can generate proper cookie");

  [arp release]; arp = nil;
  return 0;
}
