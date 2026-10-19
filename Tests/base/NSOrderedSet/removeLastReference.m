/*
 * removeLastReference.m - regression test for -[NSMutableOrderedSet
 * removeObjectAtIndex:], which removed the object from its array (releasing
 * it) before removing it from its map (hashing it), so removing an object the
 * set held the last reference to used it after it was deallocated.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static BOOL	deallocated = NO;
static BOOL	usedAfterDealloc = NO;

@interface Tracked : NSObject
@end

@implementation Tracked
- (NSUInteger) hash
{
  if (deallocated)
    {
      usedAfterDealloc = YES;
    }
  return 42;
}

- (BOOL) isEqual: (id)other
{
  if (deallocated)
    {
      usedAfterDealloc = YES;
    }
  return self == other;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void) dealloc
{
  /* Leak the instance instead of freeing it, so that a use after
   * deallocation is detected instead of being undefined behaviour.
   */
  deallocated = YES;
}
#pragma clang diagnostic pop
@end

int main(void)
{
  START_SET("NSMutableOrderedSet removing the last reference")
    NSMutableOrderedSet	*m = [NSMutableOrderedSet new];
    Tracked		*o = [Tracked new];

    [m addObject: o];
    [o release];
    [m removeObjectAtIndex: 0];
    PASS(deallocated, "removeObjectAtIndex: releases the object");
    PASS(!usedAfterDealloc,
      "removeObjectAtIndex: doesn't use the object after releasing it");
    PASS([m count] == 0, "the set is empty");

    deallocated = NO;
    usedAfterDealloc = NO;
    o = [Tracked new];
    [m addObject: o];
    [o release];
    [m removeObject: o];
    PASS(deallocated, "removeObject: releases the object");
    PASS(!usedAfterDealloc,
      "removeObject: doesn't use the object after releasing it");
    [m release];
  END_SET("NSMutableOrderedSet removing the last reference")

  return 0;
}
