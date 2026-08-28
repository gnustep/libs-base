#if	defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

int main()
{
  START_SET("GSMime streamed body decode")

  NSString	*msg =
    @"Content-Type: text/plain\r\n"
     "Content-Transfer-Encoding: base64\r\n"
     "\r\n"
     "SGVsbG8sIFdvcmxkIQ==\r\n";		/* base64 of "Hello, World!" */
  NSData	*d = [msg dataUsingEncoding: NSASCIIStringEncoding];
  const char	*b = [d bytes];
  NSUInteger	len = [d length];
  NSRange	blank = [msg rangeOfString: @"\r\n\r\n"];
  NSUInteger	split = blank.location + 4 + 4;	/* 4 base64 chars in part 1 */
  GSMimeParser	*p = [GSMimeParser mimeParser];

  /* Feed the message in two parts, splitting the base64 body.  The base64 and
   * quoted-printable decoders used to write each chunk's decoded output at the
   * start of the destination buffer, discarding the previous chunk; a body
   * arriving across several parse: calls must instead decode as a whole. */
  [p parse: [NSData dataWithBytes: b length: split]];
  [p parse: [NSData dataWithBytes: b + split length: len - split]];
  [p parse: nil];

  PASS_EQUAL([[p mimeDocument] content], @"Hello, World!",
    "a base64 body split across parse: calls decodes correctly")

  END_SET("GSMime streamed body decode")
  return 0;
}
#else
int main(void)
{
  return 0;
}
#endif
