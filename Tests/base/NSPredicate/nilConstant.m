#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  START_SET("a nil constant reads back as nil")
  NSDictionary          *named;
  NSDictionary          *unnamed;
  NSPredicate           *p;
  NSPredicate           *again;

  named = [NSDictionary dictionaryWithObject: @"ada" forKey: @"title"];
  unnamed = [NSDictionary dictionary];

  PASS_EQUAL([[NSExpression expressionForConstantValue: nil] description],
    @"nil", "a nil constant prints as nil")
  PASS_EQUAL([[NSExpression expressionForConstantValue: [NSNull null]]
    description], @"nil", "and so does a null one")

  p = [NSPredicate predicateWithFormat: @"title != nil"];
  PASS_EQUAL([p predicateFormat], @"title != nil",
    "a predicate comparing with nil prints it so")

  again = [NSPredicate predicateWithFormat: [p predicateFormat]];
  PASS(again != nil, "and the format parses back")
  PASS([again evaluateWithObject: named]
    && ![again evaluateWithObject: unnamed],
    "to a predicate that means the same")

  p = [NSPredicate predicateWithFormat: @"title == NULL"];
  PASS([[p predicateFormat] hasSuffix: @" nil"],
    "NULL is printed as nil too")

  END_SET("a nil constant reads back as nil")
  return 0;
}
