/*
 * compare_getindexes.m - tests for NSIndexPath behaviour general.m does not
 * cover: getIndexes:, the equal and prefix cases of compare:, and equal-path
 * isEqual: / hash.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static NSIndexPath *
path(NSUInteger a, NSUInteger b, NSUInteger c, NSUInteger len)
{
  NSUInteger	idx[3];

  idx[0] = a; idx[1] = b; idx[2] = c;
  return [NSIndexPath indexPathWithIndexes: idx length: len];
}

int main(void)
{
  START_SET("NSIndexPath getIndexes and equality")
    NSIndexPath	*p = path(2, 5, 9, 3);
    NSUInteger	buf[3];

    PASS([p length] == 3, "length is the number of indexes");
    [p getIndexes: buf];
    PASS(buf[0] == 2 && buf[1] == 5 && buf[2] == 9,
      "getIndexes: fills the buffer with every index in order");

    PASS([p isEqual: path(2, 5, 9, 3)] == YES,
      "index paths with the same indexes are equal");
    PASS([p hash] == [path(2, 5, 9, 3) hash],
      "equal index paths have equal hashes");
    PASS([p isEqual: path(2, 5, 8, 3)] == NO,
      "index paths with different indexes are not equal");
  END_SET("NSIndexPath getIndexes and equality")

  START_SET("NSIndexPath compare:")
    NSIndexPath	*p = path(1, 9, 0, 2);	/* [1, 9] */

    PASS([p compare: path(1, 9, 0, 2)] == NSOrderedSame,
      "equal index paths compare the same");
    PASS([p compare: path(1, 2, 0, 2)] == NSOrderedDescending,
      "a larger index at a position orders later");
    PASS([p compare: path(2, 0, 0, 2)] == NSOrderedAscending,
      "a smaller index at the first position orders earlier");
  END_SET("NSIndexPath compare:")

  return 0;
}
