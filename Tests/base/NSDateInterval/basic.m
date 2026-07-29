/*
 * basic.m - tests for NSDateInterval: construction (including the negative
 * duration / reversed dates exceptions), the start/end/duration accessors and
 * setters, compare: and isEqualToDateInterval:, intersection
 * (intersectsDateInterval:, intersectionWithDateInterval:), containsDate: and
 * copying.  Dates are built from fixed reference-time offsets so the results
 * are deterministic.
 *
 * NSCoding is intentionally not tested: it is currently a stub in the
 * implementation (initWithCoder: returns nil).
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* A date at a fixed offset (seconds) from a non-zero base.  The base keeps the
 * dates away from the reference instant itself (interval 0), which avoids
 * depending on any reference-date edge behaviour; only the relative offsets
 * matter to NSDateInterval. */
#define DATE_BASE 1000000.0
static NSDate *
D(NSTimeInterval t)
{
  return [NSDate dateWithTimeIntervalSinceReferenceDate: DATE_BASE + t];
}

/* An autoreleased interval [start, start+duration]. */
static NSDateInterval *
I(NSTimeInterval start, NSTimeInterval duration)
{
  return [[[NSDateInterval alloc] initWithStartDate: D(start)
                                           duration: duration] autorelease];
}

int main(void)
{
  START_SET("NSDateInterval construction")
    NSDateInterval	*a;

    a = [[[NSDateInterval alloc] initWithStartDate: D(0)
                                          duration: 100] autorelease];
    PASS([[a startDate] isEqualToDate: D(0)], "initWithStartDate:duration: keeps the start");
    PASS([a duration] == 100, "initWithStartDate:duration: keeps the duration");
    PASS([[a endDate] isEqualToDate: D(100)], "endDate is start + duration");

    a = [[[NSDateInterval alloc] initWithStartDate: D(10)
                                           endDate: D(60)] autorelease];
    PASS([a duration] == 50, "initWithStartDate:endDate: derives the duration");

    PASS_EXCEPTION(({ NSDateInterval *x
      = [[NSDateInterval alloc] initWithStartDate: D(0) duration: -5]; (void)x; }),
      NSInvalidArgumentException,
      "a negative duration raises NSInvalidArgumentException");
    PASS_EXCEPTION(({ NSDateInterval *x
      = [[NSDateInterval alloc] initWithStartDate: D(100) endDate: D(50)]; (void)x; }),
      NSInvalidArgumentException,
      "an end date before the start date raises NSInvalidArgumentException");
  END_SET("NSDateInterval construction")

  START_SET("NSDateInterval accessors and setters")
    NSDateInterval	*a = I(0, 100);

    [a setDuration: 200];
    PASS([[a endDate] isEqualToDate: D(200)], "setDuration: moves the end date");

    a = I(0, 100);
    [a setStartDate: D(50)];
    PASS([a duration] == 100 && [[a endDate] isEqualToDate: D(150)],
      "setStartDate: keeps the duration and shifts the end date");

    a = I(0, 100);
    [a setEndDate: D(30)];
    PASS([a duration] == 30, "setEndDate: recomputes the duration");
  END_SET("NSDateInterval accessors and setters")

  START_SET("NSDateInterval compare and equality")
    NSDateInterval	*a = I(0, 100);

    PASS([a isEqualToDateInterval: I(0, 100)] == YES,
      "isEqualToDateInterval: is YES for equal intervals");
    PASS([a isEqualToDateInterval: I(0, 50)] == NO,
      "isEqualToDateInterval: is NO for a different duration");

    PASS([a compare: I(50, 100)] == NSOrderedAscending,
      "an earlier start compares ascending");
    PASS([I(50, 100) compare: a] == NSOrderedDescending,
      "a later start compares descending");
    PASS([a compare: I(0, 200)] == NSOrderedAscending,
      "with the same start, a shorter duration compares ascending");
    PASS([a compare: I(0, 100)] == NSOrderedSame,
      "equal intervals compare the same");
  END_SET("NSDateInterval compare and equality")

  START_SET("NSDateInterval intersection")
    NSDateInterval	*a = I(0, 100);	/* [0, 100]   */
    NSDateInterval	*x;

    x = [a intersectionWithDateInterval: I(50, 100)];	/* [50, 150] */
    PASS(x != nil && [[x startDate] isEqualToDate: D(50)] && [x duration] == 50,
      "the intersection of overlapping intervals is [50, 100]");
    PASS([a intersectsDateInterval: I(50, 100)] == YES,
      "intersectsDateInterval: is YES for overlapping intervals");

    x = [a intersectionWithDateInterval: I(25, 50)];	/* [25, 75] contained */
    PASS(x != nil && [[x startDate] isEqualToDate: D(25)] && [x duration] == 50,
      "the intersection with a contained interval is that interval");

    PASS([a intersectionWithDateInterval: I(200, 50)] == nil,
      "disjoint intervals have no intersection");
    PASS([a intersectsDateInterval: I(200, 50)] == NO,
      "intersectsDateInterval: is NO for disjoint intervals");

    PASS([a intersectionWithDateInterval: I(100, 100)] == nil,
      "intervals that only touch at a point do not intersect");
  END_SET("NSDateInterval intersection")

  START_SET("NSDateInterval containsDate")
    NSDateInterval	*a = I(0, 100);	/* [0, 100] */

    PASS([a containsDate: D(0)] == YES, "the start date is contained");
    PASS([a containsDate: D(100)] == YES, "the end date is contained");
    PASS([a containsDate: D(50)] == YES, "an interior date is contained");
    PASS([a containsDate: D(-1)] == NO, "a date before the start is not contained");
    PASS([a containsDate: D(101)] == NO, "a date after the end is not contained");
  END_SET("NSDateInterval containsDate")

  START_SET("NSDateInterval copying")
    NSDateInterval	*a = I(10, 40);
    NSDateInterval	*c = [a copy];

    PASS([c isEqualToDateInterval: a], "a copy is equal to the original");
    [c release];
  END_SET("NSDateInterval copying")

  return 0;
}
