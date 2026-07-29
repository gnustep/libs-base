/* A predicate can be archived and read back, which a predicate editor needs
   since a row template built from one is stored in a nib.  The archive is
   written the way OS X writes it, so that one written here can be read there.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSComparisonPredicate.h>
#import <Foundation/NSCompoundPredicate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

static id
roundTrip(id object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];

  return [NSKeyedUnarchiver unarchiveObjectWithData: data];
}

static NSArray *
archiveObjects(id object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];
  NSDictionary *plist;

  plist = [NSPropertyListSerialization propertyListWithData: data
                                                    options: 0
                                                     format: NULL
                                                      error: NULL];
  return [plist objectForKey: @"$objects"];
}

/* The class names an archive of the object holds. */
static NSArray *
classNames(id object)
{
  NSMutableArray *names = [NSMutableArray array];

  for (id entry in archiveObjects(object))
    {
      if ([entry isKindOfClass: [NSDictionary class]]
        && [entry objectForKey: @"$classname"] != nil)
        {
          [names addObject: [entry objectForKey: @"$classname"]];
        }
    }

  return names;
}

/* The dictionary an archive holds for the comparison a predicate makes. */
static NSDictionary *
operatorObject(id object)
{
  for (id entry in archiveObjects(object))
    {
      if ([entry isKindOfClass: [NSDictionary class]]
        && [entry objectForKey: @"NSOperatorType"] != nil)
        {
          return entry;
        }
    }

  return nil;
}

static NSPredicate *
comparison(NSPredicateOperatorType type, NSUInteger options)
{
  return [NSComparisonPredicate
    predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"a"]
                rightExpression: [NSExpression expressionForConstantValue: @"b"]
                       modifier: NSDirectPredicateModifier
                           type: type
                        options: options];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSPredicate *p;
  NSDictionary *op;

  /* A comparison, and the three parts OS X writes it in. */
  p = comparison(NSEqualToPredicateOperatorType, 0);
  PASS_EQUAL(roundTrip(p), p, "a comparison predicate survives being archived");
  PASS([classNames(p) containsObject: @"NSComparisonPredicate"],
       "and is named the way OS X names it");
  op = operatorObject(p);
  PASS([[op allKeys] containsObject: @"NSOperatorType"]
       && [[op allKeys] containsObject: @"NSModifier"],
       "with the comparison it makes written as an object of its own");
  PASS_EQUAL([op objectForKey: @"NSOperatorType"], [NSNumber numberWithInt: 4],
             "under the operator type OS X writes");
  PASS_EQUAL([op objectForKey: @"NSNegate"], [NSNumber numberWithInt: 0],
             "and the negation OS X writes with it");
  PASS([classNames(p) containsObject: @"NSEqualityPredicateOperator"],
       "in the class OS X gives that family of operators");

  /* The class of the operator object goes with the family it belongs to. */
  PASS([classNames(comparison(NSLessThanPredicateOperatorType, 0))
         containsObject: @"NSComparisonPredicateOperator"],
       "an ordering comparison is written in its own class");
  PASS([classNames(comparison(NSMatchesPredicateOperatorType, 0))
         containsObject: @"NSMatchingPredicateOperator"],
       "as is a match");
  PASS([classNames(comparison(NSLikePredicateOperatorType, 0))
         containsObject: @"NSLikePredicateOperator"],
       "as is a like");
  PASS([classNames(comparison(NSBeginsWithPredicateOperatorType, 0))
         containsObject: @"NSSubstringPredicateOperator"],
       "as is a substring comparison");
  PASS([classNames(comparison(NSInPredicateOperatorType, 0))
         containsObject: @"NSInPredicateOperator"],
       "as is a membership test");
  PASS([classNames(comparison(NSBetweenPredicateOperatorType, 0))
         containsObject: @"NSBetweenPredicateOperator"],
       "as is a range test");

  /* Which name the options are written under goes with the family too. */
  op = operatorObject(comparison(NSLessThanPredicateOperatorType,
    NSCaseInsensitivePredicateOption | NSDiacriticInsensitivePredicateOption));
  PASS_EQUAL([op objectForKey: @"NSOptions"], [NSNumber numberWithInt: 3],
             "an ordering comparison writes its options under NSOptions");
  op = operatorObject(comparison(NSMatchesPredicateOperatorType,
    NSCaseInsensitivePredicateOption | NSDiacriticInsensitivePredicateOption));
  PASS_EQUAL([op objectForKey: @"NSFlags"], [NSNumber numberWithInt: 3],
             "a match writes them under NSFlags");
  op = operatorObject(comparison(NSEndsWithPredicateOperatorType, 0));
  PASS_EQUAL([op objectForKey: @"NSPosition"], [NSNumber numberWithInt: 1],
             "and a substring comparison writes which end it looks at");

  /* The options and the modifier come back. */
  p = comparison(NSMatchesPredicateOperatorType,
    NSCaseInsensitivePredicateOption);
  PASS_EQUAL(roundTrip(p), p, "a comparison with options survives");
  PASS([(NSComparisonPredicate *)roundTrip(p) options]
       == NSCaseInsensitivePredicateOption, "with the options it was given");

  p = [NSComparisonPredicate
    predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"a"]
                rightExpression: [NSExpression expressionForConstantValue: @"b"]
                       modifier: NSAnyPredicateModifier
                           type: NSEqualToPredicateOperatorType
                        options: 0];
  PASS([(NSComparisonPredicate *)roundTrip(p) comparisonPredicateModifier]
       == NSAnyPredicateModifier, "and a modifier comes back as it went in");

  /* A custom selector is written by name, as OS X writes it. */
  p = [NSComparisonPredicate
    predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"a"]
                rightExpression: [NSExpression expressionForConstantValue: @"b"]
                 customSelector: @selector(isEqual:)];
  PASS([classNames(p) containsObject: @"NSCustomPredicateOperator"],
       "a custom selector comparison is written in the class OS X gives it");
  PASS(sel_isEqual([(NSComparisonPredicate *)roundTrip(p) customSelector],
                   @selector(isEqual:)), "and the selector comes back");

  /* A compound predicate, and the two keys OS X writes it under. */
  p = [NSCompoundPredicate andPredicateWithSubpredicates:
    [NSArray arrayWithObjects: comparison(NSEqualToPredicateOperatorType, 0),
      comparison(NSLessThanPredicateOperatorType, 0), nil]];
  PASS_EQUAL(roundTrip(p), p, "a compound predicate survives being archived");
  PASS([classNames(p) containsObject: @"NSCompoundPredicate"],
       "and is named the way OS X names it");
  PASS([[[archiveObjects(p) objectAtIndex: 1] allKeys]
         containsObject: @"NSCompoundPredicateType"]
       && [[[archiveObjects(p) objectAtIndex: 1] allKeys]
            containsObject: @"NSSubpredicates"],
       "under the keys OS X writes");
  PASS_EQUAL([[archiveObjects(p) objectAtIndex: 1]
               objectForKey: @"NSCompoundPredicateType"],
             [NSNumber numberWithInt: 1], "with the type of the compound");
  PASS([[(NSCompoundPredicate *)roundTrip(p) subpredicates] count] == 2,
       "and both of the predicates it holds");

  p = [NSCompoundPredicate notPredicateWithSubpredicate:
    comparison(NSEqualToPredicateOperatorType, 0)];
  PASS_EQUAL(roundTrip(p), p, "a negated predicate survives");
  PASS([(NSCompoundPredicate *)roundTrip(p) compoundPredicateType]
       == NSNotPredicateType, "as the negation it was");

  /* A predicate of a fixed value. */
  p = [NSPredicate predicateWithValue: YES];
  PASS_EQUAL(roundTrip(p), p, "a true predicate survives being archived");
  PASS([classNames(p) containsObject: @"NSTruePredicate"],
       "and is named the way OS X names it");
  p = [NSPredicate predicateWithValue: NO];
  PASS_EQUAL(roundTrip(p), p, "a false predicate survives being archived");
  PASS([classNames(p) containsObject: @"NSFalsePredicate"],
       "and is named the way OS X names it");

  /* What a row template holds is a predicate parsed from a format. */
  p = [NSPredicate predicateWithFormat: @"name CONTAINS[cd] %@", @"x"];
  PASS_EQUAL(roundTrip(p), p, "a parsed predicate survives being archived");

  [arp release];
  return 0;
}
