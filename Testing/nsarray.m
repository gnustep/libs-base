#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>

int
main()
{
  id a, b, c, d, e, f, g, h;			/* arrays */
  id enumerator;
  id i;
  id s = @"Hello World\n";
  id pool;
  id o1, o2, o3;
  unsigned int p;

  behavior_set_debug(0);

  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  pool = [[NSAutoreleasePool alloc] init];

  o1 = [NSNumber numberWithInt:1];
  o2 = [NSNumber numberWithInt:2];
  o3 = [NSNumber numberWithInt:3];
  a = [[[NSArray arrayWithObject:o1] arrayByAddingObject:o2] arrayByAddingObject:o3];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  b = [[a copy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  c = [[b mutableCopy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);
  d = [[c copy] autorelease];
  printf("%u,%u,%u\n", [o1 retainCount], [o2 retainCount], [o3 retainCount]);

  // NSArray tests
  {
    // Class methods for allocating and initializing an array
    printf("Method: +array\n");
    a = [NSArray array];
    if ([a count] == 0)
      printf("Empty array count is zero\n");
    else
      printf("Error: empty array count is not zero\n");

    printf("Method: +arrayWithObject:\n");
    b = [NSArray arrayWithObject: s];
    printf("NSArray has count %d\n", [b count]);
    if ([b count] != 1)
      printf("Error: count != 1\n");

    printf("Method: +arrayWithObjects:...\n");
    c = [NSArray arrayWithObjects: 
		 [NSObject class],
		 [NSArray class],
		 [NSMutableArray class],
		 nil];
    printf("NSArray has count %d\n", [c count]);
    if ([c count] != 3)
      printf("Error: count != 3\n");
  }

  {
    // Instance methods for allocating and initializing an array
    printf("Method: -arrayByAddingObject:\n");
    d = [c arrayByAddingObject: s];
    printf("NSArray has count %d\n", [c count]);
    if ([d count] != 4)
      printf("Error: count != 4\n");

    printf("Method: -arrayByAddingObjectsFromArray:\n");
    e = [c arrayByAddingObjectsFromArray: b];
    printf("NSArray has count %d\n", [c count]);
    if ([e count] != 4)
      printf("Error: count != 4\n");
  }

  {
    // Querying the arra
    assert([c containsObject:[NSObject class]]);

    p = [e indexOfObject:@"Hello World\n"];
    if (p == NSNotFound)
      printf("Error: index of object not found\n");
    else
      printf("Index of object is %d\n", p);

    p = [e indexOfObjectIdenticalTo:s];
    if (p == NSNotFound)
      printf("Error: index of identical object not found\n");
    else
      printf("Index of identical object is %d\n", p);

    assert([c lastObject]);
    printf("Classname at index 2 is %s\n", [[c objectAtIndex:2] name]);

    printf("Forward enumeration\n");
    enumerator = [e objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Reverse enumeration\n");
    enumerator = [e reverseObjectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");
  }

  {
    // Sending messages to elements
    [c makeObjectsPerform:@selector(name)];

    //[c makeObjectsPerform:@selector(isEqual:) withObject: @"NSArray"];
  }

  {
    // Comparing arrays
    assert([d firstObjectCommonWithArray:e]);

    if ([d isEqualToArray: d])
      printf("NSArray is equal to itself\n");
    else
      printf("Error: NSArray is not equal to itself\n");

    if ([d isEqualToArray: e])
      printf("NSArrays are equal\n");
    else
      printf("Error: NSArrays are not equal\n");
  }

  {
    int compare(id elem1, id elem2, void* context)
      {
	return (int)[elem1 performSelector:@selector(compare:) withObject:elem2];
      }

    // Deriving new arrays
    NSRange r = NSMakeRange(0, 3);

    f = [NSMutableArray array];
    [f addObject: @"Lions"];
    [f addObject: @"Tigers"];
    [f addObject: @"Bears"];
    [f addObject: @"Penguins"];
    [f addObject: @"Giraffes"];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i cString]);
    printf("\n");

    printf("Method: -sortedArrayUsingSelector:\n");
    g = [f sortedArrayUsingSelector: @selector(compare:)];
    printf("Method: -sortedArrayUsingFunction:context:\n");
    h = [f sortedArrayUsingFunction: compare context: NULL];
    
    enumerator = [g objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i cString]);
    printf("\n");

    if (([g isEqualToArray: h]) && (![g isEqualToArray: f]))
      printf("Sorted arrays are correct\n");
    else
      printf("Error: Sorted arrays are not correct\n");

    printf("Method: -subarrayWithRange:\n");
    f = [e subarrayWithRange: r];

    printf("NSArray has count %d\n", [f count]);
    if ([f count] != 3)
      printf("Error: count != 3\n");

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    if ([f isEqualToArray: c])
      printf("Subarray is correct\n");
    else
      printf("Error: Subarray does not have correct elements\n");
  }

  {
    // Joining string elements
    printf("Method: -componentsJoinedByString:\n");
    i = [c componentsJoinedByString: @"/"];
    if ([i isEqual: @"<NSObject>/<NSArray>/<NSMutableArray>"])
      printf("%s is correct\n", [i cString]);
    else
      {
	printf("Error: %s is not correct\n", [i cString]);
	printf("Should be NSObject/NSArray/NSMutableArray\n");
      }
  }

  {
    // Creating a string description of the array
    /* What do the -description methods do?
       [e description]
       [e descriptionWithLocale:]
       [e descriptionWithLocale: indent:]
       */
  }

  // NSMutableArray tests
  printf("*** Start of NSMutableArray tests\n");
  {
    // Creating and initializing an NSMutableArray
    f = [NSMutableArray arrayWithCapacity: 10];
    assert(f);
    f = [[NSMutableArray alloc] initWithCapacity: 10];
    [f release];
    assert(f);
  }

  {
    // Adding objects
    f = [e mutableCopy];
    assert([f count]);

    printf("Method -addObject:[NSObject class]\n");
    [f addObject:[NSObject class]];
    printf("NSMutableArray has count %d\n", [f count]);
    if ([f count] != 5)
      printf("Error: count != 5\n");

    printf("Method -addObjectsFromArray:\n");
    [f addObjectsFromArray: c];
    printf("NSMutableArray has count %d\n", [f count]);
    if ([f count] != 8)
      printf("Error: count != 8\n");

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -insertObject: [NSMutableArray class] atIndex: 2\n");
    [f insertObject: [NSMutableArray class] atIndex: 2];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

  }

  g = [f mutableCopy];
  h = [f mutableCopy];

  {
    // Removing objects
    unsigned int ind[7] = {7, 4, 1, 3, 5, 0, 6};

    printf("Method -removeAllObjects\n");
    printf("Array count is %d\n", [h count]);
    [h removeAllObjects];
    printf("Array count is %d\n", [h count]);
    if ([h count] != 0)
      printf("Error: count != 0\n");

    h = [f mutableCopy];

    printf("Method -removeLastObject\n");
    [f removeLastObject];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -removeObject: [NSObject class]\n");
    [f removeObject: [NSObject class]];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -removeObjectIdenticalTo: [NSArray class]\n");
    [f removeObjectIdenticalTo: [NSArray class]];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -removeObjectAtIndex: 2\n");
    [f removeObjectAtIndex: 2];

    enumerator = [f objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -removeObjectsFromIndices: {7,4,1,3,5,0,6} "
	   "numIndices: 6\n");
    enumerator = [g objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");
    [g removeObjectsFromIndices: ind numIndices: 7];
    enumerator = [g objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    if ([f isEqualToArray: g])
      printf("Remove methods worked properly\n");
    else
      printf("Error: remove methods failed\n");

    printf("Method -removeObjectsInArray:\n");
    printf("Receiver array\n");
    enumerator = [h objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");
    printf("Removing objects in this array\n");
    enumerator = [c objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    [h removeObjectsInArray: c];

    printf("Array count is %d\n", [h count]);
    if ([h count] != 1)
      printf("Error: count != 1\n");

    printf("%s", [[h objectAtIndex: 0] cString]);
    if ([[h objectAtIndex: 0] isEqual: s])
      printf("-removeObjectsInArray: worked correctly\n");
    else
      printf("Error: object in array is not correct\n");
  }

  {
    // Replacing objects
    c = [[c mutableCopy] autorelease];
    printf("Method -replaceObjectAtIndex: 2 withObject:[NSString class]\n");
    enumerator = [c objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");
    [c replaceObjectAtIndex: 2 withObject:[NSString class]];
    enumerator = [c objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");

    printf("Method -setArray:\n");
    [h setArray: f];
    enumerator = [h objectEnumerator];
    while ((i = [enumerator nextObject]))
      printf("%s ", [i name]);
    printf("\n");
    if ([h isEqualToArray: h])
      printf("-setArray worked properly\n");
    else
      printf("Error: array is incorrect\n");
  }

  {
    // Sorting Elements
    //[ sortUsingFunction: context:];
    //[ sortUsingSelector:];
  }

  [pool release];

  exit(0);
}
