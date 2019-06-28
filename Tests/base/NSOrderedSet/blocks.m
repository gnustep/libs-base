#import "Testing.h"
#import <Foundation/NSOrderedSet.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>

static NSUInteger fooCount = 0;
static NSUInteger lastIndex = NSNotFound;
int main()
{
  START_SET("NSOrderedSet Blocks")
# ifndef __has_feature
# define __has_feature(x) 0
# endif
# if __has_feature(blocks)
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  // Code for test here...
  NSMutableOrderedSet *mutableTest4 = [NSMutableOrderedSet orderedSet];
  [mutableTest4 addObject:@"Now"];
  [mutableTest4 addObject:@"is"];
  [mutableTest4 addObject:@"the"];
  [mutableTest4 addObject:@"time"];
  [mutableTest4 addObject:@"for"];
  [mutableTest4 addObject:@"all"];
  [mutableTest4 addObject:@"Good"];
  [mutableTest4 addObject:@"men"];
  [mutableTest4 addObject:@"to"];
  [mutableTest4 addObject:@"come to"];
  [mutableTest4 addObject:@"the aid"];
  [mutableTest4 addObject:@"of their country"];
  NSMutableIndexSet *is = [NSMutableIndexSet indexSetWithIndex:6];
  [is addIndex: 9];
  NSMutableArray *array = [NSMutableArray arrayWithObjects:@"Horrible", @"Flee From", nil];
  [mutableTest4 replaceObjectsAtIndexes: is
			    withObjects: array];
  
  NSUInteger index =  [mutableTest4 indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return [obj isEqualToString:@"Horrible"];
    }];
  // NSLog(@"Index = %d", index);
  PASS(index == 6, "Found correct index using indexOfObjectPassingTest:");
    
# else
  SKIP("No Blocks support in the compiler.")
# endif
  END_SET("NSOrderedSet Blocks")
  return 0;
}
