#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSExpression.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

/* Every kind of expression answers -expressionType with its own kind.  The
 * shared expression behind +expressionForEvaluatedObject used to answer
 * with the kind whose value is zero, NSConstantValueExpressionType.
 */
int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSExpression		*evaluated;
  NSExpression		*constant;
  NSExpression		*keyPath;
  NSExpression		*variable;
  NSExpression		*function;
  NSPredicate		*predicate;

  evaluated = [NSExpression expressionForEvaluatedObject];
  constant = [NSExpression expressionForConstantValue: @"x"];
  keyPath = [NSExpression expressionForKeyPath: @"name"];
  variable = [NSExpression expressionForVariable: @"v"];
  function = [NSExpression expressionForFunction: @"count:"
    arguments: [NSArray arrayWithObject: keyPath]];

  PASS([evaluated expressionType] == NSEvaluatedObjectExpressionType,
    "+expressionForEvaluatedObject answers NSEvaluatedObjectExpressionType");
  PASS([constant expressionType] == NSConstantValueExpressionType,
    "a constant answers NSConstantValueExpressionType");
  PASS([keyPath expressionType] == NSKeyPathExpressionType,
    "a key path answers NSKeyPathExpressionType");
  PASS([variable expressionType] == NSVariableExpressionType,
    "a variable answers NSVariableExpressionType");
  PASS([function expressionType] == NSFunctionExpressionType,
    "a function answers NSFunctionExpressionType");

  /* The same expression as the parser builds it. */
  predicate = [NSPredicate predicateWithFormat: @"SELF == %@", @"x"];
  PASS([[(NSComparisonPredicate *)predicate leftExpression] expressionType]
    == NSEvaluatedObjectExpressionType,
    "SELF parsed from a format answers NSEvaluatedObjectExpressionType");

  PASS_EQUAL([evaluated expressionValueWithObject: @"hello" context: nil],
    @"hello", "SELF evaluates to the object it is given");

  [arp release];
  return 0;
}
