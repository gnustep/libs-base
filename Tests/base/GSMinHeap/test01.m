#import "Testing.h"
#import <Foundation/Foundation.h>
#import "GNUstepBase/GSMinHeap.h"

int
main(void)
{
  GSMinHeap	*heap;
  id		obj;


  START_SET("contains")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a1 = [NSMutableString stringWithString: @"abc"];
  NSMutableString *a2 = [NSMutableString stringWithString: @"abc"];
  NSMutableString *b  = [NSMutableString stringWithString: @"def"];

  [heap push: a1];
  [heap push: b];

  PASS([heap containsObject: a1] == YES,
    "containsObject finds identical object")

  PASS([heap containsObject: a2] == YES,
    "containsObject uses isEqual:")

  PASS([heap containsObjectIdenticalTo: a1] == YES,
    "containsObjectIdenticalTo finds same pointer")

  PASS([heap containsObjectIdenticalTo: a2] == NO,
    "containsObjectIdenticalTo distinguishes equal objects")

  PASS([heap containsObject: @"zzz"] == NO,
    "containsObject returns NO when absent")

  DESTROY(heap);

  END_SET("contains")

  START_SET("removeObject")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a1 = [NSMutableString stringWithString: @"a"];
  NSMutableString *a2 = [NSMutableString stringWithString: @"a"];
  NSMutableString *b  = [NSMutableString stringWithString: @"b"];

  [heap push: a1];
  [heap push: a2];
  [heap push: b];

  [heap removeObject: @"a"];

  PASS([heap count] == 1,
    "removeObject removes all equal objects")

  PASS([[heap pop] isEqual: @"b"],
    "remaining object correct")

  PASS([heap pop] == nil,
    "heap empty after removal")

  DESTROY(heap);

  END_SET("removeObject")


  START_SET("removeObjectIdenticalTo")

  heap = [[GSMinHeap alloc] init];

  NSMutableString *a1 = [NSMutableString stringWithString: @"a"];
  NSMutableString *a2 = [NSMutableString stringWithString: @"a"];

  [heap push: a1];
  [heap push: a2];

  [heap removeObjectIdenticalTo: a1];

  PASS([heap count] == 1,
    "removeObjectIdenticalTo removes only identical object")

  PASS([heap containsObjectIdenticalTo: a1] == NO,
    "removed identical object absent")

  PASS([heap containsObjectIdenticalTo: a2] == YES,
    "equal but different object remains")

  DESTROY(heap);

  END_SET("removeObjectIdenticalTo")


  return 0;
}
