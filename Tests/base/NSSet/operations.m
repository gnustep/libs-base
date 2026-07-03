/*
 * operations.m - coverage tests for NSSet and NSMutableSet semantics:
 * construction and de-duplication, membership, the set predicates
 * (isEqualToSet:, isSubsetOfSet:, intersectsSet:), the derived-set methods
 * (setByAddingObject: and friends), and NSMutableSet mutation and set
 * algebra (unionSet:, intersectSet:, minusSet:, setSet:).
 *
 * These are portable, deterministic value-semantic operations.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSSet creation, count and de-duplication")
    NSSet	*s;

    PASS([[NSSet set] count] == 0, "+set is empty");
    PASS([[NSSet setWithObject: @"a"] count] == 1, "+setWithObject: has one element");

    s = [NSSet setWithObjects: @"a", @"b", @"c", nil];
    PASS([s count] == 3, "+setWithObjects: counts distinct elements");

    s = [NSSet setWithObjects: @"a", @"b", @"a", nil];
    PASS([s count] == 2, "+setWithObjects: does not store duplicates");

    s = [NSSet setWithArray: ([NSArray arrayWithObjects: @"a", @"b", @"b", nil])];
    PASS([s count] == 2, "+setWithArray: de-duplicates the array");

    s = [NSSet setWithSet: ([NSSet setWithObjects: @"a", @"b", nil])];
    PASS([s count] == 2 && [s isEqualToSet: ([NSSet setWithObjects: @"b", @"a", nil])],
      "+setWithSet: copies the elements");
  END_SET("NSSet creation, count and de-duplication")

  START_SET("NSSet membership")
    NSSet	*s = [NSSet setWithObjects: @"a", @"b", @"c", nil];

    PASS([s containsObject: @"b"] == YES, "containsObject: is YES for a member");
    PASS([s containsObject: @"z"] == NO, "containsObject: is NO for a non-member");
    PASS_EQUAL([s member: @"b"], @"b", "member: returns the equal stored object");
    PASS([s member: @"z"] == nil, "member: returns nil for a non-member");
    PASS([s anyObject] != nil, "anyObject is non-nil for a non-empty set");
    PASS([[NSSet set] anyObject] == nil, "anyObject is nil for an empty set");
    PASS([[s allObjects] count] == 3, "allObjects returns every element");
    PASS([[s allObjects] containsObject: @"a"]
      && [[s allObjects] containsObject: @"c"],
      "allObjects contains the set's elements");
  END_SET("NSSet membership")

  START_SET("NSSet predicates")
    NSSet	*abc = [NSSet setWithObjects: @"a", @"b", @"c", nil];
    NSSet	*ab  = [NSSet setWithObjects: @"a", @"b", nil];
    NSSet	*bc  = [NSSet setWithObjects: @"b", @"c", nil];
    NSSet	*xy  = [NSSet setWithObjects: @"x", @"y", nil];
    NSSet	*empty = [NSSet set];

    PASS([abc isEqualToSet: ([NSSet setWithObjects: @"c", @"b", @"a", nil])] == YES,
      "isEqualToSet: is order-independent");
    PASS([abc isEqualToSet: ab] == NO,
      "isEqualToSet: is NO for sets of different size");

    PASS([ab isSubsetOfSet: abc] == YES, "isSubsetOfSet: is YES for a subset");
    PASS([abc isSubsetOfSet: ab] == NO, "isSubsetOfSet: is NO for a superset");
    PASS([empty isSubsetOfSet: abc] == YES, "the empty set is a subset of any set");

    PASS([ab intersectsSet: bc] == YES, "intersectsSet: is YES when they share an element");
    PASS([ab intersectsSet: xy] == NO, "intersectsSet: is NO for disjoint sets");
    PASS([empty intersectsSet: abc] == NO, "the empty set intersects nothing");
  END_SET("NSSet predicates")

  START_SET("NSSet derived sets")
    NSSet	*ab = [NSSet setWithObjects: @"a", @"b", nil];
    NSSet	*r;

    r = [ab setByAddingObject: @"c"];
    PASS([r isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", nil])],
      "setByAddingObject: returns a set with the extra object");
    PASS([ab count] == 2, "setByAddingObject: leaves the original set unchanged");

    r = [ab setByAddingObject: @"a"];
    PASS([r count] == 2, "setByAddingObject: an existing element changes nothing");

    r = [ab setByAddingObjectsFromArray: ([NSArray arrayWithObjects: @"c", @"d", nil])];
    PASS([r isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", @"d", nil])],
      "setByAddingObjectsFromArray: adds the array's objects");

    r = [ab setByAddingObjectsFromSet: ([NSSet setWithObjects: @"b", @"c", nil])];
    PASS([r isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", nil])],
      "setByAddingObjectsFromSet: adds the other set's objects");
  END_SET("NSSet derived sets")

  START_SET("NSMutableSet mutation")
    NSMutableSet	*m = [NSMutableSet set];

    [m addObject: @"a"];
    [m addObject: @"b"];
    PASS([m count] == 2, "addObject: adds distinct objects");
    [m addObject: @"a"];
    PASS([m count] == 2, "addObject: of an existing element is a no-op");

    [m addObjectsFromArray: ([NSArray arrayWithObjects: @"b", @"c", @"d", nil])];
    PASS([m isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", @"d", nil])],
      "addObjectsFromArray: adds only the new objects");

    [m removeObject: @"z"];
    PASS([m count] == 4, "removeObject: of a non-member is a no-op");
    [m removeObject: @"a"];
    PASS([m containsObject: @"a"] == NO && [m count] == 3,
      "removeObject: removes the object");

    [m removeAllObjects];
    PASS([m count] == 0, "removeAllObjects empties the set");
  END_SET("NSMutableSet mutation")

  START_SET("NSMutableSet set algebra")
    NSMutableSet	*m;

    m = [NSMutableSet setWithObjects: @"a", @"b", nil];
    [m unionSet: ([NSSet setWithObjects: @"b", @"c", nil])];
    PASS([m isEqualToSet: ([NSSet setWithObjects: @"a", @"b", @"c", nil])],
      "unionSet: adds the other set's elements");

    m = [NSMutableSet setWithObjects: @"a", @"b", @"c", nil];
    [m intersectSet: ([NSSet setWithObjects: @"b", @"c", @"d", nil])];
    PASS([m isEqualToSet: ([NSSet setWithObjects: @"b", @"c", nil])],
      "intersectSet: keeps only the shared elements");

    m = [NSMutableSet setWithObjects: @"a", @"b", @"c", nil];
    [m minusSet: ([NSSet setWithObjects: @"b", nil])];
    PASS([m isEqualToSet: ([NSSet setWithObjects: @"a", @"c", nil])],
      "minusSet: removes the other set's elements");

    m = [NSMutableSet setWithObjects: @"a", @"b", nil];
    [m setSet: ([NSSet setWithObjects: @"x", @"y", @"z", nil])];
    PASS([m isEqualToSet: ([NSSet setWithObjects: @"x", @"y", @"z", nil])],
      "setSet: replaces the receiver's contents");
  END_SET("NSMutableSet set algebra")

  return 0;
}
