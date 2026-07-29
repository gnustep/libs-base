/*
 * operations.m - tests for NSOrderedSet / NSMutableOrderedSet accessors,
 * ordering + uniqueness, and the index-based mutation and set-algebra
 * operations that basic.m does not cover: indexOfObject:, first/lastObject,
 * isEqualToOrderedSet:, reversedOrderedSet, array/set, and the mutable
 * insert / remove / replace / exchange / move / union / minus operations.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#define OS(...)  [NSOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]
#define MOS(...) [NSMutableOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]

int main(void)
{
  START_SET("NSOrderedSet ordering, uniqueness and accessors")
    NSOrderedSet	*s = OS(@"a", @"b", @"c", @"d");

    PASS([s count] == 4, "count is the number of objects");
    PASS([OS(@"a", @"b", @"a") count] == 2,
      "a duplicate object is not stored twice");
    PASS([[OS(@"a", @"b", @"a") objectAtIndex: 1] isEqual: @"b"],
      "a duplicate keeps the original ordering");

    PASS_EQUAL([s objectAtIndex: 0], @"a", "objectAtIndex: 0 is the first object");
    PASS_EQUAL([s objectAtIndex: 3], @"d", "objectAtIndex: is ordered");
    PASS_EQUAL([s firstObject], @"a", "firstObject");
    PASS_EQUAL([s lastObject], @"d", "lastObject");
    PASS([s indexOfObject: @"c"] == 2, "indexOfObject: returns the position");
    PASS([s indexOfObject: @"z"] == NSNotFound,
      "indexOfObject: of an absent object is NSNotFound");
    PASS([s containsObject: @"b"] == YES, "containsObject: is YES for a member");

    PASS_EQUAL([s array], ([NSArray arrayWithObjects: @"a", @"b", @"c", @"d", nil]),
      "-array returns the objects in order");
    PASS([[s set] isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", @"d", nil])],
      "-set returns the objects as a set");
    PASS([[s reversedOrderedSet] isEqualToOrderedSet: OS(@"d", @"c", @"b", @"a")],
      "reversedOrderedSet reverses the order");

    PASS([s isEqualToOrderedSet: OS(@"a", @"b", @"c", @"d")] == YES,
      "isEqualToOrderedSet: is YES for the same objects in the same order");
    PASS([s isEqualToOrderedSet: OS(@"d", @"c", @"b", @"a")] == NO,
      "isEqualToOrderedSet: is order-sensitive");
  END_SET("NSOrderedSet ordering, uniqueness and accessors")

  START_SET("NSMutableOrderedSet add and insert")
    NSMutableOrderedSet	*m = MOS(@"a", @"b", @"c");

    [m addObject: @"d"];
    PASS([m isEqualToOrderedSet: OS(@"a", @"b", @"c", @"d")],
      "addObject: appends at the end");
    [m addObject: @"a"];
    PASS([m isEqualToOrderedSet: OS(@"a", @"b", @"c", @"d")],
      "addObject: of an existing object is a no-op");
    [m insertObject: @"x" atIndex: 1];
    PASS([m isEqualToOrderedSet: OS(@"a", @"x", @"b", @"c", @"d")],
      "insertObject:atIndex: inserts at the position");
  END_SET("NSMutableOrderedSet add and insert")

  START_SET("NSMutableOrderedSet remove and replace")
    NSMutableOrderedSet	*m;

    m = MOS(@"a", @"b", @"c", @"d");
    [m removeObjectAtIndex: 1];
    PASS([m isEqualToOrderedSet: OS(@"a", @"c", @"d")],
      "removeObjectAtIndex: removes the object at the index");

    m = MOS(@"a", @"b", @"c", @"d");
    [m removeObject: @"c"];
    PASS([m isEqualToOrderedSet: OS(@"a", @"b", @"d")],
      "removeObject: removes the given object");

    m = MOS(@"a", @"b", @"c", @"d");
    [m removeObjectsInRange: NSMakeRange(1, 2)];
    PASS([m isEqualToOrderedSet: OS(@"a", @"d")],
      "removeObjectsInRange: removes the range");

    m = MOS(@"a", @"b", @"c", @"d");
    [m replaceObjectAtIndex: 1 withObject: @"y"];
    PASS([m isEqualToOrderedSet: OS(@"a", @"y", @"c", @"d")],
      "replaceObjectAtIndex:withObject: replaces in place");

    m = MOS(@"a", @"b", @"c", @"d");
    [m removeAllObjects];
    PASS([m count] == 0, "removeAllObjects empties the set");
  END_SET("NSMutableOrderedSet remove and replace")

  START_SET("NSMutableOrderedSet exchange")
    NSMutableOrderedSet	*m = MOS(@"a", @"b", @"c", @"d");

    [m exchangeObjectAtIndex: 0 withObjectAtIndex: 3];
    PASS([m isEqualToOrderedSet: OS(@"d", @"b", @"c", @"a")],
      "exchangeObjectAtIndex:withObjectAtIndex: swaps two objects");
  END_SET("NSMutableOrderedSet exchange")

  START_SET("NSMutableOrderedSet set algebra")
    NSMutableOrderedSet	*m;

    m = MOS(@"a", @"b", @"c");
    [m unionOrderedSet: OS(@"c", @"d", @"e")];
    PASS([m isEqualToOrderedSet: OS(@"a", @"b", @"c", @"d", @"e")],
      "unionOrderedSet: appends the new objects in order");

    m = MOS(@"a", @"b", @"c", @"d");
    [m minusOrderedSet: OS(@"b", @"d")];
    PASS([m isEqualToOrderedSet: OS(@"a", @"c")],
      "minusOrderedSet: removes the shared objects");
  END_SET("NSMutableOrderedSet set algebra")

  return 0;
}
