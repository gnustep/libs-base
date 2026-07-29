/* A compound predicate made with its own initialiser has to work, the way one
   made with the factory methods does.  The work is done by a subclass per
   type, so the initialiser has to hand back one of those.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCompoundPredicate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "ObjectTesting.h"

int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSArray *subs = [NSArray arrayWithObjects:
    [NSPredicate predicateWithFormat: @"name == 'a'"],
    [NSPredicate predicateWithFormat: @"size == 2"], nil];
  NSDictionary *object = [NSDictionary dictionaryWithObjectsAndKeys:
    @"a", @"name", [NSNumber numberWithInt: 2], @"size", nil];
  NSCompoundPredicate *and;
  NSCompoundPredicate *or;
  NSCompoundPredicate *not;

  and = AUTORELEASE([[NSCompoundPredicate alloc]
    initWithType: NSAndPredicateType subpredicates: subs]);
  or = AUTORELEASE([[NSCompoundPredicate alloc]
    initWithType: NSOrPredicateType subpredicates: subs]);
  not = AUTORELEASE([[NSCompoundPredicate alloc]
    initWithType: NSNotPredicateType
   subpredicates: [NSArray arrayWithObject:
                    [NSPredicate predicateWithFormat: @"name == 'b'"]]]);

  PASS([and compoundPredicateType] == NSAndPredicateType,
       "an and predicate keeps its type");
  PASS([or compoundPredicateType] == NSOrPredicateType,
       "an or predicate keeps its type");
  PASS([not compoundPredicateType] == NSNotPredicateType,
       "a not predicate keeps its type");

  PASS([[and subpredicates] count] == 2, "the subpredicates are kept");

  PASS([and predicateFormat] != nil, "an and predicate can be written out");
  PASS([or predicateFormat] != nil, "an or predicate can be written out");
  PASS([not predicateFormat] != nil, "a not predicate can be written out");
  PASS([and description] != nil, "an and predicate describes itself");

  PASS([and evaluateWithObject: object], "both parts hold, so and is true");
  PASS([or evaluateWithObject: object], "one part holds, so or is true");
  PASS([not evaluateWithObject: object],
       "the part does not hold, so not is true");

  {
    NSCompoundPredicate *unmet;

    unmet = AUTORELEASE([[NSCompoundPredicate alloc]
      initWithType: NSAndPredicateType
     subpredicates: [NSArray arrayWithObject:
                      [NSPredicate predicateWithFormat: @"name == 'b'"]]]);
    PASS(![unmet evaluateWithObject: object],
         "a part that does not hold makes and false");
  }

  PASS_EQUAL([and predicateFormat],
             [[NSCompoundPredicate andPredicateWithSubpredicates: subs]
               predicateFormat],
             "it reads the same as one made by the factory method");
  PASS_EQUAL(and, [NSCompoundPredicate andPredicateWithSubpredicates: subs],
             "it is equal to one made by the factory method");

  {
    BOOL raised = NO;

    NS_DURING
      {
        [[NSCompoundPredicate alloc] initWithType: (NSCompoundPredicateType)99
                                    subpredicates: subs];
      }
    NS_HANDLER
      {
        raised = YES;
      }
    NS_ENDHANDLER
    PASS(raised == YES, "a type that names no predicate raises");
  }

  [arp release];
  return 0;
}
