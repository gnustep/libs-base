/* On OS X the arithmetic operators are functions named add:to:,
   from:subtract:, multiply:by:, divide:by: and raise:toPower:, which is
   what a parsed 'a + b' answers to -function, what a keyed archive of it
   holds, and what code that builds such an expression names.  There is
   modulus:by: too, with no operator.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

static NSExpression *
function(NSString *name)
{
  return [NSExpression expressionForFunction: name
                                   arguments:
    [NSArray arrayWithObjects: [NSExpression expressionForKeyPath: @"a"],
      [NSExpression expressionForKeyPath: @"b"], nil]];
}

static double
valueOf(NSExpression *e, NSDictionary *object)
{
  return [[e expressionValueWithObject: object context: nil] doubleValue];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSDictionary *object = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt: 8], @"a", [NSNumber numberWithInt: 2], @"b", nil];
  NSExpression *e;
  NSData *archive;

  e = function(@"add:to:");
  PASS(valueOf(e, object) == 10.0, "add:to: adds");
  PASS_EQUAL([e function], @"add:to:", "and keeps the name it was given");
  PASS_EQUAL([e description], @"a + b", "and is written as an operator");
  PASS(valueOf(function(@"from:subtract:"), object) == 6.0,
    "from:subtract: subtracts the second from the first");
  PASS(valueOf(function(@"multiply:by:"), object) == 16.0,
    "multiply:by: multiplies");
  PASS(valueOf(function(@"divide:by:"), object) == 4.0,
    "divide:by: divides");
  PASS(valueOf(function(@"raise:toPower:"), object) == 64.0,
    "raise:toPower: raises to a power");
  PASS_EQUAL([function(@"raise:toPower:") description], @"a ** b",
    "and is written as an operator");
  PASS(valueOf(function(@"modulus:by:"), object) == 0.0,
    "modulus:by: is the remainder");
  PASS(valueOf(function(@"_add"), object) == 10.0,
    "the name used here before is still taken");

  e = [NSExpression expressionWithFormat: @"a + b"];
  PASS_EQUAL([e function], @"add:to:", "a parsed + is add:to:");
  PASS_EQUAL([[NSExpression expressionWithFormat: @"a - b"] function],
    @"from:subtract:", "a parsed - is from:subtract:");
  PASS_EQUAL([[NSExpression expressionWithFormat: @"a * b"] function],
    @"multiply:by:", "a parsed * is multiply:by:");
  PASS_EQUAL([[NSExpression expressionWithFormat: @"a / b"] function],
    @"divide:by:", "a parsed / is divide:by:");
  PASS_EQUAL([[NSExpression expressionWithFormat: @"a ** b"] function],
    @"raise:toPower:", "a parsed ** is raise:toPower:");
  PASS_EQUAL([[NSExpression expressionWithFormat: @"a + b * 2"] description],
    @"a + (b * 2)", "nested operators are written as they were");

  archive = [NSKeyedArchiver archivedDataWithRootObject: e];
  PASS([archive rangeOfData: [@"add:to:" dataUsingEncoding: NSUTF8StringEncoding]
    options: 0 range: NSMakeRange(0, [archive length])].location != NSNotFound,
    "a keyed archive names the function as OS X does");
  e = [NSKeyedUnarchiver unarchiveObjectWithData: archive];
  PASS(valueOf(e, object) == 10.0, "and the archive reads back");

  [arp release];
  return 0;
}
