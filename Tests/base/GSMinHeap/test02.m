#import "Testing.h"
#import <Foundation/Foundation.h>
#import "GNUstepBase/GSMinHeap.h"

int
main(void)
{
  GSMinHeap	*heap;
  id		obj;

  START_SET("reposition smaller")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a = [NSMutableString stringWithString: @"m"];
  NSMutableString *b = [NSMutableString stringWithString: @"b"];

  [heap push: a];
  [heap push: b];

  PASS([[heap peek] isEqual: @"b"],
    "'b' orders beforew 'm'");

  [a setString: @"a"];

  PASS([[heap peek] isEqual: @"b"],
    "heap unchanged before reposition");

  PASS([heap repositionObject: a] == a,
    "reposition returns object");

  PASS([[heap peek] isEqual: @"a"],
    "object moved to root after becoming smaller");

  DESTROY(heap);

  END_SET("reposition smaller")

  START_SET("reposition larger")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a = [NSMutableString stringWithString: @"a"];
  NSMutableString *b = [NSMutableString stringWithString: @"b"];
  NSMutableString *c = [NSMutableString stringWithString: @"c"];

  [heap push:a];
  [heap push:b];
  [heap push:c];

  [a setString: @"z"];

  PASS([heap repositionObject:a] == a,
    "reposition succeeds");

  PASS([[heap peek] isEqual: @"b"],
    "next smallest promoted");

  PASS([[[heap pop] description] isEqual: @"b"],
    "first pop correct");

  PASS([[[heap pop] description] isEqual: @"c"],
    "second pop correct");

  PASS([[[heap pop] description] isEqual: @"z"],
    "modified object now last");

  DESTROY(heap);

  END_SET("reposition larger")

  START_SET("reposition absent")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a = [NSMutableString stringWithString: @"a"];

  PASS([heap repositionObject:a] == nil,
    "reposition absent object returns nil");

  DESTROY(heap);

  END_SET("reposition absent")

  START_SET("reposition duplicate identities")


  heap = [[GSMinHeap alloc] init];

  NSMutableString *a = [NSMutableString stringWithString: @"b"];

  [heap push:a];
  [heap push:a];
  [heap push:a];

  PASS([heap count] == 3,
    "same object may be inserted repeatedly");

  [a setString: @"a"];

  [heap repositionObject:a];

  PASS([heap count] == 1,
    "reposition removes duplicate identities");

  PASS([[heap pop] isEqual: @"a"],
    "single repositioned object remains");

  DESTROY(heap);

  END_SET("reposition duplicate identities")

  START_SET("reposition ordering")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *m = [NSMutableString stringWithString: @"m"];

  [heap push: @"a"];
  [heap push: @"c"];
  [heap push:m];
  [heap push: @"x"];
  [heap push: @"z"];

  [m setString: @"b"];

  [heap repositionObject:m];

  PASS([[[heap pop] description] isEqual: @"a"],
    "first pop correct");

  PASS([[[heap pop] description] isEqual: @"b"],
    "repositioned object in correct position");

  PASS([[[heap pop] description] isEqual: @"c"],
    "remaining heap still ordered");

  PASS([[[heap pop] description] isEqual: @"x"],
    "heap property maintained");

  PASS([[[heap pop] description] isEqual: @"z"],
    "heap property maintained");

  DESTROY(heap);

  END_SET("reposition ordering")

  return 0;
}
