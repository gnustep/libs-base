/*
 * cend-bounds.m - regression guard for the NSXMLParser '<' tag handler
 * bounds check.
 *
 * On entry to the '<' case the cursor cp sits just past the '<'.  The
 * comment / CDATA look-ahead used `cp < cend - 3` and `cp < cend - 8`,
 * but cend is an unsigned NSUInteger, so for input with fewer than 3
 * (resp. 8) bytes after the '<' the subtraction underflows to a huge
 * value, the guard passes, and strncmp() reads three bytes at cp -
 * past the end of the buffer.  The fix tests `cp + 3 < cend` /
 * `cp + 8 < cend`, which is identical whenever cend >= 3 but cannot
 * underflow.
 *
 * The over-read has no functional effect on a normal heap (the bytes
 * read just fail to match "!--"/"![CDATA["), so the memory-safety side
 * is demonstrated separately under AddressSanitizer.  This test guards
 * the behaviour the fix must preserve: well-formed comments and CDATA
 * are still detected, and a truncated tag is handled without crashing
 * or hanging.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLParser.h>
#import "ObjectTesting.h"

@interface CendHandler : NSObject
{
@public
  int		comments;
  int		cdata;
  NSString	*lastComment;
  NSString	*lastCDATA;
}
@end

@implementation CendHandler
- (void) parser: (NSXMLParser *)parser foundComment: (NSString *)comment
{
  comments++;
  ASSIGN(lastComment, comment);
}
- (void) parser: (NSXMLParser *)parser foundCDATA: (NSData *)block
{
  cdata++;
  ASSIGN(lastCDATA, [[[NSString alloc] initWithData: block
    encoding: NSUTF8StringEncoding] autorelease]);
}
- (void) dealloc
{
  RELEASE(lastComment);
  RELEASE(lastCDATA);
  [super dealloc];
}
@end

/* Parse a raw C-string document; returns the handler (autoreleased) so
 * the caller can inspect what fired.  Never raises.
 */
static CendHandler *
parseBytes(const char *xml)
{
  NSData	*d = [NSData dataWithBytes: xml length: strlen(xml)];
  NSXMLParser	*p = [[NSXMLParser alloc] initWithData: d];
  CendHandler	*h = [[CendHandler new] autorelease];

  [p setDelegate: h];
  [p parse];
  RELEASE(p);
  return h;
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  CendHandler		*h;
  unsigned		i;
  const char		*truncated[] = {
    "<", "<!", "<!-", "<!--", "<![", "<![CDATA", "<![CDATA[", 0
  };

  START_SET("NSXMLParser comment/CDATA bounds")

  /* Regression: a well-formed comment and CDATA section are still
   * detected after the bounds expression was rewritten.
   */
  h = parseBytes("<r><!--hello--><![CDATA[world]]></r>");
  PASS(h->comments == 1 && [h->lastComment isEqual: @"hello"],
    "well-formed comment is still detected")
  PASS(h->cdata == 1 && [h->lastCDATA isEqual: @"world"],
    "well-formed CDATA is still detected")

  /* Robustness: a tag truncated to fewer than 3/8 bytes after '<' (the
   * inputs that made cend-3 / cend-8 underflow) is parsed without
   * crashing or hanging, and produces no spurious comment/CDATA.
   */
  for (i = 0; truncated[i] != 0; i++)
    {
      h = parseBytes(truncated[i]);
      PASS(h->comments == 0 && h->cdata == 0,
        "truncated tag \"%s\" yields no spurious comment/CDATA", truncated[i])
    }

  END_SET("NSXMLParser comment/CDATA bounds")

  [arp release];
  return 0;
}
