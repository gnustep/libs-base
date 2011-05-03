#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

int main()
{
  NSArray *obj;
  NSMutableArray *testObjs = [[NSMutableArray alloc] init];
  NSString *str;
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  test_alloc(@"NSArray"); 
  obj = [NSArray new];
  PASS((obj != nil && [obj count] == 0),"can create an empty array");
  str = @"hello";
  [testObjs addObject: obj];
  obj = [NSArray arrayWithObject:str];
  PASS((obj != nil && [obj count] == 1), "can create an array with one element");
  [testObjs addObject: obj];
  test_NSObject(@"NSArray", testObjs);
  test_NSCoding(testObjs);
  test_NSCopying(@"NSArray",@"NSMutableArray",testObjs,YES,NO);
  test_NSMutableCopying(@"NSArray",@"NSMutableArray",testObjs);
  
  obj = [NSArray arrayWithContentsOfFile: @"test.plist"];
  PASS((obj != nil && [obj count] > 0),"can create an array from file");
#if 1
  /* The apple foundation is arguably buggy in that it seems to create a
   * mutable array ... we currently copy that
   */
  PASS([obj isKindOfClass: [NSMutableArray class]] == YES,"array mutable");
  PASS_RUNS([obj addObject: @"x"],"can add to array");
#else
  PASS([obj isKindOfClass: [NSMutableArray class]] == NO,"array immutable");
#endif
  obj = [obj objectAtIndex: 0];
  PASS([obj isKindOfClass: [NSMutableArray class]] == YES,"array mutable");
  [arp release]; arp = nil;
  return 0;
}
