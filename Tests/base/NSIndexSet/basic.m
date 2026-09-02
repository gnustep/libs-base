/*
 * basic.m - tests for the core (non-block) NSIndexSet and NSMutableIndexSet
 * API: creation and count, containment and range queries, the first/last and
 * greater/less-than navigation (including the NSNotFound boundaries),
 * isEqualToIndexSet:, getIndexes:..., and the NSMutableIndexSet add / remove /
 * shift operations.  All deterministic.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSIndexSet creation and count")
    NSIndexSet	*s = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(2, 4)];

    PASS([[NSIndexSet indexSet] count] == 0, "+indexSet is empty");
    PASS([[NSIndexSet indexSetWithIndex: 5] count] == 1,
      "+indexSetWithIndex: has one index");
    PASS([s count] == 4, "+indexSetWithIndexesInRange: counts the range length");
    PASS([s firstIndex] == 2, "firstIndex is the range start");
    PASS([s lastIndex] == 5, "lastIndex is NSMaxRange - 1");
    PASS([[NSIndexSet indexSet] firstIndex] == NSNotFound,
      "firstIndex of an empty set is NSNotFound");
    PASS([[NSIndexSet indexSet] lastIndex] == NSNotFound,
      "lastIndex of an empty set is NSNotFound");
  END_SET("NSIndexSet creation and count")

  START_SET("NSIndexSet containment and range queries")
    NSIndexSet	*s = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(2, 4)];

    PASS([s containsIndex: 3] == YES, "containsIndex: is YES for a member");
    PASS([s containsIndex: 6] == NO, "containsIndex: is NO for a non-member");
    PASS([s containsIndexesInRange: NSMakeRange(3, 2)] == YES,
      "containsIndexesInRange: is YES when the whole range is present");
    PASS([s containsIndexesInRange: NSMakeRange(4, 4)] == NO,
      "containsIndexesInRange: is NO when part of the range is absent");
    PASS([s intersectsIndexesInRange: NSMakeRange(5, 3)] == YES,
      "intersectsIndexesInRange: is YES on an overlap");
    PASS([s intersectsIndexesInRange: NSMakeRange(6, 3)] == NO,
      "intersectsIndexesInRange: is NO with no overlap");
    PASS([s countOfIndexesInRange: NSMakeRange(0, 4)] == 2,
      "countOfIndexesInRange: counts only the members in the range");
    PASS([s containsIndexes: [NSIndexSet indexSetWithIndexesInRange:
      NSMakeRange(3, 2)]] == YES, "containsIndexes: is YES for a subset");
  END_SET("NSIndexSet containment and range queries")

  START_SET("NSIndexSet navigation")
    NSIndexSet	*s = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(2, 4)];

    PASS([s indexGreaterThanIndex: 2] == 3, "indexGreaterThanIndex: steps up");
    PASS([s indexGreaterThanIndex: 5] == NSNotFound,
      "indexGreaterThanIndex: past the last index is NSNotFound");
    PASS([s indexGreaterThanIndex: 0] == 2,
      "indexGreaterThanIndex: below the set returns the first index");
    PASS([s indexGreaterThanOrEqualToIndex: 2] == 2,
      "indexGreaterThanOrEqualToIndex: returns the index itself when present");
    PASS([s indexLessThanIndex: 5] == 4, "indexLessThanIndex: steps down");
    PASS([s indexLessThanIndex: 2] == NSNotFound,
      "indexLessThanIndex: below the first index is NSNotFound");
    PASS([s indexLessThanOrEqualToIndex: 5] == 5,
      "indexLessThanOrEqualToIndex: returns the index itself when present");
  END_SET("NSIndexSet navigation")

  START_SET("NSIndexSet equality and getIndexes")
    NSIndexSet	*s = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(2, 4)];
    NSUInteger	buf[8];
    NSUInteger	got;

    PASS([s isEqualToIndexSet: [NSIndexSet indexSetWithIndexesInRange:
      NSMakeRange(2, 4)]] == YES, "isEqualToIndexSet: is YES for equal sets");
    PASS([s isEqualToIndexSet: [NSIndexSet indexSetWithIndex: 2]] == NO,
      "isEqualToIndexSet: is NO for different sets");

    got = [s getIndexes: buf maxCount: 8 inIndexRange: NULL];
    PASS(got == 4 && buf[0] == 2 && buf[1] == 3 && buf[2] == 4 && buf[3] == 5,
      "getIndexes: fills the buffer with every index in order");
  END_SET("NSIndexSet equality and getIndexes")

  START_SET("NSMutableIndexSet mutation")
    NSMutableIndexSet	*m = [NSMutableIndexSet indexSet];

    [m addIndex: 5];
    [m addIndexesInRange: NSMakeRange(10, 3)];	/* 10,11,12 */
    PASS([m count] == 4 && [m containsIndex: 5] && [m containsIndex: 12],
      "addIndex: and addIndexesInRange: add indexes");

    [m removeIndex: 11];
    PASS([m count] == 3 && ![m containsIndex: 11],
      "removeIndex: removes a single index");

    [m removeIndexesInRange: NSMakeRange(10, 3)];	/* removes 10,12 (11 gone) */
    PASS([m count] == 1 && [m containsIndex: 5]
      && ![m containsIndex: 10] && ![m containsIndex: 12],
      "removeIndexesInRange: removes the indexes in the range");

    [m removeAllIndexes];
    PASS([m count] == 0, "removeAllIndexes empties the set");
  END_SET("NSMutableIndexSet mutation")

  START_SET("NSMutableIndexSet shiftIndexesStartingAtIndex")
    NSMutableIndexSet	*m
      = [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(5, 3)];  /* 5,6,7 */

    [m shiftIndexesStartingAtIndex: 5 by: 100];
    PASS([m count] == 3 && [m firstIndex] == 105 && [m lastIndex] == 107,
      "a positive shift moves the indexes up");

    [m shiftIndexesStartingAtIndex: 105 by: -100];
    PASS([m count] == 3 && [m firstIndex] == 5 && [m lastIndex] == 7,
      "a negative shift moves the indexes back down");
  END_SET("NSMutableIndexSet shiftIndexesStartingAtIndex")

  return 0;
}
