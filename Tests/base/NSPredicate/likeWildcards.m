/* In a LIKE pattern only '*' (any run of characters), '?' (exactly one
   character) and a backslash (which makes the next character literal) mean
   anything; every other character stands for itself, as on OS X.
*/
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"

static BOOL
like(NSString *string, NSString *pattern)
{
  return [[NSPredicate predicateWithFormat: @"SELF LIKE %@", pattern]
    evaluateWithObject: string];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  PASS(like(@"abc", @"a*"), "* matches any run of characters");
  PASS(like(@"a", @"a*"), "including none");
  PASS(like(@"a\nb", @"a*"), "and line breaks");
  PASS(like(@"axb", @"a?b"), "? matches one character");
  PASS(!like(@"ab", @"a?b"), "not none");
  PASS(!like(@"axxb", @"a?b"), "nor two");
  PASS(like(@"a.b", @"a.b") && !like(@"axb", @"a.b"), ". is a dot");
  PASS(like(@"a+b", @"a+b") && !like(@"aab", @"a+b"), "+ is a plus");
  PASS(like(@"a(b", @"a(b"), "( is a parenthesis");
  PASS(like(@"[ab]", @"[ab]") && !like(@"a", @"[ab]"),
    "brackets are brackets");
  PASS(!like(@"x", @"a|x"), "| is a bar");
  PASS(like(@"a$^b", @"a$^b"), "$ and ^ are themselves");
  PASS(like(@"a*b", @"a\\*b") && !like(@"axb", @"a\\*b"),
    "a backslash makes * literal");
  PASS(like(@"a?", @"a\\?") && !like(@"ab", @"a\\?"),
    "and ?");
  PASS(like(@"a\\b", @"a\\\\b"), "and a backslash");
  PASS(([[NSPredicate predicateWithFormat: @"SELF LIKE[c] %@", @"A?C"]
    evaluateWithObject: @"abc"]), "LIKE[c] ignores case");

  [arp release];
  return 0;
}
