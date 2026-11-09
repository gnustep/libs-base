/*
 * range.m - tests that NSOrderedSet / NSMutableOrderedSet index access
 * raises NSRangeException for indexes out of range, leaving the set
 * unchanged.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#define OS(...)  [NSOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]
#define MOS(...) [NSMutableOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]
#define IDX(...) ixs(__VA_ARGS__, NSNotFound)

static NSIndexSet *
ixs(NSUInteger first, ...)
{
  NSMutableIndexSet	*set = [NSMutableIndexSet indexSet];
  va_list		ap;
  NSUInteger		i;

  va_start(ap, first);
  for (i = first; i != NSNotFound; i = va_arg(ap, NSUInteger))
    {
      [set addIndex: i];
    }
  va_end(ap);
  return set;
}

int main(void)
{
  START_SET("NSOrderedSet index range checks")
    NSOrderedSet	*s = OS(@"a", @"b", @"c");

    PASS_EXCEPTION([s objectAtIndex: 3], NSRangeException,
      "-objectAtIndex: raises for the count")
    PASS_EXCEPTION([s objectAtIndex: NSNotFound], NSRangeException,
      "-objectAtIndex: raises for NSNotFound")
    PASS_EXCEPTION([OS(@"a") objectAtIndex: 1], NSRangeException,
      "-objectAtIndex: raises on a set with one object")
    PASS_EXCEPTION([[NSOrderedSet orderedSet] objectAtIndex: 0],
      NSRangeException, "-objectAtIndex: raises on an empty set")
  END_SET("NSOrderedSet index range checks")

  START_SET("NSMutableOrderedSet index range checks")
    NSMutableOrderedSet	*m = MOS(@"a", @"b", @"c");
    NSOrderedSet	*abc = OS(@"a", @"b", @"c");
    NSIndexSet		*zeroAndThree = IDX(0, 3);

    PASS_EXCEPTION([m objectAtIndex: 3], NSRangeException,
      "-objectAtIndex: raises for the count")

    PASS_EXCEPTION([m insertObject: @"x" atIndex: 4], NSRangeException,
      "-insertObject:atIndex: raises past the count")
    PASS_EQUAL(m, abc, "a failed insert leaves the set unchanged")
    PASS_EXCEPTION([m insertObject: @"a" atIndex: 4], NSRangeException,
      "-insertObject:atIndex: raises past the count for an existing object")
    PASS_EXCEPTION([m insertObject: nil atIndex: 4],
      NSInvalidArgumentException, "-insertObject:atIndex: raises for nil")

    PASS_EXCEPTION([m removeObjectAtIndex: 3], NSRangeException,
      "-removeObjectAtIndex: raises for the count")
    PASS_EXCEPTION([m removeObjectAtIndex: NSNotFound], NSRangeException,
      "-removeObjectAtIndex: raises for NSNotFound")
    PASS_EXCEPTION([m removeObjectsAtIndexes: zeroAndThree], NSRangeException,
      "-removeObjectsAtIndexes: raises for the count")
    PASS_EQUAL(m, abc, "a failed remove leaves the set unchanged")

    PASS_EXCEPTION([m replaceObjectAtIndex: 3 withObject: @"x"],
      NSRangeException, "-replaceObjectAtIndex:withObject: raises for the count")
    PASS_EXCEPTION([m setObject: @"x" atIndex: 4], NSRangeException,
      "-setObject:atIndex: raises past the count")
    PASS_EQUAL(m, abc, "a failed replace leaves the set unchanged")

    PASS_EXCEPTION([[NSMutableOrderedSet orderedSet] removeObjectAtIndex: 0],
      NSRangeException, "-removeObjectAtIndex: raises on an empty set")
  END_SET("NSMutableOrderedSet index range checks")

  START_SET("NSMutableOrderedSet -insertObjects:atIndexes:")
    NSMutableOrderedSet	*m;
    NSArray		*xy = [NSArray arrayWithObjects: @"x", @"y", nil];
    NSArray		*abc = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
    NSIndexSet		*outOfRange = IDX(1, 4);
    NSIndexSet		*oneToThree = IDX(1, 2, 3);

    m = MOS(@"a", @"b");
    [m insertObjects: xy atIndexes: IDX(1, 3)];
    PASS_EQUAL(m, OS(@"a", @"x", @"b", @"y"),
      "inserts each object at its index after earlier insertions")

    m = MOS(@"a", @"b");
    PASS_EXCEPTION([m insertObjects: xy atIndexes: outOfRange],
      NSRangeException, "raises for an index past the count after insertions")
    PASS_EQUAL(m, OS(@"a", @"b"), "a failed insert leaves the set unchanged")

    m = MOS(@"a");
    PASS_RUNS([m insertObjects: abc atIndexes: oneToThree],
      "does not raise when skipping an object already in the set")
    PASS_EQUAL(m, OS(@"a", @"b", @"c"),
      "skipping an existing object appends the later objects in order")
  END_SET("NSMutableOrderedSet -insertObjects:atIndexes:")

  return 0;
}
