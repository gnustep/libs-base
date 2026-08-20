/* A function expression is named with its trailing colon on OS X, as in
   'sum:', and two of the functions are known there under names this library
   implements under another one.  Code written against the documented names
   could not build an expression here at all.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

static NSExpression *
functionOfString(NSString *name, NSString *string)
{
  return [NSExpression expressionForFunction: name
                                   arguments:
    [NSArray arrayWithObject:
      [NSExpression expressionForConstantValue: string]]];
}

static NSExpression *
functionOf(NSString *name, NSArray *numbers)
{
  return [NSExpression expressionForFunction: name
                                   arguments:
    [NSArray arrayWithObject:
      [NSExpression expressionForConstantValue: numbers]]];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSArray *numbers = [NSArray arrayWithObjects:
    [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 2],
    [NSNumber numberWithInt: 3], nil];
  NSExpression *e;

  e = functionOf(@"sum:", numbers);
  PASS(e != nil, "a function named with its colon builds an expression");
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 6.0,
       "and it adds the numbers up");
  PASS_EQUAL([e function], @"sum:", "the name is kept as it was given");

  e = functionOf(@"sum", numbers);
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 6.0,
       "the name without a colon is still taken");

  e = functionOf(@"average:", numbers);
  PASS(e != nil, "the name OS X gives the average builds an expression");
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 2.0,
       "and it averages the numbers");

  e = functionOf(@"avg", numbers);
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 2.0,
       "the name it has always had here is still taken");

  e = functionOf(@"count:", numbers);
  PASS([[e expressionValueWithObject: nil context: nil] intValue] == 3,
       "count takes its colon too");

  e = functionOf(@"max:", numbers);
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 3.0,
       "so does max");

  e = functionOf(@"min:", numbers);
  PASS([[e expressionValueWithObject: nil context: nil] doubleValue] == 1.0,
       "so does min");

  e = functionOfString(@"uppercase:", @"Hello");
  PASS_EQUAL([e expressionValueWithObject: nil context: nil], @"HELLO",
       "uppercase: uppercases its argument");

  e = functionOfString(@"lowercase:", @"Hello");
  PASS_EQUAL([e expressionValueWithObject: nil context: nil], @"hello",
       "lowercase: lowercases its argument");

  e = [NSExpression expressionForFunction: @"now" arguments: [NSArray array]];
  {
    id value = [e expressionValueWithObject: nil context: nil];

    PASS([value isKindOfClass: [NSDate class]]
      && [value timeIntervalSinceNow] > -60.0
      && [value timeIntervalSinceNow] < 60.0,
      "now returns the current date");
  }

  e = [NSExpression expressionWithFormat: @"uppercase:('Hello')"];
  PASS_EQUAL([e function], @"uppercase:",
       "the colon form of a call parses as a function");
  PASS_EQUAL([e expressionValueWithObject: nil context: nil], @"HELLO",
       "and the parsed function evaluates");

  e = [NSExpression expressionWithFormat: @"now()"];
  PASS([[e expressionValueWithObject: nil context: nil]
           isKindOfClass: [NSDate class]],
       "now() parses in a format string");

  e = [NSExpression expressionWithFormat: @"%@", @"Hello"];
  PASS([e expressionType] == NSConstantValueExpressionType
    && [[e constantValue] isEqual: @"Hello"],
       "a string given for %%@ substitutes as a constant, not a key path");

  e = [NSExpression expressionWithFormat: @"uppercase:(%@)", @"Hello"];
  PASS_EQUAL([e function], @"uppercase:",
       "a %%@ argument parses inside a function call");
  PASS_EQUAL([e expressionValueWithObject: nil context: nil], @"HELLO",
       "and the substituted constant is what the function receives");

  e = [NSExpression expressionWithFormat: @"uppercase:(%K)", @"name"];
  PASS_EQUAL([e expressionValueWithObject:
    [NSDictionary dictionaryWithObject: @"Hello" forKey: @"name"]
                                  context: nil], @"HELLO",
       "a %%K argument substitutes as a key path");

  {
    BOOL raised = NO;

    NS_DURING
      {
        functionOf(@"nosuchfunction:", numbers);
      }
    NS_HANDLER
      {
        raised = YES;
      }
    NS_ENDHANDLER
    PASS(raised == YES, "a name that no function answers to still raises");
  }

  [arp release];
  return 0;
}
