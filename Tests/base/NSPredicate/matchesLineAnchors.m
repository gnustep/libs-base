/* On OS X, ^ and $ in a MATCHES pattern match at the start and end of
   each line, not only of the whole string, as though the pattern were
   compiled with NSRegularExpressionAnchorsMatchLines.  The match is still
   of the whole string.
*/
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"

static BOOL
matches(NSString *string, NSString *pattern)
{
  return [[NSPredicate predicateWithFormat: @"SELF MATCHES %@", pattern]
    evaluateWithObject: string];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  PASS(matches(@"a\nb", @".*^b$"), "^ matches after a line break");
  PASS(matches(@"a\nb", @"^a$.*"), "$ matches before a line break");
  PASS(matches(@"a\nb", @"a$\\nb"), "$ then the line break itself");
  PASS(matches(@"a\nb", @"a\\n^b"), "the line break, then ^");
  PASS(matches(@"ab", @"^ab$"), "a single line still matches with both");
  PASS(!matches(@"a\nb", @"^b$"), "the whole string must still match");
  PASS(!matches(@"a\nb", @"^a$"), "not just its first line");
  PASS(matches(@"a\nb", @"a.b"), ". still matches a line break");

  [arp release];
  return 0;
}
