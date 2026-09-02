/*
 * mutation.m - tests for NSPointerArray operations the other tests do not
 * cover: pointerAtIndex:, removePointerAtIndex:, replacePointerAtIndex:,
 * setCount: (growing with NULLs and shrinking), adding a NULL pointer, and
 * compact.  Uses a strong-objects pointer array for deterministic results.
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
  START_SET("NSPointerArray add, insert and access")
    NSPointerArray	*p = [NSPointerArray strongObjectsPointerArray];

    PASS([p count] == 0, "a new pointer array is empty");
    [p addPointer: (void *)@"a"];
    [p addPointer: (void *)@"b"];
    [p addPointer: (void *)@"c"];
    PASS([p count] == 3, "addPointer: appends");
    PASS_EQUAL(at(p, 0), @"a", "pointerAtIndex: returns the first pointer");
    PASS_EQUAL(at(p, 2), @"c", "pointerAtIndex: returns a later pointer");

    [p insertPointer: (void *)@"x" atIndex: 1];
    PASS([p count] == 4 && [at(p, 1) isEqual: @"x"] && [at(p, 2) isEqual: @"b"],
      "insertPointer:atIndex: inserts and shifts");
  END_SET("NSPointerArray add, insert and access")

  START_SET("NSPointerArray remove and replace")
    NSPointerArray	*p = [NSPointerArray strongObjectsPointerArray];

    [p addPointer: (void *)@"a"];
    [p addPointer: (void *)@"b"];
    [p addPointer: (void *)@"c"];

    [p removePointerAtIndex: 1];
    PASS([p count] == 2 && [at(p, 1) isEqual: @"c"],
      "removePointerAtIndex: removes and shifts the following pointers");

    [p replacePointerAtIndex: 0 withPointer: (void *)@"z"];
    PASS([p count] == 2 && [at(p, 0) isEqual: @"z"],
      "replacePointerAtIndex:withPointer: replaces in place");
  END_SET("NSPointerArray remove and replace")

  START_SET("NSPointerArray setCount and NULL")
    NSPointerArray	*p = [NSPointerArray strongObjectsPointerArray];

    [p addPointer: (void *)@"a"];
    [p addPointer: (void *)@"b"];

    [p setCount: 4];
    PASS([p count] == 4 && at(p, 3) == nil,
      "setCount: to a larger value pads with NULL");
    [p setCount: 1];
    PASS([p count] == 1 && [at(p, 0) isEqual: @"a"],
      "setCount: to a smaller value truncates");

    p = [NSPointerArray strongObjectsPointerArray];
    [p addPointer: (void *)@"a"];
    [p addPointer: NULL];
    [p addPointer: (void *)@"b"];
    PASS([p count] == 3, "a NULL pointer can be stored");
  END_SET("NSPointerArray setCount and NULL")

  return 0;
}
