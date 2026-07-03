#import <Foundation/Foundation.h>
#import "Testing.h"

/* Tests for the NSRange functions declared in Foundation/NSRange.h:
 * NSMakeRange, NSMaxRange, NSEqualRanges, NSLocationInRange, NSUnionRange,
 * NSIntersectionRange, and the NSStringFromRange/NSRangeFromString pair.
 * These are pure, portable computations with no platform dependency.
 */
int main(void)
{
  START_SET("NSMakeRange, NSMaxRange, NSEqualRanges")
    NSRange	r = NSMakeRange(3, 5);

    PASS(r.location == 3 && r.length == 5,
      "NSMakeRange sets location and length");
    PASS(NSMaxRange(NSMakeRange(3, 5)) == 8,
      "NSMaxRange returns location + length");
    PASS(NSMaxRange(NSMakeRange(0, 0)) == 0,
      "NSMaxRange of an empty range at 0 is 0");

    PASS(NSEqualRanges(NSMakeRange(3, 5), NSMakeRange(3, 5)) == YES,
      "NSEqualRanges is YES for identical ranges");
    PASS(NSEqualRanges(NSMakeRange(3, 5), NSMakeRange(3, 6)) == NO,
      "NSEqualRanges is NO when only the length differs");
    PASS(NSEqualRanges(NSMakeRange(3, 5), NSMakeRange(4, 5)) == NO,
      "NSEqualRanges is NO when only the location differs");

    /* The largest range that does not overflow is accepted. */
    PASS(NSMaxRange(NSMakeRange(0, NSUIntegerMax)) == NSUIntegerMax,
      "NSMakeRange accepts the maximum non-overflowing length");

    /* location + length wrapping past NSUIntegerMax must raise. */
    PASS_EXCEPTION(({ NSRange o = NSMakeRange(NSUIntegerMax, 1); (void)o; }),
      NSRangeException,
      "NSMakeRange raises NSRangeException when location + length overflows");
    PASS_EXCEPTION(({ NSRange o = NSMakeRange(1, NSUIntegerMax); (void)o; }),
      NSRangeException,
      "NSMakeRange raises NSRangeException when length + location overflows");
  END_SET("NSMakeRange, NSMaxRange, NSEqualRanges")

  START_SET("NSLocationInRange")
    NSRange	r = NSMakeRange(3, 5);	/* covers indices 3..7 */

    PASS(NSLocationInRange(3, r) == YES,
      "NSLocationInRange is YES at the range location");
    PASS(NSLocationInRange(7, r) == YES,
      "NSLocationInRange is YES at the last index (NSMaxRange - 1)");
    PASS(NSLocationInRange(8, r) == NO,
      "NSLocationInRange is NO at NSMaxRange");
    PASS(NSLocationInRange(2, r) == NO,
      "NSLocationInRange is NO below the range location");
    PASS(NSLocationInRange(5, NSMakeRange(5, 0)) == NO,
      "NSLocationInRange is NO for every location in an empty range");
  END_SET("NSLocationInRange")

  START_SET("NSUnionRange")
    PASS(NSEqualRanges(NSUnionRange(NSMakeRange(0, 4), NSMakeRange(2, 4)),
      NSMakeRange(0, 6)),
      "NSUnionRange of overlapping ranges spans both");
    PASS(NSEqualRanges(NSUnionRange(NSMakeRange(0, 2), NSMakeRange(5, 3)),
      NSMakeRange(0, 8)),
      "NSUnionRange of disjoint ranges spans the gap between them");
    PASS(NSEqualRanges(NSUnionRange(NSMakeRange(0, 10), NSMakeRange(3, 2)),
      NSMakeRange(0, 10)),
      "NSUnionRange of a contained range is the outer range");
    PASS(NSEqualRanges(NSUnionRange(NSMakeRange(0, 3), NSMakeRange(3, 2)),
      NSMakeRange(0, 5)),
      "NSUnionRange of adjacent ranges joins them");
    PASS(NSEqualRanges(NSUnionRange(NSMakeRange(2, 0), NSMakeRange(5, 3)),
      NSMakeRange(2, 6)),
      "NSUnionRange spans from an empty range's location to the other's end");
  END_SET("NSUnionRange")

  START_SET("NSIntersectionRange")
    NSRange	x;

    PASS(NSEqualRanges(NSIntersectionRange(NSMakeRange(0, 4),
      NSMakeRange(2, 4)), NSMakeRange(2, 2)),
      "NSIntersectionRange of overlapping ranges is the shared span");
    PASS(NSEqualRanges(NSIntersectionRange(NSMakeRange(0, 10),
      NSMakeRange(3, 2)), NSMakeRange(3, 2)),
      "NSIntersectionRange of a contained range is that range");
    PASS(NSEqualRanges(NSIntersectionRange(NSMakeRange(3, 5),
      NSMakeRange(3, 5)), NSMakeRange(3, 5)),
      "NSIntersectionRange of identical ranges is the range");

    x = NSIntersectionRange(NSMakeRange(0, 2), NSMakeRange(5, 3));
    PASS(x.length == 0,
      "NSIntersectionRange of disjoint ranges has zero length");

    x = NSIntersectionRange(NSMakeRange(0, 5), NSMakeRange(5, 3));
    PASS(x.length == 0,
      "NSIntersectionRange of adjacent ranges has zero length");
  END_SET("NSIntersectionRange")

  START_SET("NSStringFromRange and NSRangeFromString")
    NSRange	r = NSMakeRange(3, 5);

    PASS_EQUAL(NSStringFromRange(r), @"{location=3, length=5}",
      "NSStringFromRange formats as {location=a, length=b}");
    PASS_EQUAL(NSStringFromRange(NSMakeRange(0, 0)), @"{location=0, length=0}",
      "NSStringFromRange formats an empty range");

    PASS(NSEqualRanges(NSRangeFromString(NSStringFromRange(r)), r),
      "NSRangeFromString round-trips NSStringFromRange");
    PASS(NSEqualRanges(NSRangeFromString(NSStringFromRange(NSMakeRange(0, 0))),
      NSMakeRange(0, 0)),
      "NSRangeFromString round-trips an empty range");

    PASS(NSEqualRanges(NSRangeFromString(@"{location=12, length=34}"),
      NSMakeRange(12, 34)),
      "NSRangeFromString parses a well-formed string");
    PASS(NSEqualRanges(NSRangeFromString(@"{ location = 7 , length = 8 }"),
      NSMakeRange(7, 8)),
      "NSRangeFromString tolerates surrounding white space");

    /* Malformed input yields {0, 0} rather than raising. */
    PASS(NSEqualRanges(NSRangeFromString(@"garbage"), NSMakeRange(0, 0)),
      "NSRangeFromString returns {0,0} for unparseable input");
    PASS(NSEqualRanges(NSRangeFromString(@""), NSMakeRange(0, 0)),
      "NSRangeFromString returns {0,0} for an empty string");
    PASS(NSEqualRanges(NSRangeFromString(@"{location=3}"), NSMakeRange(0, 0)),
      "NSRangeFromString returns {0,0} when the length field is missing");
    PASS(NSEqualRanges(NSRangeFromString(@"{location=3, length=}"),
      NSMakeRange(0, 0)),
      "NSRangeFromString returns {0,0} when the length value is missing");
  END_SET("NSStringFromRange and NSRangeFromString")

  return 0;
}
