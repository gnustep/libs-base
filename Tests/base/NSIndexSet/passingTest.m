#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(blocks)

static NSString *
rangesOf(NSIndexSet *set)
{
  NSMutableArray	*a = [NSMutableArray array];

  [set enumerateRangesUsingBlock: ^(NSRange r, BOOL *stop) {
    [a addObject: [NSString stringWithFormat: @"{%lu, %lu}",
      (unsigned long)r.location, (unsigned long)r.length]];
  }];
  return [a componentsJoinedByString: @" "];
}

static NSString *
rangesIn(NSIndexSet *set, NSRange range, NSEnumerationOptions opts)
{
  NSMutableArray	*a = [NSMutableArray array];

  [set enumerateRangesInRange: range
		      options: opts
		   usingBlock: ^(NSRange r, BOOL *stop) {
    [a addObject: [NSString stringWithFormat: @"{%lu, %lu}",
      (unsigned long)r.location, (unsigned long)r.length]];
  }];
  return [a componentsJoinedByString: @" "];
}

static NSString *
indexesIn(NSIndexSet *set, NSRange range, NSEnumerationOptions opts)
{
  NSMutableArray	*a = [NSMutableArray array];

  [set enumerateIndexesInRange: range
		       options: opts
		    usingBlock: ^(NSUInteger idx, BOOL *stop) {
    [a addObject: [NSNumber numberWithUnsignedInteger: idx]];
  }];
  return [a componentsJoinedByString: @","];
}

#endif

int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("NSIndexSet blocks")
#if __has_feature(blocks)
  NSMutableIndexSet	*s = [NSMutableIndexSet indexSet];
  NSIndexSet		*empty = [NSIndexSet indexSet];
  NSMutableArray	*seen = [NSMutableArray array];
  NSIndexSet		*r;
  NSUInteger		i;
  BOOL (^even)(NSUInteger, BOOL *) = ^BOOL(NSUInteger idx, BOOL *stop) {
    [seen addObject: [NSNumber numberWithUnsignedInteger: idx]];
    return idx % 2 == 0;
  };

  [s addIndexesInRange: NSMakeRange(5, 5)];
  [s addIndexesInRange: NSMakeRange(20, 5)];
  [s addIndexesInRange: NSMakeRange(30, 1)];

  PASS_EQUAL(rangesIn(s, NSMakeRange(7, 15), 0), @"{7, 3} {20, 2}",
    "enumerateRangesInRange: clips ranges to the requested range")
  PASS_EQUAL(rangesIn(s, NSMakeRange(7, 15), NSEnumerationReverse),
    @"{20, 2} {7, 3}",
    "enumerateRangesInRange: clips ranges when enumerating in reverse")
  PASS_EQUAL(rangesIn(s, NSMakeRange(9, 12), 0), @"{9, 1} {20, 1}",
    "enumerateRangesInRange: clips single index ranges")
  PASS_EQUAL(rangesIn(s, NSMakeRange(0, 3), 0), @"",
    "enumerateRangesInRange: skips a range before the first index")
  PASS_EQUAL(rangesIn(s, NSMakeRange(12, 5), 0), @"",
    "enumerateRangesInRange: skips a range in a gap")
  PASS_EQUAL(rangesIn(s, NSMakeRange(12, 5), NSEnumerationReverse), @"",
    "enumerateRangesInRange: skips a range in a gap in reverse")
  PASS_EQUAL(rangesIn(s, NSMakeRange(10, 10), 0), @"",
    "enumerateRangesInRange: skips a range filling a gap exactly")
  PASS_EQUAL(rangesIn(s, NSMakeRange(6, 0), 0), @"",
    "enumerateRangesInRange: skips an empty range")
  PASS_EQUAL(rangesIn(s, NSMakeRange(40, 5), 0), @"",
    "enumerateRangesInRange: skips a range after the last index")
  PASS_EQUAL(rangesIn(s, NSMakeRange(0, NSUIntegerMax), 0),
    @"{5, 5} {20, 5} {30, 1}",
    "enumerateRangesInRange: handles a range overflowing NSUIntegerMax")

  PASS_EQUAL(indexesIn(s, NSMakeRange(8, 15), 0), @"8,9,20,21,22",
    "enumerateIndexesInRange: clips to the requested range")
  PASS_EQUAL(indexesIn(s, NSMakeRange(8, 15), NSEnumerationReverse),
    @"22,21,20,9,8",
    "enumerateIndexesInRange: clips to the requested range in reverse")
  PASS_EQUAL(indexesIn(s, NSMakeRange(12, 5), 0), @"",
    "enumerateIndexesInRange: skips a range in a gap")

  r = [s indexesPassingTest: even];
  PASS_EQUAL(rangesOf(r), @"{6, 1} {8, 1} {20, 1} {22, 1} {24, 1} {30, 1}",
    "indexesPassingTest: returns the passing indexes")
  PASS_EQUAL([seen componentsJoinedByString: @","],
    @"5,6,7,8,9,20,21,22,23,24,30",
    "indexesPassingTest: tests every index in ascending order")
  PASS(NO == [r isKindOfClass: [NSMutableIndexSet class]],
    "indexesPassingTest: returns an immutable set")

  [seen removeAllObjects];
  r = [s indexesWithOptions: NSEnumerationReverse passingTest: even];
  PASS_EQUAL(rangesOf(r), @"{6, 1} {8, 1} {20, 1} {22, 1} {24, 1} {30, 1}",
    "indexesWithOptions:passingTest: returns the passing indexes in reverse")
  PASS_EQUAL([seen componentsJoinedByString: @","],
    @"30,24,23,22,21,20,9,8,7,6,5",
    "indexesWithOptions:passingTest: tests in descending order in reverse")

  [seen removeAllObjects];
  r = [s indexesInRange: NSMakeRange(8, 15) options: 0 passingTest: even];
  PASS_EQUAL(rangesOf(r), @"{8, 1} {20, 1} {22, 1}",
    "indexesInRange:options:passingTest: returns passing indexes in range")
  PASS_EQUAL([seen componentsJoinedByString: @","], @"8,9,20,21,22",
    "indexesInRange:options:passingTest: tests only indexes in range")

  r = [s indexesPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return YES;
  }];
  PASS_EQUAL(rangesOf(r), @"{5, 5} {20, 5} {30, 1}",
    "indexesPassingTest: returns all indexes when all pass")
  PASS([r isEqualToIndexSet: s], "passing every index returns an equal set")

  [seen removeAllObjects];
  r = [s indexesPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    [seen addObject: [NSNumber numberWithUnsignedInteger: idx]];
    if (idx == 21) *stop = YES;
    return YES;
  }];
  PASS_EQUAL(rangesOf(r), @"{5, 5} {20, 2}",
    "indexesPassingTest: includes the index that stops and passes")
  PASS_EQUAL([seen componentsJoinedByString: @","], @"5,6,7,8,9,20,21",
    "indexesPassingTest: stops testing when the predicate sets stop")

  r = [s indexesPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    if (idx == 21) *stop = YES;
    return NO;
  }];
  PASS([r count] == 0, "indexesPassingTest: excludes indexes that fail")

  r = [s indexesWithOptions: NSEnumerationConcurrent
		passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return idx % 2 == 0;
  }];
  PASS_EQUAL(rangesOf(r), @"{6, 1} {8, 1} {20, 1} {22, 1} {24, 1} {30, 1}",
    "indexesWithOptions:passingTest: works concurrently")

  PASS([[empty indexesPassingTest: even] count] == 0,
    "indexesPassingTest: on an empty set returns an empty set")
  PASS([[s indexesInRange: NSMakeRange(12, 5) options: 0 passingTest: even]
    count] == 0, "indexesInRange:options:passingTest: in a gap is empty")

  [seen removeAllObjects];
  i = [s indexPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    [seen addObject: [NSNumber numberWithUnsignedInteger: idx]];
    return idx > 20;
  }];
  PASS(i == 21, "indexPassingTest: returns the first passing index")
  PASS_EQUAL([seen componentsJoinedByString: @","], @"5,6,7,8,9,20,21",
    "indexPassingTest: stops at the first passing index")

  [seen removeAllObjects];
  i = [s indexWithOptions: NSEnumerationReverse
	      passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    [seen addObject: [NSNumber numberWithUnsignedInteger: idx]];
    return idx < 22;
  }];
  PASS(i == 21, "indexWithOptions:passingTest: returns the last passing index")
  PASS_EQUAL([seen componentsJoinedByString: @","], @"30,24,23,22,21",
    "indexWithOptions:passingTest: tests in descending order in reverse")

  i = [s indexInRange: NSMakeRange(0, 7)
	      options: 0
	  passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return idx > 6;
  }];
  PASS(i == NSNotFound,
    "indexInRange:options:passingTest: ignores indexes beyond the range")
  i = [s indexInRange: NSMakeRange(0, 8)
	      options: 0
	  passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return idx > 6;
  }];
  PASS(i == 7, "indexInRange:options:passingTest: finds an index in range")

  [seen removeAllObjects];
  i = [s indexPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    [seen addObject: [NSNumber numberWithUnsignedInteger: idx]];
    if (idx == 7) *stop = YES;
    return NO;
  }];
  PASS(i == NSNotFound, "indexPassingTest: returns NSNotFound when stopped")
  PASS_EQUAL([seen componentsJoinedByString: @","], @"5,6,7",
    "indexPassingTest: stops testing when the predicate sets stop")

  i = [s indexPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    if (idx == 7) *stop = YES;
    return idx == 7;
  }];
  PASS(i == 7, "indexPassingTest: returns the index that stops and passes")

  i = [s indexWithOptions: NSEnumerationConcurrent
	      passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return idx == 22;
  }];
  PASS(i == 22, "indexWithOptions:passingTest: works concurrently")

  i = [empty indexPassingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return YES;
  }];
  PASS(i == NSNotFound, "indexPassingTest: on an empty set is NSNotFound")
  i = [s indexInRange: NSMakeRange(12, 5)
	      options: 0
	  passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return YES;
  }];
  PASS(i == NSNotFound, "indexInRange:options:passingTest: in a gap")
  i = [s indexInRange: NSMakeRange(22, 0)
	      options: 0
	  passingTest: ^BOOL(NSUInteger idx, BOOL *stop) {
    return YES;
  }];
  PASS(i == NSNotFound,
    "indexInRange:options:passingTest: with an empty range")
#else
  SKIP("Blocks support unavailable")
#endif
  END_SET("NSIndexSet blocks")

  [arp release];
  return 0;
}
