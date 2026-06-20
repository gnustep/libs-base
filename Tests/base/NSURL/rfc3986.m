#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"


int main()
{
  START_SET("rfc3986")

  struct {
    NSString	*string;
    NSString	*scheme;
    NSString	*user;
    NSString	*password;
    NSString	*host;
    NSString	*port;
    NSString	*path;
    NSString	*query;
    NSString	*fragment;
  } vector[] = {

    { @"//www.w3.org",                          // Just an authority (host name)
      nil, nil, nil, @"www.w3.org", nil,
      @"", nil, nil},
    { @"just/a/relative/path",                  // Just a path
      nil, nil, nil, nil, nil,
      @"just/a/relative/path", nil, nil},
    { @"file:///tmp/rfc1808.txt",
      @"file", nil, nil, @"", nil,
      @"/tmp/rfc1808.txt", nil, nil},
    { @"ftp://ftp.is.co.za/rfc/rfc1808.txt",
      @"ftp", nil, nil, @"ftp.is.co.za", nil,
      @"/rfc/rfc1808.txt", nil, nil},
    { @"http://www.ietf.org/rfc/rfc2396.txt",
      @"http", nil, nil, @"www.ietf.org", nil,
      @"/rfc/rfc2396.txt", nil, nil},
    { @"ldap://[2001:db8::7]/c=GB?objectClass?one",
      @"ldap", nil, nil, @"[2001:db8::7]", nil,
      @"/c=GB", @"objectClass?one", nil},
    { @"mailto:John.Doe@example.com",
      @"mailto", nil, nil, nil, nil,
      @"John.Doe@example.com", nil, nil},
    { @"news:comp.infosystems.www.servers.unix",
      @"news", nil, nil, nil, nil,
      @"comp.infosystems.www.servers.unix", nil, nil},
    { @"tel:+1-816-555-1212",
      @"tel", nil, nil, nil, nil,
      @"+1-816-555-1212", nil, nil},
    { @"telnet://192.0.2.16:80/",
      @"telnet", nil, nil, @"192.0.2.16", @"80",
      @"/", nil, nil},
    { @"urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
      @"urn", nil, nil, nil, nil,
      @"oasis:names:specification:docbook:dtd:xml:4.1.2", nil, nil},

    { @"http://user:password@example.com:80/",
      @"http", @"user", @"password", @"example.com", @"80",
      @"/", nil, nil },
    { @"http://example.com:80/",
      @"http", nil, nil, @"example.com", @"80",
      @"/", nil, nil },
    { @"http://example.com:80?",
      @"http", nil, nil, @"example.com", @"80",
      @"", @"", nil },
    { @"http://example.com",
      @"http", nil, nil, @"example.com", nil,
      @"", nil, nil }

  };
  unsigned	index;

  for (index = 0; index < sizeof(vector)/sizeof(*vector); index++)
    {
      NSURLComponents 	*c;
      const char	*utf8 = [vector[index].string UTF8String];

      c = [NSURLComponents componentsWithString: vector[index].string
		      encodingInvalidCharacters: NO];

      PASS(c != nil,
	"vector[%u] \"%s\" created components instance", index, utf8)

      PASS_EQUAL([c scheme], vector[index].scheme,
	"vector[%u] \"%s\" scheme correct", index, utf8)
      PASS_EQUAL([c percentEncodedUser], vector[index].user,
	"vector[%u] \"%s\" user correct", index, utf8)
      PASS_EQUAL([c percentEncodedPassword], vector[index].password,
	"vector[%u] \"%s\" password correct", index, utf8)
      PASS_EQUAL([c host], vector[index].host,
	"vector[%u] \"%s\" host correct", index, utf8)
      PASS_EQUAL([[c port] description], vector[index].port,
	"vector[%u] \"%s\" port correct", index, utf8)
      PASS_EQUAL([c percentEncodedPath], vector[index].path,
	"vector[%u] \"%s\" path correct", index, utf8)
      PASS_EQUAL([c percentEncodedQuery], vector[index].query,
	"vector[%u] \"%s\" query correct", index, utf8)
      PASS_EQUAL([c percentEncodedFragment], vector[index].fragment,
	"vector[%u] \"%s\" fragment correct", index, utf8)
      PASS_EQUAL([c string], vector[index].string,
	"vector[%u] \"%s\" string correct", index, utf8)
    }

  END_SET("rfc3986")

  return 0;
}
