/*
 * descriptors.m - tests for NSSortDescriptor behaviour that basic.m does not
 * cover: the key/ascending accessors, reversedSortDescriptor, the equal case of
 * compareObject:toObject:, a custom-selector descriptor, and single-descriptor
 * ascending/descending sorting.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static NSDictionary *
row(NSString *name)
{
  return [NSDictionary dictionaryWithObject: name forKey: @"name"];
}

int main(void)
{
  START_SET("NSSortDescriptor accessors and reversal")
    NSSortDescriptor	*s = [NSSortDescriptor sortDescriptorWithKey: @"name"
							  ascending: YES];
    NSSortDescriptor	*r = [s reversedSortDescriptor];

    PASS_EQUAL([s key], @"name", "key returns the descriptor key");
    PASS([s ascending] == YES, "ascending returns the sort direction");
    PASS_EQUAL([r key], @"name",
      "reversedSortDescriptor keeps the same key");
    PASS([r ascending] == NO,
      "reversedSortDescriptor flips the sort direction");
  END_SET("NSSortDescriptor accessors and reversal")

  START_SET("NSSortDescriptor compareObject:toObject:")
    NSSortDescriptor	*asc = [NSSortDescriptor sortDescriptorWithKey: @"name"
							    ascending: YES];
    NSSortDescriptor	*desc = [NSSortDescriptor sortDescriptorWithKey: @"name"
							     ascending: NO];
    NSDictionary	*a = row(@"a");
    NSDictionary	*b = row(@"b");

    PASS([asc compareObject: a toObject: b] == NSOrderedAscending,
      "an ascending descriptor orders a before b");
    PASS([asc compareObject: b toObject: a] == NSOrderedDescending,
      "an ascending descriptor orders b after a");
    PASS([asc compareObject: a toObject: row(@"a")] == NSOrderedSame,
      "equal key values compare the same");
    PASS([desc compareObject: a toObject: b] == NSOrderedDescending,
      "a descending descriptor reverses the order");
    PASS([[asc reversedSortDescriptor] compareObject: a toObject: b]
      == NSOrderedDescending,
      "the reversed descriptor reverses compareObject:toObject:");
  END_SET("NSSortDescriptor compareObject:toObject:")

  START_SET("NSSortDescriptor with a selector")
    NSSortDescriptor	*ci = [NSSortDescriptor sortDescriptorWithKey: @"name"
						   ascending: YES
						    selector: @selector(caseInsensitiveCompare:)];

    PASS([ci compareObject: row(@"ABC") toObject: row(@"abc")] == NSOrderedSame,
      "a case-insensitive selector treats ABC and abc as equal");
    PASS([ci compareObject: row(@"abc") toObject: row(@"abd")] == NSOrderedAscending,
      "the selector still orders distinct values");
  END_SET("NSSortDescriptor with a selector")

  START_SET("sortedArrayUsingDescriptors:")
    NSArray		*rows = [NSArray arrayWithObjects:
      row(@"b"), row(@"a"), row(@"c"), nil];
    NSArray		*wantAsc = [NSArray arrayWithObjects:
      row(@"a"), row(@"b"), row(@"c"), nil];
    NSArray		*wantDesc = [NSArray arrayWithObjects:
      row(@"c"), row(@"b"), row(@"a"), nil];
    NSSortDescriptor	*asc = [NSSortDescriptor sortDescriptorWithKey: @"name"
							    ascending: YES];

    PASS_EQUAL([rows sortedArrayUsingDescriptors:
      [NSArray arrayWithObject: asc]], wantAsc,
      "an ascending descriptor sorts the array");
    PASS_EQUAL([rows sortedArrayUsingDescriptors:
      [NSArray arrayWithObject: [asc reversedSortDescriptor]]], wantDesc,
      "the reversed descriptor sorts in descending order");
  END_SET("sortedArrayUsingDescriptors:")

  return 0;
}
