/* An expression can be archived and read back, which a predicate editor needs
   since its row templates hold expressions and are stored in a nib.  The
   archive is written the way OS X writes it, so that one written here can be
   read there and the other way about.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

static id
roundTrip(id object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];

  return [NSKeyedUnarchiver unarchiveObjectWithData: data];
}

/* The class names an archive of the object holds. */
static NSArray *
classNames(id object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];
  NSDictionary *plist;
  NSMutableArray *names = [NSMutableArray array];

  plist = [NSPropertyListSerialization propertyListWithData: data
                                                    options: 0
                                                     format: NULL
                                                      error: NULL];
  for (id entry in [plist objectForKey: @"$objects"])
    {
      if ([entry isKindOfClass: [NSDictionary class]]
        && [entry objectForKey: @"$classname"] != nil)
        {
          [names addObject: [entry objectForKey: @"$classname"]];
        }
    }

  return names;
}

/* Whether anything in an archive holds the given value under the given key. */
static BOOL
archiveHolds(id object, NSString *key, id value)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];
  NSDictionary *plist;

  plist = [NSPropertyListSerialization propertyListWithData: data
                                                    options: 0
                                                     format: NULL
                                                      error: NULL];
  for (id entry in [plist objectForKey: @"$objects"])
    {
      if ([entry isKindOfClass: [NSDictionary class]])
        {
          id held = [entry objectForKey: key];

          /* A value is written as a reference to the string holding it. */
          if ([held isKindOfClass: [NSDictionary class]])
            {
              NSUInteger index;

              index = [[held objectForKey: @"CF$UID"] unsignedIntegerValue];
              held = [[plist objectForKey: @"$objects"] objectAtIndex: index];
            }
          if ([held isEqual: value])
            {
              return YES;
            }
        }
    }

  return NO;
}

/* The dictionary an archive holds for the object itself. */
static NSDictionary *
archivedObject(id object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject: object];
  NSDictionary *plist;

  plist = [NSPropertyListSerialization propertyListWithData: data
                                                    options: 0
                                                     format: NULL
                                                      error: NULL];
  return [[plist objectForKey: @"$objects"] objectAtIndex: 1];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSExpression *e;

  /* A constant. */
  e = [NSExpression expressionForConstantValue: @"hello"];
  PASS_EQUAL(roundTrip(e), e, "a constant expression survives being archived");
  PASS([classNames(e) containsObject: @"NSConstantValueExpression"],
       "and is named the way OS X names it");
  PASS([[archivedObject(e) allKeys] containsObject: @"NSConstantValue"]
       && [[archivedObject(e) allKeys] containsObject: @"NSExpressionType"],
       "under the keys OS X writes");

  e = [NSExpression expressionForConstantValue: [NSNumber numberWithInt: 42]];
  PASS_EQUAL([roundTrip(e) constantValue], [NSNumber numberWithInt: 42],
             "a constant number comes back as it went in");

  /* The object being evaluated. */
  e = [NSExpression expressionForEvaluatedObject];
  PASS_EQUAL(roundTrip(e), e, "the evaluated object expression survives");
  PASS([classNames(e) containsObject: @"NSSelfExpression"],
       "and is named the way OS X names it");

  /* A variable. */
  e = [NSExpression expressionForVariable: @"v"];
  PASS_EQUAL(roundTrip(e), e, "a variable expression survives");
  PASS([classNames(e) containsObject: @"NSVariableExpression"],
       "and is named the way OS X names it");

  /* A key path, single and dotted. */
  e = [NSExpression expressionForKeyPath: @"name"];
  PASS_EQUAL(roundTrip(e), e, "a key path expression survives");
  PASS_EQUAL([roundTrip(e) keyPath], @"name", "with its key path");
  PASS([classNames(e) containsObject: @"NSKeyPathExpression"],
       "and is named the way OS X names it");
  PASS([classNames(e) containsObject: @"NSKeyPathSpecifierExpression"],
       "with the key path held by a specifier, as OS X holds it");

  e = [NSExpression expressionForKeyPath: @"a.b"];
  PASS_EQUAL([roundTrip(e) keyPath], @"a.b", "a dotted key path survives");

  /* A function. */
  e = [NSExpression expressionForFunction: @"sum:"
                                arguments: [NSArray arrayWithObject:
                                  [NSExpression expressionForKeyPath: @"n"]]];
  PASS_EQUAL(roundTrip(e), e, "a function expression survives");
  PASS([classNames(e) containsObject: @"NSFunctionExpression"],
       "and is named the way OS X names it");
  PASS(archiveHolds(e, @"NSSelectorName", @"sum:"),
       "under the name of the selector it calls");
  PASS(archiveHolds(e, @"NSConstantValueClassName", @"_NSPredicateUtilities"),
       "standing on the class OS X puts the functions on");

  /* An aggregate. */
  e = [NSExpression expressionForAggregate: ([NSArray arrayWithObjects:
    [NSExpression expressionForConstantValue: [NSNumber numberWithInt: 1]],
    [NSExpression expressionForConstantValue: [NSNumber numberWithInt: 2]],
    nil])];
  PASS_EQUAL(roundTrip(e), e, "an aggregate expression survives");
  PASS([classNames(e) containsObject: @"NSAggregateExpression"],
       "and is named the way OS X names it");

  /* A collection of them, which is what a row template holds. */
  {
    NSArray *list = [NSArray arrayWithObjects:
      [NSExpression expressionForKeyPath: @"name"],
      [NSExpression expressionForKeyPath: @"size"], nil];

    PASS_EQUAL(roundTrip(list), list,
               "a list of expressions survives being archived");
  }

  [arp release];
  return 0;
}
