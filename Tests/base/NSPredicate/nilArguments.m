#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  START_SET("a nil argument for %@ is nil")
  NSDictionary          *ada;
  NSDictionary          *none;
  NSPredicate           *p = nil;
  NSExpression          *e = nil;
  NSString              *missing = nil;

  ada = [NSDictionary dictionaryWithObjectsAndKeys:
    @"ada", @"name", @"london", @"city", nil];
  none = [NSDictionary dictionaryWithObjectsAndKeys:
    @"london", @"city", nil];

  PASS_RUNS((p = [NSPredicate predicateWithFormat: @"name == %@", missing]),
    "a predicate takes a nil argument")
  PASS_EQUAL([p predicateFormat],
    [[NSPredicate predicateWithFormat: @"name == nil"] predicateFormat],
    "and compares with nil, as written out")
  PASS([p evaluateWithObject: none], "matching an object without the value")
  PASS(![p evaluateWithObject: ada], "and not one with it")

  PASS_RUNS((p = [NSPredicate predicateWithFormat: @"%K == %@",
    @"name", missing]), "after a key")
  PASS([p evaluateWithObject: none], "the same")

  PASS_RUNS((p = [NSPredicate predicateWithFormat:
    @"name == %@ AND city == %@", missing, @"london"]),
    "an argument after a nil one")
  PASS([p evaluateWithObject: none], "is still its own")

  PASS_RUNS((e = [NSExpression expressionWithFormat: @"%@", missing]),
    "an expression takes a nil argument")
  PASS([e expressionType] == NSConstantValueExpressionType,
    "as a constant")

  END_SET("a nil argument for %@ is nil")
  return 0;
}
