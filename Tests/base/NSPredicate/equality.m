/* Expressions and predicates that describe the same thing are equal, as they
   are on OS X.  Without this an expression can only be found in a collection
   by identity, which is what -[NSArray containsObject:] and
   -[NSArray indexOfObject:] are given to work with.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSExpression *keyA = [NSExpression expressionForKeyPath: @"name"];
  NSExpression *keyB = [NSExpression expressionForKeyPath: @"name"];
  NSExpression *keyC = [NSExpression expressionForKeyPath: @"other"];
  NSExpression *conA = [NSExpression expressionForConstantValue: @"x"];
  NSExpression *conB = [NSExpression expressionForConstantValue: @"x"];
  NSExpression *conC = [NSExpression expressionForConstantValue: @"y"];
  NSExpression *varA = [NSExpression expressionForVariable: @"v"];
  NSExpression *varB = [NSExpression expressionForVariable: @"v"];
  NSExpression *funA = [NSExpression expressionForFunction: @"sum"
                                                 arguments:
                          [NSArray arrayWithObject: keyA]];
  NSExpression *funB = [NSExpression expressionForFunction: @"sum"
                                                 arguments:
                          [NSArray arrayWithObject: keyB]];
  NSExpression *selfA = [NSExpression expressionForEvaluatedObject];
  NSExpression *selfB = [NSExpression expressionForEvaluatedObject];

  PASS([keyA isEqual: keyB], "key path expressions of the same path are equal");
  PASS(![keyA isEqual: keyC], "key path expressions of other paths differ");
  PASS([keyA hash] == [keyB hash], "equal key path expressions hash alike");

  PASS([conA isEqual: conB], "constant expressions of the same value are equal");
  PASS(![conA isEqual: conC], "constant expressions of other values differ");
  PASS([conA hash] == [conB hash], "equal constant expressions hash alike");

  PASS(![keyA isEqual: conA], "a key path is not a constant");

  PASS([varA isEqual: varB], "variable expressions of the same name are equal");
  PASS([funA isEqual: funB], "function expressions of the same call are equal");
  PASS([selfA isEqual: selfB], "the evaluated object expression is one thing");

  PASS([[NSArray arrayWithObject: keyA] containsObject: keyB],
       "an equal key path expression is found in an array");
  PASS([[NSArray arrayWithObject: conA] indexOfObject: conB] == 0,
       "an equal constant expression is found in an array");

  {
    NSPredicate *p1 = [NSPredicate predicateWithFormat: @"name == 'x'"];
    NSPredicate *p2 = [NSPredicate predicateWithFormat: @"name == 'x'"];
    NSPredicate *p3 = [NSPredicate predicateWithFormat: @"name == 'y'"];
    NSPredicate *p4 = [NSPredicate predicateWithFormat: @"name ==[c] 'x'"];
    NSPredicate *p5 = [NSPredicate predicateWithFormat: @"name CONTAINS 'x'"];
    NSPredicate *c1 = [NSPredicate predicateWithFormat: @"a == 1 AND b == 2"];
    NSPredicate *c2 = [NSPredicate predicateWithFormat: @"a == 1 AND b == 2"];
    NSPredicate *c3 = [NSPredicate predicateWithFormat: @"a == 1 OR b == 2"];

    PASS([p1 isEqual: p2], "comparison predicates of the same shape are equal");
    PASS(![p1 isEqual: p3], "a different constant makes a different predicate");
    PASS(![p1 isEqual: p4], "different options make a different predicate");
    PASS(![p1 isEqual: p5], "a different operator makes a different predicate");
    PASS([p1 hash] == [p2 hash], "equal comparison predicates hash alike");

    PASS([c1 isEqual: c2], "compound predicates of the same shape are equal");
    PASS(![c1 isEqual: c3], "a different compound type makes a different predicate");
    PASS([c1 hash] == [c2 hash], "equal compound predicates hash alike");
    PASS(![c1 isEqual: p1], "a compound predicate is not a comparison");

    PASS([[NSPredicate predicateWithValue: YES]
           isEqual: [NSPredicate predicateWithValue: YES]],
         "the predicate that is always true is one thing");
    PASS(![[NSPredicate predicateWithValue: YES]
            isEqual: [NSPredicate predicateWithValue: NO]],
         "the predicates that are always true and always false differ");
  }

  [arp release];
  return 0;
}
