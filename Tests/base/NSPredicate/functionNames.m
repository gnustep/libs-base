/* A function expression is named with its trailing colon on OS X, as in
   'sum:', and two of the functions are known there under names this library
   implements under another one.  Code written against the documented names
   could not build an expression here at all.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

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
