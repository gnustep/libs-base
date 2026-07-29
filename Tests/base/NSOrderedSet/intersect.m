/*
 * intersect.m - regression test for -[NSMutableOrderedSet intersectOrderedSet:]
 * and -[NSMutableOrderedSet intersectSet:], which enumerated the receiver while
 * removing objects from it, tripping an internal bounds assertion.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#define OS(...)  [NSOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]
#define MOS(...) [NSMutableOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]

int main(void)
{
  START_SET("NSMutableOrderedSet intersect")
    NSMutableOrderedSet	*m;

    m = MOS(@"a", @"b", @"c", @"d");
    [m intersectOrderedSet: OS(@"b", @"c", @"x")];
    PASS([m isEqualToOrderedSet: OS(@"b", @"c")],
      "intersectOrderedSet: keeps only the shared objects, in order");

    m = MOS(@"a", @"b", @"c", @"d");
    [m intersectSet: [NSSet setWithObjects: @"b", @"c", @"x", nil]];
    PASS([m isEqualToOrderedSet: OS(@"b", @"c")],
      "intersectSet: keeps only the shared objects, in order");
  END_SET("NSMutableOrderedSet intersect")

  return 0;
}
