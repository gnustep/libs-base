/**
 *  An HTTP response whose body is multipart is kept as its data when the
 *  parser is told to (as NSURLProtocol does), chunked or not; otherwise it
 *  is parsed into parts, as before.
 */
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

static GSMimeParser *parse(NSString *text, BOOL asData)
{
  GSMimeParser	*parser = AUTORELEASE([GSMimeParser new]);

  [parser setIsHttp];
  if (asData) [parser setMultipartAsData: YES];
  [parser parse: [text dataUsingEncoding: NSISOLatin1StringEncoding]];
  [parser parse: nil];
  return parser;
}

int main()
{
  START_SET("multipart as data")
    NSString	*body = @"--b\r\nContent-Type: application/http\r\n\r\n"
      @"HTTP/1.1 204 No Content\r\n\r\n\r\n--b--\r\n";
    NSString	*head = @"HTTP/1.1 200 OK\r\n"
      @"Content-Type: multipart/mixed; boundary=b\r\n";
    NSString	*plain = [NSString stringWithFormat:
      @"%@Content-Length: %lu\r\n\r\n%@", head, (unsigned long)[body length], body];
    NSString	*chunked = [NSString stringWithFormat:
      @"%@Transfer-Encoding: chunked\r\n\r\n%lx\r\n%@\r\n0\r\n\r\n",
      head, (unsigned long)[body length], body];
    NSData	*expected = [body dataUsingEncoding: NSISOLatin1StringEncoding];
    GSMimeParser	*parser;

    parser = parse(plain, YES);
    PASS([parser isComplete], "a multipart HTTP body is parsed");
    PASS_EQUAL([[parser mimeDocument] content], expected,
      "with multipartAsData its content is the body as sent");

    parser = parse(chunked, YES);
    PASS([parser isComplete], "a chunked multipart HTTP body is parsed");
    PASS_EQUAL([[parser mimeDocument] content], expected,
      "its content is the body without the chunked encoding");

    parser = parse(plain, NO);
    PASS([[[parser mimeDocument] content] isKindOfClass: [NSArray class]]
      && [[[parser mimeDocument] content] count] == 1,
      "without it the body is a document of parts, as before");
  END_SET("multipart as data")
  return 0;
}
