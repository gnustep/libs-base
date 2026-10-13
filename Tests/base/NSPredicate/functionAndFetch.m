#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

/* Stands in for what Core Data would pass as a fetch request and a managed
 * object context: this library knows neither, and sends the two methods a
 * context answers.
 */
@interface FetchStub : NSObject
{
  id    _request;
  int   _calls;
}
- (NSArray *) executeFetchRequest: (id)request error: (NSError **)error;
- (NSUInteger) countForFetchRequest: (id)request error: (NSError **)error;
- (id) requestFor: (NSString *)name;
- (NSString *) shout: (NSString *)text;
- (NSString *) joining: (NSString *)a with: (NSString *)b;
- (NSUInteger) answer;
- (id) lastRequest;
@end

@implementation FetchStub
- (NSArray *) executeFetchRequest: (id)request error: (NSError **)error
{
  ASSIGN(_request, request);
  return [NSArray arrayWithObjects: @"one", @"two", @"three", nil];
}
- (NSUInteger) countForFetchRequest: (id)request error: (NSError **)error
{
  ASSIGN(_request, request);
  return 3;
}
- (id) requestFor: (NSString *)name
{
  return [@"request:" stringByAppendingString: name];
}
- (NSString *) shout: (NSString *)text
{
  return [text uppercaseString];
}
- (NSString *) joining: (NSString *)a with: (NSString *)b
{
  return [NSString stringWithFormat: @"%@+%@", a, b];
}
- (NSUInteger) answer
{
  return 42;
}
- (id) lastRequest
{
  return _request;
}
@end

int main(void)
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  FetchStub             *stub = AUTORELEASE([FetchStub new]);
  NSMutableDictionary   *context;
  NSExpression          *e;
  id                     v;

  context = [NSMutableDictionary dictionaryWithObject: stub forKey: @"stub"];

  /* A selector sent to the object a variable stands for. */
  e = [NSExpression expressionForFunction:
    [NSExpression expressionForVariable: @"stub"]
                             selectorName: @"shout:"
                                arguments: [NSArray arrayWithObject:
                                  [NSExpression expressionForConstantValue: @"ada"]]];
  PASS([e expressionType] == NSFunctionExpressionType,
    "a selector function expression is a function expression");
  PASS_EQUAL([e function], @"shout:", "its function is the selector name");
  PASS_EQUAL([[e operand] variable], @"stub", "its operand is the receiver");
  PASS_EQUAL(([e expressionValueWithObject: nil context: context]), @"ADA",
    "it sends the selector to the receiver");

  /* Two arguments, one per colon. */
  e = [NSExpression expressionForFunction:
    [NSExpression expressionForVariable: @"stub"]
                             selectorName: @"joining:with:"
                                arguments: [NSArray arrayWithObjects:
                                  [NSExpression expressionForConstantValue: @"a"],
                                  [NSExpression expressionForConstantValue: @"b"], nil]];
  PASS_EQUAL(([e expressionValueWithObject: nil context: context]), @"a+b",
    "every colon takes an argument");

  /* A result that is not an object comes back as a number. */
  e = [NSExpression expressionForFunction:
    [NSExpression expressionForVariable: @"stub"]
                             selectorName: @"answer"
                                arguments: nil];
  PASS_EQUAL(([e expressionValueWithObject: nil context: context]),
    [NSNumber numberWithUnsignedInteger: 42],
    "a scalar result is answered as a number");

  /* Written and read back the way OS X writes it. */
  e = [NSExpression expressionForFunction:
    [NSExpression expressionForVariable: @"stub"]
                             selectorName: @"shout:"
                                arguments: [NSArray arrayWithObject:
                                  [NSExpression expressionForConstantValue: @"ada"]]];
  /* OS X writes a space before that comma, and prints a string constant in
   * quotes where this library prints it bare - the quoting is what every
   * constant here does, not this expression's doing.
   */
  PASS_EQUAL([e description], @"FUNCTION($stub, \"shout:\" , ada)",
    "it prints as OS X prints it");
  e = [NSExpression expressionWithFormat: @"FUNCTION($stub, 'shout:', 'ada')"];
  PASS([e expressionType] == NSFunctionExpressionType,
    "FUNCTION(...) parses");
  PASS_EQUAL(([e expressionValueWithObject: nil context: context]), @"ADA",
    "and evaluates");

  v = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: e]];
  PASS_EQUAL(([v expressionValueWithObject: nil context: context]), @"ADA",
    "and survives an archive");

  /* A named function still is one: the archive of those carries a class
   * where this one carries a receiver.
   */
  e = [NSExpression expressionWithFormat: @"uppercase:('ada')"];
  v = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: e]];
  PASS_EQUAL(([v expressionValueWithObject: nil context: nil]), @"ADA",
    "a named function is unaffected");

  /* A fetch request run against a context.  Core Data declares the type
   * this answers, and names it NSFetchRequestExpressionType; its value is
   * 50, which is what an archive carries.
   */
  e = [NSExpression expressionForFetch:
    [NSExpression expressionForConstantValue: @"the request"]
                                context: [NSExpression expressionForConstantValue: stub]
                              countOnly: NO];
  PASS([e expressionType] == (NSExpressionType)50,
    "a fetch expression has the type Core Data gives it");
  PASS([e isCountOnlyRequest] == NO, "and knows it is not a count");
  PASS_EQUAL([[e requestExpression] constantValue], @"the request",
    "and keeps the request");
  PASS_EQUAL(([e expressionValueWithObject: nil context: nil]),
    ([NSArray arrayWithObjects: @"one", @"two", @"three", nil]),
    "it executes the request against the context");
  PASS_EQUAL([stub lastRequest], @"the request",
    "the context was given the request");

  e = [NSExpression expressionForFetch:
    [NSExpression expressionForConstantValue: @"the request"]
                                context: [NSExpression expressionForConstantValue: stub]
                              countOnly: YES];
  PASS_EQUAL(([e expressionValueWithObject: nil context: nil]),
    [NSNumber numberWithUnsignedInteger: 3],
    "counting answers a number");

  /* The shape Core Data's mapping models are written in: a request the
   * context's own method builds, fetched from that same context.
   */
  e = [NSExpression expressionWithFormat:
    @"FETCH(FUNCTION($stub, 'requestFor:', 'Note'), FUNCTION($stub, 'self'), NO)"];
  PASS([e expressionType] == (NSExpressionType)50, "FETCH(...) parses");
  PASS_EQUAL(([e expressionValueWithObject: nil context: context]),
    ([NSArray arrayWithObjects: @"one", @"two", @"three", nil]),
    "and evaluates, request and context and all");
  PASS_EQUAL([stub lastRequest], @"request:Note",
    "the request came from the inner function");

  v = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: e]];
  PASS([v isCountOnlyRequest] == NO, "a fetch expression survives an archive");
  PASS_EQUAL(([v expressionValueWithObject: nil context: context]),
    ([NSArray arrayWithObjects: @"one", @"two", @"three", nil]),
    "and evaluates afterwards");

  [arp release];
  return 0;
}
