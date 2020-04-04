#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"


int main()
{
  NSURLComponents *components = nil;

  START_SET("components");

  components = [NSURLComponents componentsWithURL:[NSURL URLWithString:@"https://user:password@some.host.com"] resolvingAgainstBaseURL:NO];
  
  [components setQueryItems: [NSArray arrayWithObjects:
                                        [NSURLQueryItem queryItemWithName:@"lang" value:@"en"],
                                      [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
                                      [NSURLQueryItem queryItemWithName:@"uri" value:[[NSURL URLWithString:@"https://some.url.com/path?param1=one&param2=two"] absoluteString]], nil]];
  // URL
  PASS([[components string] isEqualToString:
                                    @"https://user:password@some.host.com?lang=en&response_type=code&uri=https://some.url.com/path?param1%3Done%26param2%3Dtwo"],
       "URL string is correct");
  
  // encoded...
  PASS([[components percentEncodedQuery] isEqualToString:
                  @"lang=en&response_type=code&uri=https://some.url.com/path?param1%3Done%26param2%3Dtwo"],
       "percentEncodedQuery is correct");
  PASS([[components percentEncodedHost] isEqualToString:
                                          @"some.host.com"],
       "percentEncodedHost is correct");
  PASS([[components percentEncodedUser] isEqualToString:
                                          @"user"],
       "percentEncodedUser is correct");
  PASS([[components percentEncodedPassword] isEqualToString:
                                              @"password"],
       "percentEncodedPassword is correct");
  
  // unencoded...
  PASS([[components query] isEqualToString:
                             @"lang=en&response_type=code&uri=https://some.url.com/path?param1=one&param2=two"],
       "query is correct");
  PASS([[components host] isEqualToString:
                            @"some.host.com"],
       "host is correct");
  PASS([[components user] isEqualToString:
                            @"user"],
       "user is correct");
  PASS([[components password] isEqualToString:
                                @"password"],
       "password is correct");
    

  END_SET("components")

  return 0;
}
