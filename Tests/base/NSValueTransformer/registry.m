/*
 * registry.m - tests for NSValueTransformer behaviour basic.m does not cover:
 * the name registry (setValueTransformer:forName:, valueTransformerForName:,
 * valueTransformerNames), the allowsReverseTransformation metadata, and that
 * reverseTransformedValue: on a non-reversible transformer raises.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSValueTransformer registry")
    NSValueTransformer	*neg = [NSValueTransformer valueTransformerForName:
      NSNegateBooleanTransformerName];

    PASS([NSValueTransformer valueTransformerForName: @"NoSuchTransformer"] == nil,
      "valueTransformerForName: of an unknown name is nil");

    [NSValueTransformer setValueTransformer: neg forName: @"MyNegate"];
    PASS([NSValueTransformer valueTransformerForName: @"MyNegate"] == neg,
      "a registered transformer is returned by valueTransformerForName:");
    PASS([[NSValueTransformer valueTransformerNames]
      containsObject: @"MyNegate"] == YES,
      "valueTransformerNames lists a registered name");
  END_SET("NSValueTransformer registry")

  START_SET("NSValueTransformer reverse metadata")
    NSValueTransformer	*neg = [NSValueTransformer valueTransformerForName:
      NSNegateBooleanTransformerName];
    NSValueTransformer	*isNil = [NSValueTransformer valueTransformerForName:
      NSIsNilTransformerName];

    PASS([[neg class] allowsReverseTransformation] == YES,
      "NSNegateBoolean allows reverse transformation");
    PASS([[isNil class] allowsReverseTransformation] == NO,
      "NSIsNil does not allow reverse transformation");

    PASS_EXCEPTION(({ [isNil reverseTransformedValue: @""]; }),
      NSGenericException,
      "reverseTransformedValue: on a non-reversible transformer raises");
  END_SET("NSValueTransformer reverse metadata")

  return 0;
}
