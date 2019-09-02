#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  NSArray* values = [NSArray arrayWithObjects:
        [NSNumber numberWithFloat:2.0],
        [NSNumber numberWithFloat:1.0],
        [NSNumber numberWithFloat:3.0],
        [NSNumber numberWithFloat:4.0],
        nil];

  NSArray* keys = [NSArray arrayWithObjects:
        @"shouldSortToSecond",
        @"shouldSortToFirst",
        @"shouldSortToThird",
        @"shouldSortToFourth",
        nil];

  NSDictionary *d = [NSDictionary dictionaryWithObjects:values forKeys:keys];
  NSArray* keysOrderedByKeyedValue = [d keysSortedByValueUsingComparator:
                      ^NSComparisonResult(id obj1, id obj2) {
                              return [(NSNumber*)obj1 compare:(NSNumber*)obj2];
                      }];

  NSArray* expected = [NSArray arrayWithObjects:
        @"shouldSortToFirst",
        @"shouldSortToSecond",
        @"shouldSortToThird",
        @"shouldSortToFourth",
        nil];

  PASS([keysOrderedByKeyedValue isEqual:expected], "Can sort a dictionary's keys by its values");

  [arp release]; arp = nil;
  return 0;
}
