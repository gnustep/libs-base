#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSComparisonPredicate.h"
#import "Foundation/NSExpression.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

@interface NSExpression (KeyPathComposition)
+ (NSExpression *) expressionForKeyPathCompositionWithLeft: (NSExpression*)left
  right: (NSExpression*)right;
@end

/* A key path composition, a union, an intersection and a difference all
 * share one class, which had no -encodeWithCoder: of its own and so
 * inherited the one that raises.  A predicate containing $x.y could not be
 * archived at all.
 */
static void
testRoundTrip(NSExpression *expression, const char *what)
{
  NSExpression	*back;

  back = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: expression]];

  PASS(back != nil && [back expressionType] == [expression expressionType],
    "%s comes back from an archive as its own kind", what);
  PASS_EQUAL(back, expression, "%s survives an archive", what);
}

int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSExpression		*variable;
  NSExpression		*keyPath;
  NSExpression		*friends;
  NSExpression		*colleagues;
  NSExpression		*composition;
  NSPredicate		*predicate;
  NSPredicate		*back;

  variable = [NSExpression expressionForVariable: @"x"];
  keyPath = [NSExpression expressionForKeyPath: @"age"];
  friends = [NSExpression expressionForKeyPath: @"friends"];
  colleagues = [NSExpression expressionForKeyPath: @"colleagues"];

  composition = [NSExpression expressionForKeyPathCompositionWithLeft: variable
    right: keyPath];
  testRoundTrip(composition, "a key path composition");
  testRoundTrip([NSExpression expressionForUnionSet: friends with: colleagues],
    "a union");
  testRoundTrip([NSExpression expressionForIntersectSet: friends
    with: colleagues], "an intersection");
  testRoundTrip([NSExpression expressionForMinusSet: friends with: colleagues],
    "a difference");

  predicate = [NSComparisonPredicate
    predicateWithLeftExpression: composition
    rightExpression: [NSExpression expressionForConstantValue:
      [NSNumber numberWithInt: 40]]
    modifier: NSDirectPredicateModifier
    type: NSGreaterThanPredicateOperatorType
    options: 0];
  back = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: predicate]];
  PASS_EQUAL([back predicateFormat], [predicate predicateFormat],
    "a predicate holding a key path composition survives an archive");

  [arp release];
  return 0;
}
