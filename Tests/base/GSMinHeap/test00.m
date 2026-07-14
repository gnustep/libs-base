#import "Testing.h"
#import <Foundation/Foundation.h>
#import "GNUstepBase/GSMinHeap.h"

static NSComparisonResult
ReverseComparator(id a, id b)
{
  return [b compare: a];
}

int
main(void)
{
  GSMinHeap *heap;
  id obj;

  START_SET("GSMinHeap")

  heap = [[GSMinHeap alloc] init];

  PASS(heap != nil, "can create heap with default init");

  PASS([heap peek] == nil, "peek on empty heap returns nil");
  PASS([heap pop] == nil, "pop on empty heap returns nil");

  PASS([heap push: nil] == NO, "cannot push nil");
  PASS([heap peek] == nil, "heap still empty after push:nil");

  PASS([heap push: @"c"] == YES, "push first object");
  PASS([[heap peek] isEqual: @"c"], "peek returns first object");

  PASS([heap push: @"a"] == YES, "push smaller object");
  PASS([[heap peek] isEqual: @"a"], "peek returns minimum object");

  PASS([heap push: @"b"] == YES, "push third object");

  obj = [heap pop];
  PASS([obj isEqual: @"a"], "first pop returns smallest object");

  obj = [heap pop];
  PASS([obj isEqual: @"b"], "second pop returns second smallest object");

  obj = [heap pop];
  PASS([obj isEqual: @"c"], "third pop returns largest object");

  PASS([heap pop] == nil, "heap empty after removing all objects");

  DESTROY(heap);

  END_SET("GSMinHeap")

  START_SET("capacity growth")

  heap = [[GSMinHeap alloc] initWithCapacity: 1
                               andComparator: NULL];

  for (int i = 100; i >= 0; i--)
    {
      PASS([heap push: [NSNumber numberWithInt: i]] == YES,
        "push succeeds");
    }

  PASS([[[heap peek] stringValue] isEqual: @"0"],
    "minimum survives resizing");

  for (int i = 0; i <= 100; i++)
    {
      NSNumber *n = [heap pop];
      PASS([n intValue] == i, "pop returns values in ascending order");
    }

  PASS([heap pop] == nil, "heap empty after growth test");

  DESTROY(heap);

  END_SET("capacity growth")

  START_SET("custom comparator")

  heap = [[GSMinHeap alloc] initWithCapacity: 0
                               andComparator: ReverseComparator];

  [heap push: @"a"];
  [heap push: @"c"];
  [heap push: @"b"];

  PASS([[heap peek] isEqual: @"c"],
    "custom comparator changes ordering");

  obj = [heap pop];
  PASS([obj isEqual: @"c"], "first pop uses custom comparator");

  obj = [heap pop];
  PASS([obj isEqual: @"b"], "second pop uses custom comparator");

  obj = [heap pop];
  PASS([obj isEqual: @"a"], "third pop uses custom comparator");

  DESTROY(heap);

  END_SET("custom comparator")

  START_SET("empty")

  heap = [[GSMinHeap alloc] init];

  [heap push: @"b"];
  [heap push: @"a"];
  [heap push: @"c"];

  [heap empty];

  PASS([heap peek] == nil, "peek after empty returns nil");
  PASS([heap pop] == nil, "pop after empty returns nil");

  PASS([heap push: @"x"] == YES,
    "heap remains usable after empty");

  PASS([[heap pop] isEqual: @"x"],
    "heap functions correctly after empty");

  DESTROY(heap);

  END_SET("empty")

  return 0;
}
