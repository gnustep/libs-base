/*
 * operations.m - tests for NSHashTable behaviour the other tests do not cover:
 * membership (member:, anyObject, setRepresentation, removeAllObjects), the
 * predicates (isEqualToHashTable:, isSubsetOfHashTable:, intersectsHashTable:)
 * and the set-algebra operations (unionHashTable:, intersectHashTable:,
 * minusHashTable:).  Uses object-personality (isEqual:) strong tables.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#define A(...) [NSArray arrayWithObjects: __VA_ARGS__, nil]

static NSHashTable *
htFrom(NSArray *objs)
{
  NSHashTable	*t = [NSHashTable hashTableWithOptions:
    NSPointerFunctionsObjectPersonality];
  NSUInteger	i;

  for (i = 0; i < [objs count]; i++)
    [t addObject: [objs objectAtIndex: i]];
  return t;
}

int main(void)
{
  START_SET("NSHashTable membership")
    NSHashTable	*t = htFrom(A(@"a", @"b", @"c"));

    PASS([t count] == 3, "addObject: adds distinct objects");
    [t addObject: @"a"];
    PASS([t count] == 3, "addObject: of an equal object is a no-op");
    PASS([t containsObject: @"b"] == YES, "containsObject: finds a member");
    PASS([t containsObject: @"z"] == NO, "containsObject: rejects a non-member");
    PASS_EQUAL([t member: @"c"], @"c", "member: returns the stored object");
    PASS([t member: @"z"] == nil, "member: of a non-member is nil");
    PASS([t anyObject] != nil, "anyObject is non-nil for a non-empty table");
    PASS([[NSHashTable hashTableWithOptions: NSPointerFunctionsObjectPersonality]
      anyObject] == nil, "anyObject is nil for an empty table");
    PASS([[t setRepresentation] isEqualToSet:
      ([NSSet setWithObjects: @"a", @"b", @"c", nil])],
      "setRepresentation returns the objects as a set");

    [t removeObject: @"b"];
    PASS([t count] == 2 && ![t containsObject: @"b"],
      "removeObject: removes a member");
    [t removeAllObjects];
    PASS([t count] == 0, "removeAllObjects empties the table");
  END_SET("NSHashTable membership")

  START_SET("NSHashTable predicates")
    NSHashTable	*ab = htFrom(A(@"a", @"b"));

    PASS([ab isEqualToHashTable: htFrom(A(@"b", @"a"))] == YES,
      "isEqualToHashTable: is YES for the same members");
    PASS([ab isEqualToHashTable: htFrom(A(@"a"))] == NO,
      "isEqualToHashTable: is NO for different members");
    PASS([htFrom(A(@"a")) isSubsetOfHashTable: ab] == YES,
      "isSubsetOfHashTable: is YES for a subset");
    PASS([htFrom(A(@"a", @"c")) isSubsetOfHashTable: ab] == NO,
      "isSubsetOfHashTable: is NO when an element is missing");
    PASS([ab intersectsHashTable: htFrom(A(@"b", @"c"))] == YES,
      "intersectsHashTable: is YES on an overlap");
    PASS([ab intersectsHashTable: htFrom(A(@"x", @"y"))] == NO,
      "intersectsHashTable: is NO for disjoint tables");
  END_SET("NSHashTable predicates")

  START_SET("NSHashTable set algebra")
    NSHashTable	*t;

    t = htFrom(A(@"a", @"b"));
    [t unionHashTable: htFrom(A(@"b", @"c"))];
    PASS([t count] == 3 && [t containsObject: @"a"]
      && [t containsObject: @"c"],
      "unionHashTable: adds the other table's members");

    t = htFrom(A(@"a", @"b", @"c"));
    [t intersectHashTable: htFrom(A(@"b", @"c", @"d"))];
    PASS([t count] == 2 && [t containsObject: @"b"]
      && [t containsObject: @"c"] && ![t containsObject: @"a"],
      "intersectHashTable: keeps only the shared members");

    t = htFrom(A(@"a", @"b", @"c"));
    [t minusHashTable: htFrom(A(@"b", @"d"))];
    PASS([t count] == 2 && [t containsObject: @"a"]
      && [t containsObject: @"c"] && ![t containsObject: @"b"],
      "minusHashTable: removes the other table's members");
  END_SET("NSHashTable set algebra")

  return 0;
}
