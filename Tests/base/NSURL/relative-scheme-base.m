#import "ObjectTesting.h"
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

int main()
{
  START_SET("NSURL relative URL over a scheme-less base")

  NSURL	*base = [NSURL URLWithString: @"foo"];
  NSURL	*child;

  PASS(base != nil && [base scheme] == nil,
    "a scheme-less base URL parses and reports no scheme")

  /* A relative string that carries its own scheme used to be compared with
   * strcmp() against the base's scheme, which is NULL for a scheme-less base,
   * crashing the process.  The relative URL should instead be treated as an
   * absolute URL (its scheme differs from the base's absent one). */
  child = [NSURL URLWithString: @"http:bar" relativeToURL: base];
  PASS(child != nil,
    "a scheme-bearing relative URL over a scheme-less base does not crash")
  PASS_EQUAL([child absoluteString], @"http:bar",
    "the relative URL is resolved as an absolute URL")

  END_SET("NSURL relative URL over a scheme-less base")
  return 0;
}
