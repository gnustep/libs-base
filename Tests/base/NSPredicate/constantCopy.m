#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSExpression.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSCompoundPredicate.h"
#import "Foundation/NSComparisonPredicate.h"

/* A value that cannot be copied, as a managed object cannot.  A predicate
 * that compares with one (department == %@) must still copy: the copy
 * shares its constants, as it does on macOS.
 */
@interface NotCopyable : NSObject
@end
@implementation NotCopyable
@end

int main(void)
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NotCopyable           *value = [[NotCopyable new] autorelease];
  NSMutableArray        *list = [NSMutableArray arrayWithObject: @"a"];
  NSExpression          *constant;
  NSExpression          *copied = nil;
  NSComparisonPredicate *comparison;
  NSComparisonPredicate *copiedComparison = nil;
  NSPredicate           *compound;
  NSPredicate           *copiedCompound = nil;

  constant = [NSExpression expressionForConstantValue: value];
  PASS_RUNS(copied = [[constant copy] autorelease],
    "a constant expression whose value cannot be copied can be copied")
  PASS([copied constantValue] == value,
    "the copy shares the constant value")

  comparison = (NSComparisonPredicate *)[NSPredicate
    predicateWithFormat: @"department == %@", value];
  PASS_RUNS(copiedComparison = [[comparison copy] autorelease],
    "a predicate with such a constant can be copied")
  PASS([[copiedComparison rightExpression] constantValue] == value,
    "the copied predicate compares with the same object")
  PASS([copiedComparison evaluateWithObject:
    [NSDictionary dictionaryWithObject: value forKey: @"department"]],
    "the copied predicate matches what the original matches")

  compound = [NSCompoundPredicate andPredicateWithSubpredicates:
    [NSArray arrayWithObjects: comparison,
      [NSPredicate predicateWithFormat: @"name IN %@", list], nil]];
  PASS_RUNS(copiedCompound = [[compound copy] autorelease],
    "a compound predicate with such a constant can be copied")
  PASS([[(NSCompoundPredicate *)copiedCompound subpredicates] count] == 2,
    "the copied compound predicate keeps its subpredicates")

  copied = [[[NSExpression expressionForConstantValue: list] copy] autorelease];
  PASS([copied constantValue] == list,
    "a mutable constant is shared too, not copied")

  [arp release];
  return 0;
}
