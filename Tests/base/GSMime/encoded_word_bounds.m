#if     defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

/* Parse a single-header message and return the decoded value of `name`. */
static NSString *
decodeHeaderValue(NSString *headerLine, NSString *name)
{
  GSMimeParser		*parser = [GSMimeParser mimeParser];
  NSMutableString	*msg = [NSMutableString stringWithString: headerLine];

  [msg appendString: @"\r\n\r\n"];
  [parser parse: [msg dataUsingEncoding: NSASCIIStringEncoding]];
  return [[[parser mimeDocument] headerNamed: name] value];
}

int main()
{
  START_SET("GSMime encoded-word bounds")

  /* A well-formed quoted-printable encoded word still decodes correctly. */
  PASS_EQUAL(decodeHeaderValue(@"Subject: =?utf-8?Q?Hello=20World?=", @"subject"),
    @"Hello World",
    "quoted-printable encoded word decodes correctly");

  /* A malformed encoded word whose quoted-printable text ends in a bare '='
     used to make decodeWord step past the end of the word and keep decoding
     the following header bytes into a stack buffer sized only to the word
     (a stack-buffer-overflow).  Parsing it without overflowing is the
     regression check. */
  {
    GSMimeParser	*parser = [GSMimeParser mimeParser];
    NSMutableString	*m;
    int			i;

    m = [NSMutableString stringWithString: @"Subject: =?utf-8?Q?A=?="];
    for (i = 0; i < 200; i++)
      {
	[m appendString: @"Z"];
      }
    [m appendString: @"\r\n\r\n"];
    [parser parse: [m dataUsingEncoding: NSASCIIStringEncoding]];
    PASS([parser mimeDocument] != nil,
      "a malformed quoted-printable encoded word is parsed without overflow");
  }

  END_SET("GSMime encoded-word bounds")
  return 0;
}
#else
int main(void)
{
  return 0;
}
#endif
