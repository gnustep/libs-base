/*
 * compound.m - tests for NSPredicate / NSCompoundPredicate behaviour basic.m
 * does not cover: predicateWithValue:, NOT and ENDSWITH, the programmatic
 * NSCompoundPredicate constructors, and the empty-subpredicate semantics
 * (AND of nothing is true, OR of nothing is false).
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static NSDictionary *
rec(void)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    @"Alice", @"name", [NSNumber numberWithInt: 30], @"age", nil];
}

static NSPredicate *
pf(NSString *format)
{
  return [NSPredicate predicateWithFormat: format];
}

int main(void)
{
  START_SET("predicateWithValue, NOT and ENDSWITH")
    NSDictionary	*r = rec();

    PASS([[NSPredicate predicateWithValue: YES] evaluateWithObject: r] == YES,
      "predicateWithValue: YES always evaluates true");
    PASS([[NSPredicate predicateWithValue: NO] evaluateWithObject: r] == NO,
      "predicateWithValue: NO always evaluates false");

    PASS([pf(@"NOT (name == 'Bob')") evaluateWithObject: r] == YES,
      "NOT of a false predicate is true");
    PASS([pf(@"NOT (name == 'Alice')") evaluateWithObject: r] == NO,
      "NOT of a true predicate is false");

    PASS([pf(@"name ENDSWITH 'ce'") evaluateWithObject: r] == YES,
      "ENDSWITH matches a suffix");
    PASS([pf(@"name ENDSWITH 'xy'") evaluateWithObject: r] == NO,
      "ENDSWITH is false for a non-suffix");
  END_SET("predicateWithValue, NOT and ENDSWITH")

  START_SET("NSCompoundPredicate constructors")
    NSDictionary	*r = rec();
    NSPredicate		*nameOK = pf(@"name == 'Alice'");
    NSPredicate		*ageOK = pf(@"age == 30");
    NSPredicate		*ageBad = pf(@"age == 99");
    NSArray		*both = [NSArray arrayWithObjects: nameOK, ageOK, nil];
    NSArray		*mixed = [NSArray arrayWithObjects: nameOK, ageBad, nil];

    PASS([[NSCompoundPredicate andPredicateWithSubpredicates: both]
      evaluateWithObject: r] == YES,
      "AND of true predicates is true");
    PASS([[NSCompoundPredicate andPredicateWithSubpredicates: mixed]
      evaluateWithObject: r] == NO,
      "AND with a false predicate is false");
    PASS([[NSCompoundPredicate orPredicateWithSubpredicates: mixed]
      evaluateWithObject: r] == YES,
      "OR with a true predicate is true");
    PASS([[NSCompoundPredicate notPredicateWithSubpredicate: ageBad]
      evaluateWithObject: r] == YES,
      "NOT of a false predicate is true");

    PASS([[NSCompoundPredicate andPredicateWithSubpredicates:
      [NSArray array]] evaluateWithObject: r] == YES,
      "AND of no predicates is true");
    PASS([[NSCompoundPredicate orPredicateWithSubpredicates:
      [NSArray array]] evaluateWithObject: r] == NO,
      "OR of no predicates is false");
  END_SET("NSCompoundPredicate constructors")

  return 0;
}
