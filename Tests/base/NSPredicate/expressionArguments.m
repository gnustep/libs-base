#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  START_SET("an expression given for %@ is that expression")
  NSExpression          *path = [NSExpression expressionForKeyPath: @"tags"];
  NSExpression          *e;
  NSComparisonPredicate *p;
  NSDictionary          *ada;

  ada = [NSDictionary dictionaryWithObjectsAndKeys:
    @"ada", @"name", [NSArray arrayWithObject: @"ada"], @"tags", nil];

  e = [NSExpression expressionWithFormat: @"%@", path];
  PASS(e == path, "a whole expression format is the argument itself")

  e = [NSExpression expressionWithFormat: @"uppercase:(%@)", path];
  PASS([[e arguments] count] == 1 && [[e arguments] objectAtIndex: 0] == path,
    "a function argument is the argument itself")
  e = [NSExpression expressionWithFormat: @"uppercase:(%@)",
    [NSExpression expressionForKeyPath: @"name"]];
  PASS_EQUAL([e expressionValueWithObject: ada context: nil], @"ADA",
    "and is evaluated as one")

  e = [NSExpression expressionWithFormat: @"%@"
                           argumentArray: [NSArray arrayWithObject: path]];
  PASS(e == path, "the same through an argument array")

  p = (NSComparisonPredicate *)[NSPredicate predicateWithFormat: @"%@ == 1",
    path];
  PASS([p leftExpression] == path, "a predicate's left side")

  p = (NSComparisonPredicate *)[NSPredicate predicateWithFormat: @"name IN %@",
    path];
  PASS([p rightExpression] == path, "a predicate's right side")
  PASS([p evaluateWithObject: ada], "and is evaluated as one")

  END_SET("an expression given for %@ is that expression")

  START_SET("anything else given for %@ is a constant")
  NSExpression          *path = [NSExpression expressionForKeyPath: @"tags"];
  NSExpression          *e;

  e = [NSExpression expressionWithFormat: @"%@", @"tags"];
  PASS([e expressionType] == NSConstantValueExpressionType
    && [[e constantValue] isEqual: @"tags"], "a string")

  e = [NSExpression expressionWithFormat: @"%@",
    [NSArray arrayWithObject: path]];
  PASS([e expressionType] == NSConstantValueExpressionType,
    "an array, even of expressions")

  e = [NSExpression expressionWithFormat: @"%d", 5];
  PASS([e expressionType] == NSConstantValueExpressionType
    && [[e constantValue] isEqual: [NSNumber numberWithInt: 5]], "a number")

  END_SET("anything else given for %@ is a constant")
  return 0;
}
