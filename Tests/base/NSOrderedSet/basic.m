#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
/*
#import <Foundation/NSOrderedSet.h>
 */

int main()
{
  START_SET("NSOrderedSet base")

/*
  NSOrderedSet *testObj;
  NSMutableArray *testObjs = [NSMutableArray new];

  testObj = [NSOrderedSet new];
  [testObjs addObject: testObj];
  PASS(testObj != nil && [testObj count] == 0,
    "can create an empty ordered set");
   
  testObj = [NSOrderedSet setWithObject: @"Hello"];
  [testObjs addObject: testObj];
  PASS(testObj != nil && [testObj count] == 1,
    "can create an ordered set with one element");
  
  test_NSObject(@"NSOrderedSet", testObjs);
  test_NSCoding(testObjs);
  test_NSCopying(@"NSOrderedSet", @"NSMutableOrderedSet", testObjs, YES, NO);
  test_NSMutableCopying(@"NSOrderedSet", @"NSMutableOrderedSet", testObjs);
*/

  END_SET("NSOrderedSet base")
  return 0;
}
