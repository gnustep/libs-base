/*
 * counting.m - tests for the NSCountedSet counting behaviour the existing
 * tests (protocols, isEqualToSet:) do not cover: countForObject:, the distinct
 * count, addObject: incrementing, removeObject: decrementing and removing at
 * zero, and initWithArray: counting duplicates.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSCountedSet counting")
    NSCountedSet	*s = [NSCountedSet setWithObjects:
      @"a", @"a", @"a", @"b", nil];

    PASS([s count] == 2, "count is the number of distinct objects");
    PASS([s countForObject: @"a"] == 3,
      "countForObject: returns the occurrence count");
    PASS([s countForObject: @"b"] == 1, "a single occurrence counts once");
    PASS([s countForObject: @"z"] == 0,
      "countForObject: of an absent object is 0");
    PASS([s containsObject: @"a"] == YES, "containsObject: finds a member");

    [s addObject: @"b"];
    PASS([s countForObject: @"b"] == 2 && [s count] == 2,
      "addObject: increments the count without adding a distinct object");
  END_SET("NSCountedSet counting")

  START_SET("NSCountedSet removeObject")
    NSCountedSet	*s = [NSCountedSet setWithObjects: @"a", @"a", @"a", nil];

    [s removeObject: @"a"];
    PASS([s countForObject: @"a"] == 2 && [s count] == 1
      && [s containsObject: @"a"],
      "removeObject: decrements the count while it stays positive");

    [s removeObject: @"a"];
    [s removeObject: @"a"];
    PASS([s countForObject: @"a"] == 0 && [s count] == 0
      && ![s containsObject: @"a"],
      "the object is removed once its count reaches zero");

    [s removeObject: @"z"];
    PASS([s count] == 0, "removeObject: of an absent object is a no-op");
  END_SET("NSCountedSet removeObject")

  START_SET("NSCountedSet initWithArray")
    NSCountedSet	*s = [[[NSCountedSet alloc] initWithArray:
      ([NSArray arrayWithObjects: @"a", @"b", @"a", @"a", nil])] autorelease];

    PASS([s count] == 2, "initWithArray: counts distinct objects");
    PASS([s countForObject: @"a"] == 3 && [s countForObject: @"b"] == 1,
      "initWithArray: counts duplicate objects");
    PASS([[s allObjects] count] == 2,
      "allObjects returns each distinct object once");
  END_SET("NSCountedSet initWithArray")

  return 0;
}
