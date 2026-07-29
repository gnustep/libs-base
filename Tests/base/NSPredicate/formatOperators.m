/* The format a predicate describes itself with has to parse back to the same
   predicate, since that is how a predicate is passed around as text.
*/
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSComparisonPredicate.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

static NSString *
formatOf(NSString *format)
{
  return [[NSPredicate predicateWithFormat: format] predicateFormat];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSPredicate *p;

  PASS_EQUAL(formatOf(@"a < 1"), @"a < 1", "a less than describes itself");
  PASS_EQUAL(formatOf(@"a <= 1"), @"a <= 1",
             "a less than or equal describes itself");
  PASS_EQUAL(formatOf(@"a > 1"), @"a > 1",
             "a greater than describes itself");
  PASS_EQUAL(formatOf(@"a >= 1"), @"a >= 1",
             "a greater than or equal describes itself");
  PASS_EQUAL(formatOf(@"a = 1"), @"a = 1", "an equal describes itself");
  PASS_EQUAL(formatOf(@"a != 1"), @"a != 1", "a not equal describes itself");

  /* The description has to mean what the predicate means. */
  p = [NSPredicate predicateWithFormat: @"%@ > %@",
    [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 1]];
  PASS([p evaluateWithObject: nil] == NO, "one is not greater than one");
  PASS([[NSPredicate predicateWithFormat: [p predicateFormat]]
         evaluateWithObject: nil] == NO,
       "and neither is it read back from the description");

  [arp release];
  return 0;
}
