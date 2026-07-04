/*
 * compact.m - regression test for -[NSPointerArray compact].  The insertion
 * point was only advanced when a pointer was actually moved, so the non-nil
 * pointers before the first nil were overwritten and lost (compacting
 * [a, nil, b] produced [b]).
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static id
at(NSPointerArray *p, NSUInteger i)
{
  return (id)[p pointerAtIndex: i];
}

int main(void)
{
  START_SET("NSPointerArray compact")
    NSPointerArray	*p;

    p = [NSPointerArray strongObjectsPointerArray];
    [p addPointer: (void *)@"a"];
    [p addPointer: NULL];
    [p addPointer: (void *)@"b"];
    [p compact];
    PASS([p count] == 2, "compact removes an interior NULL without losing objects");
    PASS([at(p, 0) isEqual: @"a"] && [at(p, 1) isEqual: @"b"],
      "compact keeps the non-NULL pointers in order");

    p = [NSPointerArray strongObjectsPointerArray];
    [p addPointer: NULL];
    [p addPointer: (void *)@"a"];
    [p addPointer: NULL];
    [p addPointer: (void *)@"b"];
    [p addPointer: NULL];
    [p compact];
    PASS([p count] == 2 && [at(p, 0) isEqual: @"a"] && [at(p, 1) isEqual: @"b"],
      "compact removes leading, interior and trailing NULLs");

    p = [NSPointerArray strongObjectsPointerArray];
    [p addPointer: (void *)@"a"];
    [p addPointer: (void *)@"b"];
    [p addPointer: (void *)@"c"];
    [p compact];
    PASS([p count] == 3 && [at(p, 0) isEqual: @"a"] && [at(p, 2) isEqual: @"c"],
      "compact leaves a NULL-free array unchanged");
  END_SET("NSPointerArray compact")

  return 0;
}
