#import "Testing.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>


static NSUInteger fooCount = 0;
static NSUInteger lastIndex = NSNotFound;
int main()
{
  START_SET("NSArray Blocks")
# ifndef __has_feature
# define __has_feature(x) 0
# endif
# if __has_feature(blocks)
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  NSArray *array = [NSArray arrayWithObjects: @"foo", @"bar", @"foo", nil];
  void(^enumBlock)(id,NSUInteger,BOOL*) =  ^(id obj, NSUInteger index, BOOL *stop){
    if ([obj isEqual: @"foo"]){ fooCount++;} lastIndex = index;};
  [array enumerateObjectsUsingBlock: enumBlock];
  PASS((2 == fooCount) && (lastIndex == 2),
       "Can forward enumerate array using a block");
  fooCount = 0;
  lastIndex = NSNotFound;
  [array enumerateObjectsWithOptions: NSEnumerationConcurrent
                          usingBlock: enumBlock];
  PASS((2 == fooCount) && (lastIndex == 2),
       "Can forward enumerate array concurrently using a block");
  fooCount = 0;
  lastIndex = NSNotFound;
  [array enumerateObjectsWithOptions: NSEnumerationReverse
                          usingBlock: enumBlock];
  PASS((0 == lastIndex), "Can enumerate array in reverse using a block");
  fooCount = 0;
  lastIndex = NSNotFound;
  enumBlock = ^(id obj, NSUInteger index, BOOL *stop){if ([obj isEqual: @"foo"]){
    fooCount++;} else if ([obj isEqual: @"bar"]){ *stop=YES;}; lastIndex =
    index;};
  [array enumerateObjectsUsingBlock: enumBlock];
  PASS(((1 == fooCount) && (lastIndex == 1)),
    "Block can stop enumeration prematurely.");

  NSIndexSet *set = [array indexesOfObjectsPassingTest: ^(id obj, NSUInteger index, BOOL* stop){ if ([obj isEqual: @"foo"]) { return YES;} return NO;}];
  PASS(((2 == [set count])
    && (YES == [set containsIndex: 0])
    && (YES == [set containsIndex: 2])
    && (NO == [set containsIndex: 1])),
    "Can select object indices based on block predicate.");
  [arp release]; arp = nil;
# else
  SKIP("No Blocks support in the compiler.")
# endif
  END_SET("NSArray Blocks")
  return 0;
}
