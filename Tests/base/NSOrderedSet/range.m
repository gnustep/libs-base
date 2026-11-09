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

static NSArray *
words(NSString *s)
{
  return [s length] ? [s componentsSeparatedByString: @" "] : [NSArray array];
}

/* Inserts objs at indexes into a set made from start, and checks that the
 * set ends up as expected and that the named exception (or none) is raised.
 */
static BOOL
insertMany(NSString *start, NSString *objs, NSIndexSet *indexes,
  NSString *expected, NSString *exception)
{
  NSMutableOrderedSet	*m;
  NSString		*raised = nil;

  m = [NSMutableOrderedSet orderedSetWithArray: words(start)];
  NS_DURING
    [m insertObjects: words(objs) atIndexes: indexes];
  NS_HANDLER
    raised = [localException name];
  NS_ENDHANDLER
  if (exception != raised && NO == [exception isEqual: raised])
    {
      return NO;
    }
  return [[m array] isEqual: words(expected)];
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
    PASS_RUNS([m insertObject: @"a" atIndex: 3],
      "-insertObject:atIndex: at the count ignores an existing object")
    PASS_EQUAL(m, abc, "inserting an existing object leaves the set unchanged")
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
    /* Expected results were measured on macOS 26.6.2 (25G83). */
    PASS(insertMany(@"a b", @"x y", IDX(1, 3), @"a x b y", nil),
      "inserts each object at its index after earlier insertions")
    PASS(insertMany(@"a b", @"x y", IDX(1, 4), @"a b", NSRangeException),
      "raises for an index past the count after all insertions")
    PASS(insertMany(@"a", @"x", IDX(2), @"a", NSRangeException),
      "raises for a single index past the count")
    PASS(insertMany(@"a", @"x y", IDX(0), @"a", NSInvalidArgumentException),
      "raises for fewer indexes than objects")
    PASS(insertMany(@"a", @"x", IDX(0, 1), @"a", NSInvalidArgumentException),
      "raises for fewer objects than indexes")
    PASS(insertMany(@"a", @"a b c", IDX(1, 2, 3), @"a b c", nil),
      "a skipped object moves the rest of its run up (end of set)")
    PASS(insertMany(@"a", @"a b c", IDX(0, 1, 2), @"b c a", nil),
      "a skipped object moves the rest of its run up (start of set)")
    PASS(insertMany(@"a b", @"x a y", IDX(0, 1, 2), @"x y a b", nil),
      "a skipped object in the middle of a run moves the rest up")
    PASS(insertMany(@"a b", @"x a y", IDX(2, 3, 4), @"a b x y", nil),
      "a skipped object in a run at the end moves the rest up")
    PASS(insertMany(@"a b c", @"a x", IDX(0, 3), @"a b c x", nil),
      "a skipped object does not move later runs")
    PASS(insertMany(@"a b c", @"x a y", IDX(0, 2, 5), @"x a b c",
      NSRangeException),
      "a later run past the end after a skipped object raises")
  END_SET("NSMutableOrderedSet -insertObjects:atIndexes:")

  return 0;
}
