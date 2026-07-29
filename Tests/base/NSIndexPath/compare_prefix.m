/*
 * compare_prefix.m - regression test for -[NSIndexPath compare:] ordering a
 * path and its own prefix.  The length branches were inverted, so a prefix
 * (shorter) path compared as ordered after the longer path instead of before.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static NSIndexPath *
path2(NSUInteger a, NSUInteger b, NSUInteger len)
{
  NSUInteger	idx[2];

  idx[0] = a; idx[1] = b;
  return [NSIndexPath indexPathWithIndexes: idx length: len];
}

int main(void)
{
  START_SET("NSIndexPath compare: prefix ordering")
    NSIndexPath	*shorter = path2(1, 0, 1);	/* [1]    */
    NSIndexPath	*longer  = path2(1, 9, 2);	/* [1, 9] */

    PASS([shorter compare: longer] == NSOrderedAscending,
      "a prefix index path sorts before the longer path");
    PASS([longer compare: shorter] == NSOrderedDescending,
      "the longer path sorts after its prefix");
    PASS([longer compare: path2(1, 9, 2)] == NSOrderedSame,
      "equal-length equal paths still compare the same");
  END_SET("NSIndexPath compare: prefix ordering")

  return 0;
}
