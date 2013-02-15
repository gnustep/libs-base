#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"


int main()
{
  START_SET("test1")
  NSURL *url;

  url = [NSURL URLWithString:
    @"scheme://user:password@host.domain.org:888/path/absfile.htm"];
  url = [NSURL URLWithString:
@"file%20name.htm;param1;param2?something=other&andmore=more#fragments"
    relativeToURL: url];

  PASS_EQUAL([url description],
    @"file%20name.htm;param1;param2?something=other&andmore=more#fragments -- scheme://user:password@host.domain.org:888/path/absfile.htm",
    "description ok");

  PASS_EQUAL([url absoluteString],
    @"scheme://user:password@host.domain.org:888/path/file%20name.htm;param1;param2?something=other&andmore=more#fragments",
    "absolute string ok");

  PASS_EQUAL([[url absoluteURL] description],
    @"scheme://user:password@host.domain.org:888/path/file%20name.htm;param1;param2?something=other&andmore=more#fragments",
    "absolute url description ok");

  PASS_EQUAL([[url baseURL] description],
    @"scheme://user:password@host.domain.org:888/path/absfile.htm",
    "base url description ok");

  PASS_EQUAL([url fragment], @"fragments", "fragment ok");

  PASS_EQUAL([url host], @"host.domain.org", "host ok");
  PASS (NO == [url isFileURL], "is not a file url");
  PASS_EQUAL([url parameterString], @"param1;param2", "parameter string ok");
  PASS_EQUAL([url password], @"password", "password ok");
  PASS_EQUAL([url path], @"/path/file name.htm", "path ok");
  PASS_EQUAL([url port], [NSNumber numberWithInt:888], "port ok");
  PASS_EQUAL([url query], @"something=other&andmore=more", "query ok");
  PASS_EQUAL([url relativePath], @"file name.htm", "relativePath ok");
  PASS_EQUAL([url relativeString],
    @"file%20name.htm;param1;param2?something=other&andmore=more#fragments",
   "relativeString ok");
  PASS_EQUAL([url resourceSpecifier],
    @"file%20name.htm;param1;param2?something=other&andmore=more#fragments",
    "resourceSpecifier ok");
  PASS_EQUAL([url scheme], @"scheme", "scheme ok");
  PASS_EQUAL([[url standardizedURL] absoluteString],
@"scheme://user:password@host.domain.org:888/path/file%20name.htm;param1;param2?something=other&andmore=more#fragments",
    "standardizedURL ok");
  PASS_EQUAL([url user], @"user", "user ok");

  END_SET("test1")
  return 0;
}
