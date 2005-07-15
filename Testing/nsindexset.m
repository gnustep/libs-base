/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/Foundation.h>

int
main ()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSIndexSet		*s;
  NSMutableIndexSet	*m;
  NSMutableIndexSet	*o;
  unsigned int		buf[2];
  NSRange		r;

  printf("Can create empty set ...");
  s = [NSIndexSet indexSet];
  printf(" %s\n", s != nil ? "passed" : "failed");

  printf("Empty set count is 0 ...");
  printf(" %s\n", [s count] == 0 ? "passed" : "failed");

  printf("Empty set does not contain index 0 ...");
  printf(" %s\n", [s containsIndex: 0] == NO ? "passed" : "failed");

  printf("Empty set does not intersect indexes in range 0->NSNotFound-1 ...");
  printf(" %s\n", [s intersectsIndexesInRange: NSMakeRange(0,NSNotFound-1)] == NO ? "passed" : "failed");

  printf("Empty set first index is NSNotFound...");
  printf(" %s\n", [s firstIndex] == NSNotFound ? "passed" : "failed");

  printf("Empty set last index is NSNotFound...");
  printf(" %s\n", [s lastIndex] == NSNotFound ? "passed" : "failed");

  printf("Empty set index less than 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Empty set index less than or equal to 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanOrEqualToIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Empty set index greater than 1 is NSNotFound...");
  printf(" %s\n", [s indexGreaterThanIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Empty set index greater than or equal to 1 is NSNotFound...");
  printf(" %s\n", [s indexGreaterThanOrEqualToIndex: 1] == NSNotFound ? "passed" : "failed");

  printf("Empty set getIndexes gives 0...");
  r = NSMakeRange(0, NSNotFound-1);
  printf(" %s\n", [s getIndexes: buf maxCount:3 inIndexRange: &r] == 0 ? "passed" : "failed");


  printf("Can create single index set with 2 ...");
  s = [NSIndexSet indexSetWithIndex: 2];
  printf(" %s\n", s != nil ? "passed" : "failed");

  printf("Set count is 1 ...");
  printf(" %s\n", [s count] == 1 ? "passed" : "failed");

  printf("Set does not contain index 0 ...");
  printf(" %s\n", [s containsIndex: 0] == NO ? "passed" : "failed");

  printf("Set contains index 2 ...");
  printf(" %s\n", [s containsIndex: 2] == YES ? "passed" : "failed");

  printf("Set intersects indexes in range 0->NSNotFound-1 ...");
  printf(" %s\n", [s intersectsIndexesInRange: NSMakeRange(0,NSNotFound-1)] == YES ? "passed" : "failed");

  printf("Set first index is 2...");
  printf(" %s\n", [s firstIndex] == 2 ? "passed" : "failed");

  printf("Set last index is 2...");
  printf(" %s\n", [s lastIndex] == 2 ? "passed" : "failed");

  printf("Set index less than 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Set index less than or equal to 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanOrEqualToIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Set index less than 2 is NSNotFound...");
  printf(" %s\n", [s indexLessThanIndex: 2] == NSNotFound ? "passed" : "failed");
  printf("Set index less than or equal to 2 is 2...");
  printf(" %s\n", [s indexLessThanOrEqualToIndex: 2] == 2 ? "passed" : "failed");
  printf("Set index greater than 1 is 2...");
  printf(" %s\n", [s indexGreaterThanIndex: 1] == 2 ? "passed" : "failed");
  printf("Set index greater than or equal to 1 is 2...");
  printf(" %s\n", [s indexGreaterThanOrEqualToIndex: 1] == 2 ? "passed" : "failed");
  printf("Set index greater than 2 is NSNotFound...");
  printf(" %s\n", [s indexGreaterThanIndex: 2] == NSNotFound ? "passed" : "failed");
  printf("Set index greater than or equal to 2 is 2...");
  printf(" %s\n", [s indexGreaterThanOrEqualToIndex: 2] == 2 ? "passed" : "failed");

  printf("Set getIndexes gives 1...");
  r = NSMakeRange(0, NSNotFound-1);
  printf(" %s\n", [s getIndexes: buf maxCount:3 inIndexRange: &r] == 1 ? "passed" : "failed");


  printf("Can create multipe index set with range 2...5 ...");
  s = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(2,4)];
  printf(" %s\n", s != nil ? "passed" : "failed");

  printf("Set count is 4 ...");
  printf(" %s\n", [s count] == 4 ? "passed" : "failed");

  printf("Set does not contain index 0 ...");
  printf(" %s\n", [s containsIndex: 0] == NO ? "passed" : "failed");

  printf("Set contains index 2 ...");
  printf(" %s\n", [s containsIndex: 2] == YES ? "passed" : "failed");

  printf("Set contains index 5 ...");
  printf(" %s\n", [s containsIndex: 5] == YES ? "passed" : "failed");

  printf("Set intersects indexes in range 0->NSNotFound-1 ...");
  printf(" %s\n", [s intersectsIndexesInRange: NSMakeRange(0,NSNotFound-1)] == YES ? "passed" : "failed");

  printf("Set first index is 2...");
  printf(" %s\n", [s firstIndex] == 2 ? "passed" : "failed");

  printf("Set last index is 5...");
  printf(" %s\n", [s lastIndex] == 5 ? "passed" : "failed");

  printf("Set index less than 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Set index less than or equal to 1 is NSNotFound...");
  printf(" %s\n", [s indexLessThanOrEqualToIndex: 1] == NSNotFound ? "passed" : "failed");
  printf("Set index less than 2 is NSNotFound...");
  printf(" %s\n", [s indexLessThanIndex: 2] == NSNotFound ? "passed" : "failed");
  printf("Set index less than or equal to 2 is 2...");
  printf(" %s\n", [s indexLessThanOrEqualToIndex: 2] == 2 ? "passed" : "failed");
  printf("Set index greater than 1 is 2...");
  printf(" %s\n", [s indexGreaterThanIndex: 1] == 2 ? "passed" : "failed");
  printf("Set index greater than or equal to 1 is 2...");
  printf(" %s\n", [s indexGreaterThanOrEqualToIndex: 1] == 2 ? "passed" : "failed");
  printf("Set index greater than 2 is 3...");
  printf(" %s\n", [s indexGreaterThanIndex: 2] == 3 ? "passed" : "failed");
  printf("Set index greater than or equal to 2 is 2...");
  printf(" %s\n", [s indexGreaterThanOrEqualToIndex: 2] == 2 ? "passed" : "failed");

  printf("Set getIndexes gives 3...");
  r = NSMakeRange(0, NSNotFound-1);
  printf(" %s\n", [s getIndexes: buf maxCount:3 inIndexRange: &r] == 3 ? "passed" : "failed");

  printf("Set getIndexes gives 1...");
  printf(" %s\n", [s getIndexes: buf maxCount:3 inIndexRange: &r] == 1 ? "passed" : "failed");


  printf("Set mutableCopy works...");
  m = [[s mutableCopy] autorelease];
  printf(" %s\n", m != nil ? "passed" : "failed");

  printf("Copy equals originals...");
  printf(" %s\n", [m isEqual: s] == YES ? "passed" : "failed");

  printf("Can add index 10 to mutable set...");
  [m addIndex: 10];
  printf(" %s\n", [m containsIndex: 10] == YES && [m containsIndex: 9] == NO && [m containsIndex: 11] == NO ? "passed" : "failed");

  printf("Can add index 7 to mutable set...");
  [m addIndex: 7];
  printf(" %s\n", [m containsIndex: 7] == YES && [m containsIndex: 6] == NO && [m containsIndex: 8] == NO ? "passed" : "failed");

  printf("Can add index 8 to mutable set...");
  [m addIndex: 8];
  printf(" %s\n", [m containsIndex: 7] == YES && [m containsIndex: 8] == YES && [m containsIndex: 9] == NO ? "passed" : "failed");

  printf("Can add index 9 to mutable set...");
  [m addIndex: 9];
  printf(" %s\n", [m containsIndex: 8] == YES && [m containsIndex: 9] == YES && [m containsIndex: 10] == YES ? "passed" : "failed");

  printf("Can remove index 9 from mutable set...");
  [m removeIndex: 9];
  printf(" %s\n", [m containsIndex: 8] == YES && [m containsIndex: 9] == NO && [m containsIndex: 10] == YES ? "passed" : "failed");

  printf("Can shift right by 5 from 7...");
  [m shiftIndexesStartingAtIndex: 7 by: 5];
  printf(" %s\n", [m containsIndex: 7] == NO && [m containsIndex: 12] == YES ? "passed" : "failed");

  printf("Can shift left by 5 from 12...");
  [m shiftIndexesStartingAtIndex: 12 by: -5];
  printf(" %s\n", [m containsIndex: 7] == YES && [m containsIndex: 12] == NO ? "passed" : "failed");

  printf("Can remove range 5-7 from mutable set...");
  [m removeIndexesInRange: NSMakeRange(5, 3)];
  printf(" %s\n", [m containsIndex: 4] == YES && [m containsIndex: 5] == NO && [m containsIndex: 8] == YES ? "passed" : "failed");

  printf("Can remove range 0-10 from mutable set...");
  [m removeIndexesInRange: NSMakeRange(0, 11)];
  printf(" %s\n", [m isEqual: [NSIndexSet indexSet]] == YES ? "passed" : "failed");

  o = [NSMutableIndexSet indexSet];
  [m addIndex: 3];
  [m addIndex: 4];
  [m addIndex: 6];
  [m addIndex: 7];
  [o addIndex: 3];
  [o addIndex: 7];
  printf("Can remove range 4-6 from mutable set containing 3,4,6,7 ...");
  [m removeIndexesInRange: NSMakeRange(4, 3)];
  printf(" %s\n", [m isEqual: o] == YES ? "passed" : "failed");

  [m addIndex: 3];
  [m addIndex: 4];
  [m addIndex: 6];
  [m addIndex: 7];
  [m addIndex: 8];
  [m addIndex: 9];
  [o addIndex: 3];
  [o removeIndex: 7];
  [o addIndex: 9];
  printf("Can remove range 4-8 from mutable set containing 3,4,6,7,8,9 ...");
  [m removeIndexesInRange: NSMakeRange(4, 5)];
  printf(" %s\n", [m isEqual: o] == YES ? "passed" : "failed");

//  NSLog(@"%@", m);
  [arp release];
  exit (0);
}

