/*
 * moveObjects.m - regression test for -[NSMutableOrderedSet
 * moveObjectsAtIndexes:toIndex:], which removed the moved objects in ascending
 * index order (so each removal shifted the later indexes) and reinserted them
 * reversed, dropping and reordering objects.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#define OS(...)  [NSOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]
#define MOS(...) [NSMutableOrderedSet orderedSetWithObjects: __VA_ARGS__, nil]

int main(void)
{
  START_SET("NSMutableOrderedSet moveObjectsAtIndexes:toIndex:")
    NSMutableOrderedSet	*m;

    m = MOS(@"a", @"b", @"c", @"d");
    [m moveObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:
      NSMakeRange(1, 2)] toIndex: 0];
    PASS([m count] == 4, "no object is lost when moving a range");
    PASS([m isEqualToOrderedSet: OS(@"b", @"c", @"a", @"d")],
      "moving a range to the front places the objects there in order");

    m = MOS(@"a", @"b", @"c", @"d", @"e");
    [m moveObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:
      NSMakeRange(0, 2)] toIndex: 3];
    PASS([m isEqualToOrderedSet: OS(@"c", @"d", @"e", @"a", @"b")],
      "the target index is relative to the set after the objects are removed");

    m = MOS(@"a", @"b", @"c", @"d");
    [m moveObjectsAtIndexes: [NSIndexSet indexSetWithIndex: 0] toIndex: 2];
    PASS([m isEqualToOrderedSet: OS(@"b", @"c", @"a", @"d")],
      "moving a single object");
  END_SET("NSMutableOrderedSet moveObjectsAtIndexes:toIndex:")

  return 0;
}
