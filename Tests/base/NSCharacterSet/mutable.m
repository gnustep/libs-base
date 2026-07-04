/*
 * mutable.m - tests for NSCharacterSet / NSMutableCharacterSet behaviour the
 * existing tests (mostly characterIsMember: on predefined sets) do not cover:
 * characterSetWithRange:, isSupersetOfSet:, and the NSMutableCharacterSet
 * add / remove / formUnion / formIntersection / invert operations.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSCharacterSet range and superset")
    NSCharacterSet	*upper
      = [NSCharacterSet characterSetWithRange: NSMakeRange('A', 26)];

    PASS([upper characterIsMember: 'A'] && [upper characterIsMember: 'Z'],
      "characterSetWithRange: includes both ends of the range");
    PASS(![upper characterIsMember: 'a'] && ![upper characterIsMember: '@'],
      "characterSetWithRange: excludes characters outside the range");

    PASS([upper isSupersetOfSet:
      [NSCharacterSet characterSetWithRange: NSMakeRange('A', 5)]] == YES,
      "isSupersetOfSet: is YES for a subset");
    PASS([[NSCharacterSet characterSetWithRange: NSMakeRange('A', 5)]
      isSupersetOfSet: upper] == NO,
      "isSupersetOfSet: is NO for a superset");
  END_SET("NSCharacterSet range and superset")

  START_SET("NSMutableCharacterSet add and remove")
    NSMutableCharacterSet	*m
      = [NSMutableCharacterSet characterSetWithCharactersInString: @"abc"];

    [m addCharactersInString: @"de"];
    PASS([m characterIsMember: 'a'] && [m characterIsMember: 'd'],
      "addCharactersInString: adds the characters");
    [m addCharactersInRange: NSMakeRange('0', 10)];
    PASS([m characterIsMember: '5'], "addCharactersInRange: adds a range");

    [m removeCharactersInString: @"a"];
    PASS(![m characterIsMember: 'a'] && [m characterIsMember: 'b'],
      "removeCharactersInString: removes the characters");
    [m removeCharactersInRange: NSMakeRange('0', 10)];
    PASS(![m characterIsMember: '5'], "removeCharactersInRange: removes a range");
  END_SET("NSMutableCharacterSet add and remove")

  START_SET("NSMutableCharacterSet union, intersection and invert")
    NSMutableCharacterSet	*m;

    m = [NSMutableCharacterSet characterSetWithCharactersInString: @"ab"];
    [m formUnionWithCharacterSet:
      [NSCharacterSet characterSetWithCharactersInString: @"bc"]];
    PASS([m characterIsMember: 'a'] && [m characterIsMember: 'b']
      && [m characterIsMember: 'c'],
      "formUnionWithCharacterSet: adds the other set's characters");

    m = [NSMutableCharacterSet characterSetWithCharactersInString: @"abc"];
    [m formIntersectionWithCharacterSet:
      [NSCharacterSet characterSetWithCharactersInString: @"bcd"]];
    PASS(![m characterIsMember: 'a'] && [m characterIsMember: 'b']
      && [m characterIsMember: 'c'],
      "formIntersectionWithCharacterSet: keeps only the shared characters");

    m = [NSMutableCharacterSet characterSetWithCharactersInString: @"a"];
    [m invert];
    PASS(![m characterIsMember: 'a'] && [m characterIsMember: 'b'],
      "invert flips membership");
  END_SET("NSMutableCharacterSet union, intersection and invert")

  return 0;
}
