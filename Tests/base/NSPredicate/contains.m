/* CONTAINS asks whether the left hand side holds the right hand side, the
   way OS X reports and evaluates it.  It used to be turned into IN with the
   two sides exchanged, which left the predicate describing something else
   than it was written as, and a CONTAINS predicate built by hand, rather than
   parsed, was never true.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSComparisonPredicate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSDictionary *object;
  NSComparisonPredicate *parsed;
  NSPredicate *built;

  object = [NSDictionary dictionaryWithObjectsAndKeys:
    @"xyz", @"name",
    [NSArray arrayWithObjects: @"a", @"b", nil], @"list",
    nil];

  parsed = (NSComparisonPredicate *)
    [NSPredicate predicateWithFormat: @"name CONTAINS 'y'"];

  PASS([parsed predicateOperatorType] == NSContainsPredicateOperatorType,
       "a parsed CONTAINS is a contains predicate");
  PASS_EQUAL([[parsed leftExpression] keyPath], @"name",
             "the left hand side is the one that was written first");
  PASS_EQUAL([[parsed rightExpression] constantValue], @"y",
             "the right hand side is the one that was written second");
  PASS([parsed evaluateWithObject: object],
       "a string that holds the substring passes");
  PASS(![[NSPredicate predicateWithFormat: @"name CONTAINS 'q'"]
          evaluateWithObject: object],
       "a string that does not hold the substring fails");

  /* Built rather than parsed, the way a predicate editor builds one. */
  built = [NSComparisonPredicate
    predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"name"]
                rightExpression: [NSExpression expressionForConstantValue: @"y"]
                       modifier: NSDirectPredicateModifier
                           type: NSContainsPredicateOperatorType
                        options: 0];
  PASS([built evaluateWithObject: object],
       "a contains predicate built by hand is evaluated");
  PASS_EQUAL([built predicateFormat], [parsed predicateFormat],
             "a contains predicate built by hand reads as the parsed one");

  /* The case insensitive form. */
  PASS([[NSPredicate predicateWithFormat: @"name CONTAINS[c] 'Y'"]
         evaluateWithObject: object],
       "the case insensitive form ignores case");
  PASS(![[NSPredicate predicateWithFormat: @"name CONTAINS 'Y'"]
          evaluateWithObject: object],
       "the plain form does not ignore case");

  /* A collection on the left hand side. */
  PASS([[NSPredicate predicateWithFormat: @"list CONTAINS 'a'"]
         evaluateWithObject: object],
       "a collection that holds the object passes");
  PASS(![[NSPredicate predicateWithFormat: @"list CONTAINS 'z'"]
          evaluateWithObject: object],
       "a collection that does not hold the object fails");

  /* IN is unchanged. */
  {
    NSComparisonPredicate *in = (NSComparisonPredicate *)
      [NSPredicate predicateWithFormat: @"name IN 'wxyz'"];

    PASS([in predicateOperatorType] == NSInPredicateOperatorType,
         "IN is still IN");
    PASS_EQUAL([[in leftExpression] keyPath], @"name",
               "IN keeps the side that was written first");
    PASS([in evaluateWithObject: object],
         "a string held by the right hand side passes");
    PASS([[NSPredicate predicateWithFormat: @"'a' IN list"]
           evaluateWithObject: object],
         "an object held by a collection passes");
  }

  [arp release];
  return 0;
}
