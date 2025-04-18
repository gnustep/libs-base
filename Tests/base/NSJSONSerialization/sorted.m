#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

void testLexicographicalOrder() {
  NSArray *objects =
      [NSArray arrayWithObjects:@"a", @"b", @"c", @"d", @"e", nil];
  NSArray *keys = [NSArray
      arrayWithObjects:@"c_ab", @"a_ab", @"d_ab", @"f_cb", @"f_ab", nil];
  NSDictionary *dict = [NSDictionary dictionaryWithObjects:objects
                                                   forKeys:keys];

  NSError *error = nil;
  NSData *actualData =
      [NSJSONSerialization dataWithJSONObject:dict
                                      options:NSJSONWritingSortedKeys
                                        error:&error];
  PASS_EQUAL(error, nil, "no error occurred during serialisation");


  NSString *actual = [[NSString alloc] initWithData:actualData
                                           encoding:NSUTF8StringEncoding];
  NSString *expected = @"{\"a_ab\":\"b\",\"c_ab\":\"a\",\"d_ab\":\"c\",\"f_"
                        "ab\":\"e\",\"f_cb\":\"d\"}";
  PASS_EQUAL(actual, expected, "JSON is correctly sorted");
  NSLog(@"%@", actual);
}

int main(void) {
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  testLexicographicalOrder();

  [arp release];
}